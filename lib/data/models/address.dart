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
  final bool isDefault;

  /// Whether this pincode falls inside an active Manager territory.
  final bool isServiceable;

  String get shortLabel => '${label.label} · $line1';
}
