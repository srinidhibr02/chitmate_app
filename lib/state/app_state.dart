/// The app's single source of truth: the profile and every chit group.
///
/// Screens read groups from here and change them through [run], which checks
/// the rules, saves, reschedules reminders and refreshes the screen. If a rule
/// is broken half-way through a change, the group is rolled back untouched.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../data/repository.dart';
import '../domain/actions.dart';
import '../domain/models.dart';
import '../services/auth_service.dart';
import '../services/cloud_store.dart';
import '../services/reminders.dart';

class AppState extends ChangeNotifier {
  AppState({
    required ChitRepository repository,
    ReminderService? reminders,
    this.auth,
    this.cloud,
    ChitActions? actions,
    DateTime Function()? clock,
  })  : _repository = repository,
        _reminders = reminders ?? NoopReminderService(),
        actions = actions ?? ChitActions(clock: clock),
        _clock = clock ?? DateTime.now;

  final ChitRepository _repository;

  /// Phone sign-in. Null means the app runs without a login (tests, local use).
  final AuthService? auth;

  /// Shared database of groups. Null means groups live on this phone only.
  final CloudGroupStore? cloud;
  final ReminderService _reminders;
  final DateTime Function() _clock;

  /// The rules engine. Pass it to [run] closures.
  final ChitActions actions;

  bool _ready = false;
  bool _authReady = false;
  AppUser? _user;
  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<List<ChitGroup>>? _groupsSub;
  bool _cloudLoaded = false;

  /// Groups that were saved on this phone before sign-in existed. They are
  /// moved to the cloud, owned by the first person who signs in.
  final List<ChitGroup> _localOnly = <ChitGroup>[];
  final Set<Future<void>> _cloudSaves = <Future<void>>{};
  Profile? _profile;
  final List<ChitGroup> _groups = <ChitGroup>[];
  String? _notice;
  String? _saveProblem;
  Future<void> _saveChain = Future<void>.value();

  /// True once saved data has been loaded.
  bool get ready => _ready;

  Profile? get profile => _profile;

  /// The signed-in person, if sign-in is in use.
  AppUser? get user => _user;

  /// True once we know whether someone is already signed in.
  bool get authReady => auth == null || _authReady;

  bool get _useCloud => cloud != null && auth != null && _user != null;

  /// True while a signed-in person's groups are still being fetched.
  bool get loadingGroups => _useCloud && !_cloudLoaded;

  /// Only the organiser of a group may change it. Members can read it.
  bool canEdit(ChitGroup g) => !_useCloud || g.adminUid == null || g.adminUid == _user!.uid;

  /// Waits until every change has been handed to the database (for tests).
  Future<void> flush() async {
    await _saveChain;
    while (_cloudSaves.isNotEmpty) {
      await Future.wait(List<Future<void>>.of(_cloudSaves));
    }
  }

  /// True when sign-in is in use and nobody is signed in.
  bool get needsLogin => auth != null && _user == null;

  /// Name used as the author of changes ("Admin" until the person sets one).
  String get adminName {
    final n = _profile?.name.trim() ?? '';
    return n.isEmpty ? 'Admin' : n;
  }

  bool get needsOnboarding => _profile == null || _profile!.name.trim().isEmpty;

  List<ChitGroup> get groups => List<ChitGroup>.unmodifiable(_groups);

  /// A one-off message for the home screen (for example after a data problem).
  String? get notice => _notice;

  /// Set when the last save failed.
  String? get saveProblem => _saveProblem;

  DateTime get now => _clock();

  Future<void> init() async {
    await _reminders.init();
    try {
      final data = await _repository.load();
      _profile = data.profile;
      _groups
        ..clear()
        ..addAll(data.groups);
      if (data.recoveredFromError) {
        _notice = 'Some saved data could not be read. A backup copy was kept on this phone.';
      }
    } catch (e) {
      _notice = 'Saved data could not be loaded: $e';
    }
    if (cloud != null) {
      // With a shared database, groups come from there. Whatever was saved on
      // this phone earlier waits to be moved up after the first sign-in.
      _localOnly.addAll(_groups);
      _groups.clear();
    }
    _ready = true;
    notifyListeners();

    final a = auth;
    if (a != null) {
      _authSub = a.userChanges.listen(_onUser);
      try {
        _onUser(await a.userChanges.first.timeout(const Duration(seconds: 8)));
      } catch (_) {
        _onUser(a.currentUser);
      }
    }
    await _syncReminders();
  }

  void _onUser(AppUser? u) {
    final changed = _user?.uid != u?.uid;
    _user = u;
    _authReady = true;
    if (changed) _switchCloud();
    notifyListeners();
  }

  /// Starts (or stops) listening to the signed-in person's groups.
  void _switchCloud() {
    _groupsSub?.cancel();
    _groupsSub = null;
    _cloudLoaded = false;
    final c = cloud;
    if (c == null) return;
    _groups.clear();
    final u = _user;
    if (u == null) {
      _syncReminders();
      return;
    }
    _groupsSub = c.watchGroups(u).listen(
      _onCloudGroups,
      onError: (Object e) {
        _saveProblem = 'Could not load your groups: $e';
        _cloudLoaded = true;
        notifyListeners();
      },
    );
    _migrateLocalGroups(u);
  }

  void _onCloudGroups(List<ChitGroup> list) {
    _groups
      ..clear()
      ..addAll(list);
    _cloudLoaded = true;
    notifyListeners();
    _syncReminders();
  }

