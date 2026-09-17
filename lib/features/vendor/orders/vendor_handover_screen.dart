import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../shared/widgets/order_status_stepper.dart';

/// Handover to Driver (spec §5.10) — display-only. The Vendor mutates
/// exactly one order-status transition (`placed -> vendorAccepted`,
/// handled on the Live Order Queue / Order Detail screens); everything
/// from driver assignment through delivery is owned by the Driver's app.
/// This screen simply shows the order's handover code for the vendor to
/// read out to the driver at pickup, plus the live status for reference.
class VendorHandoverScreen extends ConsumerWidget {
  const VendorHandoverScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final order = ref.watch(orderByIdProvider(orderId)).valueOrNull;

    if (order == null) {
      return Scaffold(appBar: AppBar(title: const Text('Handover')), body: const Center(child: Text('Order not found')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Handover to Driver')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: LinearGradient(colors: palette.promoGradient), borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 36),
                const SizedBox(height: 12),
                const Text('Read this code to the driver at pickup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                Text(
                  order.handoverCode,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 44, letterSpacing: 6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(order.id, style: Theme.of(context).textTheme.titleMedium),
                    Text(order.driverName ?? 'Awaiting driver assignment', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ],
                ),
                const SizedBox(height: 16),
                OrderStatusStepper(status: order.status, statusTimestamps: order.statusTimestamps),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: palette.textSecondary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'The driver confirms this code in their app to complete pickup — you don\'t need to do anything else here.',
                    style: TextStyle(fontSize: 12, color: palette.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
