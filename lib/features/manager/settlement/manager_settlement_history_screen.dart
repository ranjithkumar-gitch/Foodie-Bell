import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/settlement_provider.dart';
import '../../../shared/utils/date_text.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';

/// How a past day reads in the history (2026-11-20). Each statement is a
/// snapshot at its day's close; anything unpaid moves to the next day, and
/// a later payment clears it there, never on the old day. So only the
/// newest day carries the live status; an older day that closed with money
/// left over says it was carried forward, or settled later once a newer day
/// closed with nothing owed.
sealed class HistoryState {
  const HistoryState();
}

/// The statement's own status (the newest day, or a day that closed clean).
class OwnStatus extends HistoryState {
  const OwnStatus(this.status);
  final SettlementStatus status;
}

/// Money left at this day's close, still open on every newer day.
class CarriedForward extends HistoryState {
  const CarriedForward(this.paise);
  final int paise;
}

/// Money left at this day's close that a later day [clearedOn] settled.
class SettledLater extends HistoryState {
  const SettledLater(this.paise, this.clearedOn);
  final int paise;
  final String clearedOn;
}

/// What the statement still showed as owed at its close (paise).
int openAtClose(SettlementStatement s) => s.remainingBalances.values.where((v) => v > 0).fold(0, (a, b) => a + b);

/// [statements] newest first.
List<HistoryState> historyStates(List<SettlementStatement> statements) => [
  for (var i = 0; i < statements.length; i++)
    () {
      final s = statements[i];
      final open = openAtClose(s);
      if (i == 0 || open == 0) return OwnStatus(s.status);
      // The first newer day that closed with nothing owed cleared it.
      for (var j = i - 1; j >= 0; j--) {
        if (openAtClose(statements[j]) == 0) return SettledLater(open, statements[j].day);
      }
      return CarriedForward(open);
    }(),
];

class ManagerSettlementHistoryScreen extends ConsumerWidget {
  const ManagerSettlementHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final statements = ref.watch(territoryStatementsProvider);
    String rupees(int paise) => AppFormat.currency(paise / 100);

    return Scaffold(
      appBar: AppBar(title: const Text('Settlement History')),
      body: statements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Couldn’t load statements: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No statements yet', subtitle: 'A statement appears once orders are delivered.');
          }
          final states = historyStates(list);
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: list.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Text(
                  'Unpaid money moves to the next day. Settle what today shows and earlier days follow.',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                );
              }
              final s = list[i - 1];
              final state = states[i - 1];
              final open = openAtClose(s);
              final (label, color, note) = switch (state) {
                OwnStatus(:final status) => (
                  status.label,
                  switch (status) {
                    SettlementStatus.completed => palette.success,
                    SettlementStatus.disputed => palette.error,
                    SettlementStatus.partiallySettled => palette.warning,
                    SettlementStatus.pending => palette.textSecondary,
                  },
                  open > 0 ? 'Still owed: ${rupees(open)}' : null,
                ),
                CarriedForward(:final paise) => ('Carried forward', palette.warning, '${rupees(paise)} moved to the next day'),
                SettledLater(:final paise, :final clearedOn) => ('Settled later', palette.success, '${rupees(paise)} cleared by ${dmyKey(clearedOn)}'),
              };
              return Container(
                key: ValueKey('history:${s.day}'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dmyKey(s.day), style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            '${s.total('orders')} orders · your earnings ${AppFormat.currency(s.total('managerEarningsPaise') / 100)}',
                            style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                          ),
                          if (note != null) Text(note, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
