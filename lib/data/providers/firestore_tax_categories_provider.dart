import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../models/tax_category.dart';
import '../models/vendor.dart';
import 'firestore_global_products_provider.dart' show globalProductsCollection;
import 'firestore_products_provider.dart' show productsCollection;
import 'firestore_vendors_provider.dart' show vendorsCollection;

/// Admin's GST/HSN tax brackets (`GST_HSN_IMPLEMENTATION.md` §2.1) — a
/// small, Admin-editable collection products reference by id rather than
/// carrying their own rate, so a rate change is one document write
/// (`updateTaxCategory`) that every referencing product picks up at read
/// time. Same flat-collection, real-Firestore pattern as
/// Categories/Territories/Managers.
const taxCategoriesCollectionPath = 'tax_categories';

CollectionReference<Map<String, dynamic>> get taxCategoriesCollection =>
    FirebaseFirestore.instance.collection(taxCategoriesCollectionPath);

Map<String, dynamic> _taxCategoryToDoc(TaxCategory category) => {
  'name': category.name,
  'parentCategory': category.parentCategory.name,
  'subCategory': category.subCategory,
  'hsnCode': category.hsnCode,
  'gstRate': category.gstRate,
  'itcAvailable': category.itcAvailable,
  'remittedBy': category.remittedBy.name,
  'isActive': category.isActive,
  'notes': category.notes,
};

TaxCategory _taxCategoryFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  final parentName = data['parentCategory'] as String?;
  var parentCategory = VendorCategory.food;
  for (final c in VendorCategory.values) {
    if (c.name == parentName) {
      parentCategory = c;
      break;
    }
  }
  return TaxCategory(
    id: doc.id,
    name: data['name'] as String? ?? '',
    parentCategory: parentCategory,
    subCategory: data['subCategory'] as String? ?? 'general',
    hsnCode: data['hsnCode'] as String? ?? '',
    gstRate: (data['gstRate'] as num?)?.toDouble() ?? 0,
    itcAvailable: data['itcAvailable'] as bool? ?? true,
    remittedBy: GstRemittedBy.values.byName(data['remittedBy'] as String? ?? 'vendor'),
    isActive: data['isActive'] as bool? ?? true,
    notes: data['notes'] as String?,
  );
}

/// Starter GST/HSN brackets covering Quicky's four vendor categories —
/// **typical Indian GST slabs, not a verified reference sheet** (the
/// `Quicky_HSN_GST_Reference.xlsx` §8 of `GST_HSN_IMPLEMENTATION.md`
/// points to wasn't available to seed from). Every category has a
/// `'general'` row as the fallback [suggestTaxCategory] resolves to when
/// nothing more specific matches. Admin should review/correct these on the
/// Tax Category Manager screen before relying on them for real invoicing.
const _defaultTaxCategories = [
  TaxCategory(
    id: 'food_general',
    name: 'Food — Standard Restaurant',
    parentCategory: VendorCategory.food,
    subCategory: 'general',
    hsnCode: '9963',
    gstRate: 5,
    itcAvailable: false,
  ),
  TaxCategory(
    id: 'food_packaged',
    name: 'Food — Packaged & Branded Items',
    parentCategory: VendorCategory.food,
    subCategory: 'packaged',
    hsnCode: '2106',
    gstRate: 12,
  ),
  TaxCategory(
    id: 'pharmacy_general',
    name: 'Pharmacy — General Medicines',
    parentCategory: VendorCategory.pharmacy,
    subCategory: 'general',
    hsnCode: '3004',
    gstRate: 12,
  ),
  TaxCategory(
    id: 'pharmacy_essential',
    name: 'Pharmacy — Essential/Life-saving Drugs',
    parentCategory: VendorCategory.pharmacy,
    subCategory: 'essential',
    hsnCode: '3004',
    gstRate: 5,
  ),
  TaxCategory(
    id: 'pharmacy_wellness',
    name: 'Pharmacy — Wellness & Cosmetics',
    parentCategory: VendorCategory.pharmacy,
    subCategory: 'wellness',
    hsnCode: '3304',
    gstRate: 18,
  ),
  TaxCategory(
    id: 'kirana_general',
    name: 'Kirana — Unbranded Staples',
    parentCategory: VendorCategory.kirana,
    subCategory: 'general',
    hsnCode: '1006',
    gstRate: 0,
    itcAvailable: false,
  ),
  TaxCategory(
    id: 'kirana_packaged',
    name: 'Kirana — Branded & Packaged Grocery',
    parentCategory: VendorCategory.kirana,
    subCategory: 'packaged',
    hsnCode: '2106',
    gstRate: 5,
  ),
  TaxCategory(
    id: 'kirana_snacks',
    name: 'Kirana — Packaged Branded Snacks',
    parentCategory: VendorCategory.kirana,
    subCategory: 'snacks',
    hsnCode: '1905',
    gstRate: 12,
  ),
  TaxCategory(
    id: 'vegetables_general',
    name: 'Vegetables & Fruits — Fresh Produce',
    parentCategory: VendorCategory.vegetables,
    subCategory: 'general',
    hsnCode: '0709',
    gstRate: 0,
    itcAvailable: false,
  ),
];

