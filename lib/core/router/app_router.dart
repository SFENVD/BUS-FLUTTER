import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_home_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/driver/presentation/driver_home_page.dart';
import '../../features/passenger/presentation/passenger_home_page.dart';
import '../providers/app_mode_provider.dart';
import '../providers/auth_provider.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      final mode = ref.read(appModeControllerProvider);
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final isLogin = location == AppRoutes.login;
      final isAuthenticated = authState.isAuthenticated;
      final isModeMatched = authState.user?.role == mode.role;

      if (!isAuthenticated || !isModeMatched) {
        return isLogin ? null : AppRoutes.login;
      }

      if (isLogin || !_isLocationAllowedForMode(location, mode.homeLocation)) {
        return mode.homeLocation;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) =>
            ref.read(appModeControllerProvider).homeLocation,
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.passenger,
        builder: (context, state) => const PassengerHomePage(),
      ),
      GoRoute(
        path: AppRoutes.driver,
        builder: (context, state) => const DriverHomePage(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminHomePage(),
      ),
    ],
  );

  ref.listen(appModeControllerProvider, (_, _) => router.refresh());
  ref.listen(
    authControllerProvider.select((auth) => (auth.user?.id, auth.user?.role)),
    (_, _) => router.refresh(),
  );
  ref.onDispose(router.dispose);
  return router;
});

bool _isLocationAllowedForMode(String location, String homeLocation) {
  return location == homeLocation || location.startsWith('$homeLocation/');
}
