import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/cart_provider.dart';
import '../../../data/providers/firestore_addresses_provider.dart';
import '../../../data/providers/order_actions.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/widgets/currency_text.dart';
import '../address_label_text.dart';
import '../translation/translated_text.dart';

/// The server's price for a cart, keyed by a JSON description of it
/// ({vendorId, addressId, couponId, items}) so it's re-asked only when one
/// of those changes.
final _checkoutQuoteProvider = FutureProvider.autoDispose.family<OrderQuote, String>((ref, key) {
  final k = jsonDecode(key) as Map<String, dynamic>;
  return quoteOrder(
    vendorId: k['vendorId'] as String,
    addressId: k['addressId'] as String,
    couponId: k['couponId'] as String?,
    items: [for (final i in k['items'] as List) (productId: i[0] as String, quantity: i[1] as int)],
  );
});

/// Checkout – Payment Method (spec §4.10): Cash on Delivery, or UPI paid
/// straight to the shop when the shop has a UPI ID.
///
/// Every amount here comes from the server (`quoteOrder`): item prices from
/// the shop's catalogue, the delivery fee by road distance from the shop,
/// the Vendor's coupon, Quicky's platform fee (set by the Super Admin; a
/// line of its own whenever it is charged), and the total. No GST line
/// while GST is off. `placeOrder` works it all out again when the
/// order is placed — the app only says what was chosen.
///
/// A UPI order is placed first and paid afterwards, from the order screen
/// (`UpiPaymentCard`): the shop accepts it only once they've seen the money
/// arrive. Online card payment (Razorpay) isn't offered for new orders.
class CheckoutPaymentScreen extends ConsumerStatefulWidget {
  const CheckoutPaymentScreen({super.key});

  @override
  ConsumerState<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends ConsumerState<CheckoutPaymentScreen> {
  PaymentMethod _payment = PaymentMethod.cod;
  bool _placingOrder = false;
  String? _error;

  /// Same for every retry of this checkout, so a repeated tap or a retried
  /// request returns the order already placed instead of a second one.
  final String _idempotencyKey = List.generate(24, (_) => Random.secure().nextInt(36).toRadixString(36)).join();

  void _selectPayment(PaymentMethod method) {
    if (_placingOrder) return;
    setState(() {
      _payment = method;
      _error = null;
    });
  }

  Future<void> _placeOrder(String quoteKey) async {
    final k = jsonDecode(quoteKey) as Map<String, dynamic>;
    setState(() {
      _placingOrder = true;
      _error = null;
    });
    try {
      final orderId = await placeOrder(
        idempotencyKey: _idempotencyKey,
        vendorId: k['vendorId'] as String,
        addressId: k['addressId'] as String,
        couponId: k['couponId'] as String?,
        items: [for (final i in k['items'] as List) (productId: i[0] as String, quantity: i[1] as int)],
        paymentMethod: _payment,
        expectedTotalPaise: ref.read(_checkoutQuoteProvider(quoteKey)).valueOrNull?.money.customerTotal,
      );
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      context.go('/user/order-success/$orderId');
    } on OrderActionException catch (e) {
      if (!mounted) return;
      setState(() {
        _placingOrder = false;
        _error = e.message;
      });
      // Prices or availability may have changed: show the new quote.
      ref.invalidate(_checkoutQuoteProvider(quoteKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final cart = ref.watch(cartProvider);
    final address = ref.watch(selectedAddressProvider);
    final vendorId = cart.items.isEmpty ? '' : cart.items.first.vendorId;
    final quoteKey = cart.isEmpty || address == null
        ? null
        : jsonEncode({
            'vendorId': vendorId,
            'addressId': address.id,
            'couponId': cart.appliedCoupon?.id,
            'items': [for (final i in cart.items) [i.product.id, i.quantity]],
          });
    final quoteAsync = quoteKey == null ? null : ref.watch(_checkoutQuoteProvider(quoteKey));
    final quote = quoteAsync?.valueOrNull;
    final quoteError = quoteAsync?.error;
    final upiAvailable = quote?.vendorUpiId != null;
    if (_payment == PaymentMethod.upi && quote != null && !upiAvailable) _payment = PaymentMethod.cod;
    final money = quote?.money;
    final total = money == null ? null : money.customerTotal / 100;

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
                _PaymentTile(icon: Icons.payments_outlined, label: context.l10n.paymentCod, subtitle: context.l10n.paymentCodSubtitle, selected: _payment == PaymentMethod.cod, onTap: () => _selectPayment(PaymentMethod.cod)),
                const SizedBox(height: 10),
                _PaymentTile(
                  icon: Icons.qr_code_2_rounded,
                  label: context.l10n.paymentUpi,
                  subtitle: upiAvailable
                      ? 'Pay the shop directly from your UPI app after placing the order. The shop confirms when the money arrives.'
                      : 'This shop doesn’t accept UPI yet',
                  selected: _payment == PaymentMethod.upi,
                  enabled: upiAvailable,
                  onTap: () => _selectPayment(PaymentMethod.upi),
                ),
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
                if (address == null)
                  Text('Choose a delivery address to see the delivery fee.', style: TextStyle(color: palette.textSecondary))
                else if (quoteError != null)
                  Text(quoteError is OrderActionException ? quoteError.message : 'We couldn’t price this order. Please try again.',
                      style: TextStyle(color: palette.error, fontWeight: FontWeight.w600))
                else if (money == null)
                  const Padding(padding: EdgeInsets.all(8), child: Center(child: CircularProgressIndicator()))
                else ...[
                  _PriceRow(context.l10n.priceSubtotal, money.itemsSubtotal / 100),
                  if (money.couponDiscount > 0)
                    _PriceRow(context.l10n.priceCouponDiscount, -money.couponDiscount / 100, valueColor: palette.success),
                  _PriceRow('${context.l10n.priceDeliveryFee} (${quote!.distanceKm.toStringAsFixed(1)} km)', money.deliveryFee / 100),
                  if (money.platformFee > 0) _PriceRow(context.l10n.pricePlatformFee, money.platformFee / 100),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                  _PriceRow(context.l10n.priceTotal, money.customerTotal / 100, emphasize: true),
                ],
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
            onPressed: (quoteKey == null || total == null || _placingOrder) ? null : () => _placeOrder(quoteKey),
            child: _placingOrder
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                : Text(total == null ? context.l10n.checkoutPaymentTitle : context.l10n.checkoutPlaceOrder(AppFormat.currency(total))),
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
          Flexible(child: Text(label, style: style)),
          CurrencyText(value, style: valueColor == null ? style : style?.copyWith(color: valueColor)),
        ],
      ),
    );
  }
}
