import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/cart_provider.dart';
import '../../theme/app_colors.dart';
import 'order_success_screen.dart';

enum _PaymentMethod { card, cash, wallet }

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  _PaymentMethod _payment = _PaymentMethod.card;
  bool _placingOrder = false;

  static const double _taxRate = 0.08;

  Future<void> _placeOrder(double total) async {
    setState(() => _placingOrder = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    ref.read(cartProvider.notifier).clear();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OrderSuccessScreen(total: total)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final deliveryFee = cart.isEmpty ? 0.0 : cart.items.first.restaurant.deliveryFee;
    final tax = cart.subtotal * _taxRate;
    final total = cart.subtotal + deliveryFee + tax;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          _SectionCard(
            title: 'Delivery address',
            trailing: TextButton(onPressed: () {}, child: const Text('Change')),
            child: const Row(
              children: [
                Icon(Icons.place_rounded, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Home', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      SizedBox(height: 2),
                      Text('221B Baker Street, London', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Payment method',
            child: Column(
              children: [
                _PaymentTile(
                  icon: Icons.credit_card_rounded,
                  label: 'Credit / Debit Card',
                  subtitle: '•••• •••• •••• 4242',
                  selected: _payment == _PaymentMethod.card,
                  onTap: () => setState(() => _payment = _PaymentMethod.card),
                ),
                const SizedBox(height: 10),
                _PaymentTile(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Wallet',
                  subtitle: 'Balance: \$45.00',
                  selected: _payment == _PaymentMethod.wallet,
                  onTap: () => setState(() => _payment = _PaymentMethod.wallet),
                ),
                const SizedBox(height: 10),
                _PaymentTile(
                  icon: Icons.payments_outlined,
                  label: 'Cash on Delivery',
                  subtitle: 'Pay when your order arrives',
                  selected: _payment == _PaymentMethod.cash,
                  onTap: () => setState(() => _payment = _PaymentMethod.cash),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Order summary',
            child: Column(
              children: [
                for (final item in cart.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.item.name, overflow: TextOverflow.ellipsis)),
                        Text('\$${item.lineTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                _PriceRow('Subtotal', cart.subtotal),
                _PriceRow('Delivery fee', deliveryFee),
                _PriceRow('Tax', tax),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                _PriceRow('Total', total, emphasize: true),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton(
            onPressed: (cart.isEmpty || _placingOrder) ? null : () => _placeOrder(total),
            child: _placingOrder
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                  )
                : Text('Place Order · \$${total.toStringAsFixed(2)}'),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : Colors.transparent, width: 1.4),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow(this.label, this.value, {this.emphasize = false});
  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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
