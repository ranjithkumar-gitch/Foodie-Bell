import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/models/brand_theme.dart';
import 'app_colors.dart';

/// App-wide [ThemeData], built per the Quicky design system (spec §1):
/// Poppins headings / Inter body, 12px card radius, 8px input radius, 24px
/// pill buttons, green seed via [ColorScheme.fromSeed]. Optionally
/// overridden by an active occasion [BrandTheme] (`branding_controller.dart`)
/// — see `Quicky_Branding_UserApp.md`.
class AppTheme {
  AppTheme._();

  static ThemeData light([BrandTheme? brand]) => _build(_resolvePalette(AppColors.light, brand), Brightness.light);
  static ThemeData dark([BrandTheme? brand]) => _build(_resolvePalette(AppColors.dark, brand), Brightness.dark);

  /// Applies an occasion theme's color overrides on top of the base
  /// light/dark palette — only `primary`/`secondary`/`onPrimary` are ever
  /// brand-controlled (per `themeColors`'s shape); everything else
  /// (surfaces, text, success/warning/error) stays the fixed design-system
  /// value regardless of occasion.
  static AppPalette _resolvePalette(AppPalette base, BrandTheme? brand) {
    final colors = brand?.themeColors;
    if (colors == null) return base;
    return base.copyWith(
      primary: colors.primary,
      secondary: colors.accent,
      onPrimary: colors.onPrimary,
    );
  }

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: palette.primary,
        brightness: brightness,
        primary: palette.primary,
        secondary: palette.secondary,
        error: palette.error,
        surface: palette.surface,
      ),
      scaffoldBackgroundColor: palette.background,
      fontFamily: GoogleFonts.inter().fontFamily,
    );

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
        height: 1.2,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: palette.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: palette.textSecondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: palette.textMuted,
      ),
      labelLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: palette.textPrimary),
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.onPrimary,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: palette.border, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: palette.primary, width: 1.6),
        ),
        hintStyle: textTheme.bodyMedium,
      ),
      dividerTheme: DividerThemeData(color: palette.divider, thickness: 1, space: 1),
      colorScheme: base.colorScheme.copyWith(
        primary: palette.primary,
        surface: palette.surface,
        error: palette.error,
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