Future<void> _seedDefaultTaxCategoriesIfMissing() async {
  final existing = await taxCategoriesCollection.limit(1).get();
  if (existing.docs.isNotEmpty) return;
  final batch = FirebaseFirestore.instance.batch();
  for (final category in _defaultTaxCategories) {
    batch.set(taxCategoriesCollection.doc(category.id), _taxCategoryToDoc(category));
  }
  await batch.commit();
}

/// Every GST/HSN tax bracket, live — Admin's Tax Category Manager reads
/// this directly; Add/Edit Product screens filter it client-side to the
/// product's own [VendorCategory] for suggestions/the picker.
final firestoreTaxCategoriesProvider = StreamProvider<List<TaxCategory>>((ref) async* {
  await _seedDefaultTaxCategoriesIfMissing();
  yield* taxCategoriesCollection.snapshots().map((snapshot) {
    final categories = snapshot.docs.map(_taxCategoryFromDoc).toList();
    categories.sort((a, b) {
      final byParent = a.parentCategory.index.compareTo(b.parentCategory.index);
      return byParent != 0 ? byParent : a.name.compareTo(b.name);
    });
    return categories;
  });
});

/// Admin edits a bracket's rate/HSN/ITC/active flag on the Tax Category
/// Manager screen — a single-document write; every product referencing
/// [category.id] picks up the new rate the next time it's resolved, with
/// nothing to fan out across the catalogue (`GST_HSN_IMPLEMENTATION.md` §5,
/// Option A).
Future<void> updateTaxCategory(TaxCategory category) => taxCategoriesCollection.doc(category.id).set(_taxCategoryToDoc(category));

/// Best-effort suggestion for which [categories] row a product belongs to,
/// used by both Add/Edit Product screens and the backfill below — never
/// authoritative, always shown/stored as something an Admin or Vendor can
/// override. Prefers a row whose [TaxCategory.subCategory] tag appears in
/// (or contains) the product's own free-text `subCategory`; falls back to
/// the category's `'general'` row, or its first active row if even that's
/// missing.
TaxCategory? suggestTaxCategory(List<TaxCategory> categories, VendorCategory parentCategory, String productSubCategory) {
  final active = categories.where((c) => c.isActive && c.parentCategory == parentCategory).toList();
  if (active.isEmpty) return null;

  final needle = productSubCategory.trim().toLowerCase();
  if (needle.isNotEmpty) {
    for (final category in active) {
      final tag = category.subCategory.toLowerCase();
      if (tag == 'general') continue;
      if (needle.contains(tag) || tag.contains(needle)) return category;
    }
  }
  for (final category in active) {
    if (category.subCategory.toLowerCase() == 'general') return category;
  }
  return active.first;
}

