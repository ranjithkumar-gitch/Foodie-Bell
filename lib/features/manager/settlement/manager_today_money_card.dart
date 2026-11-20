import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/settlement_provider.dart';
import '../../../shared/settlement/daily_money.dart';
import '../../../shared/settlement/settlement_report.dart';
import '../../../shared/widgets/currency_text.dart';

String _rupees(int paise) => AppFormat.currency(paise / 100);

String _orders(int n) => n == 1 ? '1 order' : '$n orders';

/// An overpaid line, in words (2026-11-20).
String overpaidText(ManagerMoneyLine l, String name) => l.collect
    ? 'Received ${_rupees(l.overpaidPaise)} too much — you owe it back to $name'
    : l.party == 'quicky'
    ? 'Paid ${_rupees(l.overpaidPaise)} too much — QuickMandi owes you (ask QuickMandi to undo the extra payment)'
    : 'Paid ${_rupees(l.overpaidPaise)} too much — $name owes you';

/// What a Manager line is, in words: "₹350 COD cash · 2 orders".
String managerLineText(ManagerMoneyLine l, int amountPaise) {
  final amount = _rupees(amountPaise);
  final what = switch (l.kind) {
    MoneyLineKind.codCash => l.dayFeePaise > 0 ? '$amount COD cash + day fee (${_rupees(l.dayFeePaise)})' : '$amount COD cash',
    MoneyLineKind.deliveryFees => '$amount delivery fees',
    MoneyLineKind.shopPayout => '$amount for COD orders',
    MoneyLineKind.shopUpiDues => '$amount commission + delivery (UPI orders)',
    MoneyLineKind.quicky => '$amount Quicky’s share (commission, platform & day fees)',
    MoneyLineKind.other => '$amount order money',
  };
  final parts = [
    what,
    if (l.orders > 0 && l.kind != MoneyLineKind.quicky) _orders(l.orders),
    if (l.openingPaise > 0) 'incl. ${_rupees(l.openingPaise)} from earlier days',
  ];
  return parts.join(' · ');
}

/// The top of the Manager's daily settlement: one line per person and
/// direction, one button each, amounts filled in from the server's
/// statement. Collect (Drivers' COD cash, shops' UPI dues) and Pay
/// (Drivers' delivery fees, shops' COD payouts, QuickMandi). Since
/// 2026-11-20 the Manager's "Received" / "Paid" marks it settled at once;
/// the other side has 24 hours to report a problem. Money with QuickMandi
/// is marked settled by QuickMandi, and the Manager can report it.
class ManagerTodayMoneyCard extends StatelessWidget {
  const ManagerTodayMoneyCard({
    super.key,
    required this.statement,
    required this.managerKey,
    required this.transfers,
    required this.partyName,
    required this.onRecord,
    required this.onAnswer,
    this.readOnly = false,
  });

  /// A past (closed) day: lines show, nothing can be marked settled.
  final bool readOnly;

  final SettlementStatement statement;
  final PartyKey managerKey;

  /// The Manager's live settlement payments.
  final List<SettlementTransfer> transfers;
  final String Function(PartyKey) partyName;

  /// Record a payment for [line] (Received / Paid), pre-filled with [amountPaise].
  final void Function(ManagerMoneyLine line, int amountPaise) onRecord;

  /// Confirm or reject a payment the other side recorded.
  final void Function(SettlementTransfer transfer, bool confirm) onAnswer;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final lines = managerMoneyLines(statement, managerKey, transfers: transfers);
    final known = statementPaymentIds(statement);
    final done = lines.where((l) => l.state(known) == MoneyLineState.done && !l.isOverpaid).length;
    final overpaid = lines.where((l) => l.isOverpaid).toList();
    final waiting = lines.where((l) => l.state(known) == MoneyLineState.waiting).length;
    final collect = lines.where((l) => l.collect).toList();
    final pay = lines.where((l) => !l.collect).toList();
    final settled = statement.status == SettlementStatus.completed;

    return Container(
      key: const Key('todayMoneyCard'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: settled ? palette.success : palette.border, width: settled ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Today’s money', style: Theme.of(context).textTheme.titleLarge)),
              if (settled)
                Text(
                  'Day settled ✓',
                  key: const Key('daySettled'),
                  style: TextStyle(color: palette.success, fontWeight: FontWeight.w800),
                )
              else if (lines.isNotEmpty)
                Text(
                  '$done of ${lines.length} done',
                  key: const Key('dayProgress'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
            ],
          ),
          if (lines.isEmpty) ...[
            const SizedBox(height: 8),
            Text(settled ? 'Nothing to settle for this day.' : 'No order money for this day yet.', style: TextStyle(color: palette.textSecondary)),
          ],
          if (collect.isNotEmpty) ...[
            const SizedBox(height: 12),
            _GroupTitle('COLLECT', palette.textSecondary),
            for (final l in collect)
              _LineTile(line: l, known: known, managerKey: managerKey, partyName: partyName, onRecord: onRecord, onAnswer: onAnswer, readOnly: readOnly),
          ],
          if (pay.isNotEmpty) ...[
            const SizedBox(height: 12),
            _GroupTitle('PAY', palette.textSecondary),
            for (final l in pay)
              _LineTile(line: l, known: known, managerKey: managerKey, partyName: partyName, onRecord: onRecord, onAnswer: onAnswer, readOnly: readOnly),
          ],
          if (waiting > 0) ...[
            const SizedBox(height: 10),
            Text(
              'Waiting for the other side to confirm: $waiting',
              key: const Key('waitingCount'),
              style: TextStyle(color: palette.warning, fontWeight: FontWeight.w700),
            ),
          ],
          if (overpaid.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Paid more than was owed on ${overpaid.length == 1 ? '1 line' : '${overpaid.length} lines'} — the day settles once that is put right.',
              key: const Key('overpaidNote'),
              style: TextStyle(color: palette.warning, fontWeight: FontWeight.w700, fontSize: 12.5),
            ),
          ],
          if (!settled && lines.isNotEmpty && done == lines.length) ...[
            const SizedBox(height: 10),
            Text(
              'Order money is done. Anything still open is below (cancellations, refunds or problems).',
              style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// The theme's buttons are full width (56 high); these sit in a row.
final _compact = ElevatedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16));

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.1),
  );
}

