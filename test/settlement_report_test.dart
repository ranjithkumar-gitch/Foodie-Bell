import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/providers/earnings_provider.dart';
import 'package:foodiebell/data/providers/settlement_provider.dart';
import 'package:foodiebell/shared/settlement/daily_money.dart';
import 'package:foodiebell/shared/settlement/party_today_money_card.dart';
import 'package:foodiebell/shared/settlement/settlement_report.dart';

const _d = 'driver:d1';
const _m = 'manager:m1';

SettlementTransfer _settled({DateTime? until, Map<String, dynamic>? report, String status = 'confirmed', String recordedBy = _m}) => SettlementTransfer(
  id: 't1',
  from: _d,
  to: _m,
  amountPaise: 17500,
  method: 'cash',
  status: status,
  counterparty: _d,
  settlementDay: '2026-11-20',
  recordedBy: recordedBy,
  reportUntil: until,
  report: report,
);

void main() {
  final now = DateTime(2026, 11, 20, 12);
  final later = now.add(const Duration(hours: 20));

  group('the 24-hour report window', () {
    test('the other side can report while it lasts', () {
      expect(_settled(until: later).canReport(_d, now: now), isTrue);
    });

    test('the side that marked it cannot report it', () {
      expect(_settled(until: later).canReport(_m, now: now), isFalse);
    });

    test('after 24 hours it is final', () {
      expect(_settled(until: later).canReport(_d, now: later.add(const Duration(minutes: 1))), isFalse);
    });

    test('once reported, it cannot be reported again', () {
      expect(_settled(until: later, report: {'status': 'open'}).canReport(_d, now: now), isFalse);
    });

    test('payments from before the change (no window) cannot be reported', () {
      expect(_settled().canReport(_d, now: now), isFalse);
    });
  });

  group('status text', () {
    test('settled, with the deadline', () {
      expect(settledStatusText(_settled(until: later), _d, now: now), startsWith('Settled. Wrong? Report it until'));
    });

    test('reported, kept, undone', () {
      expect(settledStatusText(_settled(until: later, report: {'status': 'open'}), _d, now: now), 'Problem reported — QuickMandi is checking it.');
      expect(settledStatusText(_settled(until: later, report: {'status': 'resolved', 'decision': 'keep'}), _d, now: now), 'Checked by QuickMandi — stays settled.');
      expect(settledStatusText(_settled(until: later, status: 'voided'), _d, now: now), 'Undone by QuickMandi — the amount is owed again.');
    });

    test('final after the window', () {
      expect(settledStatusText(_settled(until: later), _d, now: later.add(const Duration(hours: 1))), 'Settled ✓');
    });
  });

  testWidgets('the driver sees what the Manager marked and a Report button, no Yes/No', (tester) async {
    final until = DateTime.now().add(const Duration(hours: 23));
    final lines = driverMoneyLines([const EarningsDay({'settlementDay': '2026-11-20', 'orders': 1, 'codCollectedPaise': 17500})], '2026-11-20', _d, [_settled(until: until)]);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PartyTodayMoneyCard(lines: lines, me: _d)))),
    ));
    expect(find.textContaining('Your Manager marked receiving'), findsOneWidget);
    expect(find.byKey(const ValueKey('report:t1')), findsOneWidget);
    expect(find.text('Yes, I handed it over'), findsNothing);
  });
}
