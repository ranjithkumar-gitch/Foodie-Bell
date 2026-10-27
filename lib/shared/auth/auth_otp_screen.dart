import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/account_resolver.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/otp_input_field.dart';
import 'auth_navigation.dart';
import 'phone_auth.dart';

/// Passed from the login/phone screens via go_router's `extra:` —
/// `verificationId` is an opaque Firebase token, not a display value, so it
/// doesn't belong in a query param. `phoneNumber`/`resendToken` let "Resend
/// code" re-run `verifyPhoneNumber` as a proper resend.
class OtpScreenArgs {
  const OtpScreenArgs({
    required this.verificationId,
    required this.phoneNumber,
    this.resendToken,
  });

  final String verificationId;
  final String phoneNumber;
  final int? resendToken;
}

/// Verifies the SMS code with Firebase Phone Auth, then hands off to
/// [completePhoneSignIn], which asks the server which account (if any) this
/// verified number belongs to. Login lands on that account; register mode
/// goes on to the Terms gate (see [AuthTermsScreen]'s doc comment for why
/// terms come after OTP) unless the number already has an account.
///
/// Android may verify the number on its own (SMS auto-retrieval) while this
/// screen is up — that sign-in happens in `sendPhoneCode`
/// (`phone_auth.dart`), and this screen picks it up from
/// `authStateChanges()` the same as a typed code.
///
/// Bespoke layout, not [AuthHeroScaffold] — mirrors `auth_login_screen.dart`/
/// `auth_register_screen.dart`'s visual language exactly: `login_bg1.png` +
/// `login_bg2.png` hero background, a back arrow beside the "Quicky"
/// wordmark (`quicky_text.png`) up top — no "Verify OTP" text out there
/// anymore; that heading now lives inside the card as "Enter verification
/// code" (already the card's own heading, just restyled white with a soft
/// drop shadow, same as login/register's in-card titles). The pin entry
/// sits on the same glossy frosted-glass card treatment — `BackdropFilter`
/// blur, a full `Border.all` glass edge, all four corners rounded, sized to
/// its own content so both hero images stay visible around it. No logo
/// straddling its top border and no scrolling — an `Expanded` spacer
/// between the header and the card eats whatever vertical space is left,
/// same fix as login/register's.
class AuthOtpScreen extends ConsumerStatefulWidget {
  const AuthOtpScreen({super.key, required this.args, this.mode = 'login'});

  final OtpScreenArgs args;
  final String mode;

  @override
  ConsumerState<AuthOtpScreen> createState() => _AuthOtpScreenState();
}

class _AuthOtpScreenState extends ConsumerState<AuthOtpScreen> {
  late String _verificationId = widget.args.verificationId;
  late int? _resendToken = widget.args.resendToken;
  StreamSubscription<User?>? _authSub;
  String? _error;
  bool _verifying = false;
  bool _finishing = false;

