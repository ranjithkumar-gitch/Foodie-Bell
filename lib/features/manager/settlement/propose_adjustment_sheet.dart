import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/order_actions.dart';
import '../../../data/providers/settlement_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';

/// What a proposal starts from: the parties and amount the statement
/// suggests (all editable before sending).
typedef AdjustmentDraft = ({PartyKey? from, PartyKey? to, int amountPaise, String? orderId});

/// The proposal a statement discrepancy suggests, or null when an
/// adjustment isn't what resolves it. A COD shortfall is the cash the
/// Driver didn't hand over: the Driver owes it to the Manager — the same
/// proposal the server's own test settles a shortfall with
/// (`integration-tests/lifecycle.test.mjs`), and an approved one with the
/// order's id clears the discrepancy.
AdjustmentDraft? adjustmentDraftFor(Map<String, dynamic> discrepancy, SettlementStatement statement, PartyKey managerKey) {
  if (discrepancy['type'] != 'codShortfall') return null;
  final orderId = discrepancy['orderId'] as String?;
  final driverId = statement.orders.where((o) => o['orderId'] == orderId).map((o) => o['driverId'] as String?).firstOrNull;
  return (
    from: driverId == null ? null : 'driver:$driverId',
    to: managerKey,
    amountPaise: (discrepancy['amountPaise'] as num?)?.toInt() ?? 0,
    orderId: orderId,
  );
}

/// The parties a Manager can name in a proposal for [statement]: everyone
/// with a balance that day, the Manager and Quicky.
List<PartyKey> adjustmentParties(SettlementStatement statement, PartyKey managerKey) => {
  managerKey,
  'quicky',
  for (final p in statement.remainingBalances.keys)
    if (!p.startsWith('user:')) p,
  for (final o in statement.orders) ...[
    if (o['vendorId'] != null) 'vendor:${o['vendorId']}',
    if (o['driverId'] != null) 'driver:${o['driverId']}',
  ],
}.toList();

/// Manager: proposes a settlement adjustment for the Super Admin to decide
/// (`proposeSettlementAdjustment`). Nothing is written to the ledger from
/// here — an approved adjustment is posted by the server. Shows each
/// party's balance from the server's statement. One idempotency key per
/// sheet, so retrying after a timeout returns the first proposal instead of
/// filing a second one.
class ProposeAdjustmentSheet extends StatefulWidget {
  const ProposeAdjustmentSheet({
    super.key,
    required this.statement,
    required this.territoryId,
    required this.managerKey,
    required this.partyName,
    this.draft,
    this.propose = proposeSettlementAdjustment,
  });

  final SettlementStatement statement;
  final String territoryId;
  final PartyKey managerKey;
  final String Function(PartyKey) partyName;
  final AdjustmentDraft? draft;

  /// The `proposeSettlementAdjustment` call; replaceable in tests.
  final Future<({String adjustmentId, bool duplicate})> Function({
    required String territoryId,
    required String day,
    required String fromParty,
    required String toParty,
    required int amountPaise,
    required String reason,
    String? orderId,
    String? idempotencyKey,
  }) propose;

  @override
  State<ProposeAdjustmentSheet> createState() => _ProposeAdjustmentSheetState();
}

class _ProposeAdjustmentSheetState extends State<ProposeAdjustmentSheet> {
  final String _idempotencyKey = List.generate(20, (_) => Random.secure().nextInt(36).toRadixString(36)).join();
  late PartyKey? _from = widget.draft?.from;
  late PartyKey? _to = widget.draft?.to;
  late final _amount = TextEditingController(
    text: (widget.draft?.amountPaise ?? 0) > 0 ? (widget.draft!.amountPaise / 100).toStringAsFixed(2) : '',
  );
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  String _balance(PartyKey? party) {
    if (party == null) return '';
    final v = widget.statement.remainingBalances[party] ?? 0;
    if (v == 0) return 'settled for this day';
    return v > 0 ? 'owes ${_rupees(v)}' : 'is owed ${_rupees(-v)}';
  }

  Future<void> _submit() async {
    final rupees = double.tryParse(_amount.text.trim());
    final reason = _reason.text.trim();
    final error = _from == null || _to == null
        ? 'Choose who pays and who receives.'
        : _from == _to
        ? 'Choose two different parties.'
        : rupees == null || rupees <= 0
        ? 'Enter an amount above ₹0.'
        : reason.isEmpty
        ? 'Say what happened (the Super Admin reads this).'
        : null;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.propose(
        territoryId: widget.territoryId,
        day: widget.statement.day,
        fromParty: _from!,
        toParty: _to!,
        amountPaise: (rupees! * 100).round(),
        reason: reason,
        orderId: widget.draft?.orderId,
        idempotencyKey: _idempotencyKey,
      );
      if (mounted) Navigator.pop(context, result.duplicate ? 'This adjustment was already proposed.' : 'Proposed. Nothing changes until the Super Admin approves it.');
    } catch (e, st) {
      if (mounted) setState(() => _error = e is OrderActionException ? e.message : friendlyError(e, action: 'Proposing adjustment', stackTrace: st));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final parties = adjustmentParties(widget.statement, widget.managerKey);
    DropdownButtonFormField<PartyKey> picker(String label, PartyKey? value, ValueChanged<PartyKey?> onChanged) => DropdownButtonFormField<PartyKey>(
      initialValue: parties.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, helperText: _balance(value)),
      items: [for (final p in parties) DropdownMenuItem(value: p, child: Text(widget.partyName(p), overflow: TextOverflow.ellipsis))],
      onChanged: _busy ? null : onChanged,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Propose an adjustment', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Settlement day ${widget.statement.day}${widget.draft?.orderId == null ? '' : ' · order ${widget.draft!.orderId}'}. '
              'The Super Admin approves or rejects it; balances change only after approval.',
              style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            picker('Who pays', _from, (v) => setState(() => _from = v)),
            const SizedBox(height: 8),
            picker('Who receives', _to, (v) => setState(() => _to = v)),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ '),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reason,
              enabled: !_busy,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Reason (required)', hintText: 'e.g. Driver gave ₹5 less change'),
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _submit,
                child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send to Super Admin'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _rupees(int paise) => AppFormat.currency(paise / 100);
