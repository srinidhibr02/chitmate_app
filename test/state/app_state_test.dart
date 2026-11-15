import 'package:chit_mate/data/repository.dart';
import 'package:chit_mate/domain/actions.dart';
import 'package:chit_mate/domain/models.dart';
import 'package:chit_mate/services/reminders.dart';
import 'package:chit_mate/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

class _RecordingReminders implements ReminderService {
  int syncs = 0;
  List<ChitGroup> last = <ChitGroup>[];
  bool allow = true;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => allow;

  @override
  Future<void> sync(List<ChitGroup> groups, DateTime now) async {
    syncs++;
    last = groups;
  }
}

class _FailingRepository extends InMemoryRepository {
  @override
  Future<void> save(AppData data) async => throw StateError('disk full');
}

AppState makeState(InMemoryRepository repo, {ReminderService? reminders, int seed = 1}) {
  return AppState(
    repository: repo,
    reminders: reminders,
    actions: testActions(seed: seed),
    clock: () => kToday,
  );
}

void main() {
  test('a fresh install needs onboarding and saves the name', () async {
    final repo = InMemoryRepository();
    final s = makeState(repo);
    await s.init();
    expect(s.ready, isTrue);
    expect(s.needsOnboarding, isTrue);
    expect(s.adminName, 'Admin');

    expect(await s.completeOnboarding('   '), isNotNull);
    expect(await s.completeOnboarding('  Asha   Rao '), isNull);
    expect(s.adminName, 'Asha Rao');
    expect(s.needsOnboarding, isFalse);

    final again = makeState(repo);
    await again.init();
    expect(again.adminName, 'Asha Rao');
    expect(again.needsOnboarding, isFalse);
  });

  test('groups are created, changed and reloaded', () async {
    final repo = InMemoryRepository();
    final s = makeState(repo);
    await s.init();
    await s.completeOnboarding('Asha');
    ChitGroup? created;
    final err = await s.createGroup(
      createdAt: kToday,
      name: 'Friends',
      chitValue: 10000,
      onCreated: (g) => created = g,
    );
    expect(err, isNull);
    expect(created, isNotNull);
    expect(s.groups.length, 1);
    expect(s.groups.first.members.single.name, 'Asha');

    final id = s.groups.first.id;
    final changeErr = await s.run(id, (g) => s.actions.addMember(g, 'Ravi', actor: 'Asha'));
    expect(changeErr, isNull);

    final again = makeState(repo);
    await again.init();
    expect(again.groups.single.members.map((m) => m.name), <String>['Asha', 'Ravi']);
  });

  test('a rejected change leaves the group exactly as it was', () async {
    final repo = InMemoryRepository();
    final s = makeState(repo);
    await s.init();
    await s.completeOnboarding('Asha');
    await s.createGroup(createdAt: kToday, chitValue: 10000);
    final id = s.groups.first.id;
    await s.run(id, (g) => s.actions.addMember(g, 'Ravi', actor: 'Asha'));
    final before = s.groupById(id)!.toJson().toString();

    // Adds a member, then breaks a rule (duplicate name): nothing may stick.
    final err = await s.run(id, (g) {
      s.actions.addMember(g, 'Meena', actor: 'Asha');
      s.actions.addMember(g, 'ravi', actor: 'Asha');
    });
    expect(err, contains('already'));
    expect(s.groupById(id)!.toJson().toString(), before);
    expect(s.groupById(id)!.members.any((m) => m.name == 'Meena'), isFalse);
  });

  test('unexpected errors are reported and rolled back too', () async {
    final s = makeState(InMemoryRepository());
    await s.init();
    await s.completeOnboarding('Asha');
    await s.createGroup(createdAt: kToday);
    final id = s.groups.first.id;
    final err = await s.run(id, (g) {
      g.name = 'Changed';
      throw StateError('boom');
    });
    expect(err, contains('boom'));
    expect(s.groupById(id)!.name, isNot('Changed'));
  });

  test('running a change on a missing group is reported', () async {
    final s = makeState(InMemoryRepository());
    await s.init();
    expect(await s.run('nope', (g) {}), isNotNull);
  });

  test('locked values stay locked through the state layer', () async {
    final s = makeState(InMemoryRepository());
    await s.init();
    await s.completeOnboarding('Asha');
    await s.createGroup(createdAt: kToday, chitValue: 10000);
    final id = s.groups.first.id;
    await s.run(id, (g) {
      final a = s.actions;
      final r = a.addMember(g, 'Ravi', actor: 'x');
      final me = g.members.first;
      a.addChit(g, <String, int>{me.id: 10000}, actor: 'x');
      a.addChit(g, <String, int>{r.id: 10000}, actor: 'x');
      a.setFirstAnnouncementDate(g, DateTime(2026, 12, 1), actor: 'x');
      a.startCycle(g, actor: 'x');
    });
    expect(s.groupById(id)!.started, isTrue);
    final err = await s.run(id, (g) => s.actions.setChitValue(g, 20000, actor: 'x'));
    expect(err, contains('locked'));
    expect(s.groupById(id)!.chitValue, 10000);
  });

  test('deleting a group removes it for good', () async {
    final repo = InMemoryRepository();
    final s = makeState(repo);
    await s.init();
    await s.completeOnboarding('Asha');
    await s.createGroup(createdAt: kToday);
    await s.deleteGroup(s.groups.first.id);
    expect(s.groups, isEmpty);
    final again = makeState(repo);
    await again.init();
    expect(again.groups, isEmpty);
  });

  test('reminders are re-synced after every save', () async {
    final rec = _RecordingReminders();
    final s = makeState(InMemoryRepository(), reminders: rec);
    await s.init();
    final base = rec.syncs;
    await s.completeOnboarding('Asha');
    await s.createGroup(createdAt: kToday);
    expect(rec.syncs, greaterThan(base));
    expect(rec.last.length, 1);
    expect(await s.enableReminders(), isTrue);
    rec.allow = false;
    expect(await s.enableReminders(), isFalse);
  });

  test('a failing save is reported, not thrown', () async {
    final s = makeState(_FailingRepository());
    await s.init();
    await s.completeOnboarding('Asha');
    expect(s.saveProblem, contains('disk full'));
    expect(s.groups, isEmpty);
  });

  test('unreadable saved data is flagged and does not crash', () async {
    final s = makeState(InMemoryRepository(initialJson: '{not json'));
    await s.init();
    expect(s.ready, isTrue);
    expect(s.notice, isNotNull);
    s.clearNotice();
    expect(s.notice, isNull);
  });

  test('invalid group details are refused with a message', () async {
    final s = makeState(InMemoryRepository());
    await s.init();
    await s.completeOnboarding('Asha');
    final err = await s.createGroup(createdAt: kToday, chitValue: -5);
    expect(err, isNotNull);
    expect(s.groups, isEmpty);
    expect(ChitActions.maxChits, greaterThan(1));
  });
}
