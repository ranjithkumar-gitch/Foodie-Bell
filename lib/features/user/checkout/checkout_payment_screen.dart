import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/cart_item.dart';
import '../../../data/models/order.dart';
import '../../../data/models/tax_category.dart';
import '../../../data/providers/cart_provider.dart';
import '../../../data/providers/firestore_addresses_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_tax_categories_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';
import '../address_label_text.dart';
import '../translation/translated_text.dart';

/// Checkout – Payment Method (spec §4.10): Cash on Delivery is the only
/// live payment path — UPI/Card/Wallet are shown but disabled ("Coming
/// soon") since there's no real payment gateway integration yet. Placing an
/// order writes a real `orders` doc (`firestore_orders_provider.dart`)
/// instead of the old in-memory `mockOrdersProvider`.
/// This line's GST, resolved from its product's tax category/override
/// (`resolveProductGst`) and snapshotted onto the order at the moment it's
/// placed — see [OrderLineItem.gstAmount]'s doc comment for why this isn't
/// re-resolved later.
OrderLineItem _lineItemFromCartItem(CartItem item, List<TaxCategory> taxCategories) {
  final gst = resolveProductGst(item.product, taxCategories);
  return OrderLineItem(
    productId: item.product.id,
    name: item.product.name,
    price: item.product.price,
    imageUrl: item.product.imageUrl,
    quantity: item.quantity,
    hsnCode: gst.hsnCode,
    gstRate: gst.gstRate,
    gstAmount: item.lineTotal * gst.gstRate / 100,
  );
}

class CheckoutPaymentScreen extends ConsumerStatefulWidget {
  const CheckoutPaymentScreen({super.key});

  @override
  ConsumerState<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends ConsumerState<CheckoutPaymentScreen> {
  final PaymentMethod _payment = PaymentMethod.cod;
  bool _placingOrder = false;
  String? _error;

  static const double _platformFee = 5;

  Future<void> _placeOrder(
    double subtotal,
    double deliveryFee,
    double gstAmount,
    double total,
    String vendorName,
    String vendorId,
    double rebatePercent,
    List<TaxCategory> taxCategories,
  ) async {
    setState(() {
      _placingOrder = true;
      _error = null;
    });

    final cart = ref.read(cartProvider);
    final address = ref.read(selectedAddressProvider);
    final session = ref.read(sessionControllerProvider);
    final placedAt = DateTime.now();
    final coupon = cart.appliedCoupon;
    final order = Order(
      id: generateOrderId(),
      vendorId: vendorId,
      vendorName: vendorName,
      userId: session.account?.id ?? 'u1',
      userName: session.account?.name ?? 'You',
      userPhone: address?.recipientPhone ?? session.account?.phone ?? '',
      items: [for (final item in cart.items) _lineItemFromCartItem(item, taxCategories)],
      deliveryAddressLabel: address?.shortLabel ?? 'Saved address',
      paymentMethod: _payment,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      platformFee: _platformFee,
      gstAmount: gstAmount,
      total: total,
      placedAt: placedAt,
      statusTimestamps: {OrderStatus.placed: placedAt},
      rebatePercent: rebatePercent,
      couponCode: coupon?.code,
      couponDiscount: cart.couponDiscount,
      handoverCode: generateOrderCode(),
      deliveryOtp: generateOrderCode(),
    );

    try {
      if (coupon != null) {
        await createOrderWithCoupon(order, couponId: coupon.id);
      } else {
        await createOrder(order);
      }
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _placingOrder = false;
        // A rejected coupon redemption (`createOrderWithCoupon`'s
        // transaction) is a real, actionable outcome — not a
        // connectivity/backend failure — so its message is shown as-is
        // instead of being flattened into `friendlyError`'s generic text.
        _error = e is StateError ? e.message : friendlyError(e, action: 'Placing order', stackTrace: st);
      });
      return;
    }

