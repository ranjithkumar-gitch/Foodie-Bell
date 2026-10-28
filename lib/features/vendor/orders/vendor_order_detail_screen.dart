import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/order_actions.dart';
import '../../../data/providers/order_codes_provider.dart';
import '../../../shared/widgets/storage_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/document_viewer_screen.dart';
import '../../../shared/widgets/order_status_stepper.dart';
import '../../../shared/widgets/status_chip.dart';
import '../vendor_session.dart';
import 'vendor_order_actions.dart';

String _rateLabel(double rate) => rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString();

/// Order Detail — vendor view (spec §5.9): items to prepare, a customer
/// note, and status progression. Accept/Reject live here too (same
/// `placed -> vendorAccepted` transition as the Live Order Queue) since a
/// vendor may open a queued order's detail before deciding.
class VendorOrderDetailScreen extends ConsumerWidget {
  const VendorOrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  StatusTone _tone(OrderStatus status) => switch (status) {
    OrderStatus.delivered => StatusTone.success,
    OrderStatus.cancelled || OrderStatus.rejected => StatusTone.error,
    OrderStatus.placed => StatusTone.info,
    _ => StatusTone.warning,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final order = ref.watch(orderByIdProvider(orderId)).valueOrNull;

    if (order == null) {
      return Scaffold(appBar: AppBar(title: const Text('Order')), body: const Center(child: Text('Order not found')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(order.id),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: StatusChip(label: order.status.label, tone: _tone(order.status))))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invoice', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.imageUrl.isNotEmpty) ...[
                          GestureDetector(
                            onTap: () => DocumentViewerScreen.show(
                              context,
                              source: item.imageUrl,
                              title: item.name,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: StorageImage(source: item.imageUrl, width: 40, height: 40),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text('${item.quantity}x', style: TextStyle(fontWeight: FontWeight.w800, color: palette.primary)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name),
                              if (item.gstRate != null && item.gstRate! > 0)
                                Text('HSN ${item.hsnCode ?? '—'} · GST ${_rateLabel(item.gstRate!)}%', style: TextStyle(color: palette.textMuted, fontSize: 10.5)),
                            ],
                          ),
                        ),
                        CurrencyText(item.lineTotal, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                _AmountRow(label: 'Subtotal', value: order.subtotal),
                if (order.couponCode != null)
                  _AmountRow(
                    label: 'Coupon (${order.couponCode})',
                    value: -order.couponDiscount,
                    valueColor: palette.success,
                  ),
                _AmountRow(label: 'Delivery fee (for the driver)', value: order.deliveryFee),
                // Quicky's platform fee, when charged: paid by the customer, not the shop's.
                if (order.platformFee > 0) _AmountRow(label: 'Platform fee (Quicky)', value: order.platformFee),
                if (order.gstAmount > 0) _AmountRow(label: 'GST', value: order.gstAmount),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('Customer pays', style: Theme.of(context).textTheme.titleMedium), CurrencyText(order.total, style: Theme.of(context).textTheme.titleMedium)],
                ),
                const SizedBox(height: 4),
                _AmountRow(label: 'Quicky commission (${order.money != null ? '10' : order.rebatePercent.toStringAsFixed(0)}%)', value: -order.rebateAmount),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('You get', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: palette.primary)),
                    CurrencyText(order.vendorEntitlement, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: palette.primary)),
                  ],
                ),
                if (order.paymentMethod == PaymentMethod.upi) ...[
                  const SizedBox(height: 8),
                  Text(
                    switch (order.paymentStatus) {
                      OrderPaymentStatus.awaitingVerification => 'UPI: check your account for the money, then confirm.',
                      OrderPaymentStatus.verified => 'UPI payment confirmed by you.',
                      OrderPaymentStatus.disputed => 'UPI payment is being checked by your Manager.',
                      OrderPaymentStatus.refundDue => 'You must return this UPI payment to the customer.',
                      _ => 'UPI payment',
                    },
                    style: TextStyle(fontWeight: FontWeight.w700, color: palette.textSecondary, fontSize: 15),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: LinearGradient(colors: palette.promoGradient), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.two_wheeler_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Handover code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                      const SizedBox(height: 2),
                      Text('Read this to the driver at pickup', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
                    ],
                  ),
                ),
                Text(ref.watch(orderHandoverCodeProvider(order.id)).valueOrNull ?? '····', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: 3)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order status', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 14),
                OrderStatusStepper(status: order.status, statusTimestamps: order.statusTimestamps),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_outlined, color: palette.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer notes', style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Please pack it well and add extra napkins. Ring the bell twice on arrival.', style: TextStyle(color: palette.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivering to', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(order.deliveryAddressLabel, style: TextStyle(color: palette.textSecondary)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: order.status == OrderStatus.placed
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: palette.error, side: BorderSide(color: palette.error)),
                        onPressed: () => runVendorAction(context, () => vendorRejectOrder(order.id)),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: order.awaitingUpiVerification
                          // UPI: check the money is in your account before accepting.
                          ? ElevatedButton(
                              onPressed: () => confirmUpiReceived(context, order),
                              child: const Text('Money received?'),
                            )
                          : ElevatedButton(
                              onPressed: () async {
                                if (!await ensureVendorReadyToAccept(context, ref)) return;
                                if (!context.mounted) return;
                                await runVendorAction(context, () => vendorAcceptOrder(order.id));
                              },
                              child: const Text('Accept'),
                            ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({required this.label, required this.value, this.valueColor});
  final String label;
  final double value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
          CurrencyText(value, style: TextStyle(color: valueColor ?? palette.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
