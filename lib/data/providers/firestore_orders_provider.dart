import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/access_scope.dart';
import '../models/account.dart';
import '../models/order.dart';
import 'firestore_coupons_provider.dart';

/// The real, persistent order lifecycle — replaces `mockOrdersProvider` as
/// the single source of truth every role reads/writes a slice of (User
/// checkout, Vendor accept/reject, Driver assignment/pickup/delivery,
/// Manager/Admin oversight). One flat `orders` collection, same pattern as
/// `products`/`vendors` — every role's screen already filters this list
/// client-side by its own field (`userId`/`vendorId`/`driverId`), so a live,
/// unfiltered stream mirrors the old shared in-memory list exactly.
const ordersCollectionPath = 'orders';

CollectionReference<Map<String, dynamic>> get ordersCollection =>
    FirebaseFirestore.instance.collection(ordersCollectionPath);

Map<String, dynamic> _lineItemToMap(OrderLineItem item) => {
  'productId': item.productId,
  'name': item.name,
  'price': item.price,
  'imageUrl': item.imageUrl,
  'quantity': item.quantity,
  'hsnCode': item.hsnCode,
  'gstRate': item.gstRate,
  'gstAmount': item.gstAmount,
};

OrderLineItem _lineItemFromMap(Map<String, dynamic> data) => OrderLineItem(
  productId: data['productId'] as String? ?? '',
  name: data['name'] as String? ?? '',
  price: (data['price'] as num?)?.toDouble() ?? 0,
  imageUrl: data['imageUrl'] as String? ?? '',
  quantity: (data['quantity'] as num?)?.toInt() ?? 1,
  hsnCode: data['hsnCode'] as String?,
  gstRate: (data['gstRate'] as num?)?.toDouble(),
  gstAmount: (data['gstAmount'] as num?)?.toDouble(),
);

/// Public so `firestore_list_order_requests_provider.dart` can write a
/// materialized `Order` into the same `WriteBatch` that transitions a
/// `ListOrderRequest` to `accepted`, instead of duplicating this mapping.
Map<String, dynamic> orderToDoc(Order order) => {
  'vendorId': order.vendorId,
  'territoryId': order.territoryId,
  'vendorName': order.vendorName,
  'userId': order.userId,
  'userName': order.userName,
  'userPhone': order.userPhone,
  'driverId': order.driverId,
  'driverName': order.driverName,
  'driverPhone': order.driverPhone,
  'items': order.items.map(_lineItemToMap).toList(),
  'status': order.status.name,
  'deliveryAddressLabel': order.deliveryAddressLabel,
  'deliveryAddressFull': order.deliveryAddressFull,
  'deliveryAddressId': order.deliveryAddressId,
  'deliveryLatitude': order.deliveryLatitude,
  'deliveryLongitude': order.deliveryLongitude,
  'paymentMethod': order.paymentMethod.name,
  'subtotal': order.subtotal,
  'deliveryFee': order.deliveryFee,
  'platformFee': order.platformFee,
  'gstAmount': order.gstAmount,
  'total': order.total,
  'placedAt': Timestamp.fromDate(order.placedAt),
  'statusTimestamps': order.statusTimestamps.map((status, at) => MapEntry(status.name, Timestamp.fromDate(at))),
  'rebatePercent': order.rebatePercent,
  'cancelReason': order.cancelReason,
  'codPaymentReceived': order.codPaymentReceived,
  'couponCode': order.couponCode,
  'couponDiscount': order.couponDiscount,
  'paymentId': order.paymentId,
  'paidAt': order.paidAt == null ? null : Timestamp.fromDate(order.paidAt!),
};

