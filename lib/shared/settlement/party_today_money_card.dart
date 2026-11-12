import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/providers/order_actions.dart';
import '../../data/providers/settlement_provider.dart';
import '../widgets/currency_text.dart';
import 'daily_money.dart';

String _rupees(int paise) => AppFormat.currency(paise / 100);

/// The headline of a Driver's or Vendor's line, for [amountPaise].
String partyLineTitle(PartyMoneyLine l, int amountPaise) {
  final amount = _rupees(amountPaise);
  final orders = l.todayOrders;
  final forOrders = orders == null || orders == 0 ? '' : ' for ${orders == 1 ? '1 order' : '$orders orders'}';
  return switch (l.kind) {
    MoneyLineKind.codCash =>
      l.todayDayFeePaise > 0 ? 'Hand over $amount to your Manager (COD cash + ${_rupees(l.todayDayFeePaise)} day fee)' : 'Hand over $amount COD cash to your Manager',
    MoneyLineKind.deliveryFees => 'Your Manager pays you $amount delivery fees',
    MoneyLineKind.shopPayout => 'Your Manager pays you $amount$forOrders',
    MoneyLineKind.shopUpiDues => 'Pay your Manager $amount commission + delivery (UPI orders)',
    _ => '$amount order money',
  };
}

/// "Today's money" for a Driver or Vendor: what moves between them and
/// their Manager, one line each, and a Yes / No when the Manager has
/// recorded a payment. The Manager records every payment; it counts once
/// the Driver or Vendor confirms it here (both sides, as before).
class PartyTodayMoneyCard extends ConsumerWidget {
  const PartyTodayMoneyCard({super.key, required this.lines, required this.me, this.onOpenPayments});

  final List<PartyMoneyLine> lines;
  final PartyKey me;

  /// Opens the full payment list.
  final VoidCallback? onOpenPayments;

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
            decoration: const InputDecoration(hintText: 'e.g. the amount is different'),
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
      await acknowledgeSettlementTransfer(t.id, confirm: confirm, note: note);
    } on OrderActionException catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    // A line settled on an earlier day with nothing new today drops off.
    final lines = [
      for (final l in this.lines)
        if (l.state != MoneyLineState.done || l.todayPaise > 0) l,
    ];
    final allDone = lines.every((l) => l.state == MoneyLineState.done);
    return Container(
      key: const Key('partyTodayMoneyCard'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: lines.isNotEmpty && allDone ? palette.success : palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Today’s money', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              if (lines.isNotEmpty && allDone)
                Text(
                  'All settled ✓',
                  style: TextStyle(color: palette.success, fontWeight: FontWeight.w800),
                ),
            ],
          ),
          if (lines.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Nothing to settle with your Manager right now.', style: TextStyle(color: palette.textSecondary)),
            ),
          for (final l in lines) _PartyLine(line: l, me: me, onAnswer: (t, ok) => _answer(context, t, ok)),
          if (onOpenPayments != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onOpenPayments, child: const Text('All payments')),
            ),
        ],
      ),
    );
  }
}

class _PartyLine extends StatelessWidget {
  const _PartyLine({required this.line, required this.me, required this.onAnswer});
  final PartyMoneyLine line;
  final PartyKey me;
  final void Function(SettlementTransfer t, bool confirm) onAnswer;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final state = line.state;
    final toAnswer = [
      for (final t in line.pending)
        if (t.counterparty == me) t,
    ];
    final mine = [
      for (final t in line.pending)
        if (t.counterparty != me) t,
    ];
    final note = switch (state) {
      MoneyLineState.done => line.iPay ? (line.kind == MoneyLineKind.codCash ? 'Handed over ✓' : 'Paid ✓') : 'Received ✓',
      _ when toAnswer.isNotEmpty => null,
      MoneyLineState.waiting => 'Waiting for your Manager to confirm.',
      MoneyLineState.open => line.iPay ? 'When your Manager gets it, they tap “Received”. Then you confirm here.' : 'Waiting for your Manager to pay.',
    };
    final yes = switch (line.kind) {
      MoneyLineKind.codCash => 'Yes, I handed it over',
      MoneyLineKind.shopUpiDues => 'Yes, I paid it',
      MoneyLineKind.shopPayout => 'Yes, I received it',
      _ => 'Yes, received',
    };
    return Padding(
      key: ValueKey('partyLine:${line.kind.name}'),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                state == MoneyLineState.done ? Icons.check_circle_rounded : (line.iPay ? Icons.north_east_rounded : Icons.south_west_rounded),
                size: 20,
                color: state == MoneyLineState.done ? palette.success : palette.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state == MoneyLineState.done ? partyLineTitle(line, line.todayPaise) : partyLineTitle(line, line.leftPaise),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: state == MoneyLineState.done ? palette.textSecondary : palette.textPrimary,
                      ),
                    ),
                    if (state != MoneyLineState.done && line.earlierPaise > 0)
                      Text('Includes ${_rupees(line.earlierPaise)} from earlier days', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                    if (note != null)
                      Text(
                        note,
                        style: TextStyle(
                          color: state == MoneyLineState.done ? palette.success : palette.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    for (final t in mine)
                      Text(
                        'You recorded ${_rupees(t.amountPaise)} — waiting for your Manager to confirm.',
                        style: TextStyle(color: palette.warning, fontSize: 12.5),
                      ),
                    if (line.disputed.isNotEmpty)
                      Text(
                        'A payment here was disputed. Your Manager will sort it out.',
                        style: TextStyle(color: palette.error, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ],
          ),
          for (final t in toAnswer)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${line.iPay ? 'Your Manager says they received' : 'Your Manager says they paid you'} ${_rupees(t.amountPaise)}'
                    '${t.method == 'upi' ? ' by UPI ${t.reference ?? ''}' : ' in cash'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(key: ValueKey('reject:${t.id}'), onPressed: () => onAnswer(t, false), child: const Text('Something’s wrong')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(key: ValueKey('confirm:${t.id}'), onPressed: () => onAnswer(t, true), child: Text(yes)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
