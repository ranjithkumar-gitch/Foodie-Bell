import '../../data/models/order.dart';
import '../../data/providers/earnings_provider.dart';
import '../../data/providers/settlement_provider.dart';

/// "Today's money": the daily settlement as one line per person and
/// direction, for the simple settlement cards (Manager, Driver, Vendor).
///
/// Nothing here works out what anyone owes. The Manager's lines are the
/// statement's own `general` obligation rows (`functions/lib/statement.js`),
/// which are already gross per pair and direction: a Driver's COD cash in,
/// their delivery fees out, a shop's COD payout out, a shop's UPI dues in,
/// Quicky's share out. Driver and Vendor lines are the server's per-day
/// totals (`earnings_daily`) and order money snapshots. Payments still count
/// only once the other side confirms them; cancellation charges and customer
/// refunds keep their own sections and never appear here.

/// What a line is for.
enum MoneyLineKind {
  /// Driver → Manager: all the COD cash they collected.
  codCash,

  /// Manager → Driver: their delivery fees.
  deliveryFees,

  /// Manager → shop: goods money on COD orders.
  shopPayout,

  /// Shop → Manager: commission, delivery and platform fee on UPI orders
  /// (the customer paid the shop directly).
  shopUpiDues,

  /// Manager → Quicky: Quicky's share of the commission and platform fees.
  quicky,

  /// Anything else between the Manager and someone (an earlier Manager
  /// pair, a takeover leftover): shown as it is.
  other,
}

/// Where a line stands.
enum MoneyLineState {
  /// Something is still to be paid and nobody has recorded it yet.
  open,

  /// Recorded, waiting for the other side to confirm.
  waiting,

  /// Nothing left (confirmed payments cover it).
  done,
}

/// The general-purpose payments of [day] from [from] to [to], from the
/// signed-in party's transfers.
List<SettlementTransfer> transfersBetween(List<SettlementTransfer> transfers, {required String day, required PartyKey from, required PartyKey to}) => [
  for (final t in transfers)
    if (t.settlementDay == day && t.purpose == 'general' && t.from == from && t.to == to) t,
];

/// One Manager line: what [party] and the Manager still have to settle in
/// one direction on the statement's day.
class ManagerMoneyLine {
  const ManagerMoneyLine({
    required this.party,
    required this.collect,
    required this.kind,
    required this.outstandingPaise,
    required this.openingPaise,
    required this.orders,
    this.transfers = const [],
    this.settledTogether = false,
    this.dayFeePaise = 0,
  });

  /// The other side (a Driver, a shop or Quicky).
  final PartyKey party;

  /// True: [party] pays the Manager (Collect). False: the Manager pays [party].
  final bool collect;
  final MoneyLineKind kind;

  /// The statement's still-outstanding figure for this pair and direction.
  final int outstandingPaise;

  /// The part carried over from earlier days.
  final int openingPaise;

  /// The day's orders behind this line.
  final int orders;

  /// This day's general payments in this direction, from the live
  /// transfers (which can be newer than the statement).
  final List<SettlementTransfer> transfers;

  /// The pair's net balance is already zero: payments made the other way
  /// round (one net amount) settled both directions together.
  final bool settledTogether;

  /// A Driver's day fees inside a [MoneyLineKind.codCash] line (2026-11-12).
  final int dayFeePaise;

  Iterable<SettlementTransfer> get pending => transfers.where((t) => t.status == 'pendingAck');
  Iterable<SettlementTransfer> get disputed => transfers.where((t) => t.status == 'disputed');
  int get pendingPaise => pending.fold(0, (a, t) => a + t.amountPaise);

  /// Confirmed since the statement was built (not yet in its figures).
  int confirmedSincePaise(Set<String> inStatement) =>
      transfers.where((t) => t.status == 'confirmed' && !inStatement.contains(t.id)).fold(0, (a, t) => a + t.amountPaise);

