import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_orders_provider.dart';

/// Pickup and delivery codes. The server generates them when an order is
/// placed (`createOrderCodes` in QuickyAdmin's `functions/index.js`) and
/// keeps them off the order itself, which the assigned Driver can read:
///  - `orders/{id}/codes/handover` — readable by the order's Vendor, who
///    reads it to the Driver at pickup;
///  - `orders/{id}/codes/delivery` — readable by the order's Customer, who
///    gives it to the Driver at the door.
/// Only the server ever checks a code ([confirmPickupCode]/
/// [confirmDeliveryCode]), so knowing the order is never enough to skip a
/// step. Null until the server has written the code (a second or so after
/// the order is placed).
DocumentReference<Map<String, dynamic>> _codeDoc(String orderId, String kind) =>
    ordersCollection.doc(orderId).collection('codes').doc(kind);

final orderHandoverCodeProvider = StreamProvider.family<String?, String>((ref, orderId) {
  return _codeDoc(orderId, 'handover').snapshots().map((doc) => doc.data()?['code'] as String?);
});

final orderDeliveryCodeProvider = StreamProvider.family<String?, String>((ref, orderId) {
  return _codeDoc(orderId, 'delivery').snapshots().map((doc) => doc.data()?['code'] as String?);
});

/// The server's verdict on a code a Driver typed in.
class CodeCheck {
  const CodeCheck({required this.ok, this.attemptsLeft});
  final bool ok;

  /// Tries left before the code locks, when [ok] is false.
  final int? attemptsLeft;
}

final _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

Future<CodeCheck> _confirm(String callable, String orderId, String code) async {
  final result = await _functions.httpsCallable(callable).call<Map<String, dynamic>>({'orderId': orderId, 'code': code});
  final data = Map<String, dynamic>.from(result.data);
  return CodeCheck(ok: data['ok'] == true, attemptsLeft: (data['attemptsLeft'] as num?)?.toInt());
}

/// Driver at the shop: checks the Vendor's handover code and, if it
/// matches, marks the order picked up. Throws [FirebaseFunctionsException]
/// when the server refuses outright (not this Driver's order, wrong step,
/// too many wrong codes).
Future<CodeCheck> confirmPickupCode(String orderId, String code) => _confirm('confirmPickup', orderId, code);

/// Driver at the door: checks the Customer's delivery code and, if it
/// matches, marks the order delivered.
Future<CodeCheck> confirmDeliveryCode(String orderId, String code) => _confirm('confirmDelivery', orderId, code);
