import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/order_actions.dart';
import '../../../shared/error_reporting.dart';

/// Whether order detail shows [CancelOrderButton]. The server's
/// `cancelOrder` takes the customer's own order only while it is `placed`
/// (before the shop accepts). UPI orders cancel from their payment card
/// (`UpiPaymentCard`), which also explains the payment side, so this covers
/// every other order — Cash on Delivery.
bool showsCancelOrderButton(Order order) => order.status == OrderStatus.placed && order.paymentMethod != PaymentMethod.upi;

/// "Cancel order" for a `placed` order: asks for an optional reason, then
/// calls `cancelOrder`. The order screen updates from the order itself; a
/// refusal (e.g. the shop accepted meanwhile) is shown as the server says.
class CancelOrderButton extends StatefulWidget {
  const CancelOrderButton({super.key, required this.order, this.cancel = customerCancelOrder});

  final Order order;

  /// The `cancelOrder` call; replaceable in tests.
  final Future<void> Function(String orderId, String reason) cancel;

  @override
  State<CancelOrderButton> createState() => _CancelOrderButtonState();
}

class _CancelOrderButtonState extends State<CancelOrderButton> {
  bool _busy = false;
  String? _error;

  Future<void> _cancel() async {
    final reason = await _askReason(context);
    if (reason == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // The server requires a reason (at most 300 characters).
      await widget.cancel(widget.order.id, reason.isEmpty ? 'Cancelled by customer' : reason);
    } catch (e, st) {
      if (mounted) setState(() => _error = e is OrderActionException ? e.message : friendlyError(e, action: 'Cancelling order', stackTrace: st));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _cancel,
          style: OutlinedButton.styleFrom(foregroundColor: palette.error, side: BorderSide(color: palette.error)),
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cancel_outlined),
          label: const Text('Cancel order'),
        ),
        const SizedBox(height: 6),
        Text(
          _error ?? 'You can cancel until the shop accepts the order. Cash orders are never charged.',
          style: TextStyle(color: _error == null ? palette.textSecondary : palette.error, fontSize: 12.5, fontWeight: _error == null ? FontWeight.w500 : FontWeight.w600),
        ),
      ],
    );
  }
}

/// The reason, possibly empty; null if the customer keeps the order.
Future<String?> _askReason(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cancel this order?'),
      content: TextField(controller: controller, autofocus: true, maxLength: 300, decoration: const InputDecoration(hintText: 'Reason (optional)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Keep order')),
        ElevatedButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Cancel order')),
      ],
    ),
  );
}
