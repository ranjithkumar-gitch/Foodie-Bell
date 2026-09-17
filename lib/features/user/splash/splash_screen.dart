import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_cache.dart';
import '../../../core/session/session_controller.dart';
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

  /// Firebase Auth persists sign-in across app restarts — if a user is
  /// still signed in, resolve which Account they are (role-agnostic —
  /// [resolveAccountAcrossRoles], `auth_navigation.dart`, shared with the
  /// unified login screen's own cross-role lookup) and skip straight to
  /// their role's home.
  ///
  /// That persisted credential's own phone/email is usually enough to
  /// resolve from — except while `kUseDynamicOtp` is off (`otp_config.dart`),
  /// where `completePhoneAuth` signs in *anonymously* instead of with a
  /// real phone credential (its own doc comment explains why). That
  /// anonymous session is just as real and persisted, but carries no
  /// phone/email of its own — so falls back to whichever phone last
  /// completed login/registration (`session_cache.dart`, written by
  /// `SessionController.completeLogin`/`completeRegistration`, cleared on
  /// logout) rather than treating "no phone on the credential" as "nobody's
  /// signed in".
  ///
  /// No match at all (from either source) means there's nothing left to
  /// restore — sign out rather than leave a dangling
  /// authenticated-but-unknown state.
  ///
  /// Guards on `Firebase.apps.isNotEmpty` first: widget tests pump this
  /// screen without ever calling `main()`, so Firebase is never
  /// initialized there — this avoids depending on hand-rolled platform
  /// channel mocks just to exercise the splash screen in a test, and is
  /// cheap insurance in production too if init ever fails ahead of this.
  Future<void> _route() async {
    final user = Firebase.apps.isNotEmpty
        ? FirebaseAuth.instance.currentUser
        : null;
    // Blank, not just null, counts as "nothing to resolve from" — an
    // anonymous credential's phoneNumber/email come back as empty strings
    // here, not null, so a null-only check never noticed there was really
    // nothing there and went on to look up an Account by an empty string
    // (never matches anything) instead of falling through to the cache
    // below.
    var phone = _blankToNull(user?.phoneNumber);
    final email = _blankToNull(user?.email);
    if (phone == null && email == null) {
      phone = await loadCachedSessionPhone();
    }
    if (!mounted) return;
    if (phone != null || email != null) {
      final match = await resolveAccountAcrossRoles(
        ref,
        phone: phone,
        email: email,
      );
      if (!mounted) return;
      if (match != null) {
        ref.read(sessionControllerProvider.notifier).selectRole(match.role);
        ref
            .read(sessionControllerProvider.notifier)
            .completeLogin(account: match);
        if (!mounted) return;
        routeByStage(
          context,
          match.role,
          ref.read(sessionControllerProvider).stage,
        );
        return;
      }
      if (user != null) await FirebaseAuth.instance.signOut();
      await clearCachedSessionPhone();
    }
    if (!mounted) return;
    context.go('/auth/login');
  }

  String? _blankToNull(String? s) => (s == null || s.isEmpty) ? null : s;

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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
