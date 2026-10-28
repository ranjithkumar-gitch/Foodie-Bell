import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/payments/upi_service.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/order.dart';
import '../../data/providers/order_actions.dart';
import '../error_reporting.dart';
import 'currency_text.dart';

/// The Customer's side of a UPI order: pay the shop directly, then wait for
/// the shop to confirm the money arrived. Shown on the order success and
/// order detail screens while the payment isn't settled.
///
/// Paying in a UPI app is not proof of payment — only the shop checking
/// its own account is, so the order says "waiting for the shop" until then.
class UpiPaymentCard extends StatefulWidget {
  const UpiPaymentCard({super.key, required this.order});
  final Order order;

  @override
  State<UpiPaymentCard> createState() => _UpiPaymentCardState();
}

class _UpiPaymentCardState extends State<UpiPaymentCard> {
  final _reference = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  Order get order => widget.order;
  double get _amount => (order.payment?.amountPaise ?? (order.total * 100).round()) / 100;

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = done);
    } catch (e, st) {
      if (mounted) setState(() => _message = e is OrderActionException ? e.message : friendlyError(e, action: 'UPI payment', stackTrace: st));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _payInApp() async {
    final upiId = order.payment?.vendorUpiId;
    if (upiId == null) return;
    UpiApp? app;
    if (Platform.isAndroid) {
      final apps = await installedUpiApps();
      if (!mounted) return;
      if (apps.isEmpty) {
        setState(() => _message = 'No UPI app found on this phone. Pay ${AppFormat.currency(_amount)} to $upiId from any UPI app.');
        return;
      }
      app = await showModalBottomSheet<UpiApp>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => UpiAppSheet(apps: apps, amount: _amount),
      );
      if (app == null) return;
    }
    await _run(() async {
      final result = await payWithUpi(
        app: app,
        upiId: upiId,
        payeeName: order.vendorName,
        amount: _amount,
        transactionRef: order.id,
        note: 'Order ${order.id}',
      );
      // The UPI app's answer is only a hint. Pass any reference on so the
      // shop can match it; the shop still has to confirm the money arrived.
      final reference = result.transactionId;
      if (reference != null && RegExp(r'^[A-Za-z0-9-]{4,64}$').hasMatch(reference)) {
        await submitUpiReference(order.id, reference);
      }
    }, done: 'Thanks. The shop will check their account and confirm your payment.');
  }

  Future<void> _sendReference() async {
    final reference = _reference.text.trim();
    if (!RegExp(r'^[A-Za-z0-9-]{4,64}$').hasMatch(reference)) {
      setState(() => _message = 'Enter the UPI reference (UTR) from your UPI app.');
      return;
    }
    await _run(() => submitUpiReference(order.id, reference), done: 'Reference sent to the shop.');
  }

  Future<void> _reportProblem() async {
    final reason = await _askText(context, title: 'What went wrong with the payment?', hint: 'e.g. Money was debited but the order still waits');
    if (reason == null) return;
    await _run(() => reportPaymentIssue(order.id, reason), done: 'Reported. The territory manager will look into it.');
  }

  Future<void> _cancel() async {
    final reason = await _askText(context, title: 'Cancel this order?', hint: 'Reason (optional)', optional: true);
    if (reason == null) return;
    await _run(() => customerCancelOrder(order.id, reason.isEmpty ? 'Cancelled by customer' : reason));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final status = order.paymentStatus;
    final (title, body, tone) = switch (status) {
      OrderPaymentStatus.awaitingVerification => (
        'Pay the shop by UPI',
        'Pay ${AppFormat.currency(_amount)} to ${order.payment?.vendorUpiId ?? 'the shop'}. '
            'The shop confirms your order after they see the money in their account.',
        palette.warning,
      ),
      OrderPaymentStatus.verified => ('Payment confirmed by the shop', 'The shop has confirmed they received ${AppFormat.currency(_amount)}.', palette.success),
      OrderPaymentStatus.disputed => ('Payment under review', 'Your territory manager is checking this payment.${order.payment?.issueReason == null ? '' : ' (${order.payment!.issueReason})'}', palette.error),
      OrderPaymentStatus.failed => ('Payment not received', 'The shop did not receive this payment, so the order was cancelled.', palette.error),
      OrderPaymentStatus.refundDue => ('Refund due', 'The shop owes you ${AppFormat.currency(_amount)} back. It will be returned to your UPI account.', palette.warning),
      OrderPaymentStatus.refunded => ('Refunded', 'The shop has returned your payment.', palette.success),
      _ => ('UPI payment', '', palette.textSecondary),
    };
    final awaiting = status == OrderPaymentStatus.awaitingVerification;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: tone.withValues(alpha: 0.6))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.qr_code_2_rounded, color: tone),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ]),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(body, style: TextStyle(color: palette.textSecondary, height: 1.35)),
          ],
          if (awaiting) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _payInApp,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text('Pay ${AppFormat.currency(_amount)} with a UPI app'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reference,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: order.payment?.customerReference == null ? 'Already paid? Enter the UPI reference (UTR)' : 'Reference sent: ${order.payment!.customerReference}',
                suffixIcon: IconButton(icon: const Icon(Icons.send_rounded), onPressed: _busy ? null : _sendReference),
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 10),
            Text(_message!, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600)),
          ],
          if (awaiting || status == OrderPaymentStatus.verified || status == OrderPaymentStatus.unpaidCancelled) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 4, children: [
              TextButton(onPressed: _busy ? null : _reportProblem, child: const Text('Report a payment problem')),
              if (order.status == OrderStatus.placed)
                TextButton(onPressed: _busy ? null : _cancel, child: Text('Cancel order', style: TextStyle(color: palette.error))),
            ]),
          ],
        ],
      ),
    );
  }
}

/// Asks for a line of text; null if dismissed. [optional] allows empty.
Future<String?> _askText(BuildContext context, {required String title, required String hint, bool optional = false}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true, maxLength: 300, decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Back')),
        ElevatedButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isEmpty && !optional) return;
            Navigator.pop(dialogContext, text);
          },
          child: const Text('Send'),
        ),
      ],
    ),
  );
}

/// Bottom sheet listing the installed UPI apps; pops the one tapped.
class UpiAppSheet extends StatelessWidget {
  const UpiAppSheet({super.key, required this.apps, required this.amount});
  final List<UpiApp> apps;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        decoration: BoxDecoration(color: palette.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose a UPI app · ${AppFormat.currency(amount)}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final app in apps)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: app.icon != null
                          ? Image.memory(app.icon!, width: 40, height: 40)
                          : Icon(Icons.account_balance_wallet_rounded, size: 40, color: palette.primary),
                      title: Text(app.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: palette.textPrimary)),
                      trailing: Icon(Icons.chevron_right_rounded, color: palette.textMuted),
                      onTap: () => Navigator.pop(context, app),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
