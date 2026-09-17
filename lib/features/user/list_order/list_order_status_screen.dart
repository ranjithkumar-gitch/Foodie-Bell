import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/list_order_request.dart';
import '../../../data/providers/firestore_list_order_requests_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/document_viewer_screen.dart';
import '../../../shared/widgets/status_chip.dart';

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

  Future<void> _pay(double amount) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PayConfirmSheet(amount: amount),
    );
    if (confirmed != true) return;
    await _run(
      () => markListOrderRequestPaid(widget.requestId),
      failedAction: 'Paying vendor',
    );
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
                      imageUrl: request.imageUrls[i],
                      title: 'Photo ${i + 1}',
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AppNetworkImage(url: request.imageUrls[i], width: 100, height: 100),
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
  final ValueChanged<double> onPay;

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
                Text('Quoted amount', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                const SizedBox(height: 4),
                CurrencyText(request.quotedAmount ?? 0, style: Theme.of(context).textTheme.displaySmall),
              ],
            ),
            ListOrderStatus.paid => Text(
              'Payment received — waiting for ${request.vendorName} to confirm your order.',
              style: TextStyle(color: palette.textSecondary),
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
                    onPressed: busy ? null : () => onPay(request.quotedAmount ?? 0),
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

class _PayConfirmSheet extends StatelessWidget {
  const _PayConfirmSheet({required this.amount});
  final double amount;

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
            Text('Confirm payment', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Pay ${AppFormat.currency(amount)} to the vendor for this order.',
              style: TextStyle(color: palette.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Pay ${AppFormat.currency(amount)}'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
