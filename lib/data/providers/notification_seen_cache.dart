import 'package:shared_preferences/shared_preferences.dart';

/// Persists when an account last opened their Notifications screen — keyed
/// per account, not global, since a device can sign different accounts/
/// roles in over its lifetime, each with their own badge. Read (via
/// `notificationWallCountProvider`, `notification_count_badge.dart`) to
/// exclude anything already seen from the bell's count; written by each
/// role's Notifications screen the moment it opens.
String _cacheKey(String accountId) => 'notifications_last_seen_$accountId';

Future<DateTime?> loadNotificationsLastSeen(String accountId) async {
  final prefs = await SharedPreferences.getInstance();
  final iso = prefs.getString(_cacheKey(accountId));
  return iso == null ? null : DateTime.tryParse(iso);
}

Future<void> saveNotificationsLastSeen(
  String accountId,
  DateTime seenAt,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_cacheKey(accountId), seenAt.toIso8601String());
}
