import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/coupon.dart';

/// Vendor coupons — one flat `coupons` collection, same pattern as
/// `promotions`/`orders`: every screen filters this client-side by its own
/// field (`vendorId` for the Vendor's Coupons list, live+territory for
/// User Home, `vendorId` again for the Cart's "available coupons" sheet).
const couponsCollectionPath = 'coupons';

/// One doc per (coupon, user) redemption, keyed `{couponId}_{userId}` so a
/// Firestore transaction touching that exact doc is what actually enforces
/// "one use per User" (`createOrderWithCoupon`,
/// `firestore_orders_provider.dart`) — this collection is never queried by
/// a range/list, only ever read or written by that one deterministic key.
const couponRedemptionsCollectionPath = 'couponRedemptions';

CollectionReference<Map<String, dynamic>> get couponsCollection =>
    FirebaseFirestore.instance.collection(couponsCollectionPath);

CollectionReference<Map<String, dynamic>> get couponRedemptionsCollection =>
    FirebaseFirestore.instance.collection(couponRedemptionsCollectionPath);

Map<String, dynamic> _couponToDoc(Coupon coupon) => {
  'vendorId': coupon.vendorId,
  'vendorName': coupon.vendorName,
  'code': coupon.code,
  'discountType': coupon.discountType.name,
  'discountValue': coupon.discountValue,
  'appliesToAllItems': coupon.appliesToAllItems,
  'productIds': coupon.productIds,
  'startAt': Timestamp.fromDate(coupon.startAt),
  'endAt': Timestamp.fromDate(coupon.endAt),
  'createdAt': Timestamp.fromDate(coupon.createdAt),
};

Coupon _couponFromDoc(String id, Map<String, dynamic> data) => Coupon(
  id: id,
  vendorId: data['vendorId'] as String? ?? '',
  vendorName: data['vendorName'] as String? ?? '',
  code: data['code'] as String? ?? '',
  discountType: CouponDiscountType.values.byName(
    data['discountType'] as String? ?? 'percentage',
  ),
  discountValue: (data['discountValue'] as num?)?.toDouble() ?? 0,
  appliesToAllItems: data['appliesToAllItems'] as bool? ?? true,
  productIds: [
    for (final id in (data['productIds'] as List<dynamic>? ?? const []))
      id as String,
  ],
  startAt: (data['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  endAt:
      (data['endAt'] as Timestamp?)?.toDate() ??
      DateTime.now().add(const Duration(days: 7)),
  createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
);

/// Every coupon on the platform, live — every role's screen filters this
/// client-side by its own field, same convention as
/// `firestorePromotionsProvider`.
final firestoreCouponsProvider = StreamProvider<List<Coupon>>((ref) {
  return couponsCollection.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs) _couponFromDoc(doc.id, doc.data()),
    ],
  );
});

final _codeRandom = Random.secure();
const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// A short, vendor-branded, human-typeable code (e.g. "FRE-7K2QX") — a
/// 3-letter prefix from [vendorName] plus 5 random characters from a
/// 32-symbol alphabet (no `0/O/1/I` to avoid misreads). Collision risk is
/// negligible at this app's scale, same reasoning `generateOrderId`
/// (`firestore_orders_provider.dart`) already relies on.
String generateCouponCode(String vendorName) {
  final letters = vendorName.toUpperCase().replaceAll(RegExp('[^A-Z]'), '');
  final prefix = (letters.isEmpty ? 'CPN' : letters).padRight(3, 'X').substring(0, 3);
  final suffix = List.generate(
    5,
    (_) => _codeChars[_codeRandom.nextInt(_codeChars.length)],
  ).join();
  return '$prefix-$suffix';
}

/// Creates a coupon and returns the created record (with its generated
/// [Coupon.code]) so the caller can show it to the vendor immediately
/// without waiting on `firestoreCouponsProvider`'s stream to catch up.
Future<Coupon> createCoupon({
  required String vendorId,
  required String vendorName,
  required CouponDiscountType discountType,
  required double discountValue,
  required bool appliesToAllItems,
  required List<String> productIds,
  required DateTime startAt,
  required DateTime endAt,
}) async {
  final coupon = Coupon(
    id: '',
    vendorId: vendorId,
    vendorName: vendorName,
    code: generateCouponCode(vendorName),
    discountType: discountType,
    discountValue: discountValue,
    appliesToAllItems: appliesToAllItems,
    productIds: appliesToAllItems ? const [] : productIds,
    startAt: startAt,
    endAt: endAt,
    createdAt: DateTime.now(),
  );
  final ref = await couponsCollection.add(_couponToDoc(coupon));
  return Coupon(
    id: ref.id,
    vendorId: coupon.vendorId,
    vendorName: coupon.vendorName,
    code: coupon.code,
    discountType: coupon.discountType,
    discountValue: coupon.discountValue,
    appliesToAllItems: coupon.appliesToAllItems,
    productIds: coupon.productIds,
    startAt: coupon.startAt,
    endAt: coupon.endAt,
    createdAt: coupon.createdAt,
  );
}

/// Early UX feedback only (shown while a User is applying a coupon in the
/// cart) — the real single-use enforcement happens inside
/// `createOrderWithCoupon`'s transaction (`firestore_orders_provider.dart`),
/// since this check-then-act read isn't atomic with order placement.
Future<bool> hasUserRedeemedCoupon(String couponId, String userId) async {
  final doc = await couponRedemptionsCollection.doc('${couponId}_$userId').get();
  return doc.exists;
}
