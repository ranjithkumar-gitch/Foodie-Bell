import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/access_scope.dart';
import '../models/account.dart';
import 'settlement_provider.dart';

/// Earnings and dashboard figures, read from the server's read models
/// (QuickyAdmin `functions/ledger.js`) instead of adding up orders on the
/// phone. Each delivered order is counted into them once, in the same
/// transaction that posts it to the ledger, and a nightly job checks them
/// against the ledger. Days are settlement days (IST, after the cut-off
/// counts towards the next day), like the daily statement. Amounts are
/// rupees here (the documents store paise).
///
///  - `earnings_daily/{party}_{day}` — one Vendor/Driver/Manager's day
///  - `earnings_totals/{party}`      — their running total
///  - `territory_daily_stats/{territoryId}_{day}` — a territory's day (Manager)
///
/// Only orders delivered since Phase 2 (with a money snapshot) are in them;
/// older beta orders still show in the order history lists.
double _rupees(Object? paise) => ((paise as num?) ?? 0) / 100;

class EarningsFigures {
  const EarningsFigures(this.data);
  final Map<String, dynamic> data;

  int get orders => (data['orders'] as num?)?.toInt() ?? 0;

  /// The party's own share: a Vendor's entitlement, a Driver's delivery
  /// fees, a Manager's share of the commission.
  double get earnings => _rupees(data['earningsPaise']);
  double get customerTotal => _rupees(data['customerTotalPaise']);
  double get commission => _rupees(data['commissionPaise']);
  double get codTotal => _rupees(data['codTotalPaise']);
  double get upiTotal => _rupees(data['upiTotalPaise']);
  double get codCollected => _rupees(data['codCollectedPaise']);

  /// Customer totals by weekday, Monday first (Vendor).
  List<double> get weekdayTotals => [for (var d = 1; d <= 7; d++) _rupees(data['weekday${d}Paise'])];
}

class EarningsDay extends EarningsFigures {
  const EarningsDay(super.data);
  String get day => data['settlementDay'] as String? ?? '';
  DateTime get date => DateTime.parse(day);
}

String? _myParty(AccessScope? scope) {
  if (scope == null || !{AppRole.vendor, AppRole.driver, AppRole.manager}.contains(scope.role)) return null;
  return partyKeyFor(scope.role, scope.accountId);
}

/// The signed-in Vendor/Driver/Manager's last [days] settlement days that
/// had deliveries, newest first, live while a screen shows them.
final myEarningsDaysProvider = StreamProvider.autoDispose.family<List<EarningsDay>, int>((ref, days) {
  final party = _myParty(ref.watch(accessScopeProvider));
  if (party == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('earnings_daily')
      .where('party', isEqualTo: party)
      .orderBy('settlementDay', descending: true)
      .limit(days)
      .snapshots()
      .map((s) => [for (final d in s.docs) EarningsDay(d.data())]);
});

/// The signed-in Vendor/Driver/Manager's running totals (zeros before the
/// first delivery).
final myEarningsTotalsProvider = StreamProvider.autoDispose<EarningsFigures>((ref) {
  final party = _myParty(ref.watch(accessScopeProvider));
  if (party == null) return Stream.value(const EarningsFigures({}));
  return FirebaseFirestore.instance
      .doc('earnings_totals/$party')
      .snapshots()
      .map((d) => EarningsFigures(d.data() ?? const {}));
});

/// The figures for [day] out of [days], or empty ones.
EarningsFigures earningsOn(List<EarningsDay> days, String day) =>
    days.where((d) => d.day == day).firstOrNull ?? const EarningsFigures({});

/// The signed-in Manager's territory today: delivered orders and their
/// money (`territory_daily_stats`). Zeros before the first delivery.
class TerritoryDayStats {
  const TerritoryDayStats(this.data);
  final Map<String, dynamic> data;
  int get deliveredOrders => (data['deliveredOrders'] as num?)?.toInt() ?? 0;
  double get customerTotal => _rupees(data['customerTotalPaise']);
  double get itemValue => _rupees(data['itemValuePaise']);
  double get commission => _rupees(data['commissionPaise']);
  double get managerShare => _rupees(data['managerSharePaise']);
}

final territoryTodayStatsProvider = StreamProvider.autoDispose<TerritoryDayStats>((ref) {
  final scope = ref.watch(accessScopeProvider);
  final territoryId = scope?.territoryId;
  if (scope?.role != AppRole.manager || territoryId == null) return Stream.value(const TerritoryDayStats({}));
  final cutoff = ref.watch(settlementCutoffProvider).valueOrNull ?? 22 * 60;
  return FirebaseFirestore.instance
      .doc('territory_daily_stats/${territoryId}_${currentSettlementDay(cutoffMinutes: cutoff)}')
      .snapshots()
      .map((d) => TerritoryDayStats(d.data() ?? const {}));
});
