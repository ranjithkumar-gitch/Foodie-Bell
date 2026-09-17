import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A polished "not built yet" placeholder for menu items with no real
/// screen behind them — a proper bottom sheet rather than a bare snackbar,
/// so it reads as an intentional part of the product roadmap instead of a
/// broken link. Shared across every role's Profile/Dashboard menus.
class ComingSoonSheet {
  ComingSoonSheet._();

  static void show(BuildContext context, {required IconData icon, required String title, required String message}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final palette = context.colors;
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
            decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: palette.primaryLight.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(icon, color: palette.primary, size: 34),
                ),
                const SizedBox(height: 18),
                Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: TextStyle(color: palette.textSecondary)),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))),
              ],
            ),
          ),
        );
      },
    );
  }
}
