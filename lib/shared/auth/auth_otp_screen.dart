import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/coin_flip_logo.dart';
import '../widgets/otp_input_field.dart';
import 'auth_navigation.dart';
import 'otp_config.dart';

/// Passed from [AuthPhoneScreen]/the unified login screen via go_router's
/// `extra:` — `verificationId` is an opaque Firebase token, not a display
/// value, so it doesn't belong in a query param. Null while `kUseDynamicOtp`
/// is off (`otp_config.dart`), since there's no real Firebase verification
/// happening yet. `phoneNumber`/`resendToken` are needed to re-trigger
/// `verifyPhoneNumber` on "Resend code" once that's back on.
class OtpScreenArgs {
  const OtpScreenArgs({
    required this.verificationId,
    required this.phoneNumber,
    this.resendToken,
  });

  final String? verificationId;
  final String phoneNumber;
  final int? resendToken;
}

/// While `kUseDynamicOtp` is off, checks the entered code against the fixed
/// [kDemoOtp] and completes login/registration directly — no Firebase
/// credential involved, so `completePhoneAuth` gets the phone number
/// straight from [OtpScreenArgs] instead of reading
/// `FirebaseAuth.instance.currentUser`. Once that flag is on, this verifies
/// against Firebase Auth's real SMS verification instead. Either way,
/// success either completes login directly (login mode) or hands off to
/// the Terms gate before registration completes (register mode) — see
/// [AuthTermsScreen]'s doc comment for why the terms step sits after OTP
/// rather than before it.
///
/// Bespoke layout, not [AuthHeroScaffold] — mirrors `auth_login_screen.dart`/
/// `auth_register_screen.dart`'s visual language exactly: `login_bg1.png` +
/// `login_bg2.png` hero background, a plain "Verify OTP" wordmark directly
/// on it, and the same glossy frosted-glass card treatment for the actual
/// pin entry, with [CoinFlipLogo] straddling the card's top border.
class AuthOtpScreen extends ConsumerStatefulWidget {
  const AuthOtpScreen({super.key, required this.args, this.mode = 'login'});

  final OtpScreenArgs args;
  final String mode;

  @override
  ConsumerState<AuthOtpScreen> createState() => _AuthOtpScreenState();
}

class _AuthOtpScreenState extends ConsumerState<AuthOtpScreen> {
  late String? _verificationId = widget.args.verificationId;
  String? _error;
  bool _verifying = false;

