/// A Driver's last reported GPS position — written to their own
/// `drivers/{id}` doc by `driver_location_tracker.dart` while they're signed
/// in, read live by the User's order tracking map (`driver_live_map.dart`).
class DriverLocation {
  const DriverLocation({required this.latitude, required this.longitude, this.updatedAt});

  final double latitude;
  final double longitude;

  /// When the Driver's device last reported this position — null only for
  /// the instant between a write and Firestore resolving its server
  /// timestamp.
  final DateTime? updatedAt;
}
