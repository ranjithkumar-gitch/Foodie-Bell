import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/app_text_field.dart';
import '../widgets/country_code_picker.dart';
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
/// the gap between them. The header is just a back arrow (`context.pop()`,
/// falling back to `/auth/login` if there's nothing to pop) above the same
/// "Quicky" wordmark image (`quicky_text.png`) login uses — no "Register"
/// text out here anymore; that heading now lives inside the card itself,
/// styled the same way login's in-card "Login" title is (white, soft drop
/// shadow). The form sits on the same glossy frosted-glass card treatment
/// login uses — `BackdropFilter` blur, a full `Border.all` glass edge, all
/// four corners rounded (the card floats clear of the screen edges, same
/// as login's), sized to its own content so both `login_bg1.png` above and
/// `login_bg2.png` below stay visible around it. No scrolling — an
/// `Expanded` spacer between the header and the card eats whatever
/// vertical space is left, same fix as login's.
class AuthRegisterScreen extends ConsumerStatefulWidget {
  const AuthRegisterScreen({super.key});

  @override
  ConsumerState<AuthRegisterScreen> createState() => _AuthRegisterScreenState();
}

class _AuthRegisterScreenState extends ConsumerState<AuthRegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  PhoneCountry _country = kDefaultPhoneCountry;
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
                        // Back arrow sits beside the wordmark now (was
                        // stacked above it) — same "Quicky" wordmark
                        // login's header uses; the plain green "Register"
                        // Text that used to be here moved inside the card
                        // instead (see below), matching login's
                        // title-in-card treatment.
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
                                size: 35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 0),
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
                      // floats clear of the screen edges, same as login's.
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
                            // Tightened again (was 24/22, then 20/18) to
                            // keep bringing the card's overall height down.
                            padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
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
                                    Text(
                                      'Register',
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
                                    const SizedBox(height: 4),
                                    AppTextField(
                                      label: 'Full name',
                                      controller: _nameController,
                                      hint: 'Your name',
                                      prefixIcon: Icons.person_outline_rounded,
                                      textColor: Colors.black,
                                      // "Next" (not the default "Done") —
                                      // there are more fields below, and
                                      // submitting moves focus into the
                                      // next one instead of just closing
                                      // the keyboard.
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          FocusScope.of(context).nextFocus(),
                                      // Clears the validation message as
                                      // soon as the person starts fixing
                                      // the field, rather than leaving it
                                      // on screen until the next Continue
                                      // tap.
                                      onChanged: (_) {
                                        if (_error != null) {
                                          setState(() => _error = null);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 6),
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
                                      prefix: CountryCodePrefix(
                                        country: _country,
                                        onChanged: (c) =>
                                            setState(() => _country = c),
                                      ),
                                      textColor: Colors.black,
                                      maxLength: _country.phoneLength,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      // "Next" — Email (optional) is still
                                      // below this one.
                                      textInputAction: TextInputAction.next,
                                      onFieldSubmitted: (_) =>
                                          FocusScope.of(context).nextFocus(),
                                      onChanged: (_) {
                                        if (_error != null) {
                                          setState(() => _error = null);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    AppTextField(
                                      label: 'Email (optional)',
                                      controller: _emailController,
                                      hint: 'you@example.com',
                                      keyboardType: TextInputType.emailAddress,
                                      prefixIcon: Icons.mail_outline_rounded,
                                      textColor: Colors.black,
                                      // Last field on the card — "Done"
                                      // (the default), not "Next".
                                      textInputAction: TextInputAction.done,
                                    ),
                                    if (_error != null) ...[
                                      const SizedBox(height: 8),
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
                                    const SizedBox(height: 12),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(22),
                                        onTap: _continue,
                                        child: GlossySurface(
                                          borderRadius: 22,
                                          padding: const EdgeInsets.symmetric(
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
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                Icons.arrow_forward_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ),
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
                    // Reserves login_bg2.png's own rendered height (its
                    // real 941×410 aspect scaled to screen width) plus a
                    // little breathing room, so the card doesn't rest
                    // right on top of it — same fix as login's.
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
