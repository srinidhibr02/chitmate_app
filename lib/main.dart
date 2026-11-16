import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/repository.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firebase_auth_service.dart';
import 'services/reminders.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Without Firebase settings the app still runs, on this device only and
  // without a login. This keeps development possible before setup is done.
  AuthService? auth;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    auth = FirebaseAuthService();
  } catch (e) {
    debugPrint('Firebase is not set up, running without login: $e');
  }

  final state = AppState(
    repository: LocalRepository(),
    reminders: LocalReminderService(),
    auth: auth,
  );
  runApp(ChitMateApp(state: state));
  // Loading continues behind the animated splash screen.
  await state.init();
}