  /// What is still to record: outstanding, less what's already recorded
  /// or confirmed since the statement.
  int toRecordPaise(Set<String> inStatement) => settledTogether ? 0 : outstandingPaise - pendingPaise - confirmedSincePaise(inStatement);

  MoneyLineState state(Set<String> inStatement) {
    if (settledTogether || outstandingPaise - confirmedSincePaise(inStatement) <= 0) return MoneyLineState.done;
    if (toRecordPaise(inStatement) <= 0) return MoneyLineState.waiting;
    return MoneyLineState.open;
  }
}

String _role(PartyKey p) => p.split(':').first;

MoneyLineKind _kindOf(PartyKey party, bool collect) => switch ((_role(party), collect)) {
  ('driver', true) => MoneyLineKind.codCash,
  ('driver', false) => MoneyLineKind.deliveryFees,
  ('vendor', false) => MoneyLineKind.shopPayout,
  ('vendor', true) => MoneyLineKind.shopUpiDues,
  ('quicky', false) => MoneyLineKind.quicky,
  _ => MoneyLineKind.other,
};

int _ordersFor(SettlementStatement s, PartyKey party, MoneyLineKind kind) {
  final id = party.contains(':') ? party.split(':').last : '';
  bool cod(Map<String, dynamic> o) => o['paymentMethod'] == 'cod';
  return s.orders
      .where(
        (o) => switch (kind) {
          MoneyLineKind.codCash => o['driverId'] == id && cod(o),
          MoneyLineKind.deliveryFees => o['driverId'] == id,
          MoneyLineKind.shopPayout => o['vendorId'] == id && cod(o),
          MoneyLineKind.shopUpiDues => o['vendorId'] == id && !cod(o),
          MoneyLineKind.quicky => true,
          MoneyLineKind.other => false,
        },
      )
      .length;
}

/// The Manager's lines for statement [s]: every `general` obligation
/// between [managerKey] and someone else (customers excluded: refunds have
/// their own workflow). Collect lines first (Drivers, then shops), then Pay
/// lines (Drivers, shops, Quicky).
List<ManagerMoneyLine> managerMoneyLines(SettlementStatement s, PartyKey managerKey, {List<SettlementTransfer> transfers = const []}) {
  final balances = s.generalBalances;
  final lines = <ManagerMoneyLine>[];
  for (final o in s.obligations) {
    if (o.purpose != 'general') continue;
    final collect = o.to == managerKey;
    if (!collect && o.from != managerKey) continue;
    final party = collect ? o.from : o.to;
    if (party == managerKey || party.startsWith('user:')) continue;
    if (o.openingPaise == 0 && o.assessedPaise == 0 && o.settledPaise == 0 && o.outstandingPaise == 0) continue;
    final kind = _kindOf(party, collect);
    lines.add(
      ManagerMoneyLine(
        party: party,
        collect: collect,
        kind: kind,
        outstandingPaise: o.outstandingPaise,
        openingPaise: o.openingPaise,
        orders: _ordersFor(s, party, kind),
        transfers: transfersBetween(transfers, day: s.day, from: o.from, to: o.to),
        settledTogether: o.outstandingPaise > 0 && (balances[party] ?? 0) == 0,
        dayFeePaise: kind == MoneyLineKind.codCash ? s.driverDayFees[party] ?? 0 : 0,
      ),
    );
  }
  int rank(ManagerMoneyLine l) =>
      (l.collect ? 0 : 10) +
      switch (_role(l.party)) {
        'driver' => 0,
        'vendor' => 1,
        'quicky' => 2,
        _ => 3,
      };
  lines.sort((a, b) => rank(a).compareTo(rank(b)));
  return lines;
}

/// Ids of the payments [s] already counts (confirmed when it was built).
Set<String> statementPaymentIds(SettlementStatement s) => {
  for (final p in s.paymentsMade)
    if (p['transferId'] is String) p['transferId'] as String,
};

// ---- Driver and Vendor --------------------------------------------------

