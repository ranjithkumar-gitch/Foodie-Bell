import 'package:flutter/foundation.dart';

/// An order-lifecycle notification aimed at exactly one recipient — written
/// server-side by the `onOrderStatusChange` Cloud Function
/// (`QuickyAdmin/functions/index.js`) whenever an order is placed, a Vendor
/// accepts it, a Driver is assigned, or it's delivered. Unlike
/// `NotificationBroadcast` (Admin's shared, topic-wide sends), this is
/// per-recipient — [id] is *this* recipient's own doc, so deleting it
/// (`deletePersonalNotification`) only ever clears their own wall, never
/// anyone else's.
@immutable
class PersonalNotification {
  const PersonalNotification({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    this.orderId,
    this.type,
    this.createdAt,
  });

  final String id;
  final String recipientId;
  final String title;
  final String body;

  /// The order this notification is about, if any (every current use is
  /// order-related, but this stays nullable for whatever non-order personal
  /// notification shows up later).
  final String? orderId;

  /// The `OrderStatus.name` this notification was sent for (`"placed"`,
  /// `"vendorAccepted"`, `"driverAssigned"`, `"delivered"`) — free-text
  /// rather than a shared enum with the User app's own `OrderStatus`, since
  /// this is Cloud-Function-authored data crossing a language boundary.
  final String? type;

  final DateTime? createdAt;
}
