enum AddressLabel { home, work, other }

extension AddressLabelX on AddressLabel {
  String get label => switch (this) {
    AddressLabel.home => 'Home',
    AddressLabel.work => 'Work',
    AddressLabel.other => 'Other',
  };
}

/// A saved delivery address (spec §4 "Delivery Address Setup"). Backed by
/// Firestore (`firestore_addresses_provider.dart`), one doc per address,
/// scoped to its owning User via a `userId` field. [recipientName]/
/// [recipientPhone] are the delivery contact for this specific address —
/// deliberately separate from the signed-in User's own account name/phone,
/// since an order can be placed for someone else (e.g. a gift, or a
/// household member) at a saved address.
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.recipientPhone,
    required this.line1,
    required this.pincode,
    required this.city,
    this.landmark,
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.isServiceable = true,
  });

  final String id;
  final AddressLabel label;
  final String recipientName;
  final String recipientPhone;

  /// House/flat + street.
  final String line1;
  final String? landmark;
  final String pincode;
  final String city;

  /// The delivery point the User confirmed on the map (`PinLocationScreen`).
  /// Null, or invalid, for addresses saved before a pin was required —
  /// those must be pinned ([hasValidPin]) before an order can use them.
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  /// Whether this pincode falls inside an active Manager territory.
  final bool isServiceable;

  String get shortLabel => '${label.label} · $line1';

  /// Whether this address carries a delivery point the server can price
  /// (`quoteOrder` refuses an address without one).
  bool get hasValidPin => isValidDeliveryPin(latitude, longitude);

  /// This address pinned at [latitude], [longitude].
  Address withPin(double latitude, double longitude) => Address(
    id: id,
    label: label,
    recipientName: recipientName,
    recipientPhone: recipientPhone,
    line1: line1,
    pincode: pincode,
    city: city,
    landmark: landmark,
    latitude: latitude,
    longitude: longitude,
    isDefault: isDefault,
    isServiceable: isServiceable,
  );
}

/// The server's rule for a usable point (`functions/routing.js`): finite,
/// latitude within ±90, longitude within ±180 — plus not exactly (0, 0),
/// which is what a missing location tends to be stored as, never a real
/// Indian delivery address.
bool isValidDeliveryPin(double? latitude, double? longitude) =>
    latitude != null &&
    longitude != null &&
    latitude.isFinite &&
    longitude.isFinite &&
    latitude.abs() <= 90 &&
    longitude.abs() <= 180 &&
    !(latitude == 0 && longitude == 0);
