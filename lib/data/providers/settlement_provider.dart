import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/access_scope.dart';
import '../models/account.dart';

/// Daily territory settlements (QuickyAdmin `functions/ledger.js`). The
/// server keeps one statement per territory per settlement day, computed
/// from the append-only ledger; payments between parties count only once
/// the other side acknowledges them. Amounts are paise.

/// A party in the ledger: `vendor:<id>`, `driver:<id>`, `manager:<id>`,
/// `user:<id>` or `quicky`.
typedef PartyKey = String;

PartyKey partyKeyFor(AppRole role, String accountId) => '${role.name}:$accountId';

enum SettlementStatus { pending, partiallySettled, completed, disputed }

extension SettlementStatusX on SettlementStatus {
  String get label => switch (this) {
    SettlementStatus.pending => 'Pending',
    SettlementStatus.partiallySettled => 'Partially settled',
    SettlementStatus.completed => 'Completed',
    SettlementStatus.disputed => 'Disputed',
  };
}

class SettlementStatement {
  const SettlementStatement(this.data);

  /// The statement as the server wrote it (`daily_settlements/{t}_{day}`).
  final Map<String, dynamic> data;

  String get day => data['settlementDay'] as String? ?? '';
  SettlementStatus get status =>
      SettlementStatus.values.where((s) => s.name == data['status']).firstOrNull ?? SettlementStatus.pending;
  Map<String, dynamic> get totals => Map<String, dynamic>.from(data['totals'] as Map? ?? const {});
  int total(String key) => (totals[key] as num?)?.toInt() ?? 0;

  Map<PartyKey, int> _amounts(String key) =>
      {for (final e in (data[key] as Map? ?? const {}).entries) e.key as String: (e.value as num).toInt()};

  /// Positive: the party owes that much; negative: the party is owed it.
  Map<PartyKey, int> get remainingBalances => _amounts('remainingBalances');
  Map<PartyKey, int> get openingBalances => _amounts('openingBalances');
  Map<String, int> get vendorUpiCollections => _amounts('vendorUpiCollections');
  Map<String, int> get riderCodCollections => _amounts('riderCodCollections');
  Map<String, int> get vendorEntitlements => _amounts('vendorEntitlements');
  Map<String, int> get driverEarnings => _amounts('driverEarnings');

  /// Driver day fees owed to the Manager this day, per Driver (2026-11-12);
  /// already inside that Driver's hand-over obligation.
  Map<PartyKey, int> get driverDayFees => _amounts('driverDayFees');

  List<Map<String, dynamic>> _list(String key) =>
      [for (final e in (data[key] as List? ?? const [])) Map<String, dynamic>.from(e as Map)];
  List<Map<String, dynamic>> get orders => _list('orders');
  List<Map<String, dynamic>> get paymentsMade => _list('paymentsMade');
  List<Map<String, dynamic>> get paymentsAwaitingAcknowledgement => _list('paymentsAwaitingAcknowledgement');
  List<Map<String, dynamic>> get discrepancies => _list('discrepancies');

  /// Every amount owed, pairwise and by purpose (Phase I.4, Decision 6) —
  /// never netted across purposes. Empty on statements built before I.4.
  List<SettlementObligation> get obligations => [for (final o in _list('obligations')) SettlementObligation(o)];

  /// The day's cancellation money (Phase I.4), all server figures; null on
  /// statements built before I.4.
  /// The day's customer UPI refunds (Phase I.7): owed, confirmed, awaiting
  /// the customer, disputed, still outstanding. Server figures, paise; null
  /// on statements built before I.7.
  Map<String, int>? get customerRefunds {
    final c = data['customerRefunds'];
    return c is Map ? {for (final e in c.entries) '${e.key}': (e.value as num?)?.toInt() ?? 0} : null;
  }

  CancellationFinance? get cancellationFinance {
    final c = data['cancellationFinance'];
    return c is Map ? CancellationFinance(Map<String, dynamic>.from(c)) : null;
  }

  /// [remainingBalances] without the cancellation obligations — what "Who
  /// owes whom" settles with general-purpose payments. The server's
  /// balances net every purpose together; a cancellation charge is settled
  /// only by a payment tagged with its own purpose, so its still-outstanding
  /// amount is taken back out per party. No amount is computed here: both
  /// sides are the server's figures for the same day.
  Map<PartyKey, int> get generalBalances {
    final out = Map<PartyKey, int>.from(remainingBalances);
    for (final o in obligations) {
      // Customer refunds (Phase I.7) are settled only through the refund
      // workflow, never by a general payment — taken out here too.
      if (!(o.isCancellation || o.isRefund) || o.outstandingPaise == 0) continue;
      out[o.from] = (out[o.from] ?? 0) - o.outstandingPaise;
      out[o.to] = (out[o.to] ?? 0) + o.outstandingPaise;
    }
    out.removeWhere((_, v) => v == 0);
    return out;
  }
}

