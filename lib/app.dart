import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/app_mode_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appModeControllerProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: '校车管理系统',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(mode),
      routerConfig: router,
    );
  }
}
