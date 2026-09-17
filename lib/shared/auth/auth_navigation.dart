import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../data/models/account.dart';
import '../../data/providers/firestore_drivers_provider.dart';
import '../../data/providers/firestore_managers_provider.dart';
import '../../data/providers/firestore_users_provider.dart';
import '../../data/providers/firestore_vendors_provider.dart';

/// After `completeLogin()`/`completeRegistration()` run, route by the
/// resulting session stage — shared by the OTP, Login, and Terms screens
/// (the three places auth actually completes) so they all land in the same
/// spot: active accounts go home, pending ones wait for review, rejected
/// ones see why.
void routeByStage(BuildContext context, AppRole role, AuthStage stage) {
  switch (stage) {
    case AuthStage.pendingApproval:
      context.go('/auth/under-review');
    case AuthStage.rejected:
      context.go('/auth/rejected');
    case AuthStage.blocked:
      context.go('/auth/blocked');
    case AuthStage.active:
      context.go('/${role.name}');
    case AuthStage.unauthenticated:
      // Defensive only — completeLogin()/completeRegistration() always set
      // a concrete stage, so this should be unreachable in practice.
      context.go('/auth/login');
  }
}

/// Resolves an [Account] by phone or email without knowing the role ahead
/// of time — each Firestore-backed role in turn (all four now phone-keyed —
/// see [findFirestoreManagerByPhone]'s doc comment for why Manager joined
/// Vendor/Driver/User here). `email` still resolves a Manager too (kept for
/// `splash_screen.dart` restoring a session still carrying one from before
/// Manager login moved to phone+OTP) — the unified sign-in screen just never
/// passes one anymore. Deliberately never checks the in-memory
/// `mockAccountsProvider`/`MockAccounts` seed data — login only ever
/// resolves a real, Firestore-backed account. Originally
/// `splash_screen.dart`'s own inline session-restore logic, extracted here
/// since the unified login screen (`auth_login_screen.dart`) and OTP screen
/// need the exact same cross-role lookup, not a role-scoped one — see
/// [completePhoneAuth]'s doc comment for how that one differs.
Future<Account?> resolveAccountAcrossRoles(
  WidgetRef ref, {
  String? phone,
  String? email,
}) async {
  Account? match;
  if (email != null) {
    match = await findFirestoreManagerByEmail(email);
  }
  if (match == null && phone != null) {
    match = await findFirestoreManagerByPhone(phone);
  }
  if (match == null && phone != null) {
    match = await findFirestoreVendorByPhone(phone);
  }
  if (match == null && phone != null) {
    match = await findFirestoreDriverByPhone(phone);
  }
  if (match == null && phone != null) {
    match = await findFirestoreUserByPhone(phone);
  }
  return match;
}

/// The final steps once an [Account] has been resolved for the unified
/// login screen's cross-role path (`role` wasn't known ahead of time) —
/// called by [completePhoneAuth]'s role-null branch below once OTP
/// verifies: [SessionController.selectRole] first (role is only now
/// known), then [SessionController.completeLogin], then routed by the
/// resulting stage.
void completeResolvedLogin(BuildContext context, WidgetRef ref, Account match) {
  ref.read(sessionControllerProvider.notifier).selectRole(match.role);
  ref.read(sessionControllerProvider.notifier).completeLogin(account: match);
  if (!context.mounted) return;
  routeByStage(context, match.role, ref.read(sessionControllerProvider).stage);
}

