import 'package:flutter/material.dart';

/// Parses a `#RRGGBB`/`#AARRGGBB` (or bare `RRGGBB`) hex string into a
/// [Color] — the format `app_config/current_theme.themeColors.*` is stored
/// in. Returns null for anything that doesn't parse, so a malformed value
/// falls back to the default palette instead of crashing.
Color? colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var value = hex.trim().replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// The three brand colors an occasion theme can override — mirrors
/// `app_config/current_theme.themeColors` (spec doc's §1).
class BrandThemeColors {
  const BrandThemeColors({this.primary, this.accent, this.onPrimary});

  final Color? primary;
  final Color? accent;
  final Color? onPrimary;

  factory BrandThemeColors.fromMap(Map<String, dynamic> map) => BrandThemeColors(
    primary: colorFromHex(map['primary'] as String?),
    accent: colorFromHex(map['accent'] as String?),
    onPrimary: colorFromHex(map['onPrimary'] as String?),
  );
}

/// The active occasion theme, read live from `app_config/current_theme`
/// (`firestore_branding_provider.dart`) — updated by QuickyAdmin, this app
/// only ever reads it. See `Quicky_Branding_UserApp.md` for the full
/// spec this mirrors.
class BrandTheme {
  const BrandTheme({
    this.occasionId,
    this.logoOverlayUrl,
    this.dashboardThemeUrl,
    this.themeColors,
    this.appIconKey,
  });

  final String? occasionId;
  final String? logoOverlayUrl;
  final String? dashboardThemeUrl;
  final BrandThemeColors? themeColors;

  /// Which bundled home-screen icon variant this occasion activates
  /// ("festiveGold"/"festiveRed", set by QuickyAdmin's Occasion picker —
  /// see the app-icon migration plan) — null means "leave the default
  /// icon". Unlike [logoOverlayUrl]/[dashboardThemeUrl], this can never be
  /// an arbitrary uploaded image: both platforms only support switching
  /// among icons bundled into the app at build time
  /// (`app_icon_channel.dart`), so this is always one of a small fixed set
  /// of keys.
  final String? appIconKey;

  /// True when there's no active occasion — every consumer should render
  /// its default, unbranded appearance in that case.
  bool get isDefault => occasionId == null;

  factory BrandTheme.fromMap(Map<String, dynamic> map) => BrandTheme(
    occasionId: map['occasionId'] as String?,
    logoOverlayUrl: map['logoOverlayUrl'] as String?,
    dashboardThemeUrl: map['dashboardThemeUrl'] as String?,
    themeColors: map['themeColors'] == null
        ? null
        : BrandThemeColors.fromMap(Map<String, dynamic>.from(map['themeColors'] as Map)),
    appIconKey: map['appIconKey'] as String?,
  );

  Map<String, dynamic> toCacheMap() => {
    'occasionId': occasionId,
    'logoOverlayUrl': logoOverlayUrl,
    'dashboardThemeUrl': dashboardThemeUrl,
    'themeColors': themeColors == null
        ? null
        : {
            'primary': themeColors!.primary == null ? null : '#${themeColors!.primary!.toARGB32().toRadixString(16)}',
            'accent': themeColors!.accent == null ? null : '#${themeColors!.accent!.toARGB32().toRadixString(16)}',
            'onPrimary': themeColors!.onPrimary == null ? null : '#${themeColors!.onPrimary!.toARGB32().toRadixString(16)}',
          },
    'appIconKey': appIconKey,
  };
}
