import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';

/// Shown when `session.stage == AuthStage.rejected`. User/Admin can't
/// actually reach this state under current [SessionController] logic (only
/// Vendor/Driver/Manager go through approval), but the screen stays
/// generically correct for all five roles per spec.
class AuthRejectedScreen extends ConsumerWidget {
  const AuthRejectedScreen({super.key});

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

    final reason = session.account?.rejectionReason ?? "Your application didn't meet our current onboarding requirements.";

    return Scaffold(
      appBar: AppBar(title: const Text('Application rejected')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: palette.error.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(Icons.cancel_outlined, color: palette.error, size: 32),
            ),
            const SizedBox(height: 20),
            Text('Your application was rejected', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(reason, style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            ElevatedButton(
              // User can't be rejected under current logic, but /auth/phone
              // is the generically-correct "start over" step for it anyway.
              onPressed: () => context.go(role == AppRole.user ? '/auth/phone' : '/${role.name}/register'),
              child: const Text('Resubmit application'),
            ),
            const SizedBox(height: 10),
            TextButton(
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
