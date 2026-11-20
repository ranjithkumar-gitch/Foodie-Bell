import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/order_actions.dart';
import '../../../data/providers/settlement_provider.dart';
import '../../../shared/widgets/currency_text.dart';
import 'settlement_payment_sheet.dart';
import '../../../shared/widgets/busy_overlay.dart';

String _rupees(int paise) => AppFormat.currency(paise / 100);

/// `recordSettlementTransfer`'s shape — injectable for widget tests.
typedef RecordSettlementTransfer = Future<void> Function({
  required String idempotencyKey,
  required String territoryId,
  required String day,
  required String fromParty,
  required String toParty,
  required int amountPaise,
  required bool upi,
  String? reference,
  String? purpose,
});

/// Asks for a payment's amount, method and reference; null if dismissed.
typedef PickSettlementPayment = Future<SettlementPaymentInput?> Function(BuildContext context, String title, int suggestedPaise);

Future<SettlementPaymentInput?> _showPaymentSheet(BuildContext context, String title, int suggestedPaise) => showModalBottomSheet<SettlementPaymentInput>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SettlementPaymentSheet(title: title, suggestedPaise: suggestedPaise),
);

/// Daily settlement: shop-cancellation money (Phase I.4), kept apart from
/// commission, delivery earnings, platform fees and refunds. Every figure
/// is the server's statement (`cancellationFinance`, `obligations`); this
/// widget computes no amount.
///
/// Each obligation the Manager is a party to can be settled here with a
/// payment tagged with that obligation's purpose — the shop's charge paid
/// to the Manager, the driver's compensation paid by the Manager, Quicky's
/// share remitted by the Manager. Like every settlement payment it counts
/// only once the other side acknowledges it. Charges Quicky collects
/// directly (no active Manager) are shown but not recordable here.
///
/// One idempotency key per obligation, kept until a payment against it is
/// recorded: a retry after a timeout returns the first transfer instead of
/// recording a second.
class CancellationSettlementSection extends StatefulWidget {
  const CancellationSettlementSection({
    super.key,
    required this.statement,
    required this.territoryId,
    required this.managerKey,
    required this.partyName,
    required this.onRecorded,
    this.record = recordSettlementTransfer,
    this.pickPayment = _showPaymentSheet,
  });

  final SettlementStatement statement;
  final String territoryId;
  final PartyKey managerKey;
  final String Function(PartyKey) partyName;

  /// Called after a payment was recorded (the screen reloads the statement).
  final Future<void> Function() onRecorded;
  final RecordSettlementTransfer record;
  final PickSettlementPayment pickPayment;

  @override
  State<CancellationSettlementSection> createState() => _CancellationSettlementSectionState();
}

class _CancellationSettlementSectionState extends State<CancellationSettlementSection> {
  final _keys = <String, String>{};
  final _busy = <String>{};

  String _newKey() => List.generate(20, (_) => Random.secure().nextInt(36).toRadixString(36)).join();

  /// Recorded on this obligation and awaiting the other side's confirmation
  /// — the server reserves it, so only the rest can be recorded (Phase I.4.2).
  int _pendingOn(SettlementObligation o) => widget.statement.paymentsAwaitingAcknowledgement
      .where((p) => p['from'] == o.from && p['to'] == o.to && (p['purpose'] ?? 'general') == o.purpose)
      .fold(0, (a, p) => a + ((p['amountPaise'] as num?)?.toInt() ?? 0));

