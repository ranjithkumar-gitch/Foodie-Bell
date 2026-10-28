import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/models/review.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_reviews_provider.dart';
import '../../../data/providers/order_codes_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/storage_image.dart';
import '../../../shared/widgets/branded_logo.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/document_viewer_screen.dart';
import '../../../shared/widgets/driver_live_map.dart';
import '../../../shared/widgets/order_status_stepper.dart';
import '../../../shared/widgets/upi_payment_card.dart';
import '../translation/translated_text.dart';
import 'order_tracking_widgets.dart';

String _rateLabel(double rate) =>
    rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString();

/// Combines Order Tracking (Live) (spec §4.12) and Order Detail / Invoice
/// (spec §4.14) into one screen: live status + map + driver contact + OTP
/// for active orders, itemised invoice + reorder always.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  Future<void> _call(BuildContext context, String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.errorPhoneDialer)));
      }
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            friendlyError(e, action: 'Calling driver', stackTrace: st),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final orderAsync = ref.watch(orderByIdProvider(orderId));

    if (orderAsync.isLoading && !orderAsync.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (orderAsync.hasError) {
      return Scaffold(
        body: Center(
          child: Text(
            friendlyError(orderAsync.error!, action: 'Loading order'),
          ),
        ),
      );
    }
    final order = orderAsync.value;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.orderTitleFallback)),
        body: Center(child: Text(context.l10n.orderNotFound)),
      );
    }
    final isActive = !order.status.isTerminal;
    final Review? myReview = ref.watch(reviewForOrderProvider(order.id)).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(order.id)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // UPI: pay the shop, wait for the shop to confirm, or a refund owed.
          if (order.paymentMethod == PaymentMethod.upi &&
              (order.status == OrderStatus.placed ||
                  const {OrderPaymentStatus.disputed, OrderPaymentStatus.refundDue, OrderPaymentStatus.unpaidCancelled, OrderPaymentStatus.failed}
                      .contains(order.paymentStatus))) ...[
            UpiPaymentCard(order: order),
            const SizedBox(height: 16),
          ],
          if (isActive) ...[
            // One bordered card for the whole live-tracking block (map +
            // status + driver contact), the delivery OTP folded into its
            // bottom as a compact banner once picked up — same merged
            // treatment Home's own active-order card uses, instead of a
            // separate map, a separate status card, and a separate
            // full-size OTP card stacked one after another.
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.primary, width: 1.4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Swiggy/Zomato style: while the order is still
                        // with the vendor there's no partner moving to
                        // follow, so a big animated status panel stands in
                        // for the map at the same size — the map takes
                        // over once a Driver is assigned.
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: orderShowsLiveMap(order.status)
                              ? DriverLiveMap(
                                  key: const ValueKey('map'),
                                  order: order,
                                  height: 280,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                )
                              : OrderStageHero(
                                  key: ValueKey(order.status),
                                  order: order,
                                  height: 280,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        OrderStatusStepper(
                          status: order.status,
                          statusTimestamps: order.statusTimestamps,
                        ),
                        if (order.driverName != null) ...[
                          const Divider(),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: palette.primaryLight
                                    .withValues(alpha: 0.25),
                                child: Icon(
                                  Icons.two_wheeler_rounded,
                                  color: palette.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      order.driverName!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      context.l10n.orderDeliveryPartner,
                                      style: TextStyle(
                                        color: palette.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _CircleAction(
                                icon: Icons.call_rounded,
                                onTap: () => _call(context, order.driverPhone),
                              ),
                              const SizedBox(width: 8),
                              _CircleAction(
                                icon: Icons.chat_bubble_rounded,
                                onTap: () => context.push(
                                  '/user/order/${order.id}/chat',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (order.status == OrderStatus.pickedUp)
                    _DeliveryOtpBanner(orderId: order.id),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          Text(
            context.l10n.invoiceTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                // Shop name and delivery address on their own lines — side
                // by side, a long address squeezed the shop name into a
                // narrow, broken column.
                Row(
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 20,
                      color: palette.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.vendorName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 18,
                      color: palette.textSecondary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        order.deliveryAddressLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(),
                ),
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
                              child: StorageImage(
                                source: item.imageUrl,
                                width: 40,
                                height: 40,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          '${item.quantity}x',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TranslatedText(
                                item.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.gstRate != null && item.gstRate! > 0)
                                Text(
                                  context.l10n.invoiceHsnGst(
                                    item.hsnCode ?? '—',
                                    _rateLabel(item.gstRate!),
                                  ),
                                  style: TextStyle(
                                    color: palette.textMuted,
                                    fontSize: 10.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        CurrencyText(
                          item.lineTotal,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(),
                ),
                _PriceRow(context.l10n.priceSubtotal, order.subtotal),
                if (order.couponCode != null)
                  _PriceRow(
                    context.l10n.invoiceCouponLabel(order.couponCode!),
                    -order.couponDiscount,
                    valueColor: palette.success,
                  ),
                _PriceRow(context.l10n.priceDeliveryFee, order.deliveryFee),
                // Only older orders carry these; new orders have neither.
                if (order.platformFee > 0) _PriceRow(context.l10n.pricePlatformFee, order.platformFee),
                if (order.gstAmount > 0) _PriceRow(context.l10n.priceGst, order.gstAmount),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(),
                ),
                _PriceRow(
                  context.l10n.priceTotal,
                  order.total,
                  emphasize: true,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.invoicePaymentMethodLabel,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    Text(
                      order.paymentMethod.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                if (order.isCod) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.invoicePaymentStatusLabel,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        order.codPaymentReceived
                            ? context.l10n.invoicePaymentReceived
                            : context.l10n.invoicePaymentPending,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: order.codPaymentReceived
                              ? palette.success
                              : palette.warning,
                        ),
                      ),
                    ],
                  ),
                ],
                if (order.isPaidOnline) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.invoicePaymentStatusLabel,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        context.l10n.invoicePaymentPaid,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: palette.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.invoicePaymentIdLabel,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        order.paymentId!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (order.status == OrderStatus.delivered) ...[
            const SizedBox(height: 20),
            myReview == null
                ? _RateOrderPrompt(order: order)
                : _MyReviewCard(order: order, review: myReview),
          ],
          const SizedBox(height: 20),
          if (order.status == OrderStatus.delivered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: palette.promoGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const ClipOval(
                      child: BrandedLogo(fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.l10n.thankYouMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.orderEnjoyedMessage(order.vendorName),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
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

class _RateOrderPrompt extends StatelessWidget {
  const _RateOrderPrompt({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.star_rounded, color: palette.secondary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.rateOrderQuestion,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  order.driverName != null
                      ? context.l10n.rateOrderVendorAndDriver(
                          order.vendorName,
                          order.driverName!,
                        )
                      : context.l10n.rateOrderVendorOnly(order.vendorName),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => context.push('/user/rate/${order.id}'),
            child: Text(context.l10n.rateButton),
          ),
        ],
      ),
    );
  }
}

class _MyReviewCard extends StatelessWidget {
  const _MyReviewCard({required this.order, required this.review});
  final Order order;
  final Review review;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.yourReviewTitle,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  order.vendorName,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.vendorRating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: palette.secondary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          if (review.driverRating != null && order.driverName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.driverName!,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.driverRating!
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: palette.secondary,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (review.comment != null) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: TextStyle(color: palette.textSecondary),
            ),
          ],
        ],
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
      child: CircleAvatar(
        radius: 18,
        backgroundColor: palette.primary,
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

/// The delivery OTP, folded into the bottom of the live-tracking card as a
/// compact gradient banner — same treatment as Home's own active-order
/// card, instead of a separate full-size [DeliveryOtpCard] stacked below
/// it.
class _DeliveryOtpBanner extends ConsumerWidget {
  const _DeliveryOtpBanner({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Generated by the server just after placement; dots until it lands.
    final otp = ref.watch(orderDeliveryCodeProvider(orderId)).valueOrNull ?? '····';
    final palette = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.promoGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.password_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Share this code with your delivery partner',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              otp,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow(
    this.label,
    this.value, {
    this.emphasize = false,
    this.valueColor,
  });
  final String label;
  final double value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.colors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          CurrencyText(
            value,
            style: valueColor == null
                ? style
                : style?.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}
