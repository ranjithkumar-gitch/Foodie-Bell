import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/settlement_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';

/// Past daily statements for the Manager's territory, newest first, each
/// with the status the server computed from actual acknowledged payments.
/// (It used to call every past day "Settled" just because it had passed.)
class ManagerSettlementHistoryScreen extends ConsumerWidget {
  const ManagerSettlementHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final statements = ref.watch(territoryStatementsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settlement History')),
      body: statements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Couldn’t load statements: $e')),
        data: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No statements yet', subtitle: 'A statement appears once orders are delivered.')
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final s = list[i];
                  final open = s.remainingBalances.values.where((v) => v > 0).fold(0, (a, b) => a + b);
                  final color = switch (s.status) {
                    SettlementStatus.completed => palette.success,
                    SettlementStatus.disputed => palette.error,
                    SettlementStatus.partiallySettled => palette.warning,
                    SettlementStatus.pending => palette.textSecondary,
                  };
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.day, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text('${s.total('orders')} orders · your earnings ${AppFormat.currency(s.total('managerEarningsPaise') / 100)}',
                                  style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                              if (open > 0)
                                Text('Still owed: ${AppFormat.currency(open / 100)}', style: TextStyle(color: palette.warning, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Text(s.status.label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
