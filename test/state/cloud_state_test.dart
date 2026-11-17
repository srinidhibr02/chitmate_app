import 'package:chit_mate/data/repository.dart';
import 'package:chit_mate/domain/models.dart';
import 'package:chit_mate/services/auth_service.dart';
import 'package:chit_mate/services/cloud_store.dart';
import 'package:chit_mate/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const AppUser asha = AppUser(uid: 'u-asha', phone: '+919876500001');
const AppUser ravi = AppUser(uid: 'u-ravi', phone: '+919876500002');

Future<AppState> makeState(
  FakeAuthService auth,
  InMemoryCloudStore cloud, {
  InMemoryRepository? repo,
}) async {
  final s = AppState(
    repository: repo ?? InMemoryRepository(),
    auth: auth,
    cloud: cloud,
    actions: testActions(),
    clock: () => kToday,
  );
  await s.init();
  await s.flush();
  await Future<void>.delayed(Duration.zero);
  return s;
}

Future<void> settle(AppState s) async {
  await s.flush();
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('signed-out: no groups are shown and login is needed', () async {
    final s = await makeState(FakeAuthService(), InMemoryCloudStore());
    expect(s.needsLogin, isTrue);
    expect(s.groups, isEmpty);
  });

  test('a group created while signed in is saved to the cloud, owned by the creator', () async {
    final cloud = InMemoryCloudStore();
    final s = await makeState(FakeAuthService(initialUser: asha), cloud);
    await s.completeOnboarding('Asha');
    expect(s.loadingGroups, isFalse);

    String? id;
    await s.createGroup(createdAt: kToday, name: 'Friends', chitValue: 10000, onCreated: (g) => id = g.id);
    await settle(s);

    final stored = cloud.peek(id!)!;
    expect(stored.adminUid, asha.uid);
    expect(stored.members.single.name, 'Asha');
    expect(stored.members.single.phone, asha.phone);
    expect(s.groups.single.id, id);
    expect(s.canEdit(s.groups.single), isTrue);
  });

  test('changes are saved to the cloud, and rule violations never reach it', () async {
    final cloud = InMemoryCloudStore();
    final s = await makeState(FakeAuthService(initialUser: asha), cloud);
    await s.completeOnboarding('Asha');
    String? id;
    await s.createGroup(createdAt: kToday, chitValue: 10000, onCreated: (g) => id = g.id);
    await settle(s);

    expect(await s.run(id!, (g) => s.actions.addMember(g, 'Ravi', phone: '9876500002', actor: 'Asha')), isNull);
    await settle(s);
    expect(cloud.peek(id!)!.members.map((m) => m.name), <String>['Asha', 'Ravi']);

    final savesBefore = cloud.saves;
    final err = await s.run(id!, (g) => s.actions.addMember(g, 'ravi', actor: 'Asha'));
    expect(err, isNotNull);
    await settle(s);
    expect(cloud.saves, savesBefore);
  });

  test('a member sees the group but cannot change it', () async {
    final cloud = InMemoryCloudStore();
    final authA = FakeAuthService(initialUser: asha);
    final a = await makeState(authA, cloud);
    await a.completeOnboarding('Asha');
    String? id;
    await a.createGroup(createdAt: kToday, name: 'Friends', chitValue: 10000, onCreated: (g) => id = g.id);
    await a.run(id!, (g) => a.actions.addMember(g, 'Ravi', phone: '9876500002', actor: 'Asha'));
    await settle(a);

    final r = await makeState(FakeAuthService(initialUser: ravi), cloud);
    expect(r.groups.single.name, 'Friends');
    expect(r.canEdit(r.groups.single), isFalse);
    final before = cloud.saves;
    final err = await r.run(id!, (g) => g.name = 'Hacked');
    expect(err, contains('Only the organiser'));
    await r.deleteGroup(id!);
    await settle(r);
    expect(cloud.saves, before);
    expect(cloud.contains(id!), isTrue);
    expect(cloud.peek(id!)!.name, 'Friends');
  });

  test('someone not in the group sees nothing; removed members lose the group', () async {
    final cloud = InMemoryCloudStore();
    final a = await makeState(FakeAuthService(initialUser: asha), cloud);
    await a.completeOnboarding('Asha');
    String? id;
    await a.createGroup(createdAt: kToday, chitValue: 10000, onCreated: (g) => id = g.id);
    await a.run(id!, (g) => a.actions.addMember(g, 'Ravi', phone: '9876500002', actor: 'Asha'));
    await settle(a);

    final stranger = await makeState(
      FakeAuthService(initialUser: const AppUser(uid: 'x', phone: '+919876500009')),
      cloud,
    );
    expect(stranger.groups, isEmpty);

    final r = await makeState(FakeAuthService(initialUser: ravi), cloud);
    expect(r.groups.length, 1);
    await a.run(id!, (g) {
      final m = g.members.firstWhere((x) => x.name == 'Ravi');
      a.actions.removeMember(g, m.id, actor: 'Asha');
    });
    await settle(a);
    await settle(r);
    expect(r.groups, isEmpty);
  });

  test('changes made elsewhere show up live', () async {
    final cloud = InMemoryCloudStore();
    final a = await makeState(FakeAuthService(initialUser: asha), cloud);
    await a.completeOnboarding('Asha');
    String? id;
    await a.createGroup(createdAt: kToday, name: 'Friends', chitValue: 10000, onCreated: (g) => id = g.id);
    await a.run(id!, (g) => a.actions.addMember(g, 'Ravi', phone: '9876500002', actor: 'Asha'));
    await settle(a);
    final r = await makeState(FakeAuthService(initialUser: ravi), cloud);

    await a.run(id!, (g) => a.actions.postAnnouncement(g, 'See you on the 1st', actor: 'Asha'));
    await settle(a);
    await settle(r);
    expect(r.groups.single.feed.last.text, 'See you on the 1st');
  });

  test('groups saved on the phone before sign-in move to the first person who signs in', () async {
    final repo = InMemoryRepository();
    // An older, local-only run of the app.
    final old = AppState(repository: repo, actions: testActions(), clock: () => kToday);
    await old.init();
    await old.completeOnboarding('Asha');
    await old.createGroup(createdAt: kToday, name: 'Old group', chitValue: 5000);
    expect(old.groups.single.adminUid, isNull);

    final cloud = InMemoryCloudStore();
    final auth = FakeAuthService();
    final s = await makeState(auth, cloud, repo: repo);
    expect(s.groups, isEmpty); // nothing shown until someone signs in

    final challenge = await auth.sendCode(asha.phone);
    await auth.confirmCode(challenge, '123456');
    await settle(s);
    await settle(s);

    expect(s.groups.single.name, 'Old group');
    expect(s.groups.single.adminUid, 'uid-${asha.phone}');
    expect(s.groups.single.members.first.phone, asha.phone);
    expect(s.notice, contains('saved to your account'));

    // Nothing is left on the phone, so the next person never sees it.
    final data = await repo.load();
    expect(data.groups, isEmpty);
  });

  test('signing out clears the groups from the screen', () async {
    final cloud = InMemoryCloudStore();
    final auth = FakeAuthService(initialUser: asha);
    final s = await makeState(auth, cloud);
    await s.completeOnboarding('Asha');
    await s.createGroup(createdAt: kToday, chitValue: 10000);
    await settle(s);
    expect(s.groups.length, 1);
    await s.signOut();
    await settle(s);
    expect(s.groups, isEmpty);
    expect(s.needsLogin, isTrue);
    expect(cloud.saves, greaterThan(0));
  });

  test('a failed save is reported, and the problem clears after the next success', () async {
    final cloud = InMemoryCloudStore();
    final s = await makeState(FakeAuthService(initialUser: asha), cloud);
    await s.completeOnboarding('Asha');
    String? id;
    await s.createGroup(createdAt: kToday, chitValue: 10000, onCreated: (g) => id = g.id);
    await settle(s);

    cloud.failWith = StateError('offline');
    await s.run(id!, (g) => s.actions.renameGroup(g, 'New name', actor: 'Asha'));
    await settle(s);
    expect(s.saveProblem, contains('offline'));

    cloud.failWith = null;
    await s.run(id!, (g) => s.actions.renameGroup(g, 'Newer name', actor: 'Asha'));
    await settle(s);
    expect(s.saveProblem, isNull);
    expect(cloud.peek(id!)!.name, 'Newer name');
  });

  test('deleting a group removes it from the cloud for the organiser', () async {
    final cloud = InMemoryCloudStore();
    final s = await makeState(FakeAuthService(initialUser: asha), cloud);
    await s.completeOnboarding('Asha');
    String? id;
    await s.createGroup(createdAt: kToday, chitValue: 10000, onCreated: (g) => id = g.id);
    await settle(s);
    await s.deleteGroup(id!);
    await settle(s);
    expect(cloud.contains(id!), isFalse);
    expect(s.groups, isEmpty);
    expect(RoundMethod.values, isNotEmpty);
  });

  test('deleting the account removes the groups you organise, the sign-in and local data', () async {
    final cloud = InMemoryCloudStore();
    final auth = FakeAuthService(initialUser: asha);
    final s = await makeState(auth, cloud);
    await s.completeOnboarding('Asha');
    String? id;
    await s.createGroup(createdAt: kToday, chitValue: 10000, onCreated: (g) => id = g.id);
    await settle(s);
    expect(cloud.contains(id!), isTrue);

    expect(await s.deleteAccount(), isNull);
    await settle(s);

    expect(cloud.contains(id!), isFalse);
    expect(auth.deleted, 1);
    expect(s.needsLogin, isTrue);
    expect(s.groups, isEmpty);
    expect(s.profile, isNull);
  });

  test('deleting the account leaves groups run by someone else alone', () async {
    final cloud = InMemoryCloudStore();
    final ashaState = await makeState(FakeAuthService(initialUser: asha), cloud);
    await ashaState.completeOnboarding('Asha');
    String? id;
    await ashaState.createGroup(createdAt: kToday, chitValue: 10000, onCreated: (g) => id = g.id);
    await settle(ashaState);
    expect(
      await ashaState.run(id!, (g) => ashaState.actions.addMember(g, 'Ravi', phone: '9876500002', actor: 'Asha')),
      isNull,
    );
    await settle(ashaState);

    final raviAuth = FakeAuthService(initialUser: ravi);
    final raviState = await makeState(raviAuth, cloud);
    await settle(raviState);
    expect(raviState.groups, hasLength(1));
    expect(await raviState.deleteAccount(), isNull);
    expect(cloud.contains(id!), isTrue);
    expect(raviAuth.deleted, 1);
  });

  test('a failed deletion reports why and can be tried again', () async {
    final cloud = InMemoryCloudStore();
    final auth = FakeAuthService(initialUser: asha)..deleteFailure = 'Sign in again first.';
    final s = await makeState(auth, cloud);
    await s.completeOnboarding('Asha');
    expect(await s.deleteAccount(), 'Sign in again first.');
    expect(s.needsLogin, isFalse);
    expect(s.profile, isNotNull);

    auth.deleteFailure = null;
    expect(await s.deleteAccount(), isNull);
    expect(s.needsLogin, isTrue);
  });
}
