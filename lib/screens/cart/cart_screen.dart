import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/cart_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/quantity_stepper.dart';
import '../checkout/checkout_screen.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  static const double _taxRate = 0.08;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    final deliveryFee = cart.isEmpty ? 0.0 : cart.items.first.restaurant.deliveryFee;
    final tax = cart.subtotal * _taxRate;
    final total = cart.subtotal + deliveryFee + tax;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: notifier.clear,
              child: const Text('Clear', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: cart.isEmpty
          ? _EmptyCart(onBrowse: () => Navigator.of(context).popUntil((r) => r.isFirst))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final cartItem = cart.items[i];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            AppNetworkImage(
                              url: cartItem.item.imageUrl,
                              width: 64,
                              height: 64,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cartItem.item.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text('\$${cartItem.item.price.toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => notifier.removeItem(cartItem.item.id),
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.textMuted, size: 20),
                                ),
                                QuantityStepper(
                                  quantity: cartItem.quantity,
                                  compact: true,
                                  onIncrement: () => notifier.increment(cartItem.item.id),
                                  onDecrement: () => notifier.decrement(cartItem.item.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -6))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        _SummaryRow(label: 'Subtotal', value: cart.subtotal),
                        _SummaryRow(label: 'Delivery fee', value: deliveryFee),
                        _SummaryRow(label: 'Tax', value: tax),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(),
                        ),
                        _SummaryRow(label: 'Total', value: total, emphasize: true),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                          ),
                          child: const Text('Proceed to Checkout'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.emphasize = false});
  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('\$${value.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.shopping_bag_outlined, size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 22),
            Text('Your cart is empty', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Looks like you haven\'t added anything yet. Explore restaurants and find something tasty.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onBrowse, child: const Text('Browse Restaurants')),
          ],
        ),
      ),
    );
  }
}
