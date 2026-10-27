import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/session/account_resolver.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/auth/auth_navigation.dart';
import '../../../shared/widgets/branded_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeIn,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      _route();
    });
  }

  /// Shown when a still-signed-in session couldn't be restored for a
  /// reason that may pass (offline, server busy) — the sign-in is kept and
  /// the person can retry, rather than being logged out by a flaky network.
  String? _restoreError;

  /// Firebase Auth persists sign-in across app restarts. A phone-verified
  /// user is restored by asking the server which account they are
  /// (`resolveSignedInAccount`, the same lookup login uses) — never from
  /// anything stored on the device.
  ///
  /// Anything else still signed in (an anonymous session or a cached phone
  /// number from builds that used the demo OTP) is cleared and sent to
  /// login.
  ///
  /// Guards on `Firebase.apps.isNotEmpty` first: widget tests pump this
  /// screen without ever calling `main()`, so Firebase is never
  /// initialized there — this avoids depending on hand-rolled platform
  /// channel mocks just to exercise the splash screen in a test, and is
  /// cheap insurance in production too if init ever fails ahead of this.
  Future<void> _route() async {
    if (_restoreError != null) setState(() => _restoreError = null);
    final user = Firebase.apps.isNotEmpty ? FirebaseAuth.instance.currentUser : null;
    await _clearLegacySessionPhone();
    if (user != null) {
      final isPhoneUser = !user.isAnonymous && user.providerData.any((p) => p.providerId == PhoneAuthProvider.PROVIDER_ID);
      if (!isPhoneUser) {
        await FirebaseAuth.instance.signOut();
      } else {
        try {
          final account = await resolveSignedInAccount();
          if (!mounted) return;
          if (account != null) {
            completeResolvedLogin(context, ref, account);
            return;
          }
          await FirebaseAuth.instance.signOut();
        } on FirebaseAuthException catch (e) {
          // The Firebase user itself is gone or disabled — nothing to keep.
          if (const {'user-disabled', 'user-not-found', 'user-token-expired', 'invalid-user-token'}.contains(e.code)) {
            await FirebaseAuth.instance.signOut();
          } else {
            _showRestoreError("We couldn't reach the server. Check your connection and try again.");
            return;
          }
        } on AccountResolutionException catch (e) {
          if (e.isNetwork) {
            _showRestoreError(e.message);
            return;
          }
          await FirebaseAuth.instance.signOut();
        } catch (e, st) {
          debugPrint('Session restore failed: $e\n$st');
          _showRestoreError("We couldn't restore your session. Please try again.");
          return;
        }
      }
    }
    if (!mounted) return;
    context.go('/auth/login');
  }

  void _showRestoreError(String message) {
    if (mounted) setState(() => _restoreError = message);
  }

  Future<void> _signInAgain() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    context.go('/auth/login');
  }

  /// Older builds stored the last signed-in phone number here and restored a
  /// session from it alone; that's no longer trusted, so it's just removed.
  Future<void> _clearLegacySessionPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('session_phone');
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.promoGradient,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const BrandedLogo(size: 140),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your neighbourhood, delivered fast',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_restoreError != null) ...[
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _restoreError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _route, child: const Text('Try again')),
                    TextButton(
                      onPressed: _signInAgain,
                      child: const Text('Sign in with a different number', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