class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.line,
    required this.known,
    required this.managerKey,
    required this.partyName,
    required this.onRecord,
    required this.onAnswer,
    this.readOnly = false,
  });
  final bool readOnly;
  final ManagerMoneyLine line;
  final Set<String> known;
  final PartyKey managerKey;
  final String Function(PartyKey) partyName;
  final void Function(ManagerMoneyLine line, int amountPaise) onRecord;
  final void Function(SettlementTransfer transfer, bool confirm) onAnswer;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final state = line.state(known);
    final toRecord = line.toRecordPaise(known);
    final name = partyName(line.party);
    final theirs = [
      for (final t in line.pending)
        if (t.counterparty == managerKey) t,
    ];
    final mine = [
      for (final t in line.pending)
        if (t.counterparty != managerKey) t,
    ];
    final key = '${line.collect ? 'collect' : 'pay'}:${line.party}';
    final withQuicky = line.party == 'quicky';
    // Settled payments still open to a report, or with a report going.
    final settled = [
      for (final t in line.transfers)
        if (t.status == 'voided' || (t.status == 'confirmed' && (t.report != null || (t.reportUntil != null && DateTime.now().isBefore(t.reportUntil!))))) t,
    ];

    return Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                line.isOverpaid
                    ? Icons.error_outline_rounded
                    : switch (state) {
                        MoneyLineState.done => Icons.check_circle_rounded,
                        MoneyLineState.waiting => Icons.hourglass_top_rounded,
                        MoneyLineState.open => Icons.radio_button_unchecked_rounded,
                      },
                size: 20,
                color: line.isOverpaid
                    ? palette.warning
                    : switch (state) {
                        MoneyLineState.done => palette.success,
                        MoneyLineState.waiting => palette.warning,
                        MoneyLineState.open => palette.textMuted,
                      },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      line.isOverpaid
                          ? overpaidText(line, name)
                          : state == MoneyLineState.done
                          ? (line.settledTogether ? 'Settled together with their other line ✓' : 'Done ✓')
                          : managerLineText(line, state == MoneyLineState.open ? toRecord : line.outstandingPaise),
                      style: TextStyle(color: palette.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (state == MoneyLineState.open && !withQuicky && !readOnly)
                ElevatedButton(
                  key: ValueKey('record:$key'),
                  style: _compact,
                  onPressed: () => onRecord(line, toRecord),
                  child: Text(line.collect ? 'Received' : 'Paid'),
                ),
            ],
          ),
          if (withQuicky && state == MoneyLineState.open && !readOnly)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: Text('QuickMandi marks this settled when it gets the money.', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
            ),
          for (final t in settled)
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: SettledPaymentNote(
                transfer: t,
                me: managerKey,
                text:
                    '${t.recordedBy == managerKey ? 'You marked' : 'QuickMandi marked'} ${_rupees(t.amountPaise)} settled'
                    '${t.method == 'upi' ? ' (UPI)' : ' (cash)'}',
              ),
            ),
          for (final t in mine)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: Text(
                'You recorded ${_rupees(t.amountPaise)} — waiting for them to confirm',
                style: TextStyle(color: palette.warning, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          for (final t in theirs)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${line.collect ? 'They say they paid you' : 'They say you paid them'} ${_rupees(t.amountPaise)}'
                    '${t.method == 'upi' ? ' by UPI ${t.reference ?? ''}' : ' in cash'}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  Row(
                    children: [
                      TextButton(key: ValueKey('reject:${t.id}'), onPressed: () => onAnswer(t, false), child: const Text('Something’s wrong')),
                      const SizedBox(width: 6),
                      ElevatedButton(key: ValueKey('confirm:${t.id}'), style: _compact, onPressed: () => onAnswer(t, true), child: const Text('Yes, correct')),
                    ],
                  ),
                ],
              ),
            ),
          if (line.disputed.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 2),
              child: Text(
                'A payment here was disputed — see “Problems to sort out”.',
                style: TextStyle(color: palette.error, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
