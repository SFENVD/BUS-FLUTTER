import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_mode.dart';
import '../../core/providers/app_mode_provider.dart';
import '../../core/providers/auth_provider.dart';

class AppModeSwitcher extends ConsumerWidget {
  const AppModeSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(appModeControllerProvider);

    return SegmentedButton<AppMode>(
      showSelectedIcon: false,
      selected: {currentMode},
      segments: AppMode.values.map((mode) {
        return ButtonSegment<AppMode>(
          value: mode,
          label: Text(mode.shortLabel),
          icon: Icon(_iconForMode(mode), size: 18),
        );
      }).toList(),
      onSelectionChanged: (selection) {
        final nextMode = selection.first;
        if (nextMode == currentMode) {
          return;
        }
        ref.read(authControllerProvider.notifier).logout();
        ref.read(appModeControllerProvider.notifier).switchTo(nextMode);
      },
    );
  }

  IconData _iconForMode(AppMode mode) {
    return switch (mode) {
      AppMode.passenger => Icons.person_pin_circle_outlined,
      AppMode.driver => Icons.directions_bus_filled_outlined,
      AppMode.admin => Icons.space_dashboard_outlined,
    };
  }
}