  /// Moves groups from before sign-in existed up to the cloud, owned by [u].
  void _migrateLocalGroups(AppUser u) {
    if (_localOnly.isEmpty) return;
    final moving = List<ChitGroup>.of(_localOnly);
    for (final g in moving) {
      g.adminUid = u.uid;
      if (g.members.isNotEmpty && g.members.first.phone == null) {
        g.members.first.phone = u.phone;
      }
    }
    _track(() async {
      try {
        for (final g in moving) {
          await cloud!.saveGroup(g);
        }
        _localOnly.removeWhere((g) => moving.contains(g));
        await _persist();
        _notice = moving.length == 1
            ? 'Your group from this phone is now saved to your account.'
            : '${moving.length} groups from this phone are now saved to your account.';
        notifyListeners();
      } catch (e) {
        _saveProblem = 'Could not move your groups to your account: $e';
        notifyListeners();
      }
    }());
  }

  void _track(Future<void> f) {
    _cloudSaves.add(f);
    f.whenComplete(() => _cloudSaves.remove(f));
  }

  /// Signs out. The saved data on this phone is kept.
  Future<void> signOut() async {
    await auth?.signOut();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _groupsSub?.cancel();
    super.dispose();
  }

  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  ChitGroup? groupById(String id) {
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  // ------------------------------------------------------------ profile --

  Future<String?> completeOnboarding(String name) async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return 'Enter your name.';
    if (clean.length > ChitActions.maxNameLength) {
      return 'Keep your name under ${ChitActions.maxNameLength} characters.';
    }
    _profile = Profile(name: clean);
    notifyListeners();
    await _persist();
    return null;
  }

  /// Changes the organiser's name. Returns an error message, or null.
  Future<String?> setProfileName(String name) => completeOnboarding(name);

  // ------------------------------------------------------------- groups --

  /// Creates a group and saves it. Returns an error message, or null.
  Future<String?> createGroup({
    required DateTime createdAt,
    String? name,
    int? chitValue,
    int? plannedMembers,
    void Function(ChitGroup created)? onCreated,
  }) async {
    final ChitGroup g;
    try {
      g = actions.createGroup(
        createdAt: createdAt,
        organiserName: adminName,
        organiserPhone: _user?.phone,
        adminUid: _useCloud ? _user!.uid : null,
        name: name,
        chitValue: chitValue,
        plannedMembers: plannedMembers,
      );
    } on RuleViolation catch (e) {
      return e.message;
    }
    _groups.insert(0, g);
    notifyListeners();
    onCreated?.call(g);
    await _save(g);
    return null;
  }

  Future<void> deleteGroup(String id) async {
    final g = groupById(id);
    if (g == null || !canEdit(g)) return;
    _groups.removeWhere((x) => x.id == id);
    notifyListeners();
    if (_useCloud) {
      _track(_cloudCall(() => cloud!.deleteGroup(id)));
      return;
    }
    await _persist();
  }

  /// Applies [change] to a group. Returns an error message when a rule is
  /// broken (the group is then left exactly as it was), otherwise null.
  Future<String?> run(String groupId, void Function(ChitGroup g) change) async {
    final index = _groups.indexWhere((g) => g.id == groupId);
    if (index < 0) return 'This group no longer exists.';
    if (!canEdit(_groups[index])) {
      return 'Only the organiser can change this group. You can see everything in it.';
    }
    final snapshot = jsonEncode(_groups[index].toJson());
    try {
      change(_groups[index]);
    } on RuleViolation catch (e) {
      _restore(groupId, snapshot);
      return e.message;
    } catch (e) {
      _restore(groupId, snapshot);
      return 'Something went wrong: $e';
    }
    notifyListeners();
    await _save(_groups[index]);
    return null;
  }

  void _restore(String groupId, String snapshot) {
    final i = _groups.indexWhere((g) => g.id == groupId);
    if (i < 0) return;
    _groups[i] = ChitGroup.fromJson((jsonDecode(snapshot) as Map).cast<String, dynamic>());
    notifyListeners();
  }

  // ---------------------------------------------------------- persisting --

  /// Saves a changed group: to the shared database when signed in (without
  /// waiting for the network), otherwise to this phone.
  Future<void> _save(ChitGroup g) {
    if (_useCloud) {
      _track(_cloudCall(() => cloud!.saveGroup(g)));
      return Future<void>.value();
    }
    return _persist();
  }

  /// Runs one database call, remembering a failure instead of throwing.
  Future<void> _cloudCall(Future<void> Function() call) async {
    try {
      await call();
      if (_saveProblem != null) {
        _saveProblem = null;
        notifyListeners();
      }
    } catch (e) {
      _saveProblem = 'Could not save: $e';
      notifyListeners();
    }
    await _syncReminders();
  }

  Future<void> _persist() {
    _saveChain = _saveChain.then((_) async {
      try {
        // With a shared database, only groups still waiting to be moved up are
        // kept on the phone, so one person's groups never stay behind for the
        // next person who signs in.
        await _repository.save(AppData(
          profile: _profile,
          groups: cloud != null ? List<ChitGroup>.of(_localOnly) : List<ChitGroup>.of(_groups),
        ));
        if (_saveProblem != null) {
          _saveProblem = null;
          notifyListeners();
        }
      } catch (e) {
        _saveProblem = 'Could not save: $e';
        notifyListeners();
      }
      await _syncReminders();
    });
    return _saveChain;
  }

  Future<void> _syncReminders() async {
    try {
      await _reminders.sync(List<ChitGroup>.of(_groups), _clock());
    } catch (_) {
      // Reminders are a convenience; never let them break saving.
    }
  }

  /// Asks the phone for notification permission (call from a button).
  Future<bool> enableReminders() => _reminders.requestPermission();
}

/// Makes the [AppState] available to every screen below it.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found above this widget.');
    return scope!.notifier!;
  }
}
