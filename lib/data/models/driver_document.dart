import 'package:flutter/material.dart';

/// The fixed document checklist a Driver must submit before a Manager can
/// approve them (`manager_driver_detail_screen.dart`) — mirrors
/// `vendor_document.dart`'s [VendorDocumentType], one set per role since the
/// required documents differ (shop paperwork vs personal identity/licensing).
enum DriverDocumentType {
  profilePhoto,
  drivingLicense,
  addressProof;

  String get label => switch (this) {
    DriverDocumentType.profilePhoto => 'Profile Picture',
    DriverDocumentType.drivingLicense => "Driver's License",
    DriverDocumentType.addressProof => 'Government ID (Address Proof)',
  };

  IconData get icon => switch (this) {
    DriverDocumentType.profilePhoto => Icons.account_circle_outlined,
    DriverDocumentType.drivingLicense => Icons.badge_outlined,
    DriverDocumentType.addressProof => Icons.credit_card_outlined,
  };
}
