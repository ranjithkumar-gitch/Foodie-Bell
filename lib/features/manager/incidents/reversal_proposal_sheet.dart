import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/order_actions.dart';
import '../../../data/providers/vendor_incidents_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';

String _rupees(int paise) => AppFormat.currency(paise / 100);

typedef PreviewReversal = Future<ReversalPreview> Function(String orderId);
typedef ProposeReversal = Future<({String adjustmentId, bool duplicate})> Function(String orderId, {required String reason, required String evidence, required String idempotencyKey});

/// Manager: proposes reversing a shop's cancellation charge (Phase I.4.1)
/// for the Super Admin to approve. Shows the server's figures first —
/// confirmed money only — and needs a reason and supporting evidence. One
/// idempotency key per sheet, so a retry files nothing twice. Nothing
/// moves until the Super Admin approves.
class ReversalProposalSheet extends StatefulWidget {
  const ReversalProposalSheet({super.key, required this.incident, this.preview = previewCancellationReversal, this.propose = proposeCancellationReversal});

  final VendorIncident incident;
  final PreviewReversal preview;
  final ProposeReversal propose;

  @override
  State<ReversalProposalSheet> createState() => _ReversalProposalSheetState();
}

class _ReversalProposalSheetState extends State<ReversalProposalSheet> {
  final _key = List.generate(20, (_) => Random.secure().nextInt(36).toRadixString(36)).join();
  final _reason = TextEditingController();
  final _evidence = TextEditingController();
  ReversalPreview? _preview;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    _evidence.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await widget.preview(widget.incident.orderId);
      if (mounted) setState(() => _preview = p);
    } on OrderActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e, st) {
      if (mounted) setState(() => _error = friendlyError(e, action: 'Loading the reversal figures', stackTrace: st));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _ready => !_busy && _preview != null && _preview!.status != 'pending' && _preview!.status != 'approved' && _reason.text.trim().isNotEmpty && _evidence.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await widget.propose(widget.incident.orderId, reason: _reason.text.trim(), evidence: _evidence.text.trim(), idempotencyKey: _key);
      if (mounted) Navigator.pop(context, r.duplicate ? 'This reversal was already sent.' : 'Sent to the Super Admin for approval.');
    } on OrderActionException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _line(String label, int paise, {bool strong = false, Color? color}) {
    final style = TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w600, color: color ?? context.colors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(_rupees(paise), style: style)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final p = _preview?.plan;
    final status = _preview?.status;
    final small = TextStyle(color: palette.textSecondary, fontSize: 12.5);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reverse the cancellation charge', style: Theme.of(context).textTheme.titleLarge),
            Text('Order ${widget.incident.orderId}', style: small),
            const SizedBox(height: 10),
            if (p == null && _busy) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
            if (p != null) ...[
              _line('Original charge', p.chargePaise),
              _line('Confirmed paid by the shop', p.collectedPaise),
              if (p.pendingPaise > 0) _line('Recorded, not yet confirmed (not counted)', p.pendingPaise, color: palette.warning),
              if (p.disputedPaise > 0) _line('Disputed (not counted)', p.disputedPaise, color: palette.error),
              _line('Still unpaid', p.unpaidPaise),
              const Divider(),
              _line('Waived', p.waivedPaise),
              _line('Refund owed to the shop', p.refundPaise, strong: true),
              _line('Driver keeps', p.driverCompPreservedPaise),
              _line('QuickMandi pays for the reversal', p.quickyCostPaise),
              if (p.otherChargesPaise > 0)
                Text('This shop has other cancellation charges with you; its payments count towards those too.', style: small),
              const SizedBox(height: 4),
              Text('You only pass money on: you neither gain nor lose. Nothing moves until the Super Admin approves.', style: small),
              const SizedBox(height: 10),
              if (status == 'pending' || status == 'approved')
                Text(status == 'pending' ? 'A reversal is already waiting for the Super Admin.' : 'This charge has already been reversed.',
                    key: const Key('reversalStatus'), style: TextStyle(color: palette.warning, fontWeight: FontWeight.w700))
              else ...[
                TextField(
                  key: const Key('reversalReason'),
                  controller: _reason,
                  maxLength: 300,
                  enabled: !_busy,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Reason (required)'),
                ),
                TextField(
                  key: const Key('reversalEvidence'),
                  controller: _evidence,
                  maxLength: 1000,
                  minLines: 2,
                  maxLines: 4,
                  enabled: !_busy,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Supporting evidence (required)', hintText: 'What shows it wasn’t the shop’s fault — a ticket, a photo, a note'),
                ),
              ],
            ],
            if (_error != null) ...[const SizedBox(height: 6), Text(_error!, style: TextStyle(color: palette.error))],
            const SizedBox(height: 12),
            if (p != null && status != 'pending' && status != 'approved')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('submitReversal'),
                  onPressed: _ready ? _submit : null,
                  child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send for approval'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
