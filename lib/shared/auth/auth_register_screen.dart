import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/coin_flip_logo.dart';
import '../widgets/glossy_surface.dart';
import 'user_registration_draft.dart';

/// Generic registration-details step for roles that don't need role-specific
/// fields first — effectively User: name + phone + email (optional)
/// (spec §4 item 1). Submitting stages all three in
/// `userRegistrationDraftProvider`, then hands off to
/// `/auth/phone?mode=register` — `AuthPhoneScreen` pre-fills its number
/// field from the draft's phone so the user isn't asked to type the same
/// number twice; they can still edit it there before sending the OTP,
/// which is what actually ends up verified. Vendor/Driver/Manager reach
/// registration through their own `/${role}/register` flow instead of this
/// screen.
///
/// Bespoke layout, not [AuthHeroScaffold] — mirrors `auth_login_screen.dart`'s
/// visual language exactly: `login_bg1.png` (icon row + delivery rider)
/// anchored to the top, `login_bg2.png` (the stores/delivery/community
/// footer) anchored to the bottom, a plain `palette.promoGradient` filling
/// the gap between them. Just the "Register" wordmark sits directly on
/// that hero background — no subtext, no separate header logo. The form
/// sits on the same glossy frosted-glass card treatment login uses —
/// `ClipRRect`+`BackdropFilter`, a full `Border.all` glass edge, sized to
/// its own content so `login_bg2.png` stays visible below it, rising up to
/// overlap `login_bg1.png` at the top exactly the way login's card does.
/// [CoinFlipLogo] straddles the card's top border — the card's own top
/// margin is exactly half the logo's size, so the border passes through
/// the logo's center.
class AuthRegisterScreen extends ConsumerStatefulWidget {
  const AuthRegisterScreen({super.key});

  @override
  ConsumerState<AuthRegisterScreen> createState() => _AuthRegisterScreenState();
}

class _AuthRegisterScreenState extends ConsumerState<AuthRegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().length != 10) {
      setState(
        () => _error = 'Enter your name and a valid 10-digit mobile number',
      );
      return;
    }
    setState(() => _error = null);
    final email = _emailController.text.trim();
    ref
        .read(userRegistrationDraftProvider.notifier)
        .updateDetails(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: email.isEmpty ? null : email,
        );
    context.go('/auth/phone?mode=register');
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
                // in the form ever lands on top of that image's own
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
                            'Register',
                            style: TextStyle(
                              // Shared with login/OTP's own headline — see
                              // AppColors.authHeadlineGreen's doc comment.
                              color: AppColors.authHeadlineGreen,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 135),
                    // Card sized to its own content (not stretched to the
                    // screen's bottom edge) so login_bg2 stays visible
                    // below it — see the reserved bottom padding above.
                    // Wrapped in a Stack so CoinFlipLogo can straddle the
                    // card's top border as a sibling — see auth_login_screen
                    // .dart's identical treatment.
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
                                  // room before the first field.
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
                                          AppTextField(
                                            label: 'Full name',
                                            controller: _nameController,
                                            hint: 'Your name',
                                            prefixIcon:
                                                Icons.person_outline_rounded,
                                            textColor: Colors.black,
                                          ),
                                          const SizedBox(height: 16),
                                          AppTextField(
                                            label: 'Mobile number',
                                            controller: _phoneController,
                                            hint: '10-digit mobile number',
                                            // Plain numeric keypad, not the
                                            // phone dialer layout (which
                                            // adds *, #, + — unneeded here
                                            // since digitsOnly already
                                            // rejects anything but digits)
                                            // — matches the OTP field's own
                                            // TextInputType.number later in
                                            // this same registration flow.
                                            keyboardType: TextInputType.number,
                                            prefixIcon: Icons.call_outlined,
                                            textColor: Colors.black,
                                            maxLength: 10,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          AppTextField(
                                            label: 'Email (optional)',
                                            controller: _emailController,
                                            hint: 'you@example.com',
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            prefixIcon:
                                                Icons.mail_outline_rounded,
                                            textColor: Colors.black,
                                          ),
                                          if (_error != null) ...[
                                            const SizedBox(height: 14),
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
                                          const SizedBox(height: 24),
                                          Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(22),
                                              onTap: _continue,
                                              child: GlossySurface(
                                                borderRadius: 22,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 17,
                                                    ),
                                                child: const Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'Continue',
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
                                          const SizedBox(height: 16),
                                          // Small trust cue — a lightweight
                                          // reassurance right under the CTA,
                                          // not a functional element.
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: palette.primary.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.lock_outline_rounded,
                                                  size: 15,
                                                  color: palette.primary,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Your information is safe with us',
                                                  style: TextStyle(
                                                    color: palette.primary,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12,
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
