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

/// When this account last tapped "Delete all" on their Notifications screen
/// (`notification_wall.dart`). Personal notifications are deleted from the
/// server; Admin broadcasts and chat messages are shared, so the wall on
/// this device hides the ones from before this point instead.
String _clearedKey(String accountId) => 'notifications_cleared_at_$accountId';

Future<DateTime?> loadNotificationsClearedAt(String accountId) async {
  final prefs = await SharedPreferences.getInstance();
  final iso = prefs.getString(_clearedKey(accountId));
  return iso == null ? null : DateTime.tryParse(iso);
}

Future<void> saveNotificationsClearedAt(String accountId, DateTime at) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_clearedKey(accountId), at.toIso8601String());
}
