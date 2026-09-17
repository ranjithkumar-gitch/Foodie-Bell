import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../shared/widgets/mock_map_view.dart';

/// Active Delivery — Navigate to Vendor (spec §6 item 8): route preview to
/// the pickup point plus an "Arrived at Vendor" affordance that hands off
/// to Pickup Confirmation. Purely a navigation step — it doesn't touch
/// order status itself.
class DriverNavigateVendorScreen extends ConsumerWidget {
  const DriverNavigateVendorScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final order = ref.watch(orderByIdProvider(orderId)).valueOrNull;
    if (order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.home_rounded), tooltip: 'Back to dashboard', onPressed: () => context.go('/driver/home')),
        title: const Text('Navigate to vendor'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MockMapView(height: 260, showRoute: true, borderRadius: BorderRadius.all(Radius.circular(18))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
              child: Row(
                children: [
                  CircleAvatar(radius: 22, backgroundColor: palette.primaryLight.withValues(alpha: 0.25), child: Icon(Icons.storefront_rounded, color: palette.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.vendorName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: palette.textPrimary)),
                        const SizedBox(height: 2),
                        Text('Order ${order.id} · ${order.items.length} item(s)', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Head to the vendor to collect this order. Mark yourself arrived once you\'re there.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/driver/delivery/${order.id}/pickup-confirm'),
              child: const Text('Arrived at Vendor'),
            ),
          ],
        ),
      ),
    );
  }
}
