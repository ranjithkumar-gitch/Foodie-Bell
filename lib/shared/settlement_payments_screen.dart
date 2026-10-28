import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/access_scope.dart';
import '../core/theme/app_colors.dart';
import '../data/providers/order_actions.dart';
import '../data/providers/settlement_provider.dart';
import 'widgets/currency_text.dart';
import 'widgets/empty_state.dart';

/// Settlement payments a Vendor or Driver is part of. When the Manager
/// records paying them (or receiving from them), it counts only once they
/// confirm it here — or they can say it's wrong. Shown from the Vendor's and
/// Driver's earnings screens.
class SettlementPaymentsScreen extends ConsumerWidget {
  const SettlementPaymentsScreen({super.key});

  Future<void> _answer(BuildContext context, SettlementTransfer t, bool confirm) async {
    String? note;
    if (!confirm) {
      final c = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('What is wrong with this payment?'),
          content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(hintText: 'e.g. I did not get this money')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Back')),
            ElevatedButton(onPressed: () => c.text.trim().isEmpty ? null : Navigator.pop(d, c.text.trim()), child: const Text('Send')),
          ],
        ),
      );
      if (note == null) return;
    }
    try {
      await acknowledgeSettlementTransfer(t.id, confirm: confirm, note: note);
    } on OrderActionException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final scope = ref.watch(accessScopeProvider);
    final me = scope == null ? '' : partyKeyFor(scope.role, scope.accountId);
    final transfers = ref.watch(myTransfersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settlement payments')),
      body: transfers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Couldn’t load payments: $e')),
        data: (list) => list.isEmpty
            ? const EmptyState(icon: Icons.account_balance_wallet_outlined, title: 'No payments yet', subtitle: 'Payments with your Manager show up here.')
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final t = list[i];
                  final incoming = t.to == me;
                  final mustAnswer = t.status == 'pendingAck' && t.counterparty == me;
                  final statusText = switch (t.status) {
                    'confirmed' => 'Confirmed',
                    'disputed' => 'Disputed',
                    _ => mustAnswer ? 'Please confirm' : 'Waiting for the Manager to confirm',
                  };
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: mustAnswer ? palette.warning : palette.border, width: mustAnswer ? 1.6 : 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(incoming ? 'Manager paid you' : 'You paid the Manager',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ),
                          CurrencyText(t.amountPaise / 100, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: incoming ? palette.success : palette.textPrimary)),
                        ]),
                        const SizedBox(height: 4),
                        Text('${t.settlementDay} · ${t.method == 'upi' ? 'UPI ${t.reference ?? ''}' : 'Cash'}', style: TextStyle(color: palette.textSecondary, fontSize: 14)),
                        Text(statusText, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                            color: t.status == 'disputed' ? palette.error : (t.status == 'confirmed' ? palette.success : palette.warning))),
                        if (mustAnswer) ...[
                          const SizedBox(height: 8),
                          Text(incoming ? 'Did you receive this money?' : 'Did you pay this money?', style: const TextStyle(fontSize: 15)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(child: OutlinedButton(onPressed: () => _answer(context, t, false), child: const Text('No, wrong'))),
                            const SizedBox(width: 10),
                            Expanded(child: ElevatedButton(onPressed: () => _answer(context, t, true), child: const Text('Yes, correct'))),
                          ]),
                        ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
