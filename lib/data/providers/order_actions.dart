import 'package:cloud_functions/cloud_functions.dart';

import '../models/order.dart';

/// Every order and settlement change goes through these Cloud Functions
/// (QuickyAdmin `functions/orders.js`, `ledger.js`). The app sends what the
/// user chose; the server works out every price, fee, total and split and
/// checks who may do what — firestore.rules no longer lets the app write
/// orders itself.
final _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

/// A refusal from the server, with a message that's safe to show as-is.
class OrderActionException implements Exception {
  const OrderActionException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
  try {
    final result = await _functions.httpsCallable(name).call<Map<String, dynamic>>(data);
    return Map<String, dynamic>.from(result.data);
  } on FirebaseFunctionsException catch (e) {
    final network = const {'unavailable', 'deadline-exceeded', 'internal'}.contains(e.code);
    throw OrderActionException(
      network && (e.message == null || e.message == 'INTERNAL')
          ? "We couldn't reach the server. Check your connection and try again."
          : e.message ?? 'Something went wrong. Please try again.',
      code: e.code,
    );
  }
}

/// The price of a cart as the server works it out — what checkout shows.
class OrderQuote {
  const OrderQuote({required this.money, required this.distanceMeters, required this.pricingVersion, this.vendorUpiId});
  final OrderMoney money;
  final int distanceMeters;
  final int pricingVersion;
  final String? vendorUpiId;

  double get distanceKm => distanceMeters / 1000;

  static OrderQuote fromResult(Map<String, dynamic> data) => OrderQuote(
    money: OrderMoney.tryParse(data['money'])!,
    distanceMeters: (data['distanceMeters'] as num).toInt(),
    pricingVersion: (data['pricingVersion'] as num).toInt(),
    vendorUpiId: data['vendorUpiId'] as String?,
  );
}

typedef CartLine = ({String productId, int quantity});

List<Map<String, dynamic>> _items(List<CartLine> lines) => [
  for (final l in lines) {'productId': l.productId, 'quantity': l.quantity},
];

Future<OrderQuote> quoteOrder({
  required String vendorId,
  required String addressId,
  required List<CartLine> items,
  String? couponId,
}) async => OrderQuote.fromResult(
  await _call('quoteOrder', {'vendorId': vendorId, 'addressId': addressId, 'items': _items(items), 'couponId': ?couponId}),
);

/// Places the order. [idempotencyKey] must stay the same if the user's tap
/// is retried, so a retry returns the same order rather than a second one.
Future<String> placeOrder({
  required String idempotencyKey,
  required String vendorId,
  required String addressId,
  required List<CartLine> items,
  required PaymentMethod paymentMethod,
  String? couponId,
  int? expectedTotalPaise,
}) async {
  final data = await _call('placeOrder', {
    'idempotencyKey': idempotencyKey,
    'vendorId': vendorId,
    'addressId': addressId,
    'items': _items(items),
    'paymentMethod': paymentMethod == PaymentMethod.upi ? 'upi' : 'cod',
    'couponId': ?couponId,
    // The total the customer was shown: the server refuses to charge a
    // different one (e.g. the platform fee changed meanwhile).
    'expectedTotalPaise': ?expectedTotalPaise,
  });
  return data['orderId'] as String;
}

Future<void> submitUpiReference(String orderId, String reference) =>
    _call('submitUpiReference', {'orderId': orderId, 'reference': reference});

Future<void> confirmUpiPayment(String orderId) => _call('confirmUpiPayment', {'orderId': orderId});

Future<void> reportPaymentIssue(String orderId, String reason) =>
    _call('reportPaymentIssue', {'orderId': orderId, 'reason': reason});

Future<void> resolvePaymentDispute(String orderId, {required bool received, required String note}) =>
    _call('resolvePaymentDispute', {'orderId': orderId, 'outcome': received ? 'received' : 'notReceived', 'note': note});

Future<void> vendorAcceptOrder(String orderId) => _call('vendorDecision', {'orderId': orderId, 'accept': true});

Future<void> vendorRejectOrder(String orderId, {String reason = 'Rejected by shop'}) =>
    _call('vendorDecision', {'orderId': orderId, 'accept': false, 'reason': reason});

Future<void> customerCancelOrder(String orderId, String reason) => _call('cancelOrder', {'orderId': orderId, 'reason': reason});

Future<void> claimDelivery(String orderId) => _call('claimDelivery', {'orderId': orderId});

Future<void> reassignDriver(String orderId, {String? driverId, required String reason}) =>
    _call('reassignDriver', {'orderId': orderId, 'driverId': ?driverId, 'reason': reason});

/// Records the cash the Driver actually took; returns any shortfall (paise).
Future<int> recordCodCollection(String orderId, int amountPaise) async {
  final data = await _call('recordCodCollection', {'orderId': orderId, 'amountPaise': amountPaise});
  return (data['shortfallPaise'] as num?)?.toInt() ?? 0;
}

Future<void> reportDeliveryFailure(String orderId, String reason) =>
    _call('reportDeliveryFailure', {'orderId': orderId, 'reason': reason});

Future<void> resolveDeliveryIssue(String orderId, {required bool delivered, required String reason, String? proofPath}) =>
    _call('resolveDeliveryIssue', {
      'orderId': orderId,
      'outcome': delivered ? 'delivered' : 'returned',
      'reason': reason,
      'proofPath': ?proofPath,
    });

/// Vendor prices a photo order: [itemAmountPaise] for the goods; the server
/// adds the delivery fee by road distance.
Future<OrderMoney> quoteListOrder(String requestId, int itemAmountPaise) async {
  final data = await _call('quoteListOrder', {'requestId': requestId, 'itemAmountPaise': itemAmountPaise});
  return OrderMoney.tryParse(data['money'])!;
}

/// Vendor confirms the Customer's payment arrived and turns the photo order
/// into an order; [receiptPath] is the receipt photo's Storage path.
Future<String> acceptListOrder(String requestId, String receiptPath) async {
  final data = await _call('acceptListOrder', {'requestId': requestId, 'receiptPath': receiptPath});
  return data['orderId'] as String;
}

// ------------------------------------------------------------ settlement

Future<Map<String, dynamic>> generateDailySettlement(String territoryId, String day) =>
    _call('generateDailySettlement', {'territoryId': territoryId, 'day': day});

Future<void> recordSettlementTransfer({
  required String idempotencyKey,
  required String territoryId,
  required String day,
  required String fromParty,
  required String toParty,
  required int amountPaise,
  required bool upi,
  String? reference,
}) => _call('recordSettlementTransfer', {
  'idempotencyKey': idempotencyKey,
  'territoryId': territoryId,
  'day': day,
  'from': fromParty,
  'to': toParty,
  'amountPaise': amountPaise,
  'method': upi ? 'upi' : 'cash',
  'reference': ?reference,
});

Future<void> acknowledgeSettlementTransfer(String transferId, {required bool confirm, String? note}) =>
    _call('acknowledgeSettlementTransfer', {'transferId': transferId, 'confirm': confirm, 'note': ?note});

Future<void> proposeSettlementAdjustment({
  required String territoryId,
  required String day,
  required String fromParty,
  required String toParty,
  required int amountPaise,
  required String reason,
  String? orderId,
}) => _call('proposeSettlementAdjustment', {
  'territoryId': territoryId,
  'day': day,
  'from': fromParty,
  'to': toParty,
  'amountPaise': amountPaise,
  'reason': reason,
  'orderId': ?orderId,
});