/// One line on a Driver's or Vendor's card: what should move between them
/// and their Manager over the recent days shown, less the payments both
/// sides confirmed for those days. Summed over the days (not one day at a
/// time) because a Manager often settles what was left from earlier days
/// on a later day's statement.
class PartyMoneyLine {
  const PartyMoneyLine({
    required this.kind,
    required this.owedPaise,
    required this.todayPaise,
    this.todayOrders,
    this.transfers = const [],
    this.todayDayFeePaise = 0,
  });

  final MoneyLineKind kind;

  /// The server's figures, summed over the days shown (paise).
  final int owedPaise;

  /// Today's part of [owedPaise].
  final int todayPaise;

  /// Today's orders behind it; null when the figures don't say.
  final int? todayOrders;

  /// Today's driver day fee inside a COD-cash line (2026-11-12).
  final int todayDayFeePaise;

  /// The general payments with the Manager in this line's direction, on
  /// the days shown.
  final List<SettlementTransfer> transfers;

  /// The signed-in party pays (COD cash, a shop's UPI dues).
  bool get iPay => kind == MoneyLineKind.codCash || kind == MoneyLineKind.shopUpiDues;

  int _sum(String status) => transfers.where((t) => t.status == status).fold(0, (a, t) => a + t.amountPaise);
  int get confirmedPaise => _sum('confirmed');
  int get pendingPaise => _sum('pendingAck');

  /// Still to settle (confirmed payments only count).
  int get leftPaise => owedPaise - confirmedPaise;

  /// Carried over from earlier days.
  int get earlierPaise => leftPaise - todayPaise;

  Iterable<SettlementTransfer> get pending => transfers.where((t) => t.status == 'pendingAck');
  Iterable<SettlementTransfer> get disputed => transfers.where((t) => t.status == 'disputed');

  MoneyLineState get state {
    if (leftPaise <= 0) return MoneyLineState.done;
    if (pendingPaise > 0) return MoneyLineState.waiting;
    return MoneyLineState.open;
  }
}

bool _withManager(SettlementTransfer t) => t.from.startsWith('manager:') || t.to.startsWith('manager:');

/// The oldest day shown: the oldest delivery day loaded, or today.
String _windowStart(List<EarningsDay> days, String today) => days.map((d) => d.day).fold(today, (a, d) => d.compareTo(a) < 0 ? d : a);

List<SettlementTransfer> _windowTransfers(List<SettlementTransfer> transfers, String start, PartyKey me, {required bool fromMe}) => [
  for (final t in transfers)
    if (t.settlementDay.compareTo(start) >= 0 && t.purpose == 'general' && _withManager(t) && (fromMe ? t.from == me : t.to == me)) t,
];

int _p(EarningsFigures d, String k) => (d.data[k] as num?)?.toInt() ?? 0;

/// A Driver's lines: all the COD cash they collected, to hand to the
/// Manager, and the delivery fees the Manager pays them (`earnings_daily`).
List<PartyMoneyLine> driverMoneyLines(List<EarningsDay> days, String today, PartyKey me, List<SettlementTransfer> transfers) {
  final start = _windowStart(days, today);
  final todays = earningsOn(days, today);
  final out = _windowTransfers(transfers, start, me, fromMe: true);
  final inc = _windowTransfers(transfers, start, me, fromMe: false);
  // All the COD cash plus the driver day fees (2026-11-12): both go to the Manager.
  final cod = days.fold(0, (a, d) => a + _p(d, 'codCollectedPaise') + _p(d, 'dayFeePaise'));
  final fees = days.fold(0, (a, d) => a + _p(d, 'earningsPaise'));
  return [
    if (cod > 0 || out.isNotEmpty)
      PartyMoneyLine(
        kind: MoneyLineKind.codCash,
        owedPaise: cod,
        todayPaise: _p(todays, 'codCollectedPaise') + _p(todays, 'dayFeePaise'),
        todayDayFeePaise: _p(todays, 'dayFeePaise'),
        transfers: out,
      ),
    if (fees > 0 || inc.isNotEmpty)
      PartyMoneyLine(kind: MoneyLineKind.deliveryFees, owedPaise: fees, todayPaise: _p(todays, 'earningsPaise'), todayOrders: todays.orders, transfers: inc),
  ];
}

