import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/providers/settlement_provider.dart';
import 'package:foodiebell/features/manager/settlement/manager_settlement_history_screen.dart';
import 'package:foodiebell/shared/utils/date_text.dart';

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

  test('dates read dd/MM/yyyy', () {
    expect(dmyKey('2026-11-20'), '20/11/2026');
    expect(dmyKey('not a day'), 'not a day');
    expect(dmy(DateTime(2026, 1, 5)), '05/01/2026');
  });
}
