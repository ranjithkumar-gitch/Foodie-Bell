import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/vendor.dart';

/// In-memory draft carried across the 5-step Vendor registration wizard
/// (spec §5 items 1-5). Not wired to a real backend yet — the Manager Code
/// step (`vendor_manager_code_screen.dart`) rejects every code, so this
/// draft is never actually turned into an account; a real Vendor account is
/// currently only ever created by a Manager directly
/// (`manager_vendor_create_screen.dart`). This draft exists only so each
/// step remembers what earlier steps collected (and so later steps can
/// branch on category, e.g. FSSAI/ordering-window rules).
class VendorRegistrationDraft {
  const VendorRegistrationDraft({
    this.shopName = '',
    this.category = VendorCategory.food,
    this.subCategories = const [],
    this.ownerName = '',
    this.phone = '',
    this.managerCode = '',
    this.managerCodeVerified = false,
    this.fssaiFileName,
    this.gstFileName,
    this.panFileName,
    this.bankUpiFileName,
    this.operatingHours = '9:00 AM - 10:00 PM, all days',
    this.rebatePercent = 15,
    this.rebateAccepted = false,
  });

  final String shopName;
  final VendorCategory category;
  final List<String> subCategories;
  final String ownerName;
  final String phone;
  final String managerCode;
  final bool managerCodeVerified;
  final String? fssaiFileName;
  final String? gstFileName;
  final String? panFileName;
  final String? bankUpiFileName;
  final String operatingHours;
  final double rebatePercent;
  final bool rebateAccepted;

  VendorRegistrationDraft copyWith({
    String? shopName,
    VendorCategory? category,
    List<String>? subCategories,
    String? ownerName,
    String? phone,
    String? managerCode,
    bool? managerCodeVerified,
    String? fssaiFileName,
    String? gstFileName,
    String? panFileName,
    String? bankUpiFileName,
    String? operatingHours,
    double? rebatePercent,
    bool? rebateAccepted,
  }) => VendorRegistrationDraft(
    shopName: shopName ?? this.shopName,
    category: category ?? this.category,
    subCategories: subCategories ?? this.subCategories,
    ownerName: ownerName ?? this.ownerName,
    phone: phone ?? this.phone,
    managerCode: managerCode ?? this.managerCode,
    managerCodeVerified: managerCodeVerified ?? this.managerCodeVerified,
    fssaiFileName: fssaiFileName ?? this.fssaiFileName,
    gstFileName: gstFileName ?? this.gstFileName,
    panFileName: panFileName ?? this.panFileName,
    bankUpiFileName: bankUpiFileName ?? this.bankUpiFileName,
    operatingHours: operatingHours ?? this.operatingHours,
    rebatePercent: rebatePercent ?? this.rebatePercent,
    rebateAccepted: rebateAccepted ?? this.rebateAccepted,
  );
}

class VendorRegistrationNotifier extends StateNotifier<VendorRegistrationDraft> {
  VendorRegistrationNotifier() : super(const VendorRegistrationDraft());

  void update(VendorRegistrationDraft Function(VendorRegistrationDraft draft) updater) {
    state = updater(state);
  }

  /// Called once the wizard hands off to the shared phone/OTP + terms
  /// screens, so a second registration attempt in the same session starts
  /// clean.
  void reset() => state = const VendorRegistrationDraft();
}

final vendorRegistrationProvider =
    StateNotifierProvider<VendorRegistrationNotifier, VendorRegistrationDraft>(
        (ref) => VendorRegistrationNotifier());
