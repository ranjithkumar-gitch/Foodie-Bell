import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/refund_case.dart';
import '../../data/providers/refunds_provider.dart';
import '../../l10n/app_localizations_context.dart';

/// Customer UPI refunds (Phase I.7): the cards on the customer's and the
/// shop's order screens. Every action goes through the server
/// ([RefundActions]); a recorded refund is only "Refund initiated — awaiting
/// confirmation" until the customer confirms it.

/// The status in the customer's language.
String customerRefundStatusLabel(BuildContext context, RefundStatus s) {
  final l = context.l10n;
  return switch (s) {
    RefundStatus.refundDue => l.refundStatusDue,
    RefundStatus.awaitingCustomerConfirmation => l.refundStatusAwaiting,
    RefundStatus.refundDisputed => l.refundStatusDisputed,
    RefundStatus.refundReviewRequired => l.refundStatusReview,
    RefundStatus.refunded => l.refundStatusConfirmed,
    RefundStatus.unknown => l.refundCardTitle,
  };
}

Color refundStatusColor(AppPalette palette, RefundStatus s) => switch (s) {
  RefundStatus.refunded => palette.success,
  RefundStatus.refundDisputed || RefundStatus.refundReviewRequired => palette.error,
  _ => palette.warning,
};

class RefundStatusChip extends StatelessWidget {
  const RefundStatusChip({super.key, required this.status, this.label});
  final RefundStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = refundStatusColor(context.colors, status);
    return Container(
      key: Key('refundStatus_${status.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label ?? status.label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

Widget _card(BuildContext context, List<Widget> children) {
  final palette = context.colors;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(context.l10n.refundLoadError)),
      TextButton(onPressed: onRetry, child: Text(context.l10n.refundRetry)),
    ],
  );
}

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));

String _rupeesInput(int paise) => (paise / 100).toStringAsFixed(2);
int? _paiseFrom(String text) {
  final v = double.tryParse(text.trim());
  return v == null || v < 0 ? null : (v * 100).round();
}

// ---- Customer ------------------------------------------------------------------------

