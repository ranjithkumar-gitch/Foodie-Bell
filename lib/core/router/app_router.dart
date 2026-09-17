import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/driver/driver_routes.dart';
import '../../features/manager/manager_routes.dart';
import '../../features/user/splash/splash_screen.dart';
import '../../features/user/user_routes.dart';
import '../../features/vendor/vendor_routes.dart';
import '../../shared/auth/auth_routes.dart';
import '../session/session_controller.dart';
import 'session_redirect.dart';

/// Bridges Riverpod session state to go_router's `refreshListenable`, so a
/// login/logout/role-switch re-runs `redirect` without rebuilding (and
/// losing navigation stacks in) the router itself.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _ref.listen(sessionControllerProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;

  SessionState get session => _ref.read(sessionControllerProvider);
}

final _routerRefreshProvider = Provider<_RouterRefreshNotifier>(
  (ref) => _RouterRefreshNotifier(ref),
);

/// Root router. Composes each role's own `<role>_routes.dart` list — route
/// `name`s are prefixed per role (userX/vendorX/...) so files built
/// independently never collide.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(_routerRefreshProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) =>
        sessionRedirect(state.matchedLocation, refreshNotifier.session),
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      ...authRoutes,
      ...userRoutes,
      ...vendorRoutes,
      ...driverRoutes,
      ...managerRoutes,
    ],
  );
});
