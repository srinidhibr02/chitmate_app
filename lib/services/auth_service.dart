/// Phone-number sign-in. The app talks only to [AuthService]; Firebase is one
/// implementation ([FirebaseAuthService]) and tests use [FakeAuthService].
library;

import 'dart:async';

/// The signed-in person.
class AppUser {
  const AppUser({required this.uid, required this.phone});

  final String uid;

  /// E.164 format, for example +919876543210.
  final String phone;

  @override
  bool operator ==(Object other) =>
      other is AppUser && other.uid == uid && other.phone == phone;

  @override
  int get hashCode => Object.hash(uid, phone);
}

/// A sign-in problem with a message that is safe to show to the person.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A code that has been sent and is waiting to be confirmed.
class PhoneChallenge {
  const PhoneChallenge({required this.phone, this.handle});

  final String phone;

  /// Implementation detail (for Firebase, the confirmation result).
  final Object? handle;
}

abstract class AuthService {
  /// Emits the current user (or null) first, then every change. Because the
  /// sign-in is stored on the device, a returning user is emitted at start-up
  /// without being asked for a code again.
  Stream<AppUser?> get userChanges;

  AppUser? get currentUser;

  /// Sends a one-time code by SMS to [phoneE164].
  Future<PhoneChallenge> sendCode(String phoneE164);

  /// Checks the code and signs in.
  Future<AppUser> confirmCode(PhoneChallenge challenge, String code);

  Future<void> signOut();
}

/// In-memory sign-in for tests and local runs.
class FakeAuthService implements AuthService {
  FakeAuthService({AppUser? initialUser, this.validCode = '123456'}) : _user = initialUser;

  final String validCode;
  AppUser? _user;
  final StreamController<AppUser?> _controller = StreamController<AppUser?>.broadcast();

  /// Phone numbers a code was sent to, in order.
  final List<String> sent = <String>[];

  /// When set, [sendCode] fails with this message.
  String? sendFailure;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> get userChanges async* {
    yield _user;
    yield* _controller.stream;
  }

  @override
  Future<PhoneChallenge> sendCode(String phoneE164) async {
    final failure = sendFailure;
    if (failure != null) throw AuthException(failure);
    sent.add(phoneE164);
    return PhoneChallenge(phone: phoneE164);
  }

  @override
  Future<AppUser> confirmCode(PhoneChallenge challenge, String code) async {
    if (code != validCode) {
      throw const AuthException('That code is not right. Check it and try again.');
    }
    final user = AppUser(uid: 'uid-${challenge.phone}', phone: challenge.phone);
    _user = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _controller.add(null);
  }
}
