import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/access_scope.dart';
import '../models/account.dart';
import '../models/refund_case.dart';
import 'order_actions.dart' show OrderActionException;
import '../../core/release/app_build.dart';

/// Customer UPI refunds (Phase I.7). The app only reads `refunds/*`; every
/// change goes through the refund callables (QuickyAdmin `functions/refunds.js`),
/// which check who may do what. The queries match the rules: each party
/// lists only its own refunds.

/// One order's refund case, or null when none is owed.
final refundCaseProvider = StreamProvider.autoDispose.family<RefundCase?, String>((ref, orderId) {
  return FirebaseFirestore.instance
      .doc('refunds/$orderId')
      .snapshots()
      .map((d) => d.exists ? RefundCase.fromMap(d.id, d.data()!) : null);
});

Stream<List<RefundCase>> _list(Query<Map<String, dynamic>> q) =>
    q.orderBy('createdAt', descending: true).limit(50).snapshots().map((s) => [for (final d in s.docs) RefundCase.fromMap(d.id, d.data())]);

/// The signed-in customer's refunds, newest first.
final myRefundsProvider = StreamProvider.autoDispose<List<RefundCase>>((ref) {
  final scope = ref.watch(accessScopeProvider);
  if (scope == null || scope.role != AppRole.user) return Stream.value(const []);
  return _list(FirebaseFirestore.instance.collection('refunds').where('userId', isEqualTo: scope.accountId));
});

/// The refunds the signed-in shop owes, newest first.
final vendorRefundsProvider = StreamProvider.autoDispose<List<RefundCase>>((ref) {
  final scope = ref.watch(accessScopeProvider);
  if (scope == null || scope.role != AppRole.vendor) return Stream.value(const []);
  return _list(FirebaseFirestore.instance.collection('refunds').where('vendorId', isEqualTo: scope.accountId));
});

/// Refunds on the signed-in Manager's own orders (Phase I.5 attribution:
/// the order's Manager, never the shop's current one), newest first.
final managerRefundsProvider = StreamProvider.autoDispose<List<RefundCase>>((ref) {
  final scope = ref.watch(accessScopeProvider);
  final territoryId = scope?.role == AppRole.manager ? scope?.territoryId : null;
  if (scope == null || territoryId == null) return Stream.value(const []);
  return _list(FirebaseFirestore.instance
      .collection('refunds')
      .where('territoryId', isEqualTo: territoryId)
      .where('managerId', isEqualTo: scope.accountId));
});

/// A fresh request id: keep one per user action and reuse it on retry, so
/// the server records the action once.
String newRefundRequestId() => List.generate(24, (_) => Random.secure().nextInt(36).toRadixString(36)).join();

/// The refund actions, behind a provider so widget tests can replace them.
class RefundActions {
  const RefundActions();

  static final _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> data) async {
    try {
      final result = await _functions.httpsCallable(name).call<Map<String, dynamic>>(withClientBuild(data));
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

  /// The shop records the refund it sent. Reuse [requestId] when retrying.
  Future<({String transferId, bool duplicate})> record({
    required String orderId,
    required String requestId,
    required int amountPaise,
    required String upiReference,
    required String paidOn,
    String? evidencePath,
    String? note,
  }) async {
    final r = await _call('recordCustomerRefund', {
      'orderId': orderId,
      'requestId': requestId,
      'amountPaise': amountPaise,
      'upiReference': upiReference,
      'paidOn': paidOn,
      'evidencePath': ?evidencePath,
      'note': ?note,
    });
    return (transferId: r['transferId'] as String? ?? '', duplicate: r['duplicate'] == true);
  }

  /// The customer's answer: `received`, `notReceived` or `differentAmount`.
  Future<void> respond({required String orderId, required String transferId, required String response, int? receivedAmountPaise, String? note}) =>
      _call('respondToCustomerRefund', {
        'orderId': orderId,
        'transferId': transferId,
        'response': response,
        'receivedAmountPaise': ?receivedAmountPaise,
        'note': ?note,
      });

  Future<void> setDestination({required String orderId, required String upiId}) =>
      _call('setRefundDestination', {'orderId': orderId, 'upiId': upiId});

  /// The order's Manager asks Quicky to review. They can't confirm a refund.
  Future<void> escalate({required String orderId, required String reason}) =>
      _call('escalateCustomerRefund', {'orderId': orderId, 'reason': reason});

  /// The order's Manager records a follow-up remark (Phase I.7.1). A note,
  /// never a confirmation. Reuse [requestId] when retrying.
  Future<void> recordFollowUp({required String orderId, required String requestId, required String remark}) =>
      _call('recordRefundFollowUp', {'orderId': orderId, 'requestId': requestId, 'remark': remark});

  /// Uploads evidence (a screenshot or PDF) to the order's refund folder for
  /// [party] (`vendor` or `customer`) and returns its path.
  Future<String> uploadEvidence({required String orderId, required String party, required Uint8List bytes, required String contentType}) async {
    final ext = contentType == 'application/pdf' ? 'pdf' : 'jpg';
    final path = 'refund_evidence/$orderId/$party/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await FirebaseStorage.instance.ref(path).putData(bytes, SettableMetadata(contentType: contentType));
    return path;
  }
}

final refundActionsProvider = Provider<RefundActions>((ref) => const RefundActions());
