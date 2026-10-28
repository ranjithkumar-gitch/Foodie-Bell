import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/order_actions.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';

/// Runs a Vendor order action, showing the server's reason if it refuses.
Future<bool> runVendorAction(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    return true;
  } catch (e, st) {
    if (!context.mounted) return false;
    final message = e is OrderActionException ? e.message : friendlyError(e, action: 'Updating order', stackTrace: st);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return false;
  }
}

/// Asks the Vendor to check their own UPI/bank app for the Customer's
/// payment, then records the answer. This is the only "proof" a direct UPI
/// payment gets, so the question is put plainly.
Future<void> confirmUpiReceived(BuildContext context, Order order) async {
  final amount = (order.payment?.amountPaise ?? (order.total * 100).round()) / 100;
  final reference = order.payment?.customerReference;
  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final palette = dialogContext.colors;
      return AlertDialog(
        title: const Text('Did the money arrive?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Open your UPI or bank app and check for', style: TextStyle(color: palette.textSecondary, fontSize: 16)),
            const SizedBox(height: 6),
            CurrencyText(amount, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28, color: palette.textPrimary)),
            Text('from ${order.userName}', style: TextStyle(fontSize: 16, color: palette.textPrimary)),
            if (reference != null) ...[
              const SizedBox(height: 6),
              Text('Customer says the UPI reference is $reference', style: TextStyle(color: palette.textSecondary, fontSize: 15)),
            ],
            const SizedBox(height: 10),
            Text('Only say yes if you can see the money in your account. A screenshot is not enough.',
                style: TextStyle(color: palette.warning, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Check later')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('Not received', style: TextStyle(color: palette.error))),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Yes, received')),
        ],
      );
    },
  );
  if (answer == null || !context.mounted) return;
  if (answer) {
    await runVendorAction(context, () => confirmUpiPayment(order.id));
  } else {
    await runVendorAction(context, () => reportPaymentIssue(order.id, 'Shop did not receive the UPI payment'));
  }
}
