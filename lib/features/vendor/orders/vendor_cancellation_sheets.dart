import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/order_actions.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/cancellation_reasons.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';
import '../vendor_session.dart';
import 'vendor_order_actions.dart';

String _percent(int bps) => bps % 100 == 0 ? '${bps ~/ 100}' : (bps / 100).toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '');
String _rupees(int paise) => AppFormat.currency(paise / 100);

/// Accept: after the usual shop set-up checks, the vendor confirms they have
/// every item (`availabilityConfirmed`) before the order is accepted.
Future<void> confirmAvailabilityAndAccept(BuildContext context, WidgetRef ref, Order order) async {
  if (!await ensureVendorReadyToAccept(context, ref)) return;
  if (!context.mounted) return;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AvailabilityConfirmSheet(order: order),
  );
  if (confirmed != true || !context.mounted) return;
  await runVendorAction(context, () => vendorAcceptOrder(order.id, availabilityConfirmed: true));
}

/// Reject before accepting, with a structured reason (never charged).
Future<void> rejectWithReason(BuildContext context, Order order) async {
  final picked = await showModalBottomSheet<({String reasonCode, String? remark})>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const RejectReasonSheet(),
  );
  if (picked == null || !context.mounted) return;
  await runVendorAction(context, () => vendorRejectOrder(order.id, reasonCode: picked.reasonCode, remark: picked.remark));
}

/// Lists the order's items; "Accept" only once the vendor ticks that they
/// have all of them. Pops true to accept.
class AvailabilityConfirmSheet extends StatefulWidget {
  const AvailabilityConfirmSheet({super.key, required this.order});
  final Order order;

  @override
  State<AvailabilityConfirmSheet> createState() => _AvailabilityConfirmSheetState();
}

class _AvailabilityConfirmSheetState extends State<AvailabilityConfirmSheet> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.vendorAcceptConfirmTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final item in widget.order.items)
              Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('${item.quantity} × ${item.name}', style: const TextStyle(fontSize: 15))),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v ?? false),
              title: Text(l10n.vendorAcceptConfirmCheckbox),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: _confirmed ? () => Navigator.pop(context, true) : null, child: Text(l10n.vendorAcceptButton)),
            ),
          ],
        ),
      ),
    );
  }
}

/// A pre-acceptance reason (+ remark, required for "other"). Pops the choice.
class RejectReasonSheet extends StatefulWidget {
  const RejectReasonSheet({super.key});

  @override
  State<RejectReasonSheet> createState() => _RejectReasonSheetState();
}

class _RejectReasonSheetState extends State<RejectReasonSheet> {
  String? _reason;
  final _remark = TextEditingController();

