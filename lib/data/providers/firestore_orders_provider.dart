import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  'paymentMethod': order.paymentMethod.name,
  'subtotal': order.subtotal,
  'deliveryFee': order.deliveryFee,
  'platformFee': order.platformFee,
  'gstAmount': order.gstAmount,
  'total': order.total,
  'placedAt': Timestamp.fromDate(order.placedAt),
  'statusTimestamps': order.statusTimestamps.map((status, at) => MapEntry(status.name, Timestamp.fromDate(at))),
  'handoverCode': order.handoverCode,
  'deliveryOtp': order.deliveryOtp,
  'rebatePercent': order.rebatePercent,
  'cancelReason': order.cancelReason,
  'codPaymentReceived': order.codPaymentReceived,
  'couponCode': order.couponCode,
  'couponDiscount': order.couponDiscount,
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
  handoverCode: data['handoverCode'] as String? ?? '4821',
  deliveryOtp: data['deliveryOtp'] as String? ?? '7734',
  rebatePercent: (data['rebatePercent'] as num?)?.toDouble() ?? 0,
  cancelReason: data['cancelReason'] as String?,
  codPaymentReceived: data['codPaymentReceived'] as bool? ?? false,
  couponCode: data['couponCode'] as String?,
  couponDiscount: (data['couponDiscount'] as num?)?.toDouble() ?? 0,
);

/// Every order on the platform, live — every role's screen filters this
/// client-side by its own field, same as the old `mockOrdersProvider` list.
final firestoreOrdersProvider = StreamProvider<List<Order>>((ref) {
  return ordersCollection.snapshots().map((snapshot) => [for (final doc in snapshot.docs) _orderFromDoc(doc.id, doc.data())]);
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

final _orderCodeRandom = Random();

/// A random 4-digit code for [Order.handoverCode]/[Order.deliveryOtp] —
/// every order placement site (`checkout_payment_screen.dart`,
/// `vendor_order_queue_screen.dart`'s photo-order handoff) calls this once
/// per code so the two never collide with each other on the same order, and
/// no two orders ever share the same handover/delivery code. [Order]'s
/// `'4821'`/`'7734'` constructor defaults exist only as a fallback for
/// orders placed before this existed — a live placement should never rely
/// on them.
String generateOrderCode() => (1000 + _orderCodeRandom.nextInt(9000)).toString();

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

Future<void> cancelOrder(String orderId, String reason) => ordersCollection.doc(orderId).update({
  'status': OrderStatus.cancelled.name,
  'statusTimestamps.${OrderStatus.cancelled.name}': Timestamp.now(),
  'cancelReason': reason,
});

Future<void> markCodPaymentReceived(String orderId) => ordersCollection.doc(orderId).update({'codPaymentReceived': true});
