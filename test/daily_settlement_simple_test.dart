// The simple daily settlement ("Today's money"): one line per person and
// direction for the Manager, Driver and Vendor. Every figure is the
// server's (statement obligations, `earnings_daily`, order money
// snapshots); nothing about the money itself changes — payments still count
// only once the other side confirms them, and cancellation charges and
// customer refunds stay out of these lines.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/models/order.dart';
import 'package:foodiebell/data/providers/earnings_provider.dart';
import 'package:foodiebell/data/providers/settlement_provider.dart';
import 'package:foodiebell/features/manager/settlement/manager_today_money_card.dart';
import 'package:foodiebell/shared/settlement/daily_money.dart';
import 'package:foodiebell/shared/settlement/party_today_money_card.dart';

const _day = '2026-11-12';
const _m = 'manager:m1';
const _d = 'driver:d1';
const _v = 'vendor:v1';

Map<String, dynamic> _ob(String from, String to, int outstanding, {String purpose = 'general', int opening = 0, int settled = 0}) => {
  'from': from,
  'to': to,
  'purpose': purpose,
  'openingPaise': opening,
  'assessedPaise': outstanding + settled - opening,
  'settledPaise': settled,
  'outstandingPaise': outstanding,
};

/// One COD order: ₹150 items + ₹20 delivery + ₹5 platform fee = ₹175.
/// Shop ₹135, driver ₹20, Quicky ₹7.50 + ₹5. Plus a cancellation charge and
/// a customer refund, which must stay out of the simple lines.
SettlementStatement _statement({Map<String, int>? balances, List<Map<String, dynamic>>? obligations, List<Map<String, dynamic>> paymentsMade = const []}) =>
    SettlementStatement({
      'settlementDay': _day,
      'status': 'pending',
      'remainingBalances': balances ?? {_d: 15500, _v: -10000, 'quicky': -1250, 'user:c1': -500},
      'orders': [
        {'orderId': 'o1', 'vendorId': 'v1', 'driverId': 'd1', 'paymentMethod': 'cod'},
      ],
      'paymentsMade': paymentsMade,
      'obligations':
          obligations ??
          [
            _ob(_d, _m, 17500),
            _ob(_m, _v, 13500),
            _ob(_m, _d, 2000),
            _ob(_m, 'quicky', 1250),
            _ob(_v, 'user:c1', 500, purpose: 'customerRefund'),
            _ob(_v, _m, 3000, purpose: 'cancellationCharge'),
          ],
    });

SettlementTransfer _t(String id, String from, String to, int paise, {String status = 'pendingAck', required String counterparty, String day = _day}) =>
    SettlementTransfer(id: id, from: from, to: to, amountPaise: paise, method: 'cash', status: status, counterparty: counterparty, settlementDay: day);

EarningsDay _earn(String day, Map<String, int> paise, {int orders = 1}) => EarningsDay({'settlementDay': day, 'orders': orders, ...paise});

OrderMoney _money() => const OrderMoney(
  itemsSubtotal: 15000,
  couponDiscount: 0,
  eligibleItemValue: 15000,
  deliveryFee: 2000,
  platformFee: 500,
  customerTotal: 17500,
  commission: 1500,
  managerShare: 750,
  quickyShare: 750,
  vendorEntitlement: 13500,
  driverEntitlement: 2000,
);

Order _order(String id, PaymentMethod method) => Order(
  id: id,
  vendorId: 'v1',
  vendorName: 'Shop',
  userId: 'c1',
  userName: 'Customer',
  userPhone: '+910000000000',
  items: const [],
  deliveryAddressLabel: 'Home',
  paymentMethod: method,
  status: OrderStatus.delivered,
  subtotal: 150,
  deliveryFee: 20,
  platformFee: 5,
  gstAmount: 0,
  total: 175,
  placedAt: DateTime.utc(2026, 11, 12, 4),
  rebatePercent: 10,
  money: _money(),
  // 10:00 IST on the 12th, before the 22:00 cut-off.
  statusTimestamps: {OrderStatus.delivered: DateTime.utc(2026, 11, 12, 4, 30)},
);

