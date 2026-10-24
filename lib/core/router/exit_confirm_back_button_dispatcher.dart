import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/branded_logo.dart';
import '../theme/app_colors.dart';
import 'app_router.dart';

/// Device back button handling for the whole app: a back press that the
/// router can't use (nothing left to pop — the press that would close the
/// app) asks "Leaving so soon?" first instead of closing straight away.
class ExitConfirmBackButtonDispatcher extends RootBackButtonDispatcher {
  ExitConfirmBackButtonDispatcher(this._router);

  final GoRouter _router;

  @override
  Future<bool> didPopRoute() async {
    // Screens, dialogs and sheets that can go back do so as usual. A second
    // back press while the exit dialog is up lands here too and closes it.
    if (await super.didPopRoute()) return true;

    final context = _router.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return false;
    final exit = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, _) => const _ExitDialog(),
      // Pops in: a quick scale-up from 90% with a fade.
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(curved), child: child),
        );
      },
    );
    if (exit == true) await SystemNavigator.pop();
    return true;
  }
}

/// The exit confirmation card — the app logo in a brand-gradient ring,
/// a friendly question, and "Stay" as the obvious, filled choice with
/// "Exit" as the quieter one, so a stray back press is easy to undo.
class _ExitDialog extends StatelessWidget {
  const _ExitDialog();

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Material(
          color: palette.surface,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Brand-tinted header with the logo.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 28, bottom: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [palette.primary.withValues(alpha: 0.16), palette.surface],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: palette.promoGradient),
                        boxShadow: [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.3),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Container(
                        width: 76,
                        height: 76,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: palette.surface, shape: BoxShape.circle),
                        child: const BrandedLogo(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        'Leaving so soon?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: palette.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Are you sure you want to exit the app?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, height: 1.4, fontWeight: FontWeight.w500, color: palette.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Stay', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Exit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.error,
                            side: BorderSide(color: palette.error.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final exitConfirmBackButtonDispatcherProvider = Provider<BackButtonDispatcher>(
  (ref) => ExitConfirmBackButtonDispatcher(ref.watch(appRouterProvider)),
);
