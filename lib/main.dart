import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/models/app_mode.dart';
import 'core/providers/app_mode_provider.dart';
import 'core/services/backend_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeBackend();

  const rawMode = String.fromEnvironment('APP_MODE', defaultValue: 'passenger');
  final initialMode = AppMode.fromValue(rawMode);

  runApp(
    ProviderScope(
      overrides: [initialAppModeProvider.overrideWithValue(initialMode)],
      child: const AppRoot(),
    ),
  );
}