void main() {
  group('Manager lines', () {
    test('gross per person and direction: COD cash in, fees / payout / QuickMandi out; refunds and cancellations left out', () {
      final lines = managerMoneyLines(_statement(), _m);
      expect([for (final l in lines) (l.collect, l.party, l.kind, l.outstandingPaise, l.orders)], [
        (true, _d, MoneyLineKind.codCash, 17500, 1),
        (false, _d, MoneyLineKind.deliveryFees, 2000, 1),
        (false, _v, MoneyLineKind.shopPayout, 13500, 1),
        (false, 'quicky', MoneyLineKind.quicky, 1250, 1),
      ]);
      expect(lines.every((l) => l.state(const {}) == MoneyLineState.open), isTrue);
    });

    test('a recorded payment waits for the other side; a confirmed one ticks even before the statement reloads', () {
      final pending = managerMoneyLines(_statement(), _m, transfers: [_t('t1', _d, _m, 17500, counterparty: _d)]).first;
      expect(pending.state(const {}), MoneyLineState.waiting);
      expect(pending.toRecordPaise(const {}), 0);

      final part = managerMoneyLines(_statement(), _m, transfers: [_t('t1', _d, _m, 10000, counterparty: _d)]).first;
      expect(part.state(const {}), MoneyLineState.open);
      expect(part.toRecordPaise(const {}), 7500);

      final confirmed = managerMoneyLines(_statement(), _m, transfers: [_t('t1', _d, _m, 17500, status: 'confirmed', counterparty: _d)]).first;
      expect(confirmed.state(const {}), MoneyLineState.done);
      // Already in the statement's figures: not subtracted twice.
      expect(confirmed.confirmedSincePaise({'t1'}), 0);
    });

    test('another day\'s or another purpose\'s payment doesn\'t count on the line', () {
      final l = managerMoneyLines(_statement(), _m, transfers: [
        _t('t1', _d, _m, 17500, counterparty: _d, day: '2026-11-11'),
        SettlementTransfer(id: 't2', from: _d, to: _m, amountPaise: 17500, method: 'cash', status: 'pendingAck', counterparty: _d, settlementDay: _day, purpose: 'cancellationDriverComp'),
      ]).first;
      expect(l.state(const {}), MoneyLineState.open);
    });

    test('a pair already settled with one net payment shows both lines done', () {
      final s = _statement(balances: const {}, obligations: [_ob(_v, _m, 4000), _ob(_m, _v, 4000, settled: 9500)]);
      final lines = managerMoneyLines(s, _m);
      expect(lines.map((l) => l.state(const {})), everyElement(MoneyLineState.done));
      expect(lines.every((l) => l.settledTogether), isTrue);
    });

    test('carried-over money is in the same line', () {
      final l = managerMoneyLines(_statement(obligations: [_ob(_d, _m, 27500, opening: 10000)]), _m).single;
      expect(managerLineText(l, l.outstandingPaise), contains('from earlier days'));
    });
  });

  group('Driver lines', () {
    test('all the COD cash to hand over, and the delivery fees to receive, over the recent days', () {
      final days = [
        _earn(_day, {'codCollectedPaise': 17500, 'codTotalPaise': 17500, 'earningsPaise': 2000}),
        _earn('2026-11-11', {'codCollectedPaise': 10000, 'codTotalPaise': 10000, 'earningsPaise': 2000}),
      ];
      // The Manager settled yesterday's cash on today's statement.
      final lines = driverMoneyLines(days, _day, _d, [
        _t('t1', _d, _m, 10000, status: 'confirmed', counterparty: _d),
        _t('t2', _m, _d, 4000, counterparty: _d),
      ]);
      final cod = lines.firstWhere((l) => l.kind == MoneyLineKind.codCash);
      expect([cod.leftPaise, cod.todayPaise, cod.earlierPaise, cod.state], [17500, 17500, 0, MoneyLineState.open]);
      final fees = lines.firstWhere((l) => l.kind == MoneyLineKind.deliveryFees);
      expect([fees.leftPaise, fees.state], [4000, MoneyLineState.waiting]);
    });
  });

  group('driver day fee (2026-11-12)', () {
    test('the Driver hands over COD cash plus the day fee; a fee-only day is a line too', () {
      final withOrders = driverMoneyLines([_earn(_day, {'codCollectedPaise': 35000, 'dayFeePaise': 2500, 'earningsPaise': 4000}, orders: 2)], _day, _d, const []);
      final cod = withOrders.firstWhere((l) => l.kind == MoneyLineKind.codCash);
      expect([cod.leftPaise, cod.todayDayFeePaise], [37500, 2500]);
      expect(partyLineTitle(cod, cod.leftPaise), contains('COD cash + ₹25 day fee'));

      final feeOnly = driverMoneyLines([_earn(_day, {'dayFeePaise': 2500}, orders: 0)], _day, _d, const []);
      expect(feeOnly.single.kind, MoneyLineKind.codCash);
      expect(feeOnly.single.leftPaise, 2500);
    });

    test('the Manager sees the fee inside the Driver\'s hand-over line', () {
      final s = SettlementStatement({
        ..._statement().data,
        'obligations': [_ob(_d, _m, 20000), _ob(_m, 'quicky', 2500)],
        'driverDayFees': {_d: 2500},
      });
      final l = managerMoneyLines(s, _m).first;
      expect([l.kind, l.outstandingPaise, l.dayFeePaise], [MoneyLineKind.codCash, 20000, 2500]);
      expect(managerLineText(l, l.outstandingPaise), contains('day fee'));
    });
  });

  group('Vendor lines', () {
    test('COD-only and UPI-only days come straight from the day totals', () {
      expect(vendorDaySplit(_earn(_day, {'earningsPaise': 13500, 'codTotalPaise': 17500}), _day, const [], 1320).payout, 13500);
      final upi = vendorDaySplit(_earn(_day, {'earningsPaise': 13500, 'upiTotalPaise': 17500}), _day, const [], 1320);
      expect([upi.payout, upi.dues], [0, 4000]);
    });

    test('a mixed day splits by the orders\' money snapshots, or falls back to the net difference', () {
      final day = _earn(_day, {'earningsPaise': 27000, 'codTotalPaise': 17500, 'upiTotalPaise': 17500}, orders: 2);
      final split = vendorDaySplit(day, _day, [_order('o1', PaymentMethod.cod), _order('o2', PaymentMethod.upi)], 1320);
      expect([split.payout, split.dues, split.codOrders, split.upiOrders], [13500, 4000, 1, 1]);
      final net = vendorDaySplit(day, _day, const [], 1320);
      expect([net.payout, net.dues, net.codOrders], [9500, 0, null]);
    });
  });

  group('cards', () {
    testWidgets('Manager: one button per line, pre-filled; a payment the other side recorded gets Yes / No', (tester) async {
      ManagerMoneyLine? recorded;
      int? amount;
      (String, bool)? answered;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ManagerTodayMoneyCard(
              statement: _statement(),
              managerKey: _m,
              transfers: [_t('t9', _m, _d, 2000, counterparty: _m)],
              partyName: (p) => p,
              onRecord: (l, a) => (recorded, amount) = (l, a),
              onAnswer: (t, ok) => answered = (t.id, ok),
            ),
          ),
        ),
      ));
      expect(find.text('0 of 4 done'), findsOneWidget);
      expect(find.text('COLLECT'), findsOneWidget);
      expect(find.text('Waiting for the other side to confirm: 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('record:pay:$_v')));
      expect((recorded?.kind, amount), (MoneyLineKind.shopPayout, 13500));
      await tester.tap(find.byKey(const ValueKey('confirm:t9')));
      expect(answered, ('t9', true));
    });

    testWidgets('a closed (past) day shows its lines but no Received / Paid', (tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ManagerTodayMoneyCard(
                statement: _statement(),
                managerKey: _m,
                transfers: const [],
                partyName: (p) => p,
                onRecord: (l, a) {},
                onAnswer: (t, ok) {},
                readOnly: true,
              ),
            ),
          ),
        ),
      ));
      expect(find.text('COLLECT'), findsOneWidget);
      expect(find.text('Received'), findsNothing);
      expect(find.text('Paid'), findsNothing);
    });

    testWidgets('Driver: the Manager\'s "Received" is confirmed with "Yes, I handed it over"', (tester) async {
      final lines = driverMoneyLines([_earn(_day, {'codCollectedPaise': 17500, 'earningsPaise': 2000})], _day, _d, [_t('t1', _d, _m, 17500, counterparty: _d)]);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PartyTodayMoneyCard(lines: lines, me: _d)))),
      ));
      expect(find.textContaining('COD cash to your Manager'), findsOneWidget);
      expect(find.text('Yes, I handed it over'), findsOneWidget);
      expect(find.text('Waiting for your Manager to pay you.'), findsOneWidget);
    });

    testWidgets('nothing open shows a calm empty line', (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: Scaffold(body: PartyTodayMoneyCard(lines: [], me: _v))),
      ));
      expect(find.text('Nothing to settle with your Manager right now.'), findsOneWidget);
    });
  });
}
