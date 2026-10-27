import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/account_resolver.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/account.dart';

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

/// The final steps once the server has resolved which [Account] a verified
/// sign-in belongs to (`account_resolver.dart`) — shared by
/// [completePhoneSignIn], the Terms screen's registration and the splash
/// screen's session restore: [SessionController.selectRole] first (the role
/// is only known now), then [SessionController.completeLogin], then routed
/// by the resulting stage.
void completeResolvedLogin(BuildContext context, WidgetRef ref, Account match) {
  ref.read(sessionControllerProvider.notifier).selectRole(match.role);
  ref.read(sessionControllerProvider.notifier).completeLogin(account: match);
  if (!context.mounted) return;
  routeByStage(context, match.role, ref.read(sessionControllerProvider).stage);
}

enum PhoneSignInOutcome { signedIn, needsRegistration, noAccount }

/// Runs once Firebase has verified the phone number — the person is now a
/// real Phone Auth user. Shared by the OTP screen's code entry and Android's
/// instant/auto verification on the login and phone screens.
///
/// Which account (and so which role) this is comes only from the server
/// (`resolveSignedInAccount`), keyed off the verified number in the ID
/// token — nothing typed into the app can pick one.
///
/// - Account found: signs in and routes by its stage, in either [mode].
///   That includes `register`, so a number that's already registered just
///   signs in instead of creating a duplicate.
/// - No account, `register` mode: on to the Terms gate, which creates it.
/// - No account, `login` mode: signs back out and returns
///   [PhoneSignInOutcome.noAccount] for the caller to show its error.
///
/// Throws [AccountResolutionException] if the server can't be reached; the
/// verified sign-in is kept so the caller can simply retry.
Future<PhoneSignInOutcome> completePhoneSignIn(BuildContext context, WidgetRef ref, String mode) async {
  final account = await resolveSignedInAccount();
  if (account != null) {
    if (context.mounted) completeResolvedLogin(context, ref, account);
    return PhoneSignInOutcome.signedIn;
  }
  if (mode == 'register') {
    if (context.mounted) context.go('/auth/terms?mode=register');
    return PhoneSignInOutcome.needsRegistration;
  }
  await FirebaseAuth.instance.signOut();
  return PhoneSignInOutcome.noAccount;
}
