import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/models/app_mode.dart';
import 'core/providers/app_mode_provider.dart';
import 'core/persistence/demo_persistence.dart';
import 'core/persistence/demo_persistence_factory.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const rawMode = String.fromEnvironment('APP_MODE', defaultValue: 'passenger');
  final initialMode = AppMode.fromValue(rawMode);

  runApp(
    ProviderScope(
      overrides: [
        initialAppModeProvider.overrideWithValue(initialMode),
        demoPersistenceProvider.overrideWith((ref) {
          final store = createDemoPersistence();
          ref.onDispose(store.dispose);
          return store;
        }),
      ],
      child: const AppRoot(),
    ),
  );
}
