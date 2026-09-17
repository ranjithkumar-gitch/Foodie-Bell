import 'package:shared_preferences/shared_preferences.dart';

/// Persists the User's last-picked territory id (`selected_territory_provider.dart`)
/// so it survives an app restart — same pattern as `brand_theme_cache.dart`.
/// Previously this was pure in-memory state (harmless, since it only drove
/// which vendors/categories showed); it now also has to stay correct across
/// restarts so the device's FCM topic subscription (`fcm_topics.dart`)
/// doesn't silently drift from whatever territory is actually displayed.
const _cacheKey = 'selected_territory_id';

Future<String?> loadCachedTerritoryId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_cacheKey);
}

Future<void> saveCachedTerritoryId(String? territoryId) async {
  final prefs = await SharedPreferences.getInstance();
  if (territoryId == null) {
    await prefs.remove(_cacheKey);
  } else {
    await prefs.setString(_cacheKey, territoryId);
  }
}