/// The purposes shop-cancellation money is settled with (`functions/ledger.js`
/// `TRANSFER_PURPOSES`, besides `general`). The last three settle an
/// approved reversal (Phase I.4.1): the shop's refund, Quicky returning a
/// remittance, and Quicky funding a driver's compensation.
const cancellationPurposes = {
  'cancellationCharge', 'cancellationDriverComp', 'cancellationRemittance',
  'cancellationRefund', 'cancellationRemittanceReturn', 'cancellationCompFunding',
};

/// A settlement payment's or obligation's purpose, for labels.
String settlementPurposeLabel(String purpose) => switch (purpose) {
  'cancellationCharge' => 'Cancellation charge',
  'cancellationDriverComp' => 'Driver cancellation compensation',
  'cancellationRemittance' => 'QuickMandi’s share of cancellation charges',
  'cancellationRefund' => 'Cancellation charge refund to the shop',
  'cancellationRemittanceReturn' => 'QuickMandi returning its share (reversal)',
  'cancellationCompFunding' => 'QuickMandi funding driver compensation (reversal)',
  'customerRefund' => 'Customer refund',
  'refundAdvance' => 'Refund QuickMandi made for the shop',
  _ => 'Order settlement',
};

/// One row of a statement's `obligations`: what [from] owes [to] for
/// [purpose], opened from earlier days, raised by this day's charges and
/// lowered only by confirmed payments with the same purpose.
class SettlementObligation {
  const SettlementObligation(this.data);
  final Map<String, dynamic> data;

  int _paise(String k) => (data[k] as num?)?.toInt() ?? 0;

  PartyKey get from => data['from'] as String? ?? '';
  PartyKey get to => data['to'] as String? ?? '';

  /// `general`, `cancellationCharge`, `cancellationDriverComp`,
  /// `cancellationRemittance` or `customerRefund`.
  String get purpose => data['purpose'] as String? ?? 'general';
  bool get isCancellation => cancellationPurposes.contains(purpose);

  /// A customer refund the shop owes, or what it owes Quicky for one
  /// Quicky made for it (Phase I.7).
  bool get isRefund => purpose == 'customerRefund' || purpose == 'refundAdvance';
  int get openingPaise => _paise('openingPaise');
  int get assessedPaise => _paise('assessedPaise');
  int get settledPaise => _paise('settledPaise');
  int get disputedPaise => _paise('disputedPaise');
  int get outstandingPaise => _paise('outstandingPaise');

  /// Stable per obligation — keys the idempotency key kept until a payment
  /// against it is recorded.
  String get id => '$from|$to|$purpose';
}

/// A statement's `cancellationFinance`: assessed, collected, paid and still
/// owed cancellation money (paise), kept apart from commission, delivery
/// earnings, platform fees and refunds.
class CancellationFinance {
  const CancellationFinance(this.data);
  final Map<String, dynamic> data;

  int _paise(String k) => (data[k] as num?)?.toInt() ?? 0;

  int get assessedPaise => _paise('assessedPaise');
  int get driverCompAssessedPaise => _paise('driverCompAssessedPaise');
  int get quickyShareAssessedPaise => _paise('quickyShareAssessedPaise');
  int get collectedPaise => _paise('collectedPaise');
  int get driverCompPaidPaise => _paise('driverCompPaidPaise');
  int get remittedPaise => _paise('remittedPaise');
  int get outstandingChargePaise => _paise('outstandingChargePaise');
  int get outstandingDriverCompPaise => _paise('outstandingDriverCompPaise');
  int get outstandingRemittancePaise => _paise('outstandingRemittancePaise');
  int get quickyRealizedPaise => _paise('quickyRealizedPaise');
  int get disputedPaise => _paise('disputedPaise');

  // Approved reversals (Phase I.4.1).
  int get reversedPaise => _paise('reversedPaise');
  int get waivedPaise => _paise('waivedPaise');
  int get refundEstablishedPaise => _paise('refundEstablishedPaise');
  int get refundedPaise => _paise('refundedPaise');
  int get outstandingRefundPaise => _paise('outstandingRefundPaise');
  int get remittanceReturnedPaise => _paise('remittanceReturnedPaise');
  int get outstandingRemittanceReturnPaise => _paise('outstandingRemittanceReturnPaise');
  int get compFundingAssessedPaise => _paise('compFundingAssessedPaise');
  int get compFundedPaise => _paise('compFundedPaise');
  int get outstandingCompFundingPaise => _paise('outstandingCompFundingPaise');

  bool get hasReversals =>
      reversedPaise != 0 || outstandingRefundPaise != 0 || refundedPaise != 0 || outstandingRemittanceReturnPaise != 0 || outstandingCompFundingPaise != 0 || compFundedPaise != 0;

