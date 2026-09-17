import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Shared visual chassis for the sign-in, OTP, and registration screens
/// (`auth_login_screen.dart`, `auth_otp_screen.dart`, `auth_register_screen.dart`)
/// — one solid green gradient (`palette.promoGradient`, same as the splash
/// screen) filling the whole page, content flowing top-down on it. Replaced
/// an earlier two-tone "gradient hero + white sheet" version: that one
/// resized/reflowed when the keyboard opened (`resizeToAvoidBottomInset`
/// shrinking the sheet under it), which read as the page visibly jumping —
/// `resizeToAvoidBottomInset: false` here means the layout never moves;
/// the keyboard just overlays on top and the page scrolls to bring the
/// focused field above it instead.
class AuthHeroScaffold extends StatelessWidget {
  const AuthHeroScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: palette.promoGradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
