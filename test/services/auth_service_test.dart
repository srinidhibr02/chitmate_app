import 'package:chit_mate/services/auth_service.dart';
import 'package:chit_mate/services/firebase_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signing in with the right code reports the user and keeps them', () async {
    final auth = FakeAuthService();
    expect(auth.currentUser, isNull);
    expect(await auth.userChanges.first, isNull);

    final challenge = await auth.sendCode('+919876543210');
    expect(auth.sent, <String>['+919876543210']);
    final user = await auth.confirmCode(challenge, '123456');
    expect(user.phone, '+919876543210');
    expect(auth.currentUser, user);
    // A later listener (for example after the app restarts) sees the user at once.
    expect(await auth.userChanges.first, user);
  });

  test('a wrong code is refused and nobody is signed in', () async {
    final auth = FakeAuthService();
    final challenge = await auth.sendCode('+919876543210');
    await expectLater(
      auth.confirmCode(challenge, '000000'),
      throwsA(isA<AuthException>()),
    );
    expect(auth.currentUser, isNull);
  });

  test('sending can fail with a readable message', () async {
    final auth = FakeAuthService()..sendFailure = 'No internet';
    await expectLater(
      auth.sendCode('+919876543210'),
      throwsA(isA<AuthException>().having((e) => e.message, 'message', 'No internet')),
    );
  });

  test('signing out clears the user and tells listeners', () async {
    final auth = FakeAuthService(
      initialUser: const AppUser(uid: 'u1', phone: '+919876543210'),
    );
    final seen = <AppUser?>[];
    final sub = auth.userChanges.listen(seen.add);
    await Future<void>.delayed(Duration.zero);
    await auth.signOut();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen.first?.uid, 'u1');
    expect(seen.last, isNull);
    expect(auth.currentUser, isNull);
  });

  test('Firebase error codes become plain language', () {
    expect(FirebaseAuthService.friendlyMessage('invalid-phone-number'), contains('phone number'));
    expect(FirebaseAuthService.friendlyMessage('invalid-verification-code'), contains('not right'));
    expect(FirebaseAuthService.friendlyMessage('too-many-requests'), contains('Too many'));
    expect(FirebaseAuthService.friendlyMessage('network-request-failed'), contains('internet'));
    expect(FirebaseAuthService.friendlyMessage('operation-not-allowed'), contains('not turned on'));
    expect(FirebaseAuthService.friendlyMessage('invalid-app-credential'), contains('verified'));
    expect(FirebaseAuthService.friendlyMessage('something-new'), contains('something-new'));
  });
}