  bool get isEmpty => data.values.every((v) => v is! num || v == 0);
}

/// The signed-in Manager's own statements, newest day first (Phase I.5:
/// `manager_settlements` — only their shops' orders and the payments they're
/// party to; the territory-wide statement is the Super Admin's).
final territoryStatementsProvider = StreamProvider<List<SettlementStatement>>((ref) {
  final scope = ref.watch(accessScopeProvider);
  final territoryId = scope?.role == AppRole.manager ? scope?.territoryId : null;
  if (scope == null || territoryId == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('manager_settlements')
      .where('territoryId', isEqualTo: territoryId)
      .where('managerId', isEqualTo: scope.accountId)
      .orderBy('settlementDay', descending: true)
      .limit(60)
      .snapshots()
      .map((s) => [for (final d in s.docs) SettlementStatement(d.data())]);
});

class SettlementTransfer {
  const SettlementTransfer({
    required this.id,
    required this.from,
    required this.to,
    required this.amountPaise,
    required this.method,
    required this.status,
    required this.counterparty,
    required this.settlementDay,
    this.reference,
    this.purpose = 'general',
    this.recordedBy,
    this.reportUntil,
    this.report,
  });

  final String id;
  final PartyKey from;
  final PartyKey to;
  final int amountPaise;
  final String method;

  /// `confirmed` (settled), `voided` (undone by the Super Admin), or on
  /// payments from before 2026-11-20 `pendingAck` / `disputed`.
  final String status;

  /// The side that must acknowledge it (the one that didn't record it).
  final PartyKey counterparty;
  final String settlementDay;
  final String? reference;

  /// What the payment settles (Phase I.4); `general` before I.4.
  final String purpose;

  /// The party that marked it (`quicky` for the Super Admin).
  final PartyKey? recordedBy;

  /// Until when the other side may report a problem (2026-11-20: a payment
  /// counts as soon as a Manager or the Super Admin marks it settled; after
  /// this it is final). Null on payments from before then.
  final DateTime? reportUntil;

  /// A reported problem: `status` `open` or `resolved`, `decision` `keep`
  /// or `undo`, `note`, `reason`, `byParty`. Null when nobody reported one.
  final Map<String, dynamic>? report;

  String? get reportStatus => report?['status'] as String?;
  String? get reportDecision => report?['decision'] as String?;
  bool get isReportOpen => reportStatus == 'open';

  /// [me] may report a problem now: settled by the other side, inside the
  /// 24 hours, and not reported yet.
  bool canReport(PartyKey me, {DateTime? now}) =>
      status == 'confirmed' && reportUntil != null && report == null && recordedBy != me && (now ?? DateTime.now()).isBefore(reportUntil!);

  static SettlementTransfer fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final x = d.data();
    return SettlementTransfer(
      id: d.id,
      from: x['from'] as String? ?? '',
      to: x['to'] as String? ?? '',
      amountPaise: (x['amountPaise'] as num?)?.toInt() ?? 0,
      method: x['method'] as String? ?? '',
      status: x['status'] as String? ?? '',
      counterparty: x['counterparty'] as String? ?? '',
      settlementDay: x['settlementDay'] as String? ?? '',
      reference: x['reference'] as String?,
      purpose: x['purpose'] as String? ?? 'general',
      recordedBy: x['recordedBy'] as String?,
      reportUntil: (x['reportUntil'] as Timestamp?)?.toDate(),
      report: x['report'] is Map ? Map<String, dynamic>.from(x['report'] as Map) : null,
    );
  }
}

/// Settlement payments the signed-in Vendor/Driver/Manager is part of.
final myTransfersProvider = StreamProvider<List<SettlementTransfer>>((ref) {
  final scope = ref.watch(accessScopeProvider);
  if (scope == null || scope.role == AppRole.admin) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('settlement_transfers')
      .where('parties', arrayContains: partyKeyFor(scope.role, scope.accountId))
      .orderBy('settlementDay', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => [for (final d in s.docs) SettlementTransfer.fromDoc(d)]);
});

/// The live driver day fee (`app_config/driver_day_fee`, public read; only
/// the Super Admin changes it): what turning on for a day costs, in paise,
/// 0 when it's off. Until an admin saves one the server's built-in ₹25
/// applies, so that is shown too.
final driverDayFeeProvider = StreamProvider<int>((ref) => FirebaseFirestore.instance
    .doc('app_config/driver_day_fee')
    .snapshots()
    .map((d) {
      final x = d.data();
      if (x == null) return 2500;
      return x['enabled'] == true ? (x['amountPaise'] as num?)?.toInt() ?? 0 : 0;
    }));

