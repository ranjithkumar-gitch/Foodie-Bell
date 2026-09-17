import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/brand_theme.dart';

/// Persists the last-known [BrandTheme] so cold start can apply it
/// immediately, before the Firestore listener (`firestore_branding_provider.dart`)
/// resolves — see `Quicky_Branding_UserApp.md` §3.
const _cacheKey = 'brand_theme_cache';

Future<BrandTheme?> loadCachedBrandTheme() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_cacheKey);
  if (raw == null) return null;
  try {
    final theme = BrandTheme.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    return theme.isDefault ? null : theme;
  } catch (_) {
    // Corrupt/old-shape cache entry — treat as "no cached theme" rather
    // than crashing cold start over it.
    return null;
  }
}

Future<void> saveCachedBrandTheme(BrandTheme? theme) async {
  final prefs = await SharedPreferences.getInstance();
  if (theme == null) {
    await prefs.remove(_cacheKey);
  } else {
    await prefs.setString(_cacheKey, jsonEncode(theme.toCacheMap()));
  }
}
