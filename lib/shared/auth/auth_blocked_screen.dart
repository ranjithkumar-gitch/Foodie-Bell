import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';

/// Shown when `session.stage == AuthStage.blocked` — an Admin-suspended or
/// Admin-deleted Manager/Vendor tries to log in (or their still-open
/// session gets re-validated at splash). No self-service path here on
/// purpose, unlike [AuthRejectedScreen]'s "resubmit": both suspension and
/// deletion are Admin-only actions (`manager_directory_screen.dart`/
/// `vendor_directory_screen.dart`), so only Admin can undo them.
class AuthBlockedScreen extends ConsumerWidget {
  const AuthBlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final session = ref.watch(sessionControllerProvider);
    final role = session.role;

    if (role == null) {
      return Scaffold(
        body: Center(
          child: TextButton(onPressed: () => context.go('/auth/login'), child: const Text('Back to sign in')),
        ),
      );
    }

    final deleted = session.account?.deletedAt != null;
    final title = deleted ? 'Your account has been removed' : 'Your account has been suspended';
    final message = deleted
        ? "This ${role.label} account was removed by Quicky Admin and can no longer sign in. Please contact Quicky Admin if you believe this is a mistake."
        : "This ${role.label} account was suspended by Quicky Admin. Please contact Quicky Admin to reactivate your account.";

    return Scaffold(
      appBar: AppBar(title: const Text('Account access blocked')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: palette.error.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(Icons.block_rounded, color: palette.error, size: 32),
            ),
            const SizedBox(height: 20),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            OutlinedButton(
              onPressed: () {
                ref.read(sessionControllerProvider.notifier).logout();
                context.go('/auth/login');
              },
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}
