import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/repository.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/cloud_store.dart';
import 'services/firestore_group_store.dart';
import 'services/firebase_auth_service.dart';
import 'services/reminders.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Without Firebase settings the app still runs, on this device only and
  // without a login. This keeps development possible before setup is done.
  AuthService? auth;
  CloudGroupStore? cloud;
  try {
    await _initFirebase();
    auth = FirebaseAuthService();
    cloud = FirestoreGroupStore();
  } catch (e) {
    debugPrint('Firebase is not set up, running without login: $e');
  }

  final state = AppState(
    repository: LocalRepository(),
    reminders: LocalReminderService(),
    auth: auth,
    cloud: cloud,
  );
  runApp(ChitMateApp(state: state));
  // Loading continues behind the animated splash screen.
  await state.init();
}

/// Starts Firebase. Uses lib/firebase_options.dart when `flutterfire configure`
/// has generated it. Otherwise falls back to the settings the build already
/// carries (android/app/google-services.json on Android, GoogleService-Info.plist
/// on iOS), so login works on a phone before that file exists.
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on UnsupportedError {
    await Firebase.initializeApp();
  }
}
