import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';
import '../../data/providers/firestore_drivers_provider.dart';
import '../../data/providers/firestore_vendors_provider.dart';
import '../../data/providers/mock_accounts_provider.dart';
import '../widgets/driver_document_checklist.dart';
import '../widgets/status_chip.dart';
import '../widgets/vendor_document_checklist.dart';
import 'logout_confirmation_sheet.dart';

/// Shown while a Vendor/Driver/Manager registration awaits approval
/// (`AuthStage.pendingApproval`).
///
/// Vendor and Driver — the only two roles with [AppRoleX.requiresApproval]
/// true, so the only two that ever reach this screen — both get the real
/// flow: a Manager now genuinely reviews them (see
/// `manager_vendor_detail_screen.dart` / `manager_driver_detail_screen.dart`),
/// so this embeds the same [VendorDocumentChecklist]/[DriverDocumentChecklist]
/// their own "My Documents" screens use — a still-pending Vendor/Driver
/// can't reach `/vendor/**`/`/driver/**` routes yet
/// (`session_redirect.dart`), so it has to work here too — with no fake
/// "simulate approval" shortcut, since bypassing a real Manager's review
/// would defeat the point. The `else` branch below is unreachable dead code
/// today (kept only in case a future role gains `requiresApproval` without
/// a real review system yet).
class AuthUnderReviewScreen extends ConsumerWidget {
  const AuthUnderReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final session = ref.watch(sessionControllerProvider);
    final role = session.role;

    if (role == AppRole.vendor && session.account != null) {
      // A Manager can approve/reject this Vendor from another session while
      // this one sits here — poll-free live pickup via the same
      // Firestore/mock merge the checklist below uses, so GoRouter's
      // `refreshListenable` (`app_router.dart`) carries them out of this
      // screen the moment `stage` changes, no re-login required.
      ref.listen(liveVendorAccountProvider(session.account!.id), (previous, next) {
        if (next != null && next.status != AccountStatus.pendingReview) {
          ref.read(sessionControllerProvider.notifier).refreshAccount(next);
        }
      });
    }
    if (role == AppRole.driver && session.account != null) {
      // Same live pickup as Vendor above, over the Driver Firestore/mock merge.
      ref.listen(liveDriverAccountProvider(session.account!.id), (previous, next) {
        if (next != null && next.status != AccountStatus.pendingReview) {
          ref.read(sessionControllerProvider.notifier).refreshAccount(next);
        }
      });
    }

    if (role == null) {
      return Scaffold(
        body: Center(
          child: TextButton(onPressed: () => context.go('/auth/login'), child: const Text('Back to sign in')),
        ),
      );
    }

    final reviewerLabel = role == AppRole.manager ? 'System Admin' : 'Manager';
    final managerCode = session.account?.managerCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account under review'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.power_settings_new_rounded),
            onPressed: () => LogoutConfirmationSheet.show(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: palette.warning.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(Icons.hourglass_top_rounded, color: palette.warning, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            role == AppRole.vendor || role == AppRole.driver ? 'Your account is pending activation' : 'Your application is under review',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            role == AppRole.vendor
                ? 'Submit whatever your Manager has marked as required below. Once everything required is in and your Manager approves you, you\'ll be visible to Users in your territory.'
                : role == AppRole.driver
                ? 'Give your risk consent and submit whatever your Manager has marked as required below. Once everything required is in and your Manager approves you, you can start accepting deliveries.'
                : "A $reviewerLabel will review your ${role.label} application shortly. We'll notify you once it's approved.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (managerCode != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const StatusChip(label: 'PENDING REVIEW', tone: StatusTone.warning),
                const SizedBox(width: 10),
                Text('Manager Code: $managerCode', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5)),
              ],
            ),
          ],
          if (role == AppRole.vendor) ...[
            const SizedBox(height: 24),
            _VendorPendingChecklist(sessionAccount: session.account!),
          ] else if (role == AppRole.driver) ...[
            const SizedBox(height: 24),
            _DriverPendingChecklist(sessionAccount: session.account!),
          ] else ...[
            const SizedBox(height: 40),
            Text('FOR DEMO PURPOSES ONLY', style: TextStyle(color: palette.textMuted, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.6)),
            const SizedBox(height: 4),
            Text(
              "There's no real Manager/Admin on the other end in this demo — use the buttons below to simulate their decision.",
              style: TextStyle(color: palette.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () {
                ref.read(sessionControllerProvider.notifier).setStage(AuthStage.active);
                context.go('/${role.name}');
              },
              child: const Text('Simulate approval'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                ref.read(sessionControllerProvider.notifier).setStage(AuthStage.rejected);
                context.go('/auth/rejected');
              },
              child: const Text('Simulate rejection'),
            ),
          ],
        ],
      ),
    );
  }
}

class _VendorPendingChecklist extends ConsumerWidget {
  const _VendorPendingChecklist({required this.sessionAccount});
  final Account sessionAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mockAccounts = ref.watch(mockAccountsProvider);
    final firestoreVendors = ref.watch(firestoreVendorsProvider).valueOrNull ?? const [];
    final isFirestoreBacked = firestoreVendors.any((v) => v.id == sessionAccount.id);
    final account = mergeVendorAccounts(mockAccounts, firestoreVendors).where((a) => a.id == sessionAccount.id).firstOrNull ?? sessionAccount;

    return VendorDocumentChecklist(account: account, isFirestoreBacked: isFirestoreBacked);
  }
}

class _DriverPendingChecklist extends ConsumerWidget {
  const _DriverPendingChecklist({required this.sessionAccount});
  final Account sessionAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mockAccounts = ref.watch(mockAccountsProvider);
    final firestoreDrivers = ref.watch(firestoreDriversProvider).valueOrNull ?? const [];
    final isFirestoreBacked = firestoreDrivers.any((d) => d.id == sessionAccount.id);
    final account = mergeDriverAccounts(mockAccounts, firestoreDrivers).where((a) => a.id == sessionAccount.id).firstOrNull ?? sessionAccount;

    return DriverDocumentChecklist(account: account, isFirestoreBacked: isFirestoreBacked);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