/// Runs once a phone credential has been verified — shared by
/// [AuthOtpScreen]'s manual code entry and [AuthPhoneScreen]'s Android
/// auto-verification path (`verificationCompleted`), so both land in the
/// same place without duplicating the login/registration handoff.
///
/// Every Firestore/Storage rule in this app gates on `request.auth != null`
/// (`firestore.rules`/`storage.rules`). While `kUseDynamicOtp` is off
/// (`otp_config.dart`), no real phone credential ever signs in — so without
/// this upfront anonymous sign-in, logging in would complete with *no*
/// Firebase Auth session at all, and every real Firestore/Storage read or
/// write behind it (Categories, Vendor's own product catalogue, product
/// photo uploads, ...) would come back permission-denied even though the UI
/// shows a signed-in user. A no-op once a real credential is already signed
/// in (`kUseDynamicOtp` on, or a returning session).
///
/// Register mode hands off to the shared Terms screen exactly as before —
/// nothing here changes for registration, since a phone sign-in already
/// covers "an account now exists" regardless of mode. (User's own
/// `userRegistrationDraftProvider.phone` — used to build the Firestore
/// `users` doc at `/auth/terms` — is staged earlier, at
/// `AuthPhoneScreen._sendOtp()`, not here; see that screen's doc comment.)
/// Login mode resolves the specific [Account] by phone number against
/// Firestore for Vendor/Driver/User specifically — a Vendor/Driver a
/// Manager created (`manager_vendor_create_screen.dart` /
/// `manager_driver_create_screen.dart`), or a User who self-registered
/// (`auth_terms_screen.dart`). Never checks `MockAccounts`/
/// `mockAccountsProvider` — same as [resolveAccountAcrossRoles], login only
/// ever resolves a real account.
///
/// [phoneOverride] is used while `kUseDynamicOtp` is off
/// (`otp_config.dart`) — there's no real Firebase phone credential to read
/// `FirebaseAuth.instance.currentUser.phoneNumber` from, so the caller
/// passes the number straight from the phone-entry step instead.
///
/// Returns `false` only on the new unified-login path (`role` not yet
/// picked — arrived via [AuthLoginScreen] rather than the old
/// `/role-selector` flow) when the phone matches no account anywhere — the
/// caller ([AuthOtpScreen]) shows its own "no account found" error in that
/// case rather than this function doing so itself. The old role-first login
/// flow (`role` already set) below is dead in the current UI — nothing sets
/// `role` before calling this in login mode anymore — but is kept
/// defensive: a null match there now just leaves the session
/// unauthenticated ([SessionController.completeLogin] no-ops on a null
/// account) rather than falling back to a demo identity.
Future<bool> completePhoneAuth(
  BuildContext context,
  WidgetRef ref,
  String mode, {
  String? phoneOverride,
}) async {
  final role = ref.read(sessionControllerProvider).role;
  if (role == null && mode != 'login') return false;

  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      // Leaves currentUser null — every Firestore/Storage read behind this
      // login will then fail permission-denied. Surfacing here instead of
      // failing silently, since that failure mode is otherwise invisible
      // (see the class doc above for why this call exists at all).
      debugPrint('Anonymous sign-in failed (${e.code}): ${e.message}');
    }
  }

  if (mode == 'register') {
    if (!context.mounted) return true;
    context.go('/auth/terms?mode=register');
    return true;
  }

  final phone = phoneOverride ?? FirebaseAuth.instance.currentUser?.phoneNumber;

  if (role == null) {
    final match = await resolveAccountAcrossRoles(ref, phone: phone);
    if (match == null) {
      await FirebaseAuth.instance.signOut();
      return false;
    }
    if (!context.mounted) return true;
    completeResolvedLogin(context, ref, match);
    return true;
  }

  Account? match;
  if (role == AppRole.vendor && phone != null) {
    match = await findFirestoreVendorByPhone(phone);
  }
  if (match == null && role == AppRole.driver && phone != null) {
    match = await findFirestoreDriverByPhone(phone);
  }
  if (match == null && role == AppRole.user && phone != null) {
    match = await findFirestoreUserByPhone(phone);
  }
  if (!context.mounted) return true;
  ref.read(sessionControllerProvider.notifier).completeLogin(account: match);
  routeByStage(context, role, ref.read(sessionControllerProvider).stage);
  return true;
}
