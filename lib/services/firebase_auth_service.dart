/// Firebase implementation of phone sign-in. Firebase keeps the session on
/// the device (and in the browser on the web), so people stay logged in.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
      if (kIsWeb) {
        final result = await _auth.signInWithPhoneNumber(phoneE164);
        return PhoneChallenge(phone: phoneE164, handle: result);
      }
      // On phones the code is requested with verifyPhoneNumber, which reports
      // back through callbacks. Turn that into one awaited result.
      final completer = Completer<PhoneChallenge>();
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneE164,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android can sometimes verify the number by itself.
          try {
            await _auth.signInWithCredential(credential);
          } catch (_) {
            // The person can still type the code.
          }
          if (!completer.isCompleted) {
            completer.complete(PhoneChallenge(phone: phoneE164, handle: const _AutoVerified()));
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.completeError(AuthException(friendlyMessage(e.code)));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!completer.isCompleted) {
            completer.complete(
              PhoneChallenge(phone: phoneE164, handle: _SentCode(verificationId)),
            );
          }
        },
        codeAutoRetrievalTimeout: (String _) {},
      );
      return await completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw const AuthException(
          'No internet connection. Check your network and try again.',
        ),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(friendlyMessage(e.code));
    }
  }

  @override
  Future<AppUser> confirmCode(PhoneChallenge challenge, String code) async {
    final handle = challenge.handle;
    try {
      UserCredential credential;
      if (handle is ConfirmationResult) {
        credential = await handle.confirm(code);
      } else if (handle is _SentCode) {
        credential = await _auth.signInWithCredential(
          PhoneAuthProvider.credential(verificationId: handle.verificationId, smsCode: code),
        );
      } else if (handle is _AutoVerified) {
        final user = _map(_auth.currentUser);
        if (user != null) return user;
        throw const AuthException('Please request a new code.');
      } else {
        throw const AuthException('Please request a new code.');
      }
      final user = _map(credential.user);
      if (user == null) throw const AuthException('Sign-in did not complete. Please try again.');
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(friendlyMessage(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException('You are not signed in.');
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(friendlyMessage(e.code));
    }
  }

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
      case 'operation-not-allowed':
        return 'Phone sign-in is not turned on for this app yet.';
      case 'requires-recent-login':
        return 'For your safety, sign out, sign in again with a new code, and then delete '
            'your account straight away.';
      case 'quota-exceeded':
        return 'We cannot send more codes right now. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection. Check your network and try again.';
      case 'invalid-app-credential':
      case 'captcha-check-failed':
      case 'missing-client-identifier':
      case 'app-not-authorized':
        return 'This device could not be verified. Please try again.';
      default:
        return 'Sign-in failed ($code). Please try again.';
    }
  }
}

/// A code was sent; [verificationId] ties the typed code to that request.
class _SentCode {
  const _SentCode(this.verificationId);

  final String verificationId;
}

/// Android verified the number without a code being typed.
class _AutoVerified {
  const _AutoVerified();
}
