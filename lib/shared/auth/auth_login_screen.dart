import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';
import '../widgets/app_text_field.dart';
import '../widgets/coin_flip_logo.dart';
import '../widgets/glossy_surface.dart';
import 'auth_navigation.dart';
import 'auth_otp_screen.dart';
import 'otp_config.dart';

/// The app's one and only entry point — a single phone number field, no
/// role picked up front and no password anywhere: every role, Manager
/// included, signs in by phone + OTP now (Manager used to be email +
/// password — see [resolveAccountAcrossRoles]'s doc comment for how its
/// lookup joined the others). Role is inferred from whichever real account
/// the entered phone actually matches (`resolveAccountAcrossRoles`/
/// `completePhoneAuth`, `auth_navigation.dart`) — the same cross-role
/// lookup `splash_screen.dart` uses to restore a session across restarts.
/// There used to be a `/role-selector` screen that made you choose
/// User/Vendor/Driver/Manager *before* ever seeing a credential field, and
/// this screen's own "Register"/"choose role manually" links routed there
/// too — that page is gone now (this screen replaced its login purpose
/// entirely), so every path back to it is gone with it.
///
/// Bespoke layout, not [AuthHeroScaffold] (still shared by OTP/Register) —
/// two illustrations, not one full-bleed image: `login_bg1.png` (icon row
/// + delivery rider) anchored to the top, `login_bg2.png` (the
/// stores/delivery/community footer) anchored to the bottom, each at its
/// own natural aspect ratio rather than stretched to cover the screen. A
/// plain green gradient (`palette.promoGradient` — the same green both
/// images are drawn in) fills whatever gap is left between them, so the
/// seam reads as one continuous background rather than a visible edge.
/// The "Quicky" wordmark (`quicky_text.png`, the brand's own stylized
/// logotype) + "Get Orders to your Doorstep" subtext sit directly on that
/// background (no card behind them), but the sign-in
/// form below sits on a glossy frosted-glass card — `ClipRRect`+
/// `BackdropFilter`, transparent enough to still show the blurred image
/// behind it, with a full `Border.all` glass edge (plus a white-tinted
/// glow alongside the drop shadow) rather than just a top highlight — sized
/// to its own content rather than stretched to the screen's bottom edge, so
/// `login_bg2.png` stays visible below it. [CoinFlipLogo] straddles the
/// card's top border — the card's own top margin is set to exactly half
/// the logo's size, so the border passes through the logo's center, half
/// on the image above and half on the card below.
///
/// Admin has no path here — it only ever signs in via the separate
/// QuickyAdmin app. Only User self-registers (Vendor/Driver are created by
/// their territory Manager, Manager by Admin — see
/// `manager_vendor_create_screen.dart`/`manager_driver_create_screen.dart`),
/// so "Register" below sets the role to User directly and goes straight to
/// `/auth/register` — no role picker needed for a screen only one role ever
/// reaches.
///
/// A phone that matches no account anywhere is a real, visible error here
/// — not a silent fallback to a demo identity. That's an intentional
/// tightening versus the old role-first flow this replaced: once role is
/// inferred from the credential rather than picked by the person testing,
/// quietly logging into someone else's demo account on a typo would be
/// actively confusing rather than a convenience.
class AuthLoginScreen extends ConsumerStatefulWidget {
  const AuthLoginScreen({super.key});

  @override
  ConsumerState<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends ConsumerState<AuthLoginScreen> {
  final _phoneController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final digits = _phoneController.text.trim();
    if (digits.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });

    final phone = '+91$digits';