/// Today's settlement day in IST with the given cutoff (minutes after
/// midnight; after it, things count towards the next day) — the same rule
/// as `settlementDayFor` in `functions/money.js`.
String currentSettlementDay({int cutoffMinutes = 22 * 60, DateTime? now}) {
  final shift = cutoffMinutes % 1440 == 0 ? 0 : 1440 - cutoffMinutes;
  final ist = (now ?? DateTime.now()).toUtc().add(Duration(minutes: 330 + shift));
  return '${ist.year.toString().padLeft(4, '0')}-${ist.month.toString().padLeft(2, '0')}-${ist.day.toString().padLeft(2, '0')}';
}

/// The live global pricing (`app_config/pricing`, public read; only the
/// Super Admin can change it) — null until an admin has saved one; the
/// server then uses its built-in default (`functions/lib/money.js`), which
/// since 2026-11-18 is the approved 50/50 split too.
final globalPricingProvider = StreamProvider<Map<String, dynamic>?>(
  (ref) => FirebaseFirestore.instance.doc('app_config/pricing').snapshots().map((d) => d.data()),
);

/// The rates in [globalPricingProvider]'s pricing, for labels only — every
/// amount is still the server's (each order snapshots its own rates). The
/// commission, Manager share (50%) and slabs fall back to the server's
/// built-in default.
/// The server's built-in Manager share of the commission when no pricing is
/// saved (`managerShareBps` in QuickyAdmin `functions/lib/money.js`):
/// 50/50, the approved split (2026-11-18; it was 60/40).
const kDefaultManagerShareBps = 5000;

class PricingRates {
  const PricingRates({required this.commissionPercent, required this.managerSharePercent, required this.lowestDeliveryFeePaise});

  factory PricingRates.from(Map<String, dynamic>? data) {
    final slabs = data?['deliverySlabs'];
    final fees = [
      if (slabs is List)
        for (final s in slabs)
          if (s is Map && s['feePaise'] is num) (s['feePaise'] as num).toInt(),
    ];
    return PricingRates(
      commissionPercent: ((data?['commissionBps'] as num?) ?? 1000) / 100,
      managerSharePercent: ((data?['managerShareBps'] as num?) ?? kDefaultManagerShareBps) / 100,
      lowestDeliveryFeePaise: fees.isEmpty ? 2000 : fees.reduce((a, b) => a < b ? a : b),
    );
  }

  final double commissionPercent;

  /// The Territory Manager's share of the commission, in %.
  final double? managerSharePercent;

  /// The first slab's fee — what "delivery from ₹…" quotes.
  final int lowestDeliveryFeePaise;

  double? get quickySharePercent => managerSharePercent == null ? null : 100 - managerSharePercent!;

  /// "50%", or "not yet set by Quicky" when there's no saved split.
  String get managerShareLabel => managerSharePercent == null ? 'not yet set by QuickMandi' : '${formatPercent(managerSharePercent!)}%';
}

/// [PricingRates] in force now; null while the pricing doc is loading.
final pricingRatesProvider = Provider<PricingRates?>(
  (ref) => ref.watch(globalPricingProvider).whenOrNull(data: PricingRates.from),
);

/// `10` for 10.0, `12.5` for 12.5 — for rate labels.
String formatPercent(double percent) =>
    percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');

/// The live global settlement cutoff (`app_config/pricing`, public read).
final settlementCutoffProvider = StreamProvider<int>((ref) => FirebaseFirestore.instance
    .doc('app_config/pricing')
    .snapshots()
    .map((d) => (d.data()?['settlementCutoffMinutes'] as num?)?.toInt() ?? 22 * 60));

/// A settlement adjustment as filed (`settlement_adjustments`, written only
/// by the server): pending until the Super Admin approves or rejects it.
class SettlementAdjustment {
  const SettlementAdjustment(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;

  PartyKey get from => data['from'] as String? ?? '';
  PartyKey get to => data['to'] as String? ?? '';
  int get amountPaise => (data['amountPaise'] as num?)?.toInt() ?? 0;
  String get reason => data['reason'] as String? ?? '';
  String? get orderId => data['orderId'] as String?;

  /// `pending`, `approved` or `rejected`.
  String get status => data['status'] as String? ?? 'pending';
}

/// The adjustments the signed-in Manager is party to on [day], live — so a
/// proposal shows its decision and isn't filed twice.
final dayAdjustmentsProvider = StreamProvider.autoDispose.family<List<SettlementAdjustment>, String>((ref, day) {
  final scope = ref.watch(accessScopeProvider);
  final territoryId = scope?.role == AppRole.manager ? scope?.territoryId : null;
  if (scope == null || territoryId == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('settlement_adjustments')
      .where('territoryId', isEqualTo: territoryId)
      .where('managerId', isEqualTo: scope.accountId)
      .where('settlementDay', isEqualTo: day)
      .snapshots()
      .map((s) => [for (final d in s.docs) SettlementAdjustment(d.id, d.data())]);
});
