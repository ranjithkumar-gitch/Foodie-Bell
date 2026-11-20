import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/access_scope.dart';
import '../core/theme/app_colors.dart';
import '../data/providers/order_actions.dart';
import '../data/providers/settlement_provider.dart';
import 'settlement/party_today_money_card.dart';
import 'settlement/settlement_report.dart';
import 'widgets/currency_text.dart';
import 'widgets/busy_overlay.dart';

/// Settlements for a Vendor or Driver (2026-11-20): first who owes whom
/// with their Manager, then every payment between them. The Manager marks a
/// payment settled and it counts at once; the Vendor or Driver can report a
/// problem within 24 hours, after which it is final. Payments recorded
/// before then may still ask for a Yes / No.
class SettlementPaymentsScreen extends ConsumerWidget {
  const SettlementPaymentsScreen({super.key});

  /// A payment from before 2026-11-20 still waiting for this side's answer.
  Future<void> _answer(BuildContext context, SettlementTransfer t, bool confirm) async {
    String? note;
    if (!confirm) {
      final c = TextEditingController();
      note = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
          title: const Text('What is wrong with this payment?'),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. I did not get this money'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Back')),
            ElevatedButton(onPressed: () => c.text.trim().isEmpty ? null : Navigator.pop(d, c.text.trim()), child: const Text('Send')),
          ],
        ),
      );
      if (note == null) return;
    }
    try {
      await runBusy(() => acknowledgeSettlementTransfer(t.id, confirm: confirm, note: note));
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
    final lines = ref.watch(myPartyMoneyLinesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settlements')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          PartyTodayMoneyCard(title: 'Who owes whom', lines: lines, me: me),
          const SizedBox(height: 8),
          Text(
            'Your Manager marks each payment settled. If something is wrong, report it within 24 hours — after that it is final.',
            style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 20),
          Text('Payments', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...transfers.when(
            loading: () => [
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [Text('Couldn’t load payments: $e')],
            data: (list) => list.isEmpty
                ? [Text('No payments yet. Payments with your Manager show up here.', style: TextStyle(color: palette.textSecondary))]
                : [
                    for (final t in list) ...[_PaymentCard(transfer: t, me: me, onAnswer: (ok) => _answer(context, t, ok)), const SizedBox(height: 10)],
                  ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.transfer, required this.me, required this.onAnswer});

  final SettlementTransfer transfer;
  final PartyKey me;
  final void Function(bool confirm) onAnswer;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final t = transfer;
    final incoming = t.to == me;
    final other = incoming ? t.from : t.to;
    final otherName = other == 'quicky' ? 'QuickMandi' : 'your Manager';
    // Before 2026-11-20 a recorded payment waited for the other side.
    final mustAnswer = t.status == 'pendingAck' && t.counterparty == me;
    final legacyStatus = switch (t.status) {
      'disputed' => 'Disputed',
      'pendingAck' => mustAnswer ? 'Please confirm' : 'Waiting for $otherName to confirm',
      _ => null,
    };
    final reportable = t.canReport(me);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: mustAnswer || reportable ? palette.warning : palette.border, width: mustAnswer || reportable ? 1.4 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  incoming ? '${otherName[0].toUpperCase()}${otherName.substring(1)} paid you' : 'You paid $otherName',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              CurrencyText(
                t.amountPaise / 100,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: t.status == 'voided' ? palette.textMuted : (incoming ? palette.success : palette.textPrimary),
                  decoration: t.status == 'voided' ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (t.purpose != 'general')
            Text(
              settlementPurposeLabel(t.purpose),
              key: ValueKey('purpose:${t.id}'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          Text('${t.settlementDay} · ${t.method == 'upi' ? 'UPI ${t.reference ?? ''}' : 'Cash'}', style: TextStyle(color: palette.textSecondary, fontSize: 14)),
          if (legacyStatus != null)
            Text(
              legacyStatus,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: t.status == 'disputed' ? palette.error : palette.warning),
            )
          else
            SettledPaymentNote(transfer: t, me: me, text: ''),
          if (mustAnswer) ...[
            const SizedBox(height: 8),
            Text(incoming ? 'Did you receive this money?' : 'Did you pay this money?', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: () => onAnswer(false), child: const Text('No, wrong')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(onPressed: () => onAnswer(true), child: const Text('Yes, correct')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
