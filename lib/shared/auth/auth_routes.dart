import 'package:go_router/go_router.dart';

import 'auth_blocked_screen.dart';
import 'auth_login_screen.dart';
import 'auth_otp_screen.dart';
import 'auth_phone_screen.dart';
import 'auth_register_screen.dart';
import 'auth_rejected_screen.dart';
import 'auth_terms_screen.dart';
import 'auth_under_review_screen.dart';

/// The shared auth screens (spec §3) that every role's registration/login
/// flow routes through — Splash/Onboarding live elsewhere, already built in
/// Phase 0. Paths and names are final: [sessionRedirect] depends on them,
/// and Vendor/Driver/Manager's own role-specific registration flows (a
/// later agent's work, living under `/${role}/register/...`) hand off to
/// `/auth/otp` and `/auth/terms` as their generic final steps.
List<RouteBase> get authRoutes => [
  GoRoute(
    path: '/auth/phone',
    name: 'authPhone',
    builder: (context, state) =>
        AuthPhoneScreen(mode: state.uri.queryParameters['mode'] ?? 'login'),
  ),
  GoRoute(
    path: '/auth/otp',
    name: 'authOtp',
    redirect: (context, state) => state.extra is OtpScreenArgs
        ? null
        : '/auth/phone?mode=${state.uri.queryParameters['mode'] ?? 'login'}',
    builder: (context, state) => AuthOtpScreen(
      args: state.extra as OtpScreenArgs,
      mode: state.uri.queryParameters['mode'] ?? 'login',
    ),
  ),
  GoRoute(
    path: '/auth/login',
    name: 'authLogin',
    builder: (context, state) => const AuthLoginScreen(),
  ),
  GoRoute(
    path: '/auth/register',
    name: 'authRegister',
    builder: (context, state) => const AuthRegisterScreen(),
  ),
  GoRoute(
    path: '/auth/terms',
    name: 'authTerms',
    builder: (context, state) =>
        AuthTermsScreen(mode: state.uri.queryParameters['mode'] ?? 'register'),
  ),
  GoRoute(
    path: '/auth/under-review',
    name: 'authUnderReview',
    builder: (context, state) => const AuthUnderReviewScreen(),
  ),
  GoRoute(
    path: '/auth/rejected',
    name: 'authRejected',
    builder: (context, state) => const AuthRejectedScreen(),
  ),
  GoRoute(
    path: '/auth/blocked',
    name: 'authBlocked',
    builder: (context, state) => const AuthBlockedScreen(),
  ),
];