    ref.read(cartProvider.notifier).clear();
    if (!mounted) return;
    context.go('/user/order-success/${order.id}');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final cart = ref.watch(cartProvider);
    final address = ref.watch(selectedAddressProvider);
    final deliveryFee = cart.isEmpty ? 0.0 : cart.items.first.deliveryFee;
    final taxCategories = ref.watch(firestoreTaxCategoriesProvider).valueOrNull ?? const [];
    final gstAmount = cart.items.fold<double>(0, (sum, item) => sum + item.lineTotal * resolveProductGst(item.product, taxCategories).gstRate / 100);
    final couponDiscount = cart.couponDiscount;
    final total = cart.subtotal + deliveryFee + gstAmount + _platformFee - couponDiscount;
    final vendorName = cart.items.isEmpty ? '' : cart.items.first.vendorName;
    final vendorId = cart.items.isEmpty ? '' : cart.items.first.vendorId;
    final rebatePercent = cart.items.isEmpty ? 0.0 : cart.items.first.rebatePercent;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.checkoutPaymentTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          _SectionCard(
            title: context.l10n.checkoutDeliveryAddress,
            trailing: TextButton(onPressed: () => context.pop(), child: Text(context.l10n.actionChange)),
            child: Row(
              children: [
                Icon(Icons.place_rounded, color: palette.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(address == null ? context.l10n.addressLabelHome : addressLabelText(context, address.label), style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                      if (address != null) ...[
                        const SizedBox(height: 2),
                        Text('${address.recipientName} · ${address.recipientPhone}', style: TextStyle(color: palette.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 2),
                      Text(address?.line1 ?? '', style: TextStyle(color: palette.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: context.l10n.checkoutPaymentMethod,
            child: Column(
              children: [
                _PaymentTile(icon: Icons.payments_outlined, label: context.l10n.paymentCod, subtitle: context.l10n.paymentCodSubtitle, selected: true, onTap: () {}),
                const SizedBox(height: 10),
                _PaymentTile(icon: Icons.qr_code_rounded, label: context.l10n.paymentUpi, subtitle: context.l10n.paymentComingSoon, selected: false, enabled: false, onTap: () {}),
                const SizedBox(height: 10),
                _PaymentTile(icon: Icons.credit_card_rounded, label: context.l10n.paymentCard, subtitle: context.l10n.paymentComingSoon, selected: false, enabled: false, onTap: () {}),
                const SizedBox(height: 10),
                _PaymentTile(icon: Icons.account_balance_wallet_rounded, label: context.l10n.paymentWallet, subtitle: context.l10n.paymentComingSoon, selected: false, enabled: false, onTap: () {}),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: context.l10n.checkoutOrderSummary,
            child: Column(
              children: [
                for (final item in cart.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Text('${item.quantity}x', style: TextStyle(fontWeight: FontWeight.w700, color: palette.textSecondary)),
                        const SizedBox(width: 8),
                        Expanded(child: TranslatedText(item.product.name, overflow: TextOverflow.ellipsis)),
                        CurrencyText(item.lineTotal, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                _PriceRow(context.l10n.priceSubtotal, cart.subtotal),
                if (couponDiscount > 0)
                  _PriceRow(
                    context.l10n.priceCouponDiscount,
                    -couponDiscount,
                    valueColor: palette.success,
                  ),
                _PriceRow(context.l10n.priceDeliveryFee, deliveryFee),
                _PriceRow(context.l10n.pricePlatformFee, _platformFee),
                _PriceRow(context.l10n.priceGst, gstAmount),
                const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                _PriceRow(context.l10n.priceTotal, total, emphasize: true),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton(
            onPressed: (cart.isEmpty || _placingOrder)
                ? null
                : () => _placeOrder(cart.subtotal, deliveryFee, gstAmount, total, vendorName, vendorId, rebatePercent, taxCategories),
            child: _placingOrder
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                : Text(context.l10n.checkoutPlaceOrder(AppFormat.currency(total))),
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
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), ?trailing]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.icon, required this.label, required this.subtitle, required this.selected, required this.onTap, this.enabled = true});

  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? palette.primaryLight.withValues(alpha: 0.18) : palette.surfaceMuted,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? palette.primary : Colors.transparent, width: 1.4),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? palette.primary : palette.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: palette.textSecondary)),
                  ],
                ),
              ),
              Icon(
                enabled ? (selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded) : Icons.lock_outline_rounded,
                color: selected ? palette.primary : palette.textMuted,
                size: enabled ? 24 : 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow(this.label, this.value, {this.emphasize = false, this.valueColor});
  final String label;
  final double value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = emphasize ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          CurrencyText(value, style: valueColor == null ? style : style?.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}
