import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/providers/settlement_provider.dart';
import 'package:foodiebell/features/manager/settlement/manager_settlement_history_screen.dart';
import 'package:foodiebell/shared/utils/date_text.dart';
import 'package:foodiebell/shared/settlement/daily_money.dart';

SettlementStatement _s(String day, int owedPaise, String status) => SettlementStatement({
  'settlementDay': day,
  'status': status,
  'remainingBalances': {if (owedPaise > 0) 'driver:d1': owedPaise, if (owedPaise > 0) 'manager:m1': -owedPaise},
});

void main() {
  test('only the newest day keeps its status; older leftovers are carried forward', () {
    final states = historyStates([
      _s('2026-11-20', 15000, 'partiallySettled'),
      _s('2026-11-19', 17500, 'partiallySettled'),
      _s('2026-11-12', 0, 'completed'),
    ]);
    expect((states[0] as OwnStatus).status, SettlementStatus.partiallySettled);
    expect((states[1] as CarriedForward).paise, 17500);
    expect((states[2] as OwnStatus).status, SettlementStatus.completed);
  });

  test('a leftover cleared on a newer day reads as settled later, with that day', () {
    final states = historyStates([
      _s('2026-11-22', 0, 'completed'),
      _s('2026-11-21', 0, 'completed'),
      _s('2026-11-20', 15000, 'partiallySettled'),
    ]);
    final later = states[2] as SettledLater;
    expect([later.paise, later.clearedOn], [15000, '2026-11-21']);
  });

  test('an overpaid line is flagged, not done; lines that cancel out both ways are not', () {
    final lines = managerMoneyLines(_overpaidDay(), 'manager:m1');
    final quicky = lines.singleWhere((l) => l.party == 'quicky');
    expect(quicky.overpaidPaise, 2500);
    for (final l in lines.where((l) => l.party == 'driver:d1')) {
      expect(l.isOverpaid, isFalse);
    }
  });

  test('dates read dd/MM/yyyy', () {
    expect(dmyKey('2026-11-20'), '20/11/2026');
    expect(dmyKey('not a day'), 'not a day');
    expect(dmy(DateTime(2026, 1, 5)), '05/01/2026');
  });
}

// 2026-11-20: the live 20/11 statement — the Manager paid QuickMandi's ₹12.50
// three times; the driver's duplicates cancel out both ways.
SettlementStatement _overpaidDay() => const SettlementStatement({
  'settlementDay': '2026-11-20',
  'status': 'partiallySettled',
  'remainingBalances': {'quicky': 2500, 'manager:m1': -2500},
  'obligations': [
    {'from': 'driver:d1', 'to': 'manager:m1', 'purpose': 'general', 'openingPaise': -77500, 'settledPaise': 2500, 'outstandingPaise': -80000},
    {'from': 'manager:m1', 'to': 'driver:d1', 'purpose': 'general', 'openingPaise': -60000, 'settledPaise': 20000, 'outstandingPaise': -80000},
    {'from': 'manager:m1', 'to': 'quicky', 'purpose': 'general', 'openingPaise': -1250, 'settledPaise': 1250, 'outstandingPaise': -2500},
  ],
});
