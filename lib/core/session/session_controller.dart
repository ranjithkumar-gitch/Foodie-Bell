import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/providers/cart_provider.dart';
import '../../data/providers/firestore_addresses_provider.dart';
import '../../data/providers/firestore_stream_reset.dart';

enum AuthStage { unauthenticated, pendingApproval, rejected, blocked, active }

/// Maps an [Account]'s real [AccountStatus]/[Account.deletedAt] to the
/// [AuthStage] that decides what a login (or session restore) lands on —
/// shared by [SessionController.completeLogin] and [SessionController.refreshAccount]
/// so the two never drift out of sync. A soft-deleted account (Admin's
/// "Delete Manager"/"Delete Vendor") and a merely-[AccountStatus.suspended]
/// one both land on [AuthStage.blocked] — `auth_blocked_screen.dart` reads
/// [Account.deletedAt] itself to pick the exact wording.
AuthStage authStageFor(Account account) {
  if (account.deletedAt != null) return AuthStage.blocked;
  return switch (account.status) {
    AccountStatus.pendingReview => AuthStage.pendingApproval,
    AccountStatus.rejected => AuthStage.rejected,
    AccountStatus.suspended => AuthStage.blocked,
    AccountStatus.active => AuthStage.active,
  };
}

class SessionState {
  const SessionState({
    this.role,
    this.stage = AuthStage.unauthenticated,
    this.account,
  });

  final AppRole? role;
  final AuthStage stage;
  final Account? account;
}

/// The signed-in [Account] and the [AuthStage] it lands on. Drives the
/// router's `redirect:` and every role's Splash/Logout flow. Only ever filled
/// from an account the server resolved for a phone-verified Firebase user
/// (`account_resolver.dart`) — nothing here can pick a role or account by
/// itself.
class SessionController extends StateNotifier<SessionState> {
  SessionController(this._ref) : super(const SessionState());

  final Ref _ref;

  void selectRole(AppRole role) => state = SessionState(role: role);

  /// Existing-account sign-in — phone+OTP for every role reachable in this
  /// app (Manager included; Admin is email+password but only ever signs in
  /// via the separate QuickyAdmin app, never here). The resulting stage
  /// follows the resolved account's real [AccountStatus] — a Vendor a Manager
  /// created `pendingReview` (see `manager_vendor_create_screen.dart`)
  /// lands on "Account under review" rather than straight into their
  /// dashboard, same as a freshly self-registered Vendor/Driver would via
  /// [completeRegistration]. [account] must be the one the server resolved
  /// for the verified phone sign-in (`account_resolver.dart`, via
  /// `completeResolvedLogin` in `auth_navigation.dart`) — a null account is
  /// a no-op, never a silent sign-in as someone else.
  void completeLogin({Account? account}) {
    final role = state.role;
    if (role == null || account == null) return;
    final stage = authStageFor(account);
    // A previous session's Firestore listeners may still be alive from
    // before this sign-in — reset them so none carries a stale
    // permission-denied error into this new, valid session (see
    // `firestore_stream_reset.dart`'s doc comment).
    resetFirestoreStreams(_ref);
    if (role == AppRole.user)
      _ref.read(cartProvider.notifier).loadForUser(account.id);
    state = SessionState(role: role, stage: stage, account: account);
  }

  /// New-account registration. User/Admin activate immediately; Vendor/Driver
  /// go to pending-approval per the platform's Manager-Code review flow.
  /// [account] must be a real record the server just created — like
  /// [completeLogin], this never falls back to a fixed demo identity. (User
  /// registration goes through `registerCustomerAccount` and
  /// [completeLogin] now, so this only serves the wizard case below.)
  /// Vendor/Driver's own "Become a Vendor/Driver" self-registration wizard
  /// doesn't create one yet (it isn't wired to Firestore), so calling this
  /// with no account for those roles is a no-op rather than a fake sign-in.
  void completeRegistration({Account? account}) {
    final role = state.role;
    if (role == null || account == null) return;
    final stage = role.requiresApproval
        ? AuthStage.pendingApproval
        : AuthStage.active;
    final resolvedAccount = account.copyWith(
      status: role.requiresApproval
          ? AccountStatus.pendingReview
          : AccountStatus.active,
    );
    resetFirestoreStreams(_ref);
    if (role == AppRole.user)
      _ref.read(cartProvider.notifier).loadForUser(resolvedAccount.id);
    state = SessionState(role: role, stage: stage, account: resolvedAccount);
  }

  /// Re-derives `stage` from a freshly-fetched [account] (same status→stage
  /// mapping as [completeLogin]) and swaps it into the session. Used while a
  /// Vendor sits on "Account under review": their session's `Account` is a
  /// snapshot from login and won't otherwise notice a Manager approving them
  /// elsewhere (`auth_under_review_screen.dart` listens for the live
  /// Firestore/mock record and calls this once status moves off
  /// `pendingReview`) — updating `stage` here is what makes GoRouter's
  /// `refreshListenable` (`app_router.dart`) carry them out of
  /// `/auth/under-review` automatically, no re-login needed.
  void refreshAccount(Account account) {
    final role = state.role;
    if (role == null) return;
    state = SessionState(
      role: role,
      stage: authStageFor(account),
      account: account,
    );
  }

  void logout() {
    // The just-revoked auth token would otherwise leave any still-alive
    // Firestore listener erroring out with permission-denied for the rest
    // of this app session (see `firestore_stream_reset.dart`).
    resetFirestoreStreams(_ref);
    // Clears the in-memory cart only — the Firestore doc stays, so it's
    // there to restore next time this same account logs back in.
    _ref.read(cartProvider.notifier).clearLocal();
    // Otherwise the next account to sign in on this device would see the
    // previous User's checkout address pre-selected.
    _ref.read(selectedAddressProvider.notifier).state = null;
    state = const SessionState();
  }
}

final sessionControllerProvider =
    StateNotifierProvider<SessionController, SessionState>(
      (ref) => SessionController(ref),
    );
