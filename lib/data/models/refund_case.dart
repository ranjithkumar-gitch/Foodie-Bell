import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/utils/date_text.dart';

/// A customer's UPI refund (Phase I.7, QuickyAdmin `functions/refunds.js`,
/// `refunds/{orderId}`), written only by the server. The customer paid the
/// shop directly, so the shop owes it back; the customer confirms receipt,
/// or disputes it for Quicky to review.
enum RefundStatus { refundDue, awaitingCustomerConfirmation, refundDisputed, refundReviewRequired, refunded, unknown }

RefundStatus refundStatusFrom(Object? raw) => RefundStatus.values.where((s) => s.name == raw).firstOrNull ?? RefundStatus.unknown;

extension RefundStatusX on RefundStatus {
  /// The same wording on every screen (mirrors `STATUS_LABELS` in
  /// `functions/lib/refund.js`). Never "refunded" before the customer, or a
  /// Super Admin's check of outside evidence, has confirmed it.
  String get label => switch (this) {
    RefundStatus.refundDue => 'Refund owed',
    RefundStatus.awaitingCustomerConfirmation => 'Refund initiated — awaiting confirmation',
    RefundStatus.refundDisputed => 'Refund disputed',
    RefundStatus.refundReviewRequired => 'Review required',
    RefundStatus.refunded => 'Refund confirmed',
    RefundStatus.unknown => 'Refund',
  };

  bool get isDone => this == RefundStatus.refunded;
}

int? _paise(Object? v) => (v as num?)?.toInt();
DateTime? _time(Object? v) => v is Timestamp ? v.toDate() : null;

/// The refund the shop (or Quicky, for the shop) says it sent, awaiting the customer.
class RefundAttempt {
  const RefundAttempt({required this.transferId, required this.amountPaise, this.reference, this.paidOn, this.byQuicky = false, this.recordedAt});
  final String transferId;
  final int amountPaise;

  /// The UPI reference the payer typed — their claim, not proof.
  final String? reference;
  final String? paidOn;
  final bool byQuicky;
  final DateTime? recordedAt;

  static RefundAttempt? tryParse(Object? raw) {
    if (raw is! Map) return null;
    return RefundAttempt(
      transferId: raw['transferId'] as String? ?? '',
      amountPaise: _paise(raw['amountPaise']) ?? 0,
      reference: raw['reference'] as String?,
      paidOn: raw['paidOn'] as String?,
      byQuicky: raw['byQuicky'] == true,
      recordedAt: _time(raw['recordedAt']),
    );
  }
}

/// The customer's answer when a refund didn't arrive as recorded.
class RefundDispute {
  const RefundDispute({required this.transferId, required this.response, required this.amountPaise, this.reference, this.receivedAmountPaise, this.note});
  final String transferId;

  /// `notReceived` or `differentAmount`.
  final String response;
  final int amountPaise;
  final String? reference;
  final int? receivedAmountPaise;
  final String? note;

  static RefundDispute? tryParse(Object? raw) {
    if (raw is! Map) return null;
    return RefundDispute(
      transferId: raw['transferId'] as String? ?? '',
      response: raw['response'] as String? ?? '',
      amountPaise: _paise(raw['amountPaise']) ?? 0,
      reference: raw['reference'] as String?,
      receivedAmountPaise: _paise(raw['receivedAmountPaise']),
      note: raw['note'] as String?,
    );
  }
}

class RefundCase {
  const RefundCase({
    required this.orderId,
    required this.vendorId,
    required this.userId,
    required this.status,
    this.vendorName,
    this.managerId,
    this.territoryId,
    this.owedPaise,
    this.refundedPaise = 0,
    this.pendingPaise = 0,
    this.outstandingPaise,
    this.cause,
    this.destinationUpiId,
    this.originalReference,
    this.activeAttempt,
    this.openDispute,
    this.escalated = false,
    this.escalationReason,
    this.reviewReasons = const [],
    this.quickyAdvancedPaise = 0,
    this.createdAt,
    this.refundedAt,
    this.dueAt,
    this.escalationStage = 'none',
    this.managerFollowUpAt,
    this.adminReviewAt,
    this.lastNotifiedAt,
    this.lastFollowUpAt,
    this.lastFollowUpRemark,
    this.followUpCount = 0,
    this.lastReviewAt,
  });

  final String orderId;
  final String vendorId;
  final String? vendorName;
  final String userId;
  final String? managerId;
  final String? territoryId;
  final RefundStatus status;

  /// What's owed in total; null while Quicky establishes it (a legacy order).
  final int? owedPaise;
  final int refundedPaise;

  /// Recorded and awaiting the customer — counts for nothing yet.
  final int pendingPaise;
  final int? outstandingPaise;

  /// `customerCancelled`, `vendorRejected`, `vendorCancelled`, `returnedDelivery`…
  final String? cause;

  /// The UPI ID the customer asked to be refunded to; null = the account that paid.
  final String? destinationUpiId;

  /// The customer's original payment reference (where the money came from).
  final String? originalReference;
  final RefundAttempt? activeAttempt;
  final RefundDispute? openDispute;
  final bool escalated;
  final String? escalationReason;
  final List<String> reviewReasons;

  /// Of [refundedPaise], what Quicky paid for the shop (the shop then owes Quicky).
  final int quickyAdvancedPaise;
  final DateTime? createdAt;
  final DateTime? refundedAt;

