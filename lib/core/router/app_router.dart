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
  final mode = ref.watch(appModeControllerProvider);
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
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
      GoRoute(path: '/', redirect: (context, state) => mode.homeLocation),
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
});

bool _isLocationAllowedForMode(String location, String homeLocation) {
  return location == homeLocation || location.startsWith('$homeLocation/');
}