  /// The code went through but the server couldn't be reached afterwards —
  /// the verified sign-in is kept, so "Try again" only needs to redo the
  /// account lookup, not re-enter a (now used) code.
  bool _canRetryLookup = false;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null && user.phoneNumber == widget.args.phoneNumber && !_verifying) {
        _finish();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _onCompleted(String code) async {
    if (_verifying || _finishing) return;
    setState(() {
      _verifying = true;
      _error = null;
      _canRetryLookup = false;
    });
    try {
      await signInWithPhoneCode(_verificationId, code);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _error = phoneAuthErrorMessage(e);
      });
      return;
    }
    await _finish();
  }

  /// Runs at most once at a time, whichever of a typed code or Android's
  /// auto-retrieval gets there first.
  Future<void> _finish() async {
    if (_finishing || !mounted) return;
    setState(() {
      _finishing = true;
      _verifying = true;
      _error = null;
      _canRetryLookup = false;
    });
    try {
      final outcome = await completePhoneSignIn(context, ref, widget.mode);
      if (outcome == PhoneSignInOutcome.noAccount && mounted) {
        setState(() => _error = 'No account found for this number. Check the number, or register instead.');
      }
    } on AccountResolutionException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _canRetryLookup = true;
      });
    } catch (e, st) {
      debugPrint('completePhoneSignIn failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _canRetryLookup = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _finishing = false;
          _verifying = false;
        });
      }
    }
  }

  Future<void> _onResend() async {
    setState(() {
      _error = null;
      _canRetryLookup = false;
    });
    try {
      final result = await sendPhoneCode(widget.args.phoneNumber, resendToken: _resendToken);
      if (!mounted) return;
      switch (result) {
        case SmsCodeSent(:final verificationId, :final resendToken):
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A new code is on its way.')));
        case PhoneVerifiedAutomatically():
          await _finish();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = phoneAuthErrorMessage(e));
    }
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
              // No scrolling here — the whole background, login_bg1's rider
              // up top down to login_bg2's stores footer at the bottom, has
              // to be visible in one screen. See auth_login_screen.dart's
              // identical fix for why.
              //
              // No `MediaQuery.viewInsetsOf(context).bottom` in this
              // padding — with no scroll view to absorb it, the Expanded
              // spacer below can only shrink to 0, so reserving the
              // keyboard's height here just overflowed the layout once the
              // spacer ran out of room. resizeToAvoidBottomInset is
              // already false, so the keyboard just overlays the bottom of
              // the screen instead.
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back arrow beside the "Quicky" wordmark, same
                        // treatment as login/register's headers — the
                        // plain green "Verify OTP" Text that used to be
                        // here moved inside the card instead (see below),
                        // matching their title-in-card treatment.
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                                Icons.keyboard_arrow_left_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Image.asset(
                              'assets/images/quicky_text.png',
                              height: 44,
                              fit: BoxFit.contain,
                            ),
                          ],
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
                    // Flexible gap (replaces the old fixed SizedBox) so the
                    // card settles wherever's left between the header and
                    // the bottom-reserved space — same fix as login's.
                    const Expanded(child: SizedBox.shrink()),
                    // Card sized to its own content (not stretched to the
                    // screen's bottom edge) so login_bg1/login_bg2 stay
                    // visible around it. No logo straddling its top border
                    // anymore, so no Stack sibling for one.
                    Container(
                      width: double.infinity,
                      // Frosted-glass look — transparent, blurring the
                      // rider/road behind it — via clipBehavior +
                      // BackdropFilter rather than a solid fill.
                      clipBehavior: Clip.antiAlias,
                      // All four corners now (was top-only) — the card
                      // floats clear of the screen edges, same as
                      // login/register's.
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(30)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 30,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(30),
                            ),
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
                            // Matches the outer clip's radius (was
                            // unrounded) so the white edge wraps cleanly
                            // around every corner instead of drawing as a
                            // plain rectangle under a rounded clip.
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7),
                              width: 1.6,
                            ),
                          ),
                          child: Padding(
                            // Shorter now that there's no logo to clear at
                            // the top — just breathing room on all sides.
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 440,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Same treatment as login's in-card
                                    // "Login" title — white with a soft
                                    // dark shadow so it stays legible over
                                    // the lighter patches of the glass.
                                    // (This was already the card's own
                                    // heading — just restyled, not a new
                                    // element — the outer green "Verify
                                    // OTP" text is what moved out.)
                                    Text(
                                      'Enter verification code',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 6,
                                          ),
                                        ],
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
                                            text: 'We sent a 6-digit code to ',
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
                                    const SizedBox(height: 20),
                                    Center(
                                      child: OtpInputField(
                                        onCompleted: _onCompleted,
                                        onResend: _onResend,
                                      ),
                                    ),
                                    if (_verifying) ...[
                                      const SizedBox(height: 10),
                                      Center(
                                        child: CircularProgressIndicator(
                                          color: palette.primary,
                                        ),
                                      ),
                                    ],
                                    if (_error != null) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: palette.error.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
                                      if (_canRetryLookup && !_verifying)
                                        TextButton(
                                          onPressed: _finish,
                                          child: const Text('Try again'),
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
                    // Reserves login_bg2.png's own rendered height (its
                    // real 941×410 aspect scaled to screen width) plus
                    // extra breathing room so the card sits up off the
                    // footer image — the Expanded spacer above shrinks to
                    // make room, which is what actually pulls the card up
                    // off the bottom of the screen (same knob as login's).
                    SizedBox(
                      height:
                          MediaQuery.sizeOf(context).width * (410 / 941) + 40,
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
