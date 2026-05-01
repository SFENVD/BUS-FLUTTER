import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_mode.dart';

final initialAppModeProvider = Provider<AppMode>((ref) {
  return AppMode.passenger;
});

final appModeControllerProvider = NotifierProvider<AppModeController, AppMode>(
  AppModeController.new,
);

class AppModeController extends Notifier<AppMode> {
  @override
  AppMode build() {
    return ref.watch(initialAppModeProvider);
  }

  void switchTo(AppMode mode) {
    state = mode;
  }
}
