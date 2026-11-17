import 'package:chit_mate/app.dart';
import 'package:chit_mate/data/repository.dart';
import 'package:chit_mate/services/auth_service.dart';
import 'package:chit_mate/services/cloud_store.dart';
import 'package:chit_mate/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const AppUser asha = AppUser(uid: 'u-asha', phone: '+919876500001');

Future<AppState> signedInState(FakeAuthService auth, InMemoryCloudStore cloud) async {
  final s = AppState(
    repository: InMemoryRepository(),
    auth: auth,
    cloud: cloud,
    actions: testActions(),
    clock: () => kToday,
  );
  await s.init();
  await s.completeOnboarding('Asha');
  await s.createGroup(createdAt: kToday, name: 'Friends', chitValue: 10000);
  await s.flush();
  await Future<void>.delayed(Duration.zero);
  return s;
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-settings')));
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('settings shows who is signed in and the help entries', (tester) async {
    final s = await signedInState(FakeAuthService(initialUser: asha), InMemoryCloudStore());
    await tester.pumpWidget(ChitMateApp(state: s));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await openSettings(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Asha'), findsWidgets);
    expect(find.text('+919876500001'), findsOneWidget);
    for (final key in <String>['open-faq', 'contact-support', 'send-feedback', 'sign-out', 'delete-account']) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('the FAQ opens and answers open on tap', (tester) async {
    final s = await signedInState(FakeAuthService(initialUser: asha), InMemoryCloudStore());
    await tester.pumpWidget(ChitMateApp(state: s));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await openSettings(tester);
    await tapKey(tester, 'open-faq');
    expect(find.text('Does ChitMate handle my money?'), findsOneWidget);
    await tester.tap(find.text('Does ChitMate handle my money?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Money moves between the people'), findsOneWidget);
  });

  testWidgets('the name can be changed from settings', (tester) async {
    final s = await signedInState(FakeAuthService(initialUser: asha), InMemoryCloudStore());
    await tester.pumpWidget(ChitMateApp(state: s));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await openSettings(tester);
    await tapKey(tester, 'edit-name');
    await tester.enterText(find.byKey(const Key('name-field')), 'Asha K');
    await tapKey(tester, 'save-name');
    expect(s.profile?.name, 'Asha K');
  });

  testWidgets('signing out asks first and returns to the login screen', (tester) async {
    final auth = FakeAuthService(initialUser: asha);
    final s = await signedInState(auth, InMemoryCloudStore());
    await tester.pumpWidget(ChitMateApp(state: s));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await openSettings(tester);
    await tapKey(tester, 'sign-out');
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(s.needsLogin, isTrue);
    expect(find.text('Welcome to ChitMate'), findsOneWidget);
  });

  testWidgets('deleting the account needs a fresh code and then removes everything', (tester) async {
    final auth = FakeAuthService(initialUser: asha);
    final cloud = InMemoryCloudStore();
    final s = await signedInState(auth, cloud);
    final groupId = s.groups.single.id;
    await tester.pumpWidget(ChitMateApp(state: s));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await openSettings(tester);
    await tapKey(tester, 'delete-account');

    // Nothing happens until a code is entered.
    expect(find.byKey(const Key('confirm-delete')), findsNothing);
    await tapKey(tester, 'send-delete-code');
    expect(auth.sent, <String>[asha.phone]);
    expect(cloud.contains(groupId), isTrue);

    // A wrong code deletes nothing.
    await tester.enterText(find.byKey(const Key('delete-code-field')), '111111');
    await tapKey(tester, 'confirm-delete');
    expect(find.text('That code is not right. Check it and try again.'), findsOneWidget);
    expect(cloud.contains(groupId), isTrue);
    expect(auth.deleted, 0);

    // The right code deletes the account and lands on the login screen.
    await tester.enterText(find.byKey(const Key('delete-code-field')), '123456');
    await tapKey(tester, 'confirm-delete');
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(auth.deleted, 1);
    expect(cloud.contains(groupId), isFalse);
    expect(find.text('Welcome to ChitMate'), findsOneWidget);
  });
}