/// The customer's refund on their order screen: what's owed, the shop's
/// recorded refund (with its UPI reference) and the answer we need — or
/// nothing when no refund is owed.
class CustomerRefundCard extends ConsumerStatefulWidget {
  const CustomerRefundCard({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<CustomerRefundCard> createState() => _CustomerRefundCardState();
}

class _CustomerRefundCardState extends ConsumerState<CustomerRefundCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _toast(context, context.l10n.refundThanks);
    } catch (e) {
      if (mounted) _toast(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respond(RefundCase k, String response) async {
    final actions = ref.read(refundActionsProvider);
    final attempt = k.activeAttempt!;
    if (response == 'received') {
      await _run(() => actions.respond(orderId: k.orderId, transferId: attempt.transferId, response: 'received'));
      return;
    }
    final result = await showDialog<({int? amountPaise, String note})>(
      context: context,
      builder: (_) => _CustomerAnswerDialog(differentAmount: response == 'differentAmount'),
    );
    if (result == null) return;
    await _run(() => actions.respond(
      orderId: k.orderId,
      transferId: attempt.transferId,
      response: response,
      receivedAmountPaise: result.amountPaise,
      note: result.note.isEmpty ? null : result.note,
    ));
  }

  Future<void> _changeUpi(RefundCase k) async {
    final upi = await showDialog<String>(context: context, builder: (_) => _UpiIdDialog(initial: k.destinationUpiId));
    if (upi == null || upi.isEmpty) return;
    await _run(() => ref.read(refundActionsProvider).setDestination(orderId: k.orderId, upiId: upi));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final palette = context.colors;
    final async = ref.watch(refundCaseProvider(widget.orderId));
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator())),
      error: (_, _) => _card(context, [_LoadError(onRetry: () => ref.invalidate(refundCaseProvider(widget.orderId)))]),
      data: (k) {
        if (k == null) return const SizedBox.shrink();
        final attempt = k.activeAttempt;
        return _card(context, [
          Row(children: [
            Expanded(child: Text(l.refundCardTitle, style: Theme.of(context).textTheme.titleMedium)),
            RefundStatusChip(status: k.status, label: customerRefundStatusLabel(context, k.status)),
          ]),
          const SizedBox(height: 8),
          if (k.owedPaise != null && k.status != RefundStatus.refunded)
            Text(l.refundOwedToYou(rupeesOf(k.outstandingPaise ?? k.owedPaise!)), key: const Key('refundOwed'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          if (k.vendorName != null) Text(l.refundFromShop(k.vendorName!), style: TextStyle(color: palette.textSecondary)),
          if (k.refundedPaise > 0 && k.status != RefundStatus.refunded) Text(l.refundReturnedSoFar(rupeesOf(k.refundedPaise))),
          const SizedBox(height: 8),
          switch (k.status) {
            RefundStatus.refunded => Text(l.refundConfirmedNote(rupeesOf(k.refundedPaise)), key: const Key('refundConfirmedNote'), style: TextStyle(color: palette.success, fontWeight: FontWeight.w700)),
            RefundStatus.refundDisputed => Text(l.refundDisputedNote),
            RefundStatus.refundReviewRequired when attempt == null => Text(l.refundReviewNote),
            _ when attempt == null => Text(l.refundWaitingShop),
            _ => const SizedBox.shrink(),
          },
          if (attempt != null && k.status != RefundStatus.refunded) ...[
            Text(
              l.refundSentClaim(attempt.byQuicky ? l.refundPayerQuicky : l.refundPayerShop, rupeesOf(attempt.amountPaise), attempt.paidOn ?? '—', attempt.reference ?? '—'),
              key: const Key('refundClaim'),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(key: const Key('refundReceived'), onPressed: _busy ? null : () => _respond(k, 'received'), child: Text(l.refundReceived)),
              OutlinedButton(key: const Key('refundNotReceived'), onPressed: _busy ? null : () => _respond(k, 'notReceived'), child: Text(l.refundNotReceived)),
              OutlinedButton(key: const Key('refundDifferentAmount'), onPressed: _busy ? null : () => _respond(k, 'differentAmount'), child: Text(l.refundDifferentAmount)),
            ]),
          ],
          if (k.status != RefundStatus.refunded) ...[
            const SizedBox(height: 10),
            Text(k.destinationUpiId == null ? l.refundToOriginal : l.refundToUpi(k.destinationUpiId!), style: TextStyle(color: palette.textSecondary, fontSize: 13)),
            if (attempt == null)
              TextButton(key: const Key('refundChangeUpi'), onPressed: _busy ? null : () => _changeUpi(k), child: Text(l.refundChangeUpi)),
          ],
        ]);
      },
    );
  }
}

class _CustomerAnswerDialog extends StatefulWidget {
  const _CustomerAnswerDialog({required this.differentAmount});
  final bool differentAmount;

  @override
  State<_CustomerAnswerDialog> createState() => _CustomerAnswerDialogState();
}

class _CustomerAnswerDialogState extends State<_CustomerAnswerDialog> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final amount = _paiseFrom(_amount.text);
    final ok = !widget.differentAmount || amount != null;
    return AlertDialog(
      title: Text(widget.differentAmount ? l.refundDifferentAmountTitle : l.refundNotReceivedTitle),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!widget.differentAmount) Text(l.refundNotReceivedBody),
        if (widget.differentAmount)
          TextField(
            key: const Key('refundReceivedAmount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(labelText: l.refundAmountReceivedLabel),
            onChanged: (_) => setState(() {}),
          ),
        TextField(key: const Key('refundAnswerNote'), controller: _note, maxLength: 300, decoration: InputDecoration(labelText: l.refundNoteLabel)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.refundCancel)),
        FilledButton(
          key: const Key('refundAnswerSubmit'),
          onPressed: ok ? () => Navigator.pop(context, (amountPaise: widget.differentAmount ? amount : null, note: _note.text.trim())) : null,
          child: Text(l.refundSubmit),
        ),
      ],
    );
  }
}

class _UpiIdDialog extends StatefulWidget {
  const _UpiIdDialog({this.initial});
  final String? initial;

  @override
  State<_UpiIdDialog> createState() => _UpiIdDialogState();
}