  /// When the refund obligation was created — the escalation clock (Phase
  /// I.7.1, server time; never restarted). Null when no trustworthy time exists.
  final DateTime? dueAt;

  /// `none`, `managerFollowUp` (24 h) or `adminReview` (48 h).
  final String escalationStage;
  final DateTime? managerFollowUpAt;
  final DateTime? adminReviewAt;
  final DateTime? lastNotifiedAt;
  final DateTime? lastFollowUpAt;
  final String? lastFollowUpRemark;
  final int followUpCount;
  final DateTime? lastReviewAt;

  /// Whole hours since the obligation was created (null without a clock).
  int? ageHours([DateTime? now]) => dueAt == null ? null : (now ?? DateTime.now()).difference(dueAt!).inHours;

  bool get managerFollowUpNeeded => escalationStage != 'none' && !status.isDone;
  bool get escalatedToQuicky => escalationStage == 'adminReview';

  /// The escalation in words. Never "unpaid" when a refund is awaiting the
  /// customer's confirmation, and never a finding that the shop didn't pay.
  String get escalationLabel {
    if (status.isDone) return escalationStage == 'none' ? '' : 'Was overdue; now confirmed';
    final awaiting = status == RefundStatus.awaitingCustomerConfirmation;
    return switch (escalationStage) {
      'adminReview' => awaiting ? 'Over 48 h, awaiting confirmation · with Quicky for review' : 'Over 48 h · with Quicky for review',
      'managerFollowUp' => awaiting ? 'Over 24 h, awaiting confirmation · Manager following up' : 'Over 24 h · Manager following up',
      _ => '',
    };
  }

  /// Can the shop record a refund now?
  bool get canRecord => owedPaise != null && status == RefundStatus.refundDue && (outstandingPaise ?? 0) - pendingPaise > 0;

  /// Still to cover by a new attempt.
  int get capacityPaise => (outstandingPaise ?? 0) - pendingPaise;

  factory RefundCase.fromMap(String id, Map<String, dynamic> d) {
    final destination = (d['destination'] as Map?)?.cast<String, dynamic>() ?? const {};
    final escalation = (d['escalation'] as Map?)?.cast<String, dynamic>();
    final overdue = (d['overdue'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RefundCase(
      orderId: d['orderId'] as String? ?? id,
      vendorId: d['vendorId'] as String? ?? '',
      vendorName: d['vendorName'] as String?,
      userId: d['userId'] as String? ?? '',
      managerId: d['managerId'] as String?,
      territoryId: d['territoryId'] as String?,
      status: refundStatusFrom(d['status']),
      owedPaise: _paise(d['owedPaise']),
      refundedPaise: _paise(d['refundedPaise']) ?? 0,
      pendingPaise: _paise(d['pendingPaise']) ?? 0,
      outstandingPaise: _paise(d['outstandingPaise']),
      cause: d['cause'] as String?,
      destinationUpiId: destination['kind'] == 'upiId' ? destination['upiId'] as String? : null,
      originalReference: destination['customerReference'] as String?,
      activeAttempt: RefundAttempt.tryParse(d['activeAttempt']),
      openDispute: RefundDispute.tryParse(d['openDispute']),
      escalated: escalation?['open'] == true,
      escalationReason: escalation?['reason'] as String?,
      reviewReasons: [for (final r in (d['reviewReasons'] as List? ?? const [])) '$r'],
      quickyAdvancedPaise: _paise(d['quickyAdvancedPaise']) ?? 0,
      createdAt: _time(d['createdAt']),
      refundedAt: _time(d['refundedAt']),
      dueAt: _time(d['dueAt']),
      escalationStage: d['escalationStage'] as String? ?? 'none',
      managerFollowUpAt: _time(overdue['managerFollowUpAt']),
      adminReviewAt: _time(overdue['adminReviewAt']),
      lastNotifiedAt: _time(overdue['lastNotifiedAt']),
      lastFollowUpAt: _time(overdue['lastFollowUpAt']),
      lastFollowUpRemark: overdue['lastFollowUpRemark'] as String?,
      followUpCount: (overdue['followUpCount'] as num?)?.toInt() ?? 0,
      lastReviewAt: _time(d['lastReviewAt']),
    );
  }
}

/// Why the refund became due, in words.
String refundCauseLabel(String? cause) => switch (cause) {
  'customerCancelled' => 'Customer cancelled',
  'vendorRejected' => 'Shop rejected the order',
  'vendorCancelled' => 'Shop cancelled after accepting',
  'returnedDelivery' => 'Delivery returned',
  'paymentResolution' => 'Payment dispute resolved',
  _ => 'Order not completed',
};

String rupeesOf(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

/// [hours] as "5 h" or "2 d 3 h".
String ageLabel(int hours) => hours < 24 ? '$hours h' : '${hours ~/ 24} d ${hours % 24} h';

/// A time in India Standard Time, e.g. "2 Nov, 3:05 PM IST" (whatever the device's zone).
String istLabel(DateTime t) {
  final ist = t.toUtc().add(const Duration(hours: 5, minutes: 30));
  final h = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
  return '${dmy(ist)}, $h:${ist.minute.toString().padLeft(2, '0')} ${ist.hour < 12 ? 'AM' : 'PM'} IST';
}

