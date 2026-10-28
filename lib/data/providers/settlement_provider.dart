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

  List<Map<String, dynamic>> _list(String key) =>
      [for (final e in (data[key] as List? ?? const [])) Map<String, dynamic>.from(e as Map)];
  List<Map<String, dynamic>> get orders => _list('orders');
  List<Map<String, dynamic>> get paymentsMade => _list('paymentsMade');
  List<Map<String, dynamic>> get paymentsAwaitingAcknowledgement => _list('paymentsAwaitingAcknowledgement');
  List<Map<String, dynamic>> get discrepancies => _list('discrepancies');
}

/// The territory's statements, newest day first (Manager only).
final territoryStatementsProvider = StreamProvider<List<SettlementStatement>>((ref) {
  final territoryId = ref.watch(accessScopeProvider.select((s) => s?.role == AppRole.manager ? s?.territoryId : null));
  if (territoryId == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('daily_settlements')
      .where('territoryId', isEqualTo: territoryId)
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
  });

  final String id;
  final PartyKey from;
  final PartyKey to;
  final int amountPaise;
  final String method;

  /// `pendingAck`, `confirmed` or `disputed`.
  final String status;

  /// The side that must acknowledge it (the one that didn't record it).
  final PartyKey counterparty;
  final String settlementDay;
  final String? reference;

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

/// Today's settlement day in IST with the given cutoff (minutes after
/// midnight; after it, things count towards the next day) — the same rule
/// as `settlementDayFor` in `functions/money.js`.
String currentSettlementDay({int cutoffMinutes = 22 * 60, DateTime? now}) {
  final shift = cutoffMinutes % 1440 == 0 ? 0 : 1440 - cutoffMinutes;
  final ist = (now ?? DateTime.now()).toUtc().add(Duration(minutes: 330 + shift));
  return '${ist.year.toString().padLeft(4, '0')}-${ist.month.toString().padLeft(2, '0')}-${ist.day.toString().padLeft(2, '0')}';
}

/// The live global pricing (`app_config/pricing`, public read; only the
/// Super Admin can change it) — null until an admin has saved one, when the
/// built-in default (₹20/30/40/50/60 up to 3/5/7/9/11 km, 10%, 60/40) applies.
final globalPricingProvider = StreamProvider<Map<String, dynamic>?>(
  (ref) => FirebaseFirestore.instance.doc('app_config/pricing').snapshots().map((d) => d.data()),
);

/// The live global settlement cutoff (`app_config/pricing`, public read).
final settlementCutoffProvider = StreamProvider<int>((ref) => FirebaseFirestore.instance
    .doc('app_config/pricing')
    .snapshots()
    .map((d) => (d.data()?['settlementCutoffMinutes'] as num?)?.toInt() ?? 22 * 60));
