import 'package:flutter/foundation.dart';

/// A push notification Admin sent (QuickyAdmin's `push_notification_screen.dart`
/// → the `sendPushNotification` Cloud Function → `notification_broadcasts`).
/// The User app's own copy of this shape — see
/// `firestore_notifications_provider.dart` for how it's filtered down to
/// only the ones this device was actually subscribed to receive.
@immutable
class NotificationBroadcast {
  const NotificationBroadcast({
    required this.id,
    required this.title,
    required this.body,
    required this.topic,
    required this.targetLabel,
    this.sentAt,
  });

  final String id;
  final String title;
  final String body;
  final String topic;

  /// "All users" or the territory's name — kept for parity with the admin
  /// side's copy of this shape (`push_notification_screen.dart`'s history
  /// list shows it); the User-facing Notifications screen doesn't display
  /// it, just [title]/[body].
  final String targetLabel;

  final DateTime? sentAt;
}