/// Resolution order for what GST rate/HSN code a line item in an order
/// should actually be charged (`GST_HSN_IMPLEMENTATION.md` §2.2): a
/// per-product [Product.gstOverride] wins if set; otherwise the product's
/// assigned [Product.taxCategoryId] is looked up in [taxCategories]. A
/// product with neither yet (never assigned a tax category) contributes 0%
/// rather than blocking checkout — visible as such in the invoice, so it's
/// obvious which product still needs one assigned (Tax Category Manager's
/// backfill, or the product's own Add/Edit form) rather than silently wrong.
({String? hsnCode, double gstRate}) resolveProductGst(Product product, List<TaxCategory> taxCategories) {
  final override = product.gstOverride;
  if (override != null) return (hsnCode: override.hsnCode, gstRate: override.gstRate);

  final taxCategoryId = product.taxCategoryId;
  if (taxCategoryId != null) {
    for (final category in taxCategories) {
      if (category.id == taxCategoryId) return (hsnCode: category.hsnCode, gstRate: category.gstRate);
    }
  }
  return (hsnCode: null, gstRate: 0);
}

/// Resolves a [VendorCategory] the same way `currentVendorCategoryProvider`
/// (`vendor_session.dart`) does for the signed-in vendor's own session —
/// `Account.category` was historically stored as either the stable id
/// (`"pharmacy"`) or the display label (`"Pharmacy"`) depending on when the
/// vendor record was created, so both are checked. Falls back to Food,
/// same safety net that provider uses.
VendorCategory _resolveVendorCategory(String? accountCategory) {
  if (accountCategory != null) {
    for (final category in VendorCategory.values) {
      if (category.name == accountCategory || category.label == accountCategory) return category;
    }
  }
  return VendorCategory.food;
}

/// One-time (idempotent) backfill: assigns a suggested `taxCategoryId` to
/// every existing product — in both a Vendor's real catalogue (`products`)
/// and Admin's Global Catalogue (`global_products`) — that doesn't already
/// have one. Safe to run more than once: only untouched products (no
/// `taxCategoryId` yet) are written, so it never overwrites a deliberate
/// choice (a suggestion, once accepted or overridden, is sticky). Returns
/// the total count updated across both collections.
Future<int> backfillProductTaxCategories() async {
  final categories = (await taxCategoriesCollection.get()).docs.map(_taxCategoryFromDoc).toList();
  if (categories.isEmpty) return 0;

  final vendorCategoryById = {
    for (final doc in (await vendorsCollection.get()).docs) doc.id: _resolveVendorCategory(doc.data()['category'] as String?),
  };

  var updated = 0;

  final productDocs = (await productsCollection.get()).docs;
  var batch = FirebaseFirestore.instance.batch();
  var pending = 0;
  for (final doc in productDocs) {
    final data = doc.data();
    if (data['taxCategoryId'] != null) continue;
    final category = vendorCategoryById[data['vendorId'] as String?] ?? VendorCategory.food;
    final suggestion = suggestTaxCategory(categories, category, data['subCategory'] as String? ?? '');
    if (suggestion == null) continue;
    batch.update(doc.reference, {'taxCategoryId': suggestion.id});
    updated++;
    pending++;
    if (pending == 450) {
      await batch.commit();
      batch = FirebaseFirestore.instance.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();

  final globalDocs = (await globalProductsCollection.get()).docs;
  batch = FirebaseFirestore.instance.batch();
  pending = 0;
  for (final doc in globalDocs) {
    final data = doc.data();
    if (data['taxCategoryId'] != null) continue;
    var category = VendorCategory.food;
    for (final c in VendorCategory.values) {
      if (c.name == data['category'] as String?) {
        category = c;
        break;
      }
    }
    final suggestion = suggestTaxCategory(categories, category, data['subCategory'] as String? ?? '');
    if (suggestion == null) continue;
    batch.update(doc.reference, {'taxCategoryId': suggestion.id});
    updated++;
    pending++;
    if (pending == 450) {
      await batch.commit();
      batch = FirebaseFirestore.instance.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();

  return updated;
}
