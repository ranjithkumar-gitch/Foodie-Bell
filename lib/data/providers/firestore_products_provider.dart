import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/global_product.dart';
import '../models/product.dart';
import '../models/tax_category.dart';
import 'vendor_product_storage_provider.dart';

/// A vendor's real, persistent catalogue (spec §5.11) — same Firestore
/// pattern as Categories/Territories/Managers/Vendors. Docs live in one
/// flat `products` collection (not a `vendors/{id}/products` subcollection)
/// so a single `where('vendorId', ...)` stream works the same way
/// `firestore_vendors_provider.dart` filters orders by vendor — and each
/// vendor's own products keep their existing flat ids (`v1p1`, ...), used
/// directly as the Firestore doc id.
const productsCollectionPath = 'products';

CollectionReference<Map<String, dynamic>> get productsCollection =>
    FirebaseFirestore.instance.collection(productsCollectionPath);

Map<String, dynamic> _productToDoc(String vendorId, Product product) => {
  'vendorId': vendorId,
  'name': product.name,
  'description': product.description,
  'price': product.price,
  'imageUrl': product.imageUrl,
  'subCategory': product.subCategory,
  'unit': product.unit,
  'isVeg': product.isVeg,
  'isPopular': product.isPopular,
  'inStock': product.inStock,
  'spiceLevel': product.spiceLevel,
  'globalProductId': product.globalProductId,
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

Product _productFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
  return Product(
    id: doc.id,
    name: data['name'] as String? ?? '',
    description: data['description'] as String? ?? '',
    price: (data['price'] as num?)?.toDouble() ?? 0,
    imageUrl: data['imageUrl'] as String? ?? '',
    subCategory: data['subCategory'] as String? ?? '',
    unit: data['unit'] as String? ?? '1 pc',
    isVeg: data['isVeg'] as bool?,
    isPopular: data['isPopular'] as bool? ?? false,
    inStock: data['inStock'] as bool? ?? true,
    spiceLevel: (data['spiceLevel'] as num?)?.toInt() ?? 0,
    globalProductId: data['globalProductId'] as String?,
    taxCategoryId: data['taxCategoryId'] as String?,
    gstOverride: _gstOverrideFromDoc(data['gstOverride'] as Map<String, dynamic>?),
  );
}

/// This vendor's live catalogue — the single source of truth for the
/// Catalogue, Add/Edit Product, and Category Manager screens (spec
/// §5.11-§5.13). Sorted client-side (by sub-category then name) rather
/// than via Firestore `orderBy` so a single-field `where` doesn't need a
/// composite index. A vendor with no products yet just gets an empty list —
/// nothing seeds it.
/// Disposed when no screen shows that vendor's catalogue any more.
final vendorProductsProvider = StreamProvider.autoDispose.family<List<Product>, String>((
  ref,
  vendorId,
) {
  return productsCollection
      .where('vendorId', isEqualTo: vendorId)
      .snapshots()
      .map((snapshot) {
        final products = snapshot.docs.map(_productFromDoc).toList();
        products.sort((a, b) {
          final bySubCategory = a.subCategory.compareTo(b.subCategory);
          return bySubCategory != 0 ? bySubCategory : a.name.compareTo(b.name);
        });
        return products;
      });
});

/// One product in a territory's search index (`catalog_index`, kept by the
/// server from `products` — QuickyAdmin `functions/aggregates.js`): just
/// what search, the trending-dish filter and "Pure Veg" need. No image —
/// a result loads its own ([productByIdProvider]) when it is shown.
class CatalogEntry {
  const CatalogEntry({
    required this.productId,
    required this.vendorId,
    required this.name,
    required this.price,
    required this.isVeg,
    required this.inStock,
  });

  final String productId;
  final String vendorId;
  final String name;
  final double price;
  final bool isVeg;
  final bool inStock;
}

/// Every product of the vendors in [territoryId] — read from a few compact
/// index documents (one per shard) instead of the whole `products`
/// collection, so a search costs a handful of reads however large the
/// catalogue. Cached while any screen uses it.
final catalogIndexProvider = StreamProvider.autoDispose.family<List<CatalogEntry>, String>((ref, territoryId) {
  return FirebaseFirestore.instance
      .collection('catalog_index')
      .where('territoryId', isEqualTo: territoryId)
      .snapshots()
      .map((snapshot) => [
            for (final doc in snapshot.docs)
              for (final e in (doc.data()['products'] as Map<String, dynamic>? ?? const {}).entries)
                if (e.value is Map)
                  CatalogEntry(
                    productId: e.key,
                    vendorId: (e.value as Map)['v'] as String? ?? '',
                    name: (e.value as Map)['n'] as String? ?? '',
                    price: ((e.value as Map)['p'] as num?)?.toDouble() ?? 0,
                    isVeg: (e.value as Map)['g'] == true,
                    inStock: (e.value as Map)['s'] != false,
                  ),
          ]);
});

/// One product, read once — a search result's image and details.
final productByIdProvider = FutureProvider.autoDispose.family<Product?, String>((ref, productId) async {
  final doc = await productsCollection.doc(productId).get();
  return doc.exists ? _productFromDoc(doc) : null;
});

Future<void> addProduct(String vendorId, Product product) =>
    productsCollection.doc(product.id).set(_productToDoc(vendorId, product));

Future<void> updateProduct(String vendorId, Product product) =>
    productsCollection.doc(product.id).set(_productToDoc(vendorId, product));

/// Deletes the product doc and best-effort cleans up its Storage photo
/// (`vendor_product_storage_provider.dart`) — a Storage failure (already
/// missing, transient network hiccup) shouldn't block the product itself
/// from disappearing from the catalogue.
Future<void> removeProduct(String vendorId, String productId) async {
  await productsCollection.doc(productId).delete();
  try {
    await deleteProductImage(vendorId, productId);
  } catch (_) {
    // Best-effort only.
  }
}

Future<void> setProductStock(String productId, bool inStock) =>
    productsCollection.doc(productId).update({'inStock': inStock});

/// Bulk-copies selected Global Catalogue items into this vendor's own
/// catalogue in one batch (`vendor_global_catalogue_screen.dart`'s "Copy
/// selected" action) — each becomes its own independent product doc, with
/// [Product.globalProductId] set purely so that screen can tell it's
/// already been added. `inStock` defaults true and `isPopular`/spice carry
/// over; nothing here is shared with the template afterward.
Future<void> copyGlobalProducts(
  String vendorId,
  List<GlobalProduct> products,
) async {
  final batch = FirebaseFirestore.instance.batch();
  for (var i = 0; i < products.length; i++) {
    final g = products[i];
    final product = Product(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}_$i',
      name: g.name,
      description: g.description,
      price: g.price,
      imageUrl: g.imageUrl,
      subCategory: g.subCategory,
      unit: g.unit,
      isVeg: g.isVeg,
      spiceLevel: g.spiceLevel,
      globalProductId: g.id,
      taxCategoryId: g.taxCategoryId,
      gstOverride: g.gstOverride,
    );
    batch.set(
      productsCollection.doc(product.id),
      _productToDoc(vendorId, product),
    );
  }
  await batch.commit();
}