  @override
  void dispose() {
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.colors;
    final needsRemark = _reason == 'other';
    final ready = _reason != null && (!needsRemark || _remark.text.trim().isNotEmpty);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.vendorRejectTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(l10n.vendorRejectNote, style: TextStyle(color: palette.textSecondary)),
              RadioGroup<String>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                child: Column(children: [for (final r in preAcceptanceReasons) RadioListTile<String>(value: r, contentPadding: EdgeInsets.zero, title: Text(reasonLabel(l10n, r)))]),
              ),
              TextField(
                controller: _remark,
                maxLength: 500,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: needsRemark ? l10n.remarkRequired : l10n.remarkOptional),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: ready ? () => Navigator.pop(context, (reasonCode: _reason!, remark: _remark.text.trim().isEmpty ? null : _remark.text.trim())) : null,
                  child: Text(l10n.vendorRejectButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cancels an order the vendor accepted (before pickup). Shows the server's
/// authoritative charge first; on confirmation sends exactly what was shown,
/// and if the server says the charge changed (a driver claimed or was
/// released meanwhile) shows the new quote and asks again. One idempotency
/// key per sheet. Nothing is computed on the phone.
class VendorCancelOrderSheet extends StatefulWidget {
  const VendorCancelOrderSheet({super.key, required this.order, this.quote = quoteVendorCancellation, this.cancel = vendorCancelOrder});

  final Order order;

  /// The `quoteVendorCancellation` / `vendorCancelOrder` calls; replaceable in tests.
  final Future<VendorCancellationQuote> Function(String orderId) quote;
  final Future<void> Function(String orderId, {required VendorCancellationQuote quote, required String reasonCode, required String remark, required String idempotencyKey}) cancel;

  @override
  State<VendorCancelOrderSheet> createState() => _VendorCancelOrderSheetState();
}

class _VendorCancelOrderSheetState extends State<VendorCancelOrderSheet> {
  final String _idempotencyKey = List.generate(24, (_) => Random.secure().nextInt(36).toRadixString(36)).join();
  final _remark = TextEditingController();
  VendorCancellationQuote? _quote;
  String? _reason;
  String? _error;
  String? _notice;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remark.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final q = await widget.quote(widget.order.id);
      if (mounted) setState(() => _quote = q);
    } catch (e, st) {
      if (mounted) setState(() => _error = e is OrderActionException ? e.message : friendlyError(e, action: 'Getting the cancellation charge', stackTrace: st));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final quote = _quote;
    if (quote == null) return;
    if (_reason == null) {
      setState(() => _error = l10n.chooseReason);
      return;
    }
    if (_remark.text.trim().length < cancelRemarkMin) {
      setState(() => _error = l10n.vendorCancelRemarkTooShort);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.cancel(widget.order.id, quote: quote, reasonCode: _reason!, remark: _remark.text.trim(), idempotencyKey: _idempotencyKey);
      if (mounted) Navigator.pop(context, true);
    } on OrderActionException catch (e) {
      final changed = changedQuoteOf(e);
      if (!mounted) return;
      setState(() {
        if (changed != null) {
          _quote = changed;
          _notice = l10n.vendorCancelChargeChanged;
        } else {
          _error = e.message;
        }
      });
    } catch (e, st) {
      if (mounted) setState(() => _error = friendlyError(e, action: 'Cancelling the order', stackTrace: st));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.colors;
    final q = _quote;
    final blocked = q != null && !q.upiCancellationAllowed;
    final chargeText = q == null
        ? null
        : q.chargePaise == 0
        ? l10n.vendorCancelNoCharge
        : q.scenario == 'B'
        ? l10n.vendorCancelChargeWithDriver(_rupees(q.chargePaise), _percent(q.bps), _rupees(q.deliveryFeePaise ?? 0), _rupees(q.driverSharePaise))
        : l10n.vendorCancelChargeNoDriver(_rupees(q.chargePaise), _percent(q.bps), _rupees(q.deliveryFeePaise ?? 0));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.vendorCancelTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(l10n.vendorCancelWarning, style: TextStyle(color: palette.warning, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              if (q == null && _busy) const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              if (_notice != null) ...[
                Text(_notice!, style: TextStyle(color: palette.warning, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
              ],
              if (chargeText != null) Text(chargeText, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (q != null && q.refundDuePaise != null) ...[
                const SizedBox(height: 6),
                Text(l10n.vendorCancelRefundOwed(_rupees(q.refundDuePaise!)), style: TextStyle(color: palette.textSecondary)),
              ],
              if (blocked) ...[
                const SizedBox(height: 10),
                Text(l10n.vendorCancelUpiBlocked, style: TextStyle(color: palette.error, fontWeight: FontWeight.w700)),
              ] else if (q != null) ...[
                RadioGroup<String>(
                  groupValue: _reason,
                  onChanged: (v) => setState(() => _reason = v),
                  child: Column(children: [for (final r in postAcceptanceReasons) RadioListTile<String>(value: r, contentPadding: EdgeInsets.zero, title: Text(reasonLabel(l10n, r)))]),
                ),
                TextField(controller: _remark, maxLength: 500, minLines: 2, maxLines: 4, enabled: !_busy, decoration: InputDecoration(labelText: l10n.remarkRequired, hintText: l10n.vendorCancelRemarkHint)),
              ],
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 10),
              if (q != null && !blocked)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: palette.error, foregroundColor: Colors.white),
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(q.chargePaise == 0 ? l10n.vendorCancelConfirmNoCharge : l10n.vendorCancelConfirm),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens [VendorCancelOrderSheet]; shows a confirmation when it's done.
Future<void> showVendorCancelOrderSheet(BuildContext context, Order order) async {
  final done = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => VendorCancelOrderSheet(order: order));
  if (done == true && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.vendorCancelDone)));
}