  Future<void> _record(SettlementObligation o) async {
    if (_busy.contains(o.id)) return;
    final receiving = o.to == widget.managerKey;
    final title = '${settlementPurposeLabel(o.purpose)} · ${receiving ? 'received from ${widget.partyName(o.from)}' : 'paid to ${widget.partyName(o.to)}'}';
    final input = await widget.pickPayment(context, title, o.outstandingPaise - _pendingOn(o));
    if (input == null || !mounted) return;
    setState(() => _busy.add(o.id));
    final key = _keys.putIfAbsent(o.id, _newKey);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await runBusy(() => widget.record(
        idempotencyKey: key,
        territoryId: widget.territoryId,
        day: widget.statement.day,
        fromParty: o.from,
        toParty: o.to,
        amountPaise: input.amountPaise,
        upi: input.upi,
        reference: input.reference,
        purpose: o.purpose,
      ));
      _keys.remove(o.id);
      messenger.showSnackBar(const SnackBar(content: Text('Settled. They can report a problem within 24 hours.')));
      await widget.onRecorded();
    } on OrderActionException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy.remove(o.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final finance = widget.statement.cancellationFinance;
    final rows = widget.statement.obligations.where((o) => o.isCancellation).toList();
    // A statement built before Phase I.4 has no cancellation figures at all.
    if (finance == null && rows.isEmpty) return const SizedBox.shrink();
    final f = finance ?? const CancellationFinance({});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Shop cancellations', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Charges for orders a shop cancelled after accepting. Settled separately from order money — not commission, delivery fees or refunds.',
          style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 8),
        if (f.isEmpty && rows.isEmpty)
          Text('No cancellation charges this day.', style: TextStyle(color: palette.textMuted))
        else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              _Row('Charged to shops', f.assessedPaise),
              _Row('Collected from shops', f.collectedPaise),
              _Row('Still owed by shops', f.outstandingChargePaise, strong: true),
              const Divider(),
              _Row('Driver compensation', f.driverCompAssessedPaise),
              _Row('Paid to drivers', f.driverCompPaidPaise),
              _Row('Still owed to drivers', f.outstandingDriverCompPaise, strong: true),
              const Divider(),
              _Row('Quicky’s share', f.quickyShareAssessedPaise),
              _Row('Sent to Quicky', f.remittedPaise),
              _Row('Still to send Quicky', f.outstandingRemittancePaise, strong: true),
              if (f.disputedPaise > 0) _Row('Disputed payments', f.disputedPaise, color: palette.error),
              // Charges Quicky approved reversing (Phase I.4.1): the shop's
              // unpaid part is waived, what it paid is refunded; the driver
              // keeps the compensation and Quicky funds it.
              if (f.hasReversals) ...[
                const Divider(),
                _Row('Reversed by Quicky', f.reversedPaise),
                _Row('Waived (was unpaid)', f.waivedPaise),
                _Row('Refund still owed to shops', f.outstandingRefundPaise, strong: true),
                _Row('Refunded to shops', f.refundedPaise),
                _Row('Still to come from Quicky', f.outstandingCompFundingPaise + f.outstandingRemittanceReturnPaise, strong: true),
              ],
            ]),
          ),
          const SizedBox(height: 8),
          for (final o in rows) _obligationTile(context, o),
        ],
      ],
    );
  }

  Widget _obligationTile(BuildContext context, SettlementObligation o) {
    final palette = context.colors;
    // Money with QuickMandi is marked settled by QuickMandi (2026-11-20).
    final withQuicky = o.from == 'quicky' || o.to == 'quicky';
    final mine = (o.from == widget.managerKey || o.to == widget.managerKey) && !withQuicky;
    final receiving = o.to == widget.managerKey;
    final busy = _busy.contains(o.id);
    final pending = _pendingOn(o);
    final recordable = o.outstandingPaise - pending;
    return Card(
      key: ValueKey('obligation:${o.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(settlementPurposeLabel(o.purpose), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${widget.partyName(o.from)} → ${widget.partyName(o.to)}', style: TextStyle(color: palette.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  o.outstandingPaise > 0 ? 'Outstanding ${_rupees(o.outstandingPaise)}' : 'Settled',
                  style: TextStyle(color: o.outstandingPaise > 0 ? palette.warning : palette.success, fontWeight: FontWeight.w600),
                ),
                if (pending > 0) Text('Awaiting confirmation ${_rupees(pending)}', key: ValueKey('pending:${o.id}'), style: TextStyle(color: palette.warning, fontSize: 12.5)),
                if (o.disputedPaise > 0) Text('Disputed ${_rupees(o.disputedPaise)}', style: TextStyle(color: palette.error, fontSize: 12.5)),
                if (!mine) Text('QuickMandi marks this settled.', style: TextStyle(color: palette.textMuted, fontSize: 12.5)),
              ]),
            ),
            if (mine && recordable > 0)
              busy
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(onPressed: () => _record(o), child: Text(receiving ? 'Got paid' : 'Paid')),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.paise, {this.strong = false, this.color});
  final String label;
  final int paise;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600, color: color ?? context.colors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(_rupees(paise), style: style)]),
    );
  }
}
