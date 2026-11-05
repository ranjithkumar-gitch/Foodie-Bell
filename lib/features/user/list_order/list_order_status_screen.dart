import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/payments/upi_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/list_order_request.dart';
import '../../../data/providers/firestore_list_order_requests_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/storage_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/document_viewer_screen.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../../shared/widgets/upi_payment_card.dart' show UpiAppSheet;

StatusTone _tone(ListOrderStatus status) => switch (status) {
  ListOrderStatus.pending => StatusTone.warning,
  ListOrderStatus.quoted => StatusTone.warning,
  ListOrderStatus.paid => StatusTone.info,
  ListOrderStatus.accepted => StatusTone.success,
  ListOrderStatus.rejected || ListOrderStatus.cancelled => StatusTone.error,
};

/// Tracking screen for one "Order via Photo" request
/// (`list_order_capture_screen.dart`) between submit and it becoming a real
/// `Order` — shows the submitted photos, the vendor's quote once set, the
/// pay step, and a handoff to `order_detail_screen.dart` once the vendor
/// has confirmed and delivery tracking takes over.
class ListOrderStatusScreen extends ConsumerStatefulWidget {
  const ListOrderStatusScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<ListOrderStatusScreen> createState() => _ListOrderStatusScreenState();
}

class _ListOrderStatusScreenState extends ConsumerState<ListOrderStatusScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, {required String failedAction}) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, action: failedAction, stackTrace: st))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() => _run(
    () => cancelListOrderRequest(widget.requestId),
    failedAction: 'Cancelling request',
  );

  /// The shop is paid directly by UPI — nothing passes through the app —
  /// so the request is only marked paid once the Customer says the money
  /// went, and the shop still checks its own account before confirming
  /// (`acceptListOrder`). With the shop's UPI ID on the quote, the UPI app
  /// opens with the amount filled in; without it, the Customer pays the
  /// shop's QR code or the ID the shop gives them.
  Future<void> _pay(ListOrderRequest request) async {
    final amount = request.quotedAmount ?? 0;
    final upiId = request.quote?.vendorUpiId;
    if (upiId != null) {
      final paid = await _payWithUpiApp(request, upiId, amount);
      if (paid != true || !mounted) return;
    }
    if (!mounted) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PayConfirmSheet(amount: amount, vendorName: request.vendorName, openedUpiApp: upiId != null),
    );
    if (confirmed != true) return;
    await _run(
      () => markListOrderRequestPaid(widget.requestId),
      failedAction: 'Marking as paid',
    );
  }

  /// Opens a UPI app to pay [upiId]; true when the payment may have gone
  /// through (the app's answer is only a hint), false when it clearly
  /// didn't, null when nothing was opened.
  Future<bool?> _payWithUpiApp(ListOrderRequest request, String upiId, double amount) async {
    final messenger = ScaffoldMessenger.of(context);
    UpiApp? app;
    if (Platform.isAndroid) {
      final apps = await installedUpiApps();
      if (!mounted) return null;
      if (apps.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text('No UPI app found on this phone. Pay ${AppFormat.currency(amount)} to $upiId from any UPI app.')));
        return null;
      }
      app = await showModalBottomSheet<UpiApp>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => UpiAppSheet(apps: apps, amount: amount),
      );
      if (app == null) return null;
    }
    try {
      final result = await payWithUpi(
        app: app,
        upiId: upiId,
        payeeName: request.vendorName,
        amount: amount,
        transactionRef: request.id,
        note: 'Photo order ${request.id}',
      );
      if (result.status == UpiStatus.failure || result.status == UpiStatus.cancelled) {
        messenger.showSnackBar(const SnackBar(content: Text('The payment did not go through. Nothing was paid.')));
        return false;
      }
      return true;
    } on UpiAppNotFoundException {
      messenger.showSnackBar(SnackBar(content: Text('No UPI app found on this phone. Pay ${AppFormat.currency(amount)} to $upiId from any UPI app.')));
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final requestAsync = ref.watch(listOrderRequestByIdProvider(widget.requestId));

    return Scaffold(
      appBar: AppBar(title: const Text('Order via Photo')),
      body: requestAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(friendlyError(e, action: 'Loading request', stackTrace: st))),
        data: (request) {
          if (request == null) {
            return const Center(child: Text('This request no longer exists.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(request.vendorName, style: Theme.of(context).textTheme.headlineSmall),
                  StatusChip(label: request.status.label, tone: _tone(request.status)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                request.deliveryAddressLabel,
                style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: request.imageUrls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => DocumentViewerScreen.show(
                      context,
                      source: request.imageUrls[i],
                      title: 'Photo ${i + 1}',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: StorageImage(source: request.imageUrls[i], width: 100, height: 100),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _StatusCard(request: request, busy: _busy, onCancel: _cancel, onPay: _pay),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.request, required this.busy, required this.onCancel, required this.onPay});

  final ListOrderRequest request;
  final bool busy;
  final VoidCallback onCancel;
  final ValueChanged<ListOrderRequest> onPay;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          switch (request.status) {
            ListOrderStatus.pending => Text(
              'Waiting for ${request.vendorName} to look at your photos and send a price.',
              style: TextStyle(color: palette.textSecondary),
            ),
            ListOrderStatus.quoted => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount to pay', style: TextStyle(color: palette.textSecondary, fontSize: 14)),
                const SizedBox(height: 4),
                CurrencyText(request.quotedAmount ?? 0, style: Theme.of(context).textTheme.displaySmall),
                if (request.quote case final quote?) ...[
                  const SizedBox(height: 12),
                  _QuoteLine(label: 'Items', paise: quote.itemsPaise),
                  _QuoteLine(label: 'Delivery fee', paise: quote.deliveryFeePaise),
                  if (quote.platformFeePaise > 0) _QuoteLine(label: 'Platform fee', paise: quote.platformFeePaise),
                ],
                const SizedBox(height: 12),
                Text(
                  'You pay ${request.vendorName} directly by UPI. ${request.vendorName} checks the money arrived, then confirms your order.',
                  style: TextStyle(color: palette.textSecondary, fontSize: 14, height: 1.35),
                ),
              ],
            ),
            ListOrderStatus.paid => Text(
              'You said you paid ${AppFormat.currency(request.quotedAmount ?? 0)}. '
              'Waiting for ${request.vendorName} to check the money arrived and confirm your order.',
              style: TextStyle(color: palette.textSecondary, fontSize: 14, height: 1.35),
            ),
            ListOrderStatus.accepted => Text(
              'Order confirmed! Track your delivery below.',
              style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w700),
            ),
            ListOrderStatus.rejected => Text(
              '${request.vendorName} wasn\'t able to fulfill this request.',
              style: TextStyle(color: palette.error, fontWeight: FontWeight.w600),
            ),
            ListOrderStatus.cancelled => Text(
              'You cancelled this request.',
              style: TextStyle(color: palette.textSecondary),
            ),
          },
          const SizedBox(height: 16),
          if (request.status == ListOrderStatus.pending)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: palette.error, side: BorderSide(color: palette.error)),
                onPressed: busy ? null : onCancel,
                child: const Text('Cancel request'),
              ),
            ),
          if (request.status == ListOrderStatus.quoted)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: busy ? null : () => onPay(request),
                    child: Text('Pay ${AppFormat.currency(request.quotedAmount ?? 0)}'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: palette.error, side: BorderSide(color: palette.error)),
                    onPressed: busy ? null : onCancel,
                    child: const Text('Cancel request'),
                  ),
                ),
              ],
            ),
          if (request.status == ListOrderStatus.accepted && request.orderId != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/user/order/${request.orderId}'),
                child: const Text('Track order'),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuoteLine extends StatelessWidget {
  const _QuoteLine({required this.label, required this.paise});
  final String label;
  final int paise;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 14))),
          Text(AppFormat.currency(paise / 100), style: TextStyle(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Asks the Customer to confirm they really paid — the request is marked
/// paid only on "I have paid". [openedUpiApp] says whether a UPI app was
/// just opened for them; otherwise this also says how to pay.
class _PayConfirmSheet extends StatelessWidget {
  const _PayConfirmSheet({required this.amount, required this.vendorName, required this.openedUpiApp});
  final double amount;
  final String vendorName;
  final bool openedUpiApp;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(openedUpiApp ? 'Did the payment go through?' : 'Pay $vendorName by UPI', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              openedUpiApp
                  ? 'Tap "I have paid" only if ${AppFormat.currency(amount)} left your account.'
                  : 'Open any UPI app and pay ${AppFormat.currency(amount)} to $vendorName — scan their UPI QR code or use the UPI ID they give you. '
                    'Come back and tap "I have paid" once the money has left your account.',
              style: TextStyle(color: palette.textSecondary, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              '$vendorName checks they received it before confirming your order.',
              style: TextStyle(color: palette.textMuted, fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('I have paid ${AppFormat.currency(amount)}'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not yet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
