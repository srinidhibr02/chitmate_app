import 'package:flutter/material.dart';

import 'app.dart';
import 'data/repository.dart';
import 'services/reminders.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(
    repository: LocalRepository(),
    reminders: LocalReminderService(),
  );
  runApp(ChitMateApp(state: state));
  // Loading continues behind the animated splash screen.
  await state.init();
}