    if (!kUseDynamicOtp) {
      setState(() => _submitting = false);
      if (!mounted) return;
      context.push(
        '/auth/otp?mode=login',
        extra: OtpScreenArgs(verificationId: null, phoneNumber: phone),
      );
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (!mounted) return;
          setState(() {
            _submitting = false;
            _error = e.message ?? 'Verification failed. Please try again.';
          });
          return;
        }
        if (!mounted) return;
        final resolved = await completePhoneAuth(context, ref, 'login');
        if (!resolved && mounted) {
          setState(() {
            _submitting = false;
            _error =
                'No account found for this number. Check the number, or register instead.';
          });
        }
      },
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _error = e.message ?? 'Could not send the code. Please try again.';
        });
      },
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() => _submitting = false);
        context.push(
          '/auth/otp?mode=login',
          extra: OtpScreenArgs(
            verificationId: verificationId,
            phoneNumber: phone,
            resendToken: resendToken,
          ),
        );
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
        body: Stack(
          children: [
            // Fills the gap between the two images below (they're each
            // sized to their own aspect ratio, not stretched to cover the
            // full screen, so there's a real gap between them on most
            // devices) with the same green the images themselves are
            // drawn in, so the seams read as one continuous background
            // rather than a visible edge where the images stop.
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
                // Bottom padding reserves exactly login_bg2.png's own
                // rendered height (it's fitWidth, so that height scales
                // with screen width — 941×410 is the asset's actual pixel
                // size) plus a little breathing room, so "New here?
                // Register" always ends above it instead of landing on
                // top of the image's own baked-in pin/text and going
                // unreadable the way it did before this reserved gap.
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
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The "Quicky" wordmark itself, not styled Text —
                          // quicky_text.png is the brand's own stylized
                          // logotype (dimensional white-on-green lettering,
                          // leaf accent on the "y"), not something a plain
                          // TextStyle can reproduce.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Image.asset(
                              'assets/images/quicky_text.png',
                              height: 44,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Get Orders to your Doorstep',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 210),
                    // Card sized to its own content (not Expanded/stretched
                    // to fill the screen) so everything below it stays the
                    // plain, unobstructed background image. Wrapped in a
                    // Stack so [CoinFlipLogo] can sit as a sibling,
                    // straddling the card's top border rather than living
                    // in the content flow — see the Positioned below.
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          width: double.infinity,
                          // Half the logo's own size, so the card's top
                          // border passes exactly through the logo's
                          // vertical center — the other half hangs above
                          // it, over the background image.
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
                              // A second, white-tinted glow (tight, negative
                              // spread) rather than just the one dark drop
                              // shadow above — reads as light catching the
                              // card's edge, part of "more glossy at the
                              // borders" alongside the all-around border below.
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.35),
                                blurRadius: 18,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          // ClipRRect+BackdropFilter for the frosted-glass
                          // look (transparent, blurring the rider/road
                          // behind it) — the blur only samples whatever's
                          // inside this clip, so it has to wrap the filter
                          // tightly to the card's own rounded shape or
                          // it'd blur past the corners. Card is sized to
                          // its own content (not stretched to the bottom
                          // of the screen), so login_bg2 stays visible
                          // below it — see the bottom padding reserved for
                          // it further up this build method.
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
                                    // The sheen: noticeably lighter right at
                                    // the top edge (glossy highlight),
                                    // settling to a flatter, still-translucent
                                    // white for the rest of the card.
                                    colors: [
                                      Colors.white.withValues(alpha: 0.55),
                                      Colors.white.withValues(alpha: 0.32),
                                      Colors.white.withValues(alpha: 0.4),
                                    ],
                                    stops: const [0.0, 0.15, 1.0],
                                  ),
                                  // All four sides now (was top-only) and
                                  // brighter — the actual "more glossy at the
                                  // borders" ask: a visible glass edge running
                                  // all the way around the card, not just a
                                  // highlight along the top.
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    width: 1.6,
                                  ),
                                ),
                                child: Padding(
                                  // Top padding cleared for the logo's
                                  // bottom half (56) plus real breathing
                                  // room before "Sign in to continue".
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    76,
                                    24,
                                    28,
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
                                            'Sign in to continue',
                                            style: TextStyle(
                                              color: palette.textPrimary,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Use your mobile number',
                                            style: TextStyle(
                                              color: palette.textSecondary,
                                              fontSize: 13,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 28),
                                          AppTextField(
                                            label: 'Mobile number',
                                            controller: _phoneController,
                                            hint: '10-digit mobile number',
                                            keyboardType: TextInputType.phone,
                                            prefixIcon: Icons.call_outlined,
                                            enabled: !_submitting,
                                            textColor: Colors.black,
                                            maxLength: 10,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                          ),
                                          if (_error != null) ...[
                                            const SizedBox(height: 8),
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
                                                style: TextStyle(
                                                  color: palette.error,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 20),
                                          Opacity(
                                            opacity: _submitting ? 0.7 : 1,
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                                onTap: _submitting
                                                    ? null
                                                    : _submit,
                                                child: GlossySurface(
                                                  borderRadius: 22,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 17,
                                                      ),
                                                  child: Center(
                                                    child: _submitting
                                                        ? const SizedBox(
                                                            width: 22,
                                                            height: 22,
                                                            child:
                                                                CircularProgressIndicator(
                                                                  color: Colors
                                                                      .white,
                                                                  strokeWidth:
                                                                      2.4,
                                                                ),
                                                          )
                                                        : const Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              Text(
                                                                'Send OTP',
                                                                style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 16,
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                width: 8,
                                                              ),
                                                              Icon(
                                                                Icons
                                                                    .arrow_forward_rounded,
                                                                color: Colors
                                                                    .white,
                                                                size: 20,
                                                              ),
                                                            ],
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "New here?",
                                                style: TextStyle(
                                                  color: palette.textSecondary,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              TextButton(
                                                // Only User self-registers — see this
                                                // screen's doc comment — so this can
                                                // go straight there.
                                                onPressed: () {
                                                  ref
                                                      .read(
                                                        sessionControllerProvider
                                                            .notifier,
                                                      )
                                                      .selectRole(AppRole.user);
                                                  // push, not go — Register has a real
                                                  // back button (context.pop()) that
                                                  // needs an actual stack entry
                                                  // underneath it to return to; go()
                                                  // replaces the stack instead of
                                                  // adding to it, which is what made
                                                  // that back button throw "nothing to
                                                  // pop".
                                                  context.push(
                                                    '/auth/register',
                                                  );
                                                },
                                                child: const Text(
                                                  'Register',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
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
