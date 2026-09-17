import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';

/// Reusable logout confirmation bottom sheet, meant to be wired into each
/// role's Profile screen. Call [LogoutConfirmationSheet.show] rather than
/// constructing this widget directly — it also owns clearing the session
/// (both the local [SessionController] and the real, persisted Firebase
/// Auth session — skipping the latter would leave Splash silently
/// re-signing them back in on next launch) and navigating back to the
/// unified sign-in screen once confirmed.
class LogoutConfirmationSheet extends StatelessWidget {
  const LogoutConfirmationSheet({super.key});

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const LogoutConfirmationSheet(),
    );
    if (confirmed != true || !context.mounted) return;
    await FirebaseAuth.instance.signOut();
    ref.read(sessionControllerProvider.notifier).logout();
    if (!context.mounted) return;
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(color: palette.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text('Log out?', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Are you sure you want to log out?', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: palette.error),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Log out'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
