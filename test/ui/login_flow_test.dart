import 'package:chit_mate/app.dart';
import 'package:chit_mate/data/repository.dart';
import 'package:chit_mate/services/auth_service.dart';
import 'package:chit_mate/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

Future<AppState> signedOutState(FakeAuthService auth, {InMemoryRepository? repo}) async {
  final s = AppState(
    repository: repo ?? InMemoryRepository(),
    auth: auth,
    actions: testActions(),
    clock: () => kToday,
  );
  await s.init();
  return s;
}

void main() {
  test('without a session the app asks for login; a session is remembered', () async {
    final auth = FakeAuthService();
    final repo = InMemoryRepository();
    final s = await signedOutState(auth, repo: repo);
    expect(s.authReady, isTrue);
    expect(s.needsLogin, isTrue);

    final challenge = await auth.sendCode('+919876543210');
    await auth.confirmCode(challenge, '123456');
    await Future<void>.delayed(Duration.zero);
    expect(s.needsLogin, isFalse);
    expect(s.user?.phone, '+919876543210');

    // "Restart": a new AppState on the same sign-in is logged in straight away.
    final again = await signedOutState(auth, repo: repo);
    expect(again.needsLogin, isFalse);

    await again.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(again.needsLogin, isTrue);
  });

  test('with no auth service the app never asks for login', () async {
    final s = AppState(repository: InMemoryRepository(), clock: () => kToday);
    await s.init();
    expect(s.needsLogin, isFalse);
    expect(s.authReady, isTrue);
  });

  testWidgets('login screen: bad number, wrong code, then success', (tester) async {
    final auth = FakeAuthService();
    final s = await signedOutState(auth);
    await s.completeOnboarding('Asha');
    await tester.pumpWidget(ChitMateApp(state: s));
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Welcome to ChitMate'), findsOneWidget);

    // Too short.
    await tester.enterText(find.byKey(const Key('phone-field')), '12345');
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid 10-digit mobile number.'), findsOneWidget);
    expect(auth.sent, isEmpty);

    // Valid number.
    await tester.enterText(find.byKey(const Key('phone-field')), '9876543210');
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(auth.sent, <String>['+919876543210']);
    expect(find.text('Enter the code'), findsOneWidget);

    // Wrong code is refused (entering 6 digits submits by itself).
    await tester.enterText(find.byKey(const Key('code-field')), '111111');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('That code is not right. Check it and try again.'), findsOneWidget);
    expect(s.needsLogin, isTrue);

    // Right code signs in and leaves the login screen.
    await tester.enterText(find.byKey(const Key('code-field')), '123456');
    await tester.pump();
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(s.needsLogin, isFalse);
    expect(find.text('Welcome to ChitMate'), findsNothing);
  });

  testWidgets('"Change number" goes back to the number step', (tester) async {
    final auth = FakeAuthService();
    final s = await signedOutState(auth);
    await tester.pumpWidget(ChitMateApp(state: s));
    await tester.pumpAndSettle(const Duration(seconds: 1));
    await tester.enterText(find.byKey(const Key('phone-field')), '9876543210');
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('change-number')));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('phone-field')), findsOneWidget);
  });
}
