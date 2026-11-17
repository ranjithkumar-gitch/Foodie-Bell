import '../../data/models/account.dart';
import '../session/session_controller.dart';

const publicPathPrefixes = ['/splash', '/auth'];

AppRole? _roleFromPath(String path) {
  for (final role in AppRole.values) {
    if (path.startsWith('/${role.name}')) return role;
  }
  return null;
}

/// Central auth guard: every `/<role>/...` route requires an active session
/// for that exact role; everything else (splash/shared auth) is public.
/// Written once here rather than duplicated per role file, since
/// it's the one thing every role's routes depend on.
///
/// Exception: `/<role>/register/...` is reachable as soon as that role is
/// selected (`SessionController.selectRole`), before auth completes —
/// Vendor/Driver/Manager's own multi-step registration screens (business
/// details, Manager Code entry, documents, application form, ...) live
/// under their natural role path prefix but run pre-auth, unlike the rest
/// of `/<role>/*`.
/// Customer screens a guest may open without signing in (2026-11-17: browse
/// first, verify the phone only when it matters). Everything else under
/// `/user` — orders, checkout, profile, addresses, wallet, notifications —
/// asks for phone verification first.
const guestUserPaths = ['/user/home', '/user/cart', '/user/vendor/', '/user/search', '/user/help'];

bool isGuestUserPath(String path) =>
    guestUserPaths.any((p) => p.endsWith('/') ? path.startsWith(p) && !path.endsWith('/list-order') : path == p);

/// Where login sends a guest who tried to open [location]: phone
/// verification, then back to [location] (`auth_navigation.dart`).
String loginFor(String location) => '/auth/login?next=${Uri.encodeComponent(location)}';

String? sessionRedirect(String path, SessionState session, {String? location}) {
  if (publicPathPrefixes.any(path.startsWith)) return null;

  final roleForPath = _roleFromPath(path);
  if (roleForPath == null) return null;

  // A guest (nobody signed in) browses the customer app freely; anything
  // that needs an account asks to verify the phone first.
  if (roleForPath == AppRole.user && session.stage == AuthStage.unauthenticated && !path.startsWith('/user/register')) {
    return isGuestUserPath(path) ? null : loginFor(location ?? path);
  }

  if (path.startsWith('/${roleForPath.name}/register')) {
    return session.role == roleForPath ? null : '/auth/login';
  }

  if (session.role != roleForPath ||
      session.stage == AuthStage.unauthenticated) {
    return '/auth/login';
  }
  if (session.stage == AuthStage.pendingApproval) return '/auth/under-review';
  if (session.stage == AuthStage.rejected) return '/auth/rejected';
  if (session.stage == AuthStage.blocked) return '/auth/blocked';
  return null;
}