class _UpiIdDialogState extends State<_UpiIdDialog> {
  late final _upi = TextEditingController(text: widget.initial ?? '');
  static final _pattern = RegExp(r'^[A-Za-z0-9._-]{2,256}@[A-Za-z][A-Za-z0-9.-]{1,63}$');

  @override
  void dispose() {
    _upi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final valid = _pattern.hasMatch(_upi.text.trim());
    return AlertDialog(
      title: Text(l.refundUpiDialogTitle),
      content: TextField(key: const Key('refundUpiId'), controller: _upi, decoration: InputDecoration(hintText: l.refundUpiHint), onChanged: (_) => setState(() {})),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.refundCancel)),
        FilledButton(key: const Key('refundUpiSave'), onPressed: valid ? () => Navigator.pop(context, _upi.text.trim()) : null, child: Text(l.refundSave)),
      ],
    );
  }
}

// ---- Shop ---------------------------------------------------------------------------------

/// The refund the shop owes on its order screen: how much, where to send it,
/// "Record refund", and what's happened since.
class VendorRefundCard extends ConsumerWidget {
  const VendorRefundCard({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final async = ref.watch(refundCaseProvider(orderId));
    return async.when(
      loading: () => const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator())),
      error: (_, _) => _card(context, [_LoadError(onRetry: () => ref.invalidate(refundCaseProvider(orderId)))]),
      data: (k) {
        if (k == null) return const SizedBox.shrink();
        final attempt = k.activeAttempt;
        final dispute = k.openDispute;
        return _card(context, [
          Row(children: [
            Expanded(child: Text('Customer refund', style: Theme.of(context).textTheme.titleMedium)),
            RefundStatusChip(status: k.status),
          ]),
          const SizedBox(height: 8),
          if (k.owedPaise == null)
            const Text('Quicky is checking the amount for this older order before a refund can be recorded.')
          else ...[
            Text('Refund owed to the customer: ${rupeesOf(k.owedPaise!)}', key: const Key('vendorRefundOwed'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('Items, delivery fee and platform fee — everything the customer paid you.', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
            if (k.refundedPaise > 0) Text('Confirmed so far: ${rupeesOf(k.refundedPaise)} · Still owed: ${rupeesOf(k.outstandingPaise ?? 0)}'),
          ],
          if (k.ageHours() != null && !k.status.isDone) ...[
            const SizedBox(height: 6),
            Text(
              'Owed for ${ageLabel(k.ageHours()!)} (since ${istLabel(k.dueAt!)})${k.escalationLabel.isEmpty ? '' : ' · ${k.escalationLabel}'}',
              key: const Key('vendorRefundAge'),
              style: TextStyle(color: k.escalationStage == 'none' ? palette.textSecondary : palette.error, fontWeight: FontWeight.w600),
            ),
            if (k.escalationStage == 'none') Text('Your Manager is asked to follow up after 24 hours, and Quicky reviews it after 48 hours.', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Text(
            k.destinationUpiId != null
                ? 'Send it to the customer\'s UPI ID: ${k.destinationUpiId}'
                : 'Send it back to the UPI account that paid you${k.originalReference != null ? ' (their payment ref ${k.originalReference})' : ''}.',
            key: const Key('vendorRefundDestination'),
          ),
          const SizedBox(height: 8),
          if (attempt != null)
            Text('You recorded ${rupeesOf(attempt.amountPaise)} on ${attempt.paidOn ?? '—'} (UPI ref ${attempt.reference ?? '—'}). Waiting for the customer to confirm.'),
          if (dispute != null)
            Text(
              dispute.response == 'differentAmount'
                  ? 'The customer says they received ${rupeesOf(dispute.receivedAmountPaise ?? 0)}, not ${rupeesOf(dispute.amountPaise)}. Quicky will review it; keep your UPI receipt ready.'
                  : 'The customer says the refund of ${rupeesOf(dispute.amountPaise)} didn\'t arrive. Quicky will review it; keep your UPI receipt ready.',
              key: const Key('vendorRefundDispute'),
              style: TextStyle(color: palette.error),
            ),
          if (k.status == RefundStatus.refundReviewRequired && dispute == null) const Text('Quicky is reviewing this refund.'),
          if (k.status == RefundStatus.refunded)
            Text(k.quickyAdvancedPaise > 0 ? 'Quicky refunded the customer for you. You owe Quicky ${rupeesOf(k.quickyAdvancedPaise)}.' : 'The customer confirmed your refund.', style: TextStyle(color: palette.success, fontWeight: FontWeight.w700)),
          if (k.canRecord) ...[
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const Key('recordRefund'),
              icon: const Icon(Icons.currency_rupee_rounded),
              label: const Text('Record refund'),
              onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => RecordRefundSheet(refund: k)),
            ),
          ],
        ]);
      },
    );
  }
}

/// The shop records the refund it sent: amount, UPI reference (UTR), date and,
/// optionally, a screenshot of the payment.
class RecordRefundSheet extends ConsumerStatefulWidget {
  const RecordRefundSheet({super.key, required this.refund, this.today});
  final RefundCase refund;

  /// For tests.
  final DateTime? today;

  @override
  ConsumerState<RecordRefundSheet> createState() => _RecordRefundSheetState();
}

class _RecordRefundSheetState extends ConsumerState<RecordRefundSheet> {
  late final _amount = TextEditingController(text: _rupeesInput(widget.refund.capacityPaise));
  final _utr = TextEditingController();
  final _note = TextEditingController();
  late DateTime _paidOn = widget.today ?? DateTime.now();
  final _requestId = newRefundRequestId();
  String? _evidencePath;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _utr.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _day => '${_paidOn.year.toString().padLeft(4, '0')}-${_paidOn.month.toString().padLeft(2, '0')}-${_paidOn.day.toString().padLeft(2, '0')}';

  Future<void> _attach() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final path = await ref.read(refundActionsProvider).uploadEvidence(orderId: widget.refund.orderId, party: 'vendor', bytes: await file.readAsBytes(), contentType: 'image/jpeg');
      setState(() => _evidencePath = path);
    } catch (e) {
      setState(() => _error = 'Couldn\'t upload the screenshot. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final amount = _paiseFrom(_amount.text);
    final utr = _utr.text.trim();
    if (amount == null || amount <= 0) return setState(() => _error = 'Enter the amount you sent.');
    if (amount > widget.refund.capacityPaise) return setState(() => _error = 'That\'s more than the ${rupeesOf(widget.refund.capacityPaise)} still owed.');
    if (utr.replaceAll(RegExp(r'\s'), '').length < 6) return setState(() => _error = 'Enter the UPI transaction reference (UTR) from your UPI app.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(refundActionsProvider).record(
        orderId: widget.refund.orderId,
        requestId: _requestId,
        amountPaise: amount,
        upiReference: utr,
        paidOn: _day,
        evidencePath: _evidencePath,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Record refund', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Send the money from your UPI app first, then record it here. The customer is asked to confirm it arrived; until then it isn\'t counted.', style: TextStyle(color: palette.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('refundAmount'),
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(labelText: 'Amount sent (₹)'),
          ),
          TextField(key: const Key('refundUtr'), controller: _utr, maxLength: 35, decoration: const InputDecoration(labelText: 'UPI transaction reference (UTR)')),
          Row(children: [
            Expanded(child: Text('Sent on $_day')),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final now = widget.today ?? DateTime.now();
                      final picked = await showDatePicker(context: context, initialDate: _paidOn, firstDate: now.subtract(const Duration(days: 90)), lastDate: now);
                      if (picked != null) setState(() => _paidOn = picked);
                    },
              child: const Text('Change date'),
            ),
          ]),
          TextField(key: const Key('refundNote'), controller: _note, maxLength: 300, decoration: const InputDecoration(labelText: 'Note (optional)')),
          OutlinedButton.icon(
            onPressed: _busy ? null : _attach,
            icon: Icon(_evidencePath == null ? Icons.attach_file_rounded : Icons.check_circle_rounded),
            label: Text(_evidencePath == null ? 'Attach payment screenshot (optional)' : 'Screenshot attached'),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const Key('refundError'), style: TextStyle(color: palette.error))),
          const SizedBox(height: 12),
          FilledButton(key: const Key('refundSubmit'), onPressed: _busy ? null : _submit, child: Text(_busy ? 'Recording…' : 'Record refund')),
        ]),
      ),
    );
  }
}
