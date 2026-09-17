import 'package:flutter/material.dart';

/// A brightness-resolved, occasion-brand-resolved palette. Surface/text
/// colors flip with brightness; `primary`/`secondary`/`onPrimary` also
/// shift when an occasion theme is active (`branding_controller.dart`,
/// `app_theme.dart`'s `AppTheme.light`/`.dark`). Access via `context.colors`,
/// never the raw [AppColors.light]/[AppColors.dark] statics, so widgets
/// stay both dark-mode- and brand-correct — it's registered as a
/// [ThemeExtension] on the app's [ThemeData] specifically so that's true
/// everywhere, not just for widgets that go through [Theme.of]'s
/// `colorScheme`.
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.secondary,
    required this.success,
    required this.warning,
    required this.error,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.promoGradient,
    this.onPrimary = Colors.white,
  });

  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color secondary;
  final Color success;
  final Color warning;
  final Color error;
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color divider;
  final List<Color> promoGradient;
  final Color onPrimary;

  @override
  AppPalette copyWith({
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? secondary,
    Color? success,
    Color? warning,
    Color? error,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? divider,
    List<Color>? promoGradient,
    Color? onPrimary,
  }) => AppPalette(
    primary: primary ?? this.primary,
    primaryLight: primaryLight ?? this.primaryLight,
    primaryDark: primaryDark ?? this.primaryDark,
    secondary: secondary ?? this.secondary,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    border: border ?? this.border,
    divider: divider ?? this.divider,
    promoGradient: promoGradient ?? this.promoGradient,
    onPrimary: onPrimary ?? this.onPrimary,
  );

  // Theme changes in this app are instant swaps (brand activation, light/dark
  // switch), never animated — so this is a threshold step rather than a
  // real per-frame Color.lerp of every field.
  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) =>
      t < 0.5 || other is! AppPalette ? this : other;
}

/// Quicky design-system palette (spec §1). Brand green primary with
/// light/dark surface & text tables.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1B8A3D);
  static const Color primaryLight = Color(0xFF4CAF6D);
  static const Color primaryDark = Color(0xFF0F5C26);
  static const Color secondary = Color(0xFFF5A623);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFED6C02);
  static const Color error = Color(0xFFD32F2F);

  static const List<Color> promoGradient = [primaryLight, primaryDark];

  /// The "Quicky"/"Register"/"Verify OTP" wordmark on
  /// `auth_login_screen.dart`/`auth_register_screen.dart`/
  /// `auth_otp_screen.dart` — a single shared constant, not each screen
  /// picking its own value, so the three actually stay identical instead of
  /// silently drifting apart one green-shade tweak at a time. Fixed
  /// (doesn't flip with light/dark theme like [AppPalette]'s own colors do)
  /// because it's tuned for one specific thing: legible, richly-saturated
  /// green against `login_bg1.png`'s own busy greens at this exact spot —
  /// `primary`/`primaryLight` both proved too close in tone to read as
  /// green at all there, and plain `Colors.greenAccent` (Material's
  /// pastel-mint shade200) worked but read a little washed out; this is
  /// that same accent one shade more saturated (`Colors.greenAccent.shade400`).
  static const Color authHeadlineGreen = Color(0xFF00E676);

  static const AppPalette light = AppPalette(
    primary: primary,
    primaryLight: primaryLight,
    primaryDark: primaryDark,
    secondary: secondary,
    success: success,
    warning: warning,
    error: error,
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1F3EF),
    textPrimary: Color(0xFF1A1C19),
    textSecondary: Color(0xFF49454A),
    textMuted: Color(0xFF8A8D86),
    border: Color(0xFFE0E3DD),
    divider: Color(0xFFE0E3DD),
    promoGradient: promoGradient,
  );

  static const AppPalette dark = AppPalette(
    primary: primaryLight,
    primaryLight: primaryLight,
    primaryDark: primaryDark,
    secondary: secondary,
    success: Color(0xFF6BCB77),
    warning: Color(0xFFFFA24C),
    error: Color(0xFFEF5350),
    background: Color(0xFF0E1410),
    surface: Color(0xFF16201A),
    surfaceMuted: Color(0xFF1C2820),
    textPrimary: Color(0xFFE2E3DE),
    textSecondary: Color(0xFFA9ACA5),
    textMuted: Color(0xFF767B72),
    border: Color(0xFF2A362E),
    divider: Color(0xFF2A362E),
    promoGradient: [primary, primaryDark],
  );
}

extension AppColorsContext on BuildContext {
  /// Brightness- and occasion-brand-resolved palette for the nearest
  /// [Theme] — reads the [AppPalette] [ThemeExtension] [AppTheme.light]/
  /// [AppTheme.dark] register (`app_theme.dart`), so a widget reading
  /// `context.colors.primary` picks up an active occasion theme exactly
  /// like the default [ElevatedButtonTheme]/etc. do. Falls back to the
  /// plain brightness-resolved static only if a screen somehow renders
  /// under a [ThemeData] that never went through [AppTheme] (shouldn't
  /// happen in practice, but keeps this from ever returning null).
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);
}
