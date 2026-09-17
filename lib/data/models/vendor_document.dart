import 'package:flutter/material.dart';

/// The fixed document checklist Manager maintains per Vendor
/// (`manager_vendor_detail_screen.dart`).
enum VendorDocumentType {
  fssaiLicense,
  gstCertificate,
  shopFrontPhoto,
  bankDetails;

  String get label => switch (this) {
    VendorDocumentType.fssaiLicense => 'FSSAI License',
    VendorDocumentType.gstCertificate => 'GST Certificate',
    VendorDocumentType.shopFrontPhoto => 'Shop Front Photo',
    VendorDocumentType.bankDetails => 'Bank Details',
  };

  IconData get icon => switch (this) {
    VendorDocumentType.fssaiLicense => Icons.badge_outlined,
    VendorDocumentType.gstCertificate => Icons.receipt_long_outlined,
    VendorDocumentType.shopFrontPhoto => Icons.storefront_outlined,
    VendorDocumentType.bankDetails => Icons.account_balance_outlined,
  };
}

/// Manager sets [required]/[notRequired] (which documents actually apply to
/// this vendor); only the Vendor, from their own login, can move a document
/// to [submitted] — Manager can see it but not tick it on the vendor's
/// behalf, otherwise "submitted" wouldn't mean anything.
enum VendorDocumentStatus { notRequired, required, submitted }
