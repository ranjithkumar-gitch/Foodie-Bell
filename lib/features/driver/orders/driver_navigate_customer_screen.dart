import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/mock_map_view.dart';

/// Active Delivery — Navigate to Customer (spec §6 item 10): route preview
/// to the drop-off address, with a real call (device dialer, `order.userPhone`)
/// and a real one-to-one chat (`order_chat_screen.dart`) about this order,
/// plus an "Arrived" action that routes into Cash Collection (COD orders
/// only) then Delivery Confirmation. Call/chat only show while the order is
/// still active — once delivered/cancelled there's nothing left to
/// coordinate, so they disappear rather than staying reachable for a closed
/// order.
class DriverNavigateCustomerScreen extends ConsumerWidget {
  const DriverNavigateCustomerScreen({super.key, required this.orderId});

  final String orderId;

  Future<void> _call(BuildContext context, String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the phone dialer.')));
      }
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, action: 'Calling customer', stackTrace: st))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final order = ref.watch(orderByIdProvider(orderId)).valueOrNull;
    if (order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final canContact = !order.status.isTerminal;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.home_rounded), tooltip: 'Back to dashboard', onPressed: () => context.go('/driver/home')),
        title: const Text('Navigate to customer'),
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
                  CircleAvatar(radius: 22, backgroundColor: palette.primaryLight.withValues(alpha: 0.25), child: Icon(Icons.person_rounded, color: palette.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.userName, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: palette.textPrimary)),
                        const SizedBox(height: 2),
                        Text(order.deliveryAddressLabel, style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  if (canContact) ...[
                    _CircleAction(icon: Icons.call_rounded, onTap: () => _call(context, order.userPhone)),
                    const SizedBox(width: 8),
                    _CircleAction(icon: Icons.chat_bubble_rounded, onTap: () => context.push('/driver/delivery/${order.id}/chat')),
                  ],
                ],
              ),
            ),
            const Spacer(),
            Text(
              'Head to the customer to hand over this order.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(
                order.isCod ? '/driver/delivery/${order.id}/cash-collection' : '/driver/delivery/${order.id}/delivery-confirm',
              ),
              child: const Text('Arrived at Customer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: CircleAvatar(radius: 18, backgroundColor: palette.primary, child: Icon(icon, color: Colors.white, size: 18)),
    );
  }
}
