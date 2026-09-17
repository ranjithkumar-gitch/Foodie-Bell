import 'vendor.dart';

/// Who actually remits this GST to the government for a sale under this tax
/// category — almost always the Vendor themselves (spec's normal case);
/// `platform` exists for the rarer categories where Quicky is the
/// deemed supplier (e.g. certain e-commerce-operator liabilities under
/// Section 9(5) CGST) and collects/remits on the Vendor's behalf.
enum GstRemittedBy { vendor, platform }

extension GstRemittedByX on GstRemittedBy {
  String get label => switch (this) {
    GstRemittedBy.vendor => 'Vendor',
    GstRemittedBy.platform => 'Platform',
  };
}

/// A GST/HSN tax bracket, scoped to a [VendorCategory] (and a finer
/// [subCategory] tag within it) — see `GST_HSN_IMPLEMENTATION.md` §1-2.
/// Products reference one of these by [id] (`Product.taxCategoryId`)
/// instead of carrying their own `gstRate`/`hsnCode`, so an Admin
/// rate change (`tax_category_manager_screen.dart`) is a single-document
/// write that every referencing product picks up at read time — nothing to
/// fan out across the catalogue for a routine rate change.
class TaxCategory {
  const TaxCategory({
    required this.id,
    required this.name,
    required this.parentCategory,
    required this.subCategory,
    required this.hsnCode,
    required this.gstRate,
    this.itcAvailable = true,
    this.remittedBy = GstRemittedBy.vendor,
    this.isActive = true,
    this.notes,
  });

  final String id;
  final String name;
  final VendorCategory parentCategory;

  /// Free-text tag matched against a product's own `subCategory` by
  /// `suggestTaxCategory` (`firestore_tax_categories_provider.dart`) —
  /// `'general'` is the fallback row every [parentCategory] should have one
  /// of, used whenever no finer-grained row matches.
  final String subCategory;

  final String hsnCode;

  /// Percentage, e.g. `5`, `12`, `18` — not a fraction.
  final double gstRate;
  final bool itcAvailable;
  final GstRemittedBy remittedBy;

  /// Admin can retire a bracket without deleting it (history/audit stays
  /// intact for past orders that already snapshotted it) — inactive rows
  /// are excluded from [parentCategory] suggestions and the picker.
  final bool isActive;
  final String? notes;

  TaxCategory copyWith({String? hsnCode, double? gstRate, bool? itcAvailable, GstRemittedBy? remittedBy, bool? isActive, String? notes}) => TaxCategory(
    id: id,
    name: name,
    parentCategory: parentCategory,
    subCategory: subCategory,
    hsnCode: hsnCode ?? this.hsnCode,
    gstRate: gstRate ?? this.gstRate,
    itcAvailable: itcAvailable ?? this.itcAvailable,
    remittedBy: remittedBy ?? this.remittedBy,
    isActive: isActive ?? this.isActive,
    notes: notes ?? this.notes,
  );
}

/// A per-product exception to its inherited [TaxCategory] rate (spec's
/// `gstOverride`) — e.g. one specific SKU is taxed differently from the
/// rest of its sub-category. [reason] is required precisely because this
/// is meant to be rare and auditable, not a routine way to set rates.
class GstOverride {
  const GstOverride({required this.hsnCode, required this.gstRate, required this.reason});

  final String hsnCode;
  final double gstRate;
  final String reason;
}
