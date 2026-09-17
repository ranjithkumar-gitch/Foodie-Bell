import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

/// A User's cart, persisted so it survives logout/app-restart instead of
/// living purely in memory (`cart_provider.dart`'s previous behavior). One
/// doc per user (`carts/{userId}`) rather than a subcollection of per-item
/// docs — a cart is always small and every item in it shares the same
/// vendor (enforced by `CartNotifier.addItem`'s vendor-mismatch guard), so
/// the vendor fields live once at the doc level and `items` is a plain
/// array — a single read/write covers the whole cart, no batching needed.
const cartsCollectionPath = 'carts';

CollectionReference<Map<String, dynamic>> get cartsCollection =>
    FirebaseFirestore.instance.collection(cartsCollectionPath);

Map<String, dynamic> _cartItemToMap(CartItem item) => {
  'productId': item.product.id,
  'name': item.product.name,
  'description': item.product.description,
  'price': item.product.price,
  'imageUrl': item.product.imageUrl,
  'subCategory': item.product.subCategory,
  'unit': item.product.unit,
  'isVeg': item.product.isVeg,
  'isPopular': item.product.isPopular,
  'inStock': item.product.inStock,
  'spiceLevel': item.product.spiceLevel,
  'globalProductId': item.product.globalProductId,
  'quantity': item.quantity,
};

CartItem _cartItemFromMap(
  Map<String, dynamic> data, {
  required String vendorId,
  required String vendorName,
  required double deliveryFee,
  required double rebatePercent,
}) {
  return CartItem(
    product: Product(
      id: data['productId'] as String? ?? '',
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
    ),
    vendorId: vendorId,
    vendorName: vendorName,
    deliveryFee: deliveryFee,
    rebatePercent: rebatePercent,
    quantity: (data['quantity'] as num?)?.toInt() ?? 1,
  );
}

/// Overwrites the whole cart doc with the current item list — called after
/// every local mutation (`cart_provider.dart`). An empty list deletes the
/// doc instead of writing an empty one, so a cleared/checked-out cart
/// doesn't leave a stale doc behind.
Future<void> saveCart(String userId, List<CartItem> items) {
  if (items.isEmpty) return clearCartDoc(userId);
  final first = items.first;
  return cartsCollection.doc(userId).set({
    'vendorId': first.vendorId,
    'vendorName': first.vendorName,
    'deliveryFee': first.deliveryFee,
    'rebatePercent': first.rebatePercent,
    'items': items.map(_cartItemToMap).toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> clearCartDoc(String userId) => cartsCollection.doc(userId).delete();

/// One-shot read on login (`session_controller.dart`) — not a live stream,
/// since a cart only ever needs to load once per session, not stay
/// subscribed for the app's whole lifetime (see `firestore_stream_reset.dart`'s
/// doc comment for why a needlessly long-lived listener is exactly the kind
/// of thing that causes stale-state bugs).
Future<List<CartItem>> loadCart(String userId) async {
  final doc = await cartsCollection.doc(userId).get();
  final data = doc.data();
  if (data == null) return const [];
  final vendorId = data['vendorId'] as String? ?? '';
  final vendorName = data['vendorName'] as String? ?? '';
  final deliveryFee = (data['deliveryFee'] as num?)?.toDouble() ?? 0;
  final rebatePercent = (data['rebatePercent'] as num?)?.toDouble() ?? 0;
  final rawItems = data['items'] as List<dynamic>? ?? const [];
  return [
    for (final raw in rawItems)
      _cartItemFromMap(
        Map<String, dynamic>.from(raw as Map),
        vendorId: vendorId,
        vendorName: vendorName,
        deliveryFee: deliveryFee,
        rebatePercent: rebatePercent,
      ),
  ];
}