  Future<void> _onCompleted(String code) async {
    setState(() {
      _verifying = true;
      _error = null;
    });

    if (!kUseDynamicOtp) {
      if (code != kDemoOtp) {
        if (!mounted) return;
        setState(() {
          _verifying = false;
          _error = 'Incorrect code. Please try again.';
        });
        return;
      }
      if (!mounted) return;
      await _completePhoneAuth(phoneOverride: widget.args.phoneNumber);
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = e.code == 'invalid-verification-code'
            ? 'Incorrect code. Please try again.'
            : (e.message ?? 'Verification failed.');
      });
      return;
    }
    if (!mounted) return;
    await _completePhoneAuth();
  }

  /// Wraps [completePhoneAuth] so a lookup failure (e.g. the Firestore
  /// `vendors` query in `auth_navigation.dart`) shows an error and resets
  /// the spinner instead of leaving the screen stuck on `_verifying: true`
  /// with no feedback — and, for the unified login screen's path (no role
  /// pre-picked), so a phone that matches no account anywhere shows a real
  /// "no account found" error instead of the old role-first flow's
  /// demo-account fallback (`completePhoneAuth` only returns `false` in
  /// that one case — see its own doc comment).
  Future<void> _completePhoneAuth({String? phoneOverride}) async {
    try {
      final resolved = await completePhoneAuth(
        context,
        ref,
        widget.mode,
        phoneOverride: phoneOverride,
      );
      if (!resolved && mounted) {
        setState(() {
          _verifying = false;
          _error =
              "No account found for this number. Check the number, or register instead.";
        });
      }
    } catch (e, st) {
      debugPrint('completePhoneAuth failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _onResend() async {
    if (!kUseDynamicOtp) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Demo mode — use $kDemoOtp.')));
      return;
    }
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.args.phoneNumber,
      forceResendingToken: widget.args.resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
        } on FirebaseAuthException {
          return;
        }
        if (!mounted) return;
        await _completePhoneAuth();
      },
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() => _error = e.message ?? 'Could not resend the code.');
      },
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _error = null;
        });
      },
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The background image is dark green under the status bar — without
      // this the system default (often dark icons) would be unreadable.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: palette.primaryDark,
        // StackFit.expand, not the default loose — Scaffold gives body
        // *loose* constraints, so with only Positioned children and this
        // screen's (shorter than login/register's) card content, the Stack
        // was shrinking to fit that content instead of filling the screen,
        // leaving login_bg2 — pinned bottom:0, but only relative to the
        // Stack's own shrunk size — short of the real bottom edge with
        // Scaffold's backgroundColor showing through beneath it. expand
        // forces the Stack to the screen's full size regardless of content.
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Fills the gap between the two images below (each sized to
            // its own aspect ratio, not stretched to cover the full
            // screen) with the same green they're drawn in, so the seams
            // read as one continuous background.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: palette.promoGradient,
                  ),
                ),
              ),
            ),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Image(
                image: AssetImage('assets/images/login_bg1.png'),
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
              ),
            ),
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Image(
                image: AssetImage('assets/images/login_bg2.png'),
                fit: BoxFit.fitWidth,
                alignment: Alignment.bottomCenter,
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                // Reserves exactly login_bg2's own rendered height (its
                // real 941×410 aspect scaled to screen width) so nothing
                // in the card ever lands on top of that image's own
                // content — see auth_login_screen.dart's identical fix.
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.sizeOf(context).width * (410 / 941) +
                      32 +
                      MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          IconButton(
                            // Defensive: falls back to the sign-in screen
                            // if this was ever reached via context.go()
                            // (replaces the stack) rather than push() —
                            // pop() alone throws "nothing to pop" in that
                            // case.
                            onPressed: () => context.canPop()
                                ? context.pop()
                                : context.go('/auth/login'),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Verify OTP',
                            style: TextStyle(
                              // Shared with login/register's own headline —
                              // see AppColors.authHeadlineGreen's doc
                              // comment.
                              color: AppColors.authHeadlineGreen,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Back-button-plus-title only header, same shape as
                    // register's, so it clears the background image's icon
                    // row the same way and uses the same gap.
                    const SizedBox(height: 135),
                    // Card sized to its own content (not stretched to the
                    // screen's bottom edge) so login_bg2 stays visible
                    // below it — see the reserved bottom padding above.
                    // Wrapped in a Stack so CoinFlipLogo can straddle the
                    // card's top border as a sibling — see
                    // auth_login_screen.dart's identical treatment.
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          width: double.infinity,
                          // Half the logo's own size, so the card's top
                          // border passes exactly through the logo's
                          // vertical center.
                          margin: const EdgeInsets.only(top: 56),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 30,
                                offset: const Offset(0, -6),
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.35),
                                blurRadius: 18,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.55),
                                      Colors.white.withValues(alpha: 0.32),
                                      Colors.white.withValues(alpha: 0.4),
                                    ],
                                    stops: const [0.0, 0.15, 1.0],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    width: 1.6,
                                  ),
                                ),
                                child: Padding(
                                  // Top padding cleared for the logo's
                                  // bottom half (56) plus real breathing
                                  // room before the heading.
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    76,
                                    24,
                                    32,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 440,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            'Enter verification code',
                                            style: TextStyle(
                                              color: palette.textPrimary,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 6),
                                          Text.rich(
                                            TextSpan(
                                              style: TextStyle(
                                                color: palette.textSecondary,
                                                fontSize: 13,
                                              ),
                                              children: [
                                                const TextSpan(
                                                  text:
                                                      'We sent a 6-digit code to ',
                                                ),
                                                TextSpan(
                                                  text: widget.args.phoneNumber,
                                                  style: TextStyle(
                                                    color: palette.textPrimary,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 24),
                                          if (!kUseDynamicOtp) ...[
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: palette.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.info_outline_rounded,
                                                    size: 16,
                                                    color: palette.primary,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Demo mode — use $kDemoOtp.',
                                                    style: TextStyle(
                                                      color: palette.primary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 20),
                                          ],
                                          Center(
                                            child: OtpInputField(
                                              onCompleted: _onCompleted,
                                              onResend: _onResend,
                                            ),
                                          ),
                                          if (_verifying) ...[
                                            const SizedBox(height: 20),
                                            Center(
                                              child: CircularProgressIndicator(
                                                color: palette.primary,
                                              ),
                                            ),
                                          ],
                                          if (_error != null) ...[
                                            const SizedBox(height: 16),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: palette.error.withValues(
                                                  alpha: 0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                _error!,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: palette.error,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Straddles the card's top border — see the
                        // Container's margin above, set to exactly half
                        // this logo's size.
                        const Positioned(
                          top: 0,
                          child: CoinFlipLogo(size: 112),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
