/// Where ChitMate keeps its data.
///
/// Version 1 stores everything on the organiser's phone. The [ChitRepository]
/// interface is the seam for a cloud backend later (so members can vote from
/// their own phones): implement it against Firebase/Supabase and pass it to
/// `AppState`; nothing else changes.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

/// The person using this phone (the organiser / admin).
class Profile {
  Profile({required this.name});

  String name;

  Map<String, dynamic> toJson() => <String, dynamic>{'name': name};

  factory Profile.fromJson(Map<String, dynamic> j) =>
      Profile(name: (j['name'] as String?) ?? '');
}

/// Everything that is saved.
class AppData {
  AppData({this.profile, List<ChitGroup>? groups, this.recoveredFromError = false})
      : groups = groups ?? <ChitGroup>[];

  Profile? profile;
  final List<ChitGroup> groups;

  /// True when saved data could not be read and a backup copy was kept.
  final bool recoveredFromError;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': 1,
        'profile': profile?.toJson(),
        'groups': groups.map((g) => g.toJson()).toList(),
      };

  factory AppData.fromJson(Map<String, dynamic> j) {
    final p = j['profile'];
    return AppData(
      profile: p is Map ? Profile.fromJson(p.cast<String, dynamic>()) : null,
      groups: ((j['groups'] as List?) ?? const <Object?>[])
          .map((e) => ChitGroup.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

abstract class ChitRepository {
  Future<AppData> load();
  Future<void> save(AppData data);
}

/// Keeps data in memory only. Used in tests; round-trips through JSON so
/// tests also exercise saving and loading.
class InMemoryRepository implements ChitRepository {
  InMemoryRepository({String? initialJson}) : _json = initialJson;

  String? _json;
  int saveCount = 0;

  /// The raw saved text (null when nothing has been saved).
  String? get savedJson => _json;

  @override
  Future<AppData> load() async {
    final raw = _json;
    if (raw == null) return AppData();
    try {
      return AppData.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return AppData(recoveredFromError: true);
    }
  }

  @override
  Future<void> save(AppData data) async {
    saveCount++;
    _json = jsonEncode(data.toJson());
  }
}

/// Saves to the phone with `shared_preferences`.
class LocalRepository implements ChitRepository {
  static const String _key = 'chitmate.data.v1';
  static const String _backupKey = 'chitmate.data.unreadable';

  @override
  Future<AppData> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return AppData();
    try {
      return AppData.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      // Keep the unreadable text so it is never silently lost.
      await prefs.setString(_backupKey, raw);
      return AppData(recoveredFromError: true);
    }
  }

  @override
  Future<void> save(AppData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(data.toJson()));
  }
}
