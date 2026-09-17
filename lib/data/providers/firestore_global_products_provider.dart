import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/global_product.dart';
import '../models/tax_category.dart';
import '../models/vendor.dart';
import 'firestore_products_provider.dart' show productsCollection;
import 'global_product_storage_provider.dart';

/// Admin's platform-wide Global Catalogue (`admin_global_catalogue_screen.dart`)
/// — template products a Vendor can bulk-copy into their own catalogue
/// (`vendor_global_catalogue_screen.dart`) instead of adding every common
/// item by hand. Same real Firestore pattern as `firestore_products_provider.dart`,
/// one flat collection with an explicit `category` field per doc (a
/// vendor's own products get theirs implicitly from the vendor itself, but
/// these aren't scoped to any vendor).
const globalProductsCollectionPath = 'global_products';

CollectionReference<Map<String, dynamic>> get globalProductsCollection =>
    FirebaseFirestore.instance.collection(globalProductsCollectionPath);

Map<String, dynamic> _globalProductToDoc(GlobalProduct product) => {
  'name': product.name,
  'description': product.description,
  'price': product.price,
  'imageUrl': product.imageUrl,
  'category': product.category.name,
  'subCategory': product.subCategory,
  'unit': product.unit,
  'isVeg': product.isVeg,
  'spiceLevel': product.spiceLevel,
  'taxCategoryId': product.taxCategoryId,
  'gstOverride': product.gstOverride == null
      ? null
      : {'hsnCode': product.gstOverride!.hsnCode, 'gstRate': product.gstOverride!.gstRate, 'reason': product.gstOverride!.reason},
};

GstOverride? _gstOverrideFromDoc(Map<String, dynamic>? data) {
  if (data == null) return null;
  return GstOverride(
    hsnCode: data['hsnCode'] as String? ?? '',
    gstRate: (data['gstRate'] as num?)?.toDouble() ?? 0,
    reason: data['reason'] as String? ?? '',
  );
}

GlobalProduct _globalProductFromDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data();
  final categoryName = data['category'] as String?;
  var category = VendorCategory.food;
  for (final c in VendorCategory.values) {
    if (c.name == categoryName) {
      category = c;
      break;
    }
  }
  return GlobalProduct(
    id: doc.id,
    name: data['name'] as String? ?? '',
    description: data['description'] as String? ?? '',
    price: (data['price'] as num?)?.toDouble() ?? 0,
    imageUrl: data['imageUrl'] as String? ?? '',
    category: category,
    subCategory: data['subCategory'] as String? ?? '',
    unit: data['unit'] as String? ?? '1 pc',
    isVeg: data['isVeg'] as bool?,
    spiceLevel: (data['spiceLevel'] as num?)?.toInt() ?? 0,
    taxCategoryId: data['taxCategoryId'] as String?,
    gstOverride: _gstOverrideFromDoc(data['gstOverride'] as Map<String, dynamic>?),
  );
}

/// The full Global Catalogue, every category — Admin's management screen
/// reads this directly; Vendor's copy screen filters it client-side via
/// [globalProductsByCategoryProvider] rather than a separate query, since
/// the whole collection is small enough to watch in one shot and this keeps
/// both live without needing a composite index.
final globalProductsProvider = StreamProvider<List<GlobalProduct>>((ref) {
  return globalProductsCollection.snapshots().map((snapshot) {
    final products = snapshot.docs.map(_globalProductFromDoc).toList();
    products.sort((a, b) {
      final byCategory = a.category.index.compareTo(b.category.index);
      if (byCategory != 0) return byCategory;
      final bySubCategory = a.subCategory.compareTo(b.subCategory);
      return bySubCategory != 0 ? bySubCategory : a.name.compareTo(b.name);
    });
    return products;
  });
});

/// This vendor's own category slice of the Global Catalogue — what
/// `vendor_global_catalogue_screen.dart`'s "Copy to my catalogue" list shows.
final globalProductsByCategoryProvider =
    Provider.family<List<GlobalProduct>, VendorCategory>((ref, category) {
      final all = ref.watch(globalProductsProvider).valueOrNull ?? const [];
      return all.where((p) => p.category == category).toList();
    });

Future<void> addGlobalProduct(GlobalProduct product) =>
    globalProductsCollection.doc(product.id).set(_globalProductToDoc(product));

Future<void> updateGlobalProduct(GlobalProduct product) =>
    globalProductsCollection.doc(product.id).set(_globalProductToDoc(product));

/// Deletes the template doc and best-effort cleans up its Storage photo.
/// Vendors who already copied this into their own catalogue keep their
/// independent copy untouched — see [Product.globalProductId]'s doc comment.
Future<void> removeGlobalProduct(String productId) async {
  await globalProductsCollection.doc(productId).delete();
  try {
    await deleteGlobalProductImage(productId);
  } catch (_) {
    // Best-effort only.
  }
}

/// One-time (but idempotent) import: copies every product currently sitting
/// in any vendor's real catalogue (`products` collection,
/// `firestore_products_provider.dart`) into the Global Catalogue as a
/// template — lets Admin seed it from whatever vendors have already added
/// instead of starting from a blank slate. No callers within this app —
/// Admin's own Global Catalogue screen lives in the separate QuickyAdmin
/// app, which shares this Firestore project but has its own copy of this
/// provider. A product doc carries no [VendorCategory] of its own, so every
/// import defaults to Food, same fallback `currentVendorCategoryProvider` uses.
///
/// Safe to run more than once: each imported doc's id is derived from the
/// source product's id (`gp_import_<productId>`), so re-running just
/// overwrites the same templates rather than duplicating them. Skips a
/// product that's itself already a copy *from* the Global Catalogue
/// (`globalProductId` set) to avoid an import -> copy -> import loop.
Future<int> importExistingProductsIntoGlobalCatalogue() async {
  final snapshot = await productsCollection.get();
  final batch = FirebaseFirestore.instance.batch();
  var count = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();
    if (data['globalProductId'] != null) continue;

    final product = GlobalProduct(
      id: 'gp_import_${doc.id}',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      imageUrl: data['imageUrl'] as String? ?? '',
      category: VendorCategory.food,
      subCategory: data['subCategory'] as String? ?? '',
      unit: data['unit'] as String? ?? '1 pc',
      isVeg: data['isVeg'] as bool?,
      spiceLevel: (data['spiceLevel'] as num?)?.toInt() ?? 0,
      taxCategoryId: data['taxCategoryId'] as String?,
      gstOverride: _gstOverrideFromDoc(data['gstOverride'] as Map<String, dynamic>?),
    );
    batch.set(
      globalProductsCollection.doc(product.id),
      _globalProductToDoc(product),
    );
    count++;
  }

  if (count > 0) await batch.commit();
  return count;
}