Order _orderFromDoc(String id, Map<String, dynamic> data) => Order(
  id: id,
  vendorId: data['vendorId'] as String? ?? '',
  vendorName: data['vendorName'] as String? ?? '',
  userId: data['userId'] as String? ?? '',
  userName: data['userName'] as String? ?? '',
  userPhone: data['userPhone'] as String? ?? '',
  driverId: data['driverId'] as String?,
  driverName: data['driverName'] as String?,
  driverPhone: data['driverPhone'] as String?,
  items: [for (final raw in (data['items'] as List<dynamic>? ?? const [])) _lineItemFromMap(Map<String, dynamic>.from(raw as Map))],
  status: OrderStatus.values.byName(data['status'] as String? ?? 'placed'),
  deliveryAddressLabel: data['deliveryAddressLabel'] as String? ?? '',
  deliveryAddressId: data['deliveryAddressId'] as String?,
  deliveryLatitude: (data['deliveryLatitude'] as num?)?.toDouble(),
  deliveryLongitude: (data['deliveryLongitude'] as num?)?.toDouble(),
  paymentMethod: PaymentMethod.values.byName(data['paymentMethod'] as String? ?? 'cod'),
  subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
  deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0,
  platformFee: (data['platformFee'] as num?)?.toDouble() ?? 0,
  gstAmount: (data['gstAmount'] as num?)?.toDouble() ?? 0,
  total: (data['total'] as num?)?.toDouble() ?? 0,
  placedAt: (data['placedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  statusTimestamps: {
    for (final entry in (data['statusTimestamps'] as Map<String, dynamic>? ?? const {}).entries)
      if (OrderStatus.values.any((s) => s.name == entry.key)) OrderStatus.values.byName(entry.key): (entry.value as Timestamp).toDate(),
  },
  territoryId: data['territoryId'] as String?,
  deliveryAddressFull: data['deliveryAddressFull'] as String?,
  driverLatitude: (data['driverLatitude'] as num?)?.toDouble(),
  driverLongitude: (data['driverLongitude'] as num?)?.toDouble(),
  driverLocationUpdatedAt: (data['driverLocationUpdatedAt'] as Timestamp?)?.toDate(),
  rebatePercent: (data['rebatePercent'] as num?)?.toDouble() ?? 0,
  cancelReason: data['cancelReason'] as String?,
  codPaymentReceived: data['codPaymentReceived'] as bool? ?? false,
  couponCode: data['couponCode'] as String?,
  couponDiscount: (data['couponDiscount'] as num?)?.toDouble() ?? 0,
  paymentId: data['paymentId'] as String?,
  paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
);

/// The orders the signed-in account may see, live — exactly what
/// `firestore.rules` allows for its role (screens still filter further on
/// their own fields):
///  - Customer: their own orders.
///  - Vendor: orders placed with them.
///  - Driver: deliveries assigned to them, plus — once approved — open
///    offers (Vendor-accepted, unassigned) in their territory.
///  - Manager: every order in their territory.
final firestoreOrdersProvider = StreamProvider<List<Order>>((ref) {
  final scope = ref.watch(accessScopeProvider);
  if (scope == null) return Stream.value(const []);
  Stream<List<Order>> run(Query<Map<String, dynamic>> query) =>
      query.snapshots().map((snapshot) => [for (final doc in snapshot.docs) _orderFromDoc(doc.id, doc.data())]);
  final territoryId = scope.territoryId;
  return switch (scope.role) {
    AppRole.user => run(ordersCollection.where('userId', isEqualTo: scope.accountId)),
    AppRole.vendor => run(ordersCollection.where('vendorId', isEqualTo: scope.accountId)),
    AppRole.driver => mergeQueryStreams([
      run(ordersCollection.where('driverId', isEqualTo: scope.accountId)),
      if (scope.isActive && territoryId != null)
        run(ordersCollection
            .where('territoryId', isEqualTo: territoryId)
            .where('status', isEqualTo: OrderStatus.vendorAccepted.name)),
    ], (order) => order.id),
    AppRole.manager => territoryId == null ? Stream.value(const []) : run(ordersCollection.where('territoryId', isEqualTo: territoryId)),
    AppRole.admin => Stream.value(const []),
  };
});

/// A single order, live — used by screens that navigate straight to one
/// order (checkout success, order/vendor/driver detail screens) rather than
/// filtering the full list, so they don't depend on the unfiltered stream
/// having synced yet.
final orderByIdProvider = StreamProvider.family<Order?, String>((ref, orderId) {
  return ordersCollection.doc(orderId).snapshots().map((doc) {
    final data = doc.data();
    return data == null ? null : _orderFromDoc(doc.id, data);
  });
});

/// Generates a short, cosmetic order number ("ORD-482913") used as both the
/// Firestore doc id and the id shown throughout the UI — collision risk is
/// negligible for this app's traffic, so no atomic counter/transaction is
/// needed.
String generateOrderId() => 'ORD-${DateTime.now().millisecondsSinceEpoch % 1000000}';

Future<void> createOrder(Order order) => ordersCollection.doc(order.id).set(orderToDoc(order));

/// Places an order that redeemed a coupon (`checkout_payment_screen.dart`)
/// — writes the order and a `couponRedemptions/{couponId}_{userId}` marker
/// in the same transaction, both keyed off that one deterministic
/// redemption doc. Firestore serializes concurrent transactions that touch
/// the same doc, so this is the actual enforcement point for "a coupon can
/// only be redeemed once per User" (the cart's `hasUserRedeemedCoupon`
/// check is only an early warning — see its doc comment). Throws
/// [StateError] if this User already redeemed this coupon.
Future<void> createOrderWithCoupon(Order order, {required String couponId}) {
  final redemptionRef = couponRedemptionsCollection.doc('${couponId}_${order.userId}');
  return FirebaseFirestore.instance.runTransaction((transaction) async {
    final redemption = await transaction.get(redemptionRef);
    if (redemption.exists) {
      throw StateError('You have already used this coupon.');
    }
    transaction.set(redemptionRef, {
      'couponId': couponId,
      'userId': order.userId,
      'orderId': order.id,
      'redeemedAt': Timestamp.now(),
    });
    transaction.set(ordersCollection.doc(order.id), orderToDoc(order));
  });
}

/// Advances an order's status — also stamps `statusTimestamps.{status}` via
/// a dotted-field update, so it's recorded without touching any other
/// status already stamped (each one is set exactly once, the first time
/// the order reaches it).
Future<void> updateOrderStatus(String orderId, OrderStatus status, {String? driverId, String? driverName, String? driverPhone}) => ordersCollection.doc(orderId).update({
  'status': status.name,
  'statusTimestamps.${status.name}': Timestamp.now(),
  'driverId': ?driverId,
  'driverName': ?driverName,
  'driverPhone': ?driverPhone,
});

/// The assigned Driver's position, mirrored onto their order
/// (`driver_location_tracker.dart`) so its Customer can follow the delivery
/// (`DriverLiveMap`) without reading the Driver's own record.
Future<void> updateOrderDriverLocation(String orderId, {required double latitude, required double longitude}) =>
    ordersCollection.doc(orderId).update({
      'driverLatitude': latitude,
      'driverLongitude': longitude,
      'driverLocationUpdatedAt': FieldValue.serverTimestamp(),
    });

Future<void> cancelOrder(String orderId, String reason) => ordersCollection.doc(orderId).update({
  'status': OrderStatus.cancelled.name,
  'statusTimestamps.${OrderStatus.cancelled.name}': Timestamp.now(),
  'cancelReason': reason,
});

/// Also stamps `paidAt` — the moment the cash changed hands is when a COD
/// order's payment completed, same as Checkout success is for an online one.
Future<void> markCodPaymentReceived(String orderId) => ordersCollection.doc(orderId).update({
  'codPaymentReceived': true,
  'paidAt': Timestamp.now(),
});
