import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/coupon.dart';
import '../../../data/providers/cart_provider.dart';
import '../../../data/providers/firestore_coupons_provider.dart';
import '../../../data/providers/firestore_tax_categories_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/quantity_stepper.dart';
import '../translation/translated_text.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final _codeController = TextEditingController();
  bool _applyingCoupon = false;
  String? _couponError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  /// Validates [coupon] against the current cart and the signed-in User,
  /// then applies it — shared by both the manual code entry field and the
  /// "View available coupons" sheet so they can never disagree on what
  /// counts as a valid redemption.
  Future<void> _applyCoupon(Coupon coupon) async {
    final cart = ref.read(cartProvider);
    if (coupon.vendorId != cart.vendorId) {
      setState(() => _couponError = context.l10n.cartCouponInvalidVendor);
      return;
    }
    if (!coupon.isLiveNow) {
      setState(() => _couponError = context.l10n.cartCouponExpired);
      return;
    }
    final appliesToCart = cart.items.any((i) => coupon.appliesToProduct(i.product.id));
    if (!appliesToCart) {
      setState(() => _couponError = context.l10n.cartCouponNotApplicable);
      return;
    }

    setState(() {
      _applyingCoupon = true;
      _couponError = null;
    });
    final userId = ref.read(sessionControllerProvider).account?.id;
    final alreadyRedeemed = userId == null
        ? false
        : await hasUserRedeemedCoupon(coupon.id, userId);
    if (!mounted) return;
    if (alreadyRedeemed) {
      setState(() {
        _applyingCoupon = false;
        _couponError = context.l10n.cartCouponAlreadyUsed;
      });
      return;
    }

    ref.read(cartProvider.notifier).applyCoupon(coupon);
    _codeController.clear();
    setState(() => _applyingCoupon = false);
  }

  Future<void> _applyTypedCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    final cart = ref.read(cartProvider);
    final coupons = ref.read(firestoreCouponsProvider).valueOrNull ?? const [];
    final match = coupons
        .where(
          (c) => c.vendorId == cart.vendorId && c.code.toUpperCase() == code.toUpperCase(),
        )
        .toList();
    if (match.isEmpty) {
      setState(() => _couponError = context.l10n.cartCouponNotFound);
      return;
    }
    await _applyCoupon(match.first);
  }

  Future<void> _showAvailableCoupons() async {
    final cart = ref.read(cartProvider);
    final coupons =
        (ref.read(firestoreCouponsProvider).valueOrNull ?? const [])
            .where((c) => c.vendorId == cart.vendorId && c.isLiveNow)
            .toList();
    final picked = await showModalBottomSheet<Coupon>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AvailableCouponsSheet(coupons: coupons),
    );
    if (picked != null) await _applyCoupon(picked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    final deliveryFee = cart.isEmpty ? 0.0 : cart.items.first.deliveryFee;
    final taxCategories = ref.watch(firestoreTaxCategoriesProvider).valueOrNull ?? const [];
    final gstAmount = cart.items.fold<double>(0, (sum, item) => sum + item.lineTotal * resolveProductGst(item.product, taxCategories).gstRate / 100);
    final couponDiscount = cart.couponDiscount;
    final total = cart.subtotal + deliveryFee + gstAmount - couponDiscount;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.cartTitle),
        actions: [
          if (!cart.isEmpty)
            TextButton(
              onPressed: notifier.clear,
              child: Text(context.l10n.cartClear, style: TextStyle(color: palette.error, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: context.l10n.cartEmptyTitle,
              subtitle: context.l10n.cartEmptySubtitle,
              ctaLabel: context.l10n.cartBrowseVendors,
              onCta: () => context.go('/user/home'),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    itemCount: cart.items.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      if (i == cart.items.length) {
                        return _CouponSection(
                          appliedCoupon: cart.appliedCoupon,
                          codeController: _codeController,
                          applying: _applyingCoupon,
                          error: _couponError,
                          onApplyTyped: _applyTypedCode,
                          onViewAvailable: _showAvailableCoupons,
                          onRemove: () {
                            ref.read(cartProvider.notifier).removeCoupon();
                            setState(() => _couponError = null);
                          },
                        );
                      }
                      final cartItem = cart.items[i];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
                        child: Row(
                          children: [
                            AppNetworkImage(url: cartItem.product.imageUrl, width: 64, height: 64, borderRadius: BorderRadius.circular(12)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TranslatedText(cartItem.product.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  CurrencyText(cartItem.product.price, style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => notifier.removeItem(cartItem.product.id),
                                  icon: Icon(Icons.delete_outline_rounded, color: palette.textMuted, size: 20),
                                ),
                                QuantityStepper(
                                  quantity: cartItem.quantity,
                                  compact: true,
                                  onIncrement: () => notifier.increment(cartItem.product.id),
                                  onDecrement: () => notifier.decrement(cartItem.product.id),
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
                    color: palette.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -6))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      children: [
                        _SummaryRow(label: context.l10n.priceSubtotal, value: cart.subtotal),
                        if (couponDiscount > 0)
                          _SummaryRow(
                            label: context.l10n.priceCouponDiscount,
                            value: -couponDiscount,
                            valueColor: palette.success,
                          ),
                        _SummaryRow(label: context.l10n.priceDeliveryFee, value: deliveryFee),
                        _SummaryRow(label: context.l10n.priceGst, value: gstAmount),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                        _SummaryRow(label: context.l10n.priceTotal, value: total, emphasize: true),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.push('/user/checkout/address'),
                          child: Text(context.l10n.cartProceedToCheckout),
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

class _CouponSection extends StatelessWidget {
  const _CouponSection({
    required this.appliedCoupon,
    required this.codeController,
    required this.applying,
    required this.error,
    required this.onApplyTyped,
    required this.onViewAvailable,
    required this.onRemove,
  });

  final Coupon? appliedCoupon;
  final TextEditingController codeController;
  final bool applying;
  final String? error;
  final VoidCallback onApplyTyped;
  final VoidCallback onViewAvailable;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final coupon = appliedCoupon;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
      child: coupon == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: context.l10n.cartCouponCodeHint,
                          prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: applying ? null : onApplyTyped,
                      child: Text(context.l10n.cartCouponApply),
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 6),
                  Text(error!, style: TextStyle(color: palette.error, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 6),
                InkWell(
                  onTap: applying ? null : onViewAvailable,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_offer_outlined, size: 16, color: palette.primary),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.cartCouponViewAvailable,
                          style: TextStyle(color: palette.primary, fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Icon(Icons.confirmation_number_rounded, color: palette.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(coupon.code, style: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary)),
                      Text(coupon.discountLabel, style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onRemove,
                  child: Text(context.l10n.cartCouponRemove, style: TextStyle(color: palette.error)),
                ),
              ],
            ),
    );
  }
}

class _AvailableCouponsSheet extends StatelessWidget {
  const _AvailableCouponsSheet({required this.coupons});
  final List<Coupon> coupons;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),
            Text(context.l10n.cartAvailableCouponsTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            if (coupons.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  context.l10n.cartNoAvailableCoupons,
                  style: TextStyle(color: palette.textSecondary),
                ),
              )
            else
              for (final coupon in coupons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, coupon),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.surfaceMuted,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.local_offer_rounded, color: palette.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(coupon.code, style: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary)),
                                Text(
                                  coupon.appliesToAllItems ? coupon.discountLabel : '${coupon.discountLabel} on select items',
                                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: palette.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.emphasize = false, this.valueColor});
  final String label;
  final double value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
