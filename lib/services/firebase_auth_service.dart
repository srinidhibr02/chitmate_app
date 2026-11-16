/// Firebase implementation of phone sign-in. Firebase keeps the session on
/// the device (and in the browser on the web), so people stay logged in.
library;

import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  static AppUser? _map(User? user) {
    if (user == null) return null;
    return AppUser(uid: user.uid, phone: user.phoneNumber ?? '');
  }

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> get userChanges => _auth.authStateChanges().map(_map);

  @override
  Future<PhoneChallenge> sendCode(String phoneE164) async {
    try {
      final result = await _auth.signInWithPhoneNumber(phoneE164);
      return PhoneChallenge(phone: phoneE164, handle: result);
    } on FirebaseAuthException catch (e) {
      throw AuthException(friendlyMessage(e.code));
    }
  }

  @override
  Future<AppUser> confirmCode(PhoneChallenge challenge, String code) async {
    final handle = challenge.handle;
    if (handle is! ConfirmationResult) {
      throw const AuthException('Please request a new code.');
    }
    try {
      final credential = await handle.confirm(code);
      final user = _map(credential.user);
      if (user == null) throw const AuthException('Sign-in did not complete. Please try again.');
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(friendlyMessage(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// Turns Firebase error codes into plain language.
  static String friendlyMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'That phone number does not look right.';
      case 'invalid-verification-code':
        return 'That code is not right. Check it and try again.';
      case 'session-expired':
      case 'code-expired':
        return 'That code has expired. Request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a while and try again.';
      case 'quota-exceeded':
        return 'We cannot send more codes right now. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'captcha-check-failed':
      case 'missing-client-identifier':
      case 'app-not-authorized':
        return 'This device could not be verified. Please try again.';
      default:
        return 'Sign-in failed ($code). Please try again.';
    }
  }
}