/// The settlement day an order counts towards: the day it was delivered,
/// after the cut-off the next one (the server's `settlementDayFor`).
String? settlementDayOfOrder(Order o, int cutoffMinutes) {
  final at = o.statusTimestamps[OrderStatus.delivered];
  return at == null ? null : currentSettlementDay(cutoffMinutes: cutoffMinutes, now: at);
}

/// One shop day split into goods money on COD orders (the Manager pays the
/// shop) and commission + delivery + platform fee on UPI orders (the shop
/// pays the Manager). A day with one kind of order comes straight from
/// `earnings_daily`; a mixed day from its delivered orders' own money
/// snapshots when every one of them is at hand, else as the net difference
/// (also `earnings_daily`) — never a guess.
({int payout, int dues, int? codOrders, int? upiOrders}) vendorDaySplit(EarningsFigures day, String dayKey, List<Order> deliveredOrders, int cutoffMinutes) {
  final entitlement = _p(day, 'earningsPaise');
  final upi = _p(day, 'upiTotalPaise');
  if (upi == 0) return (payout: entitlement, dues: 0, codOrders: day.orders, upiOrders: 0);
  if (_p(day, 'codTotalPaise') == 0) return (payout: 0, dues: upi - entitlement, codOrders: 0, upiOrders: day.orders);
  final ofDay = [
    for (final o in deliveredOrders)
      if (o.money != null && settlementDayOfOrder(o, cutoffMinutes) == dayKey) o,
  ];
  if (ofDay.length == day.orders) {
    var payout = 0, dues = 0, codOrders = 0, upiOrders = 0;
    for (final o in ofDay) {
      final m = o.money!;
      if (o.paymentMethod == PaymentMethod.cod) {
        payout += m.vendorEntitlement;
        codOrders++;
      } else {
        dues += m.commission + m.deliveryFee + m.platformFee;
        upiOrders++;
      }
    }
    return (payout: payout, dues: dues, codOrders: codOrders, upiOrders: upiOrders);
  }
  final net = entitlement - upi;
  return (payout: net > 0 ? net : 0, dues: net < 0 ? -net : 0, codOrders: null, upiOrders: null);
}

/// A shop's lines over the days shown (see [vendorDaySplit]).
List<PartyMoneyLine> vendorMoneyLines(
  List<EarningsDay> days,
  String today,
  PartyKey me,
  List<SettlementTransfer> transfers, {
  List<Order> deliveredOrders = const [],
  int cutoffMinutes = 22 * 60,
}) {
  final start = _windowStart(days, today);
  final inc = _windowTransfers(transfers, start, me, fromMe: false);
  final out = _windowTransfers(transfers, start, me, fromMe: true);
  var payout = 0, dues = 0;
  ({int payout, int dues, int? codOrders, int? upiOrders})? todays;
  for (final d in days) {
    final split = vendorDaySplit(d, d.day, deliveredOrders, cutoffMinutes);
    payout += split.payout;
    dues += split.dues;
    if (d.day == today) todays = split;
  }
  return [
    if (payout > 0 || inc.isNotEmpty)
      PartyMoneyLine(
        kind: MoneyLineKind.shopPayout,
        owedPaise: payout,
        todayPaise: todays?.payout ?? 0,
        todayOrders: todays == null ? 0 : todays.codOrders,
        transfers: inc,
      ),
    if (dues > 0 || out.isNotEmpty)
      PartyMoneyLine(
        kind: MoneyLineKind.shopUpiDues,
        owedPaise: dues,
        todayPaise: todays?.dues ?? 0,
        todayOrders: todays == null ? 0 : todays.upiOrders,
        transfers: out,
      ),
  ];
}
