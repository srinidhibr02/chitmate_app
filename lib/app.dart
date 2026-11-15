import 'package:flutter/material.dart';

import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'ui/screens/entry_screens.dart';

/// The whole app. Takes the [AppState] so tests can supply their own.
class ChitMateApp extends StatelessWidget {
  const ChitMateApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'ChitMate',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const RootGate(),
      ),
    );
  }
}
