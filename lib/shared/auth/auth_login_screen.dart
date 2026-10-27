import 'dart:ui' show ImageFilter;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/account_resolver.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';
import '../widgets/app_text_field.dart';
import '../widgets/country_code_picker.dart';
import '../widgets/glossy_surface.dart';
import 'auth_navigation.dart';
import 'auth_otp_screen.dart';
import 'phone_auth.dart';

/// The app's one and only entry point — a single phone number field, no
/// role picked up front and no password anywhere: every role, Manager
/// included, signs in by phone + OTP (Manager used to be email +
/// password). The role is never picked here or inferred from the typed
/// number: once Firebase has verified the number, the server works out
/// which account it belongs to (`completePhoneSignIn`,
/// `auth_navigation.dart`) — the same lookup `splash_screen.dart` uses to
/// restore a session across restarts.
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
/// background (no card behind them), and the sign-in form below sits on a
/// glossy frosted-glass card — `BackdropFilter`, transparent enough to
/// still show the blurred image behind it, with a `Border.all` glass edge
/// — sized to its own content, kept deliberately short (no logo straddling
/// its top border anymore) so both `login_bg1.png` above and
/// `login_bg2.png` below stay visible around it rather than the card
/// eating most of the screen.
///
/// The whole page is laid out to fit one screen without scrolling — the
/// old `SingleChildScrollView` is gone, replaced by an `Expanded` spacer
/// between the wordmark block and the card that eats whatever vertical
/// space is left, so `login_bg1.png` up top and `login_bg2.png` at the
/// bottom both stay fully visible at once instead of requiring a scroll
/// to reach.
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
  PhoneCountry _country = kDefaultPhoneCountry;
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

    final phone = '${_country.dialCode}$digits';

    try {
      final result = await sendPhoneCode(phone);
      if (!mounted) return;
      switch (result) {
        case SmsCodeSent(:final verificationId, :final resendToken):
          setState(() => _submitting = false);
          context.push(
            '/auth/otp?mode=login',
            extra: OtpScreenArgs(
              verificationId: verificationId,
              phoneNumber: phone,
              resendToken: resendToken,
            ),
          );
        case PhoneVerifiedAutomatically():
          final outcome = await completePhoneSignIn(context, ref, 'login');
          if (!mounted) return;
          setState(() {
            _submitting = false;
            if (outcome == PhoneSignInOutcome.noAccount) {
              _error = 'No account found for this number. Check the number, or register instead.';
            }
          });
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = phoneAuthErrorMessage(e);
      });
    } on AccountResolutionException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
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
              // No scrolling here (was SingleChildScrollView) — the whole
              // background, login_bg1's rider up top down to login_bg2's
              // stores footer at the bottom, has to be visible in one
              // screen, not revealed by scrolling. The Expanded spacer
              // below does the job the old fixed "SizedBox(height: 210)"
              // gap used to: it eats whatever vertical space is left
              // between the wordmark block and the card, shrinking on
              // short screens instead of overflowing.
              //
              // No `MediaQuery.viewInsetsOf(context).bottom` in this
              // padding (unlike the still-scrolling OTP/register-details
              // screens) — with the scroll view gone there's nothing left
              // to absorb it: the Expanded spacer can shrink to 0 but no
              // further, so reserving the keyboard's height here just
              // overflowed the layout by however much the keyboard didn't
              // fit once the spacer ran out of room. resizeToAvoidBottomInset
              // is already false, so the keyboard simply overlays the
              // bottom of the screen instead — nothing here needs to
              // shrink for it.
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
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
                    // Flexible gap (replaces the old fixed SizedBox) so the
                    // card settles wherever's left between the wordmark and
                    // the bottom-reserved space, keeping bg1 fully visible
                    // above it without needing to scroll to see it.
                    const Expanded(child: SizedBox.shrink()),
                    // Card sized to its own content (not Expanded/stretched
                    // to fill the screen) so everything below and above it
                    // stays the plain, unobstructed background image — no
                    // logo straddling its top border anymore, so no Stack
                    // sibling/margin reserved for one.
                    Container(
                      width: double.infinity,
                      // Frosted-glass look — transparent, blurring the
                      // rider/road behind it — via clipBehavior +
                      // BackdropFilter rather than a solid fill.
                      clipBehavior: Clip.antiAlias,
                      // All four corners now (was top-only) — the card
                      // floats clear of the screen edges these days (it
                      // no longer sits flush against the bottom), so a
                      // square bottom read as a mistake rather than a
                      // deliberate edge-to-edge sheet.
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
                              // The sheen: noticeably lighter right at
                              // the top edge (glossy highlight), settling
                              // to a flatter, still-translucent white for
                              // the rest of the card.
                              colors: [
                                Colors.white.withValues(alpha: 0.55),
                                Colors.white.withValues(alpha: 0.32),
                                Colors.white.withValues(alpha: 0.4),
                              ],
                              stops: const [0.0, 0.15, 1.0],
                            ),
                            // Matches the outer clip's radius now (was
                            // unrounded) — without this the border drew as
                            // a plain rectangle while the clip rounded the
                            // corners around it, so the white edge looked
                            // cut off/broken right where it mattered most.
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.7),
                              width: 1.6,
                            ),
                          ),
                          child: Padding(
                            // Shorter now that there's no logo to
                            // clear at the top — just breathing room
                            // on all four sides, so the card takes
                            // up less height and more background
                            // shows above and below it.
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 400,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Login',
                                      // White reads cleanly against the
                                      // glass — a soft dark shadow keeps it
                                      // legible over the lighter patches of
                                      // the gradient instead of washing out.
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
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
                                    const SizedBox(height: 3),
                                    Text(
                                      'Enter your mobile number to continue',
                                      // Kept dark (was already
                                      // textSecondary) — at this smaller
                                      // size and weight, white read too
                                      // faint against the glass; the
                                      // existing muted dark tone stayed the
                                      // more legible choice.
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    AppTextField(
                                      label: 'Mobile number',
                                      controller: _phoneController,
                                      hint: '10-digit mobile number',
                                      keyboardType: TextInputType.phone,
                                      // Only field on this card — "Done",
                                      // not "Next".
                                      textInputAction: TextInputAction.done,
                                      prefix: CountryCodePrefix(
                                        country: _country,
                                        enabled: !_submitting,
                                        onChanged: (c) =>
                                            setState(() => _country = c),
                                      ),
                                      enabled: !_submitting,
                                      textColor: Colors.black,
                                      maxLength: _country.phoneLength,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      // Clears the validation message as
                                      // soon as the person starts fixing
                                      // the number, rather than leaving it
                                      // on screen until the next Send OTP
                                      // tap.
                                      onChanged: (_) {
                                        if (_error != null) {
                                          setState(() => _error = null);
                                        }
                                      },
                                    ),
                                    if (_error != null) ...[
                                      const SizedBox(height: 5),
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
                                          style: TextStyle(
                                            color: palette.error,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 15),
                                    Opacity(
                                      opacity: _submitting ? 0.7 : 1,
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                          onTap: _submitting ? null : _submit,
                                          child: GlossySurface(
                                            borderRadius: 22,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 17,
                                            ),
                                            child: Center(
                                              child: _submitting
                                                  ? const SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                            color: Colors.white,
                                                            strokeWidth: 2.4,
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
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Icon(
                                                          Icons
                                                              .arrow_forward_rounded,
                                                          color: Colors.white,
                                                          size: 20,
                                                        ),
                                                      ],
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          "Don't have account?",
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
                                            context.push('/auth/register');
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
                    // Reserves login_bg2.png's own rendered height (it's
                    // fitWidth, so that height scales with screen width —
                    // 941×410 is the asset's actual pixel size) below the
                    // card, plus a little breathing room so the card
                    // doesn't rest right on top of it. Kept small (was 40)
                    // — too much here starves the Expanded spacer above,
                    // pulling the card up far enough to crowd out
                    // login_bg1's rider at the top.
                    SizedBox(
                      height:
                          MediaQuery.sizeOf(context).width * (410 / 941) + 0,
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
