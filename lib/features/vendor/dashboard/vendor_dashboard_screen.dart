import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/vendor_document.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/firestore_reviews_provider.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../shared/auth/logout_confirmation_sheet.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/notification_count_badge.dart';
import '../vendor_session.dart';

/// Dashboard (spec §5.7): today's order count, earnings snapshot, open/
/// closed toggle, pending settlement amount.
///
/// Kept deliberately plain for small-town shop owners: white cards, one
/// green accent, large text, and a simple menu list instead of tiles.
class VendorDashboardScreen extends ConsumerWidget {
  const VendorDashboardScreen({super.key});

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final sessionAccount = ref.watch(
      sessionControllerProvider.select((s) => s.account),
    );
    // Live lookup, not the session snapshot — a document uploaded while
    // still `pendingReview` never touches the session's cached Account
    // (see `vendor_profile_screen.dart`'s doc comment for why).
    final account = sessionAccount == null
        ? null
        : ref.watch(liveVendorAccountProvider(sessionAccount.id)) ??
              sessionAccount;
    final shopFrontPhotoUrl = account?.documentUrl(
      VendorDocumentType.shopFrontPhoto,
    );
    final vendorId = ref.watch(currentVendorIdProvider);
    final vendor = ref.watch(currentVendorProvider);
    final orders = (ref.watch(firestoreOrdersProvider).valueOrNull ?? const [])
        .where((o) => o.vendorId == vendorId)
        .toList();

    final todaysOrders = orders.where((o) => _isToday(o.placedAt)).toList();
    final todaysDelivered = todaysOrders.where(
      (o) => o.status == OrderStatus.delivered,
    );
    final todaysEarnings = todaysDelivered.fold<double>(
      0,
      (sum, o) => sum + o.total,
    );

    final allDelivered = orders.where((o) => o.status == OrderStatus.delivered);
    final pendingSettlement = allDelivered.fold<double>(
      0,
      (sum, o) => sum + (o.total - o.rebateAmount),
    );

    final liveQueueCount = orders
        .where((o) => o.status == OrderStatus.placed)
        .length;

    final vendorReviews =
        (ref.watch(firestoreReviewsProvider).valueOrNull ?? const [])
            .where((r) => r.vendorId == vendorId)
            .toList();
    final averageRating = vendorReviews.isEmpty
        ? 0.0
        : vendorReviews.map((r) => r.vendorRating).reduce((a, b) => a + b) /
              vendorReviews.length;

    final isOpen = account?.isOpen ?? true;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton.filledTonal(
                tooltip: 'Notifications',
                style: IconButton.styleFrom(
                  backgroundColor: palette.surfaceMuted,
                  foregroundColor: palette.textPrimary,
                ),
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () => context.push('/vendor/notifications'),
              ),
              const NotificationBellDot(),
            ],
          ),
          const SizedBox(width: 6),
          // Red power button, so it reads as "log out" at a glance and
          // isn't mistaken for the notification bell beside it.
          IconButton.filledTonal(
            tooltip: 'Log out',
            style: IconButton.styleFrom(
              backgroundColor: palette.error.withValues(alpha: 0.1),
              foregroundColor: palette.error,
            ),
            icon: const Icon(Icons.power_settings_new_rounded),
            onPressed: () => LogoutConfirmationSheet.show(context, ref),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          // Shop + open/closed.
          _Section(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      shopFrontPhotoUrl != null
                          ? AppNetworkImage(
                              url: shopFrontPhotoUrl,
                              width: 52,
                              height: 52,
                              borderRadius: BorderRadius.circular(12),
                            )
                          : Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: palette.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                vendor.category.icon,
                                color: palette.textSecondary,
                              ),
                            ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account?.name ?? vendor.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              account?.category ?? vendor.category.label,
                              style: TextStyle(
                                fontSize: 14,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: palette.divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOpen ? palette.success : palette.error,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isOpen ? 'Shop is open' : 'Shop is closed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      Switch(
                        value: isOpen,
                        onChanged: (v) =>
                            confirmAndSetVendorOpen(context, ref, vendorId, v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (liveQueueCount > 0) ...[
            const SizedBox(height: 12),
            Material(
              color: palette.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.go('/vendor/orders'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        color: palette.warning,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          liveQueueCount == 1
                              ? '1 new order is waiting'
                              : '$liveQueueCount new orders are waiting',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        'View',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const _SectionTitle('Today'),
          const SizedBox(height: 10),
          _Section(
            child: Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Stat(
                        label: 'Orders',
                        value: Text('${todaysOrders.length}'),
                      ),
                      VerticalDivider(width: 1, color: palette.divider),
                      _Stat(
                        label: 'Earnings',
                        value: CurrencyText(todaysEarnings),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: palette.divider),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Stat(
                        label: 'To be settled',
                        value: CurrencyText(pendingSettlement),
                        onTap: () => context.push('/vendor/earnings'),
                      ),
                      VerticalDivider(width: 1, color: palette.divider),
                      _Stat(
                        label: vendorReviews.isEmpty
                            ? 'Rating'
                            : 'Rating (${vendorReviews.length})',
                        value: Text(
                          vendorReviews.isEmpty
                              ? '—'
                              : '★ ${averageRating.toStringAsFixed(1)}',
                        ),
                        onTap: () => context.push('/vendor/reviews'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('Manage'),
          const SizedBox(height: 10),
          _Section(
            child: Column(
              children: [
                _MenuRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'Orders',
                  trailing: liveQueueCount > 0 ? '$liveQueueCount new' : null,
                  onTap: () => context.go('/vendor/orders'),
                ),
                _MenuRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Products',
                  onTap: () => context.go('/vendor/catalogue'),
                ),
                _MenuRow(
                  icon: Icons.qr_code_2_rounded,
                  label: 'UPI for payments',
                  trailing: account?.primaryUpiId == null ? 'Add now' : null,
                  onTap: () => context.push('/vendor/profile/upi'),
                ),
                _MenuRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Earnings & Payments',
                  onTap: () => context.push('/vendor/earnings'),
                ),
                _MenuRow(
                  icon: Icons.local_offer_outlined,
                  label: 'Offers',
                  onTap: () => context.push('/vendor/promotions'),
                ),
                _MenuRow(
                  icon: Icons.star_outline_rounded,
                  label: 'Reviews',
                  onTap: () => context.push('/vendor/reviews'),
                ),
                _MenuRow(
                  icon: Icons.help_outline_rounded,
                  label: 'Help',
                  onTap: () => context.push('/vendor/help'),
                  showDivider: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A plain white bordered card.
class _Section extends StatelessWidget {
  const _Section({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Text(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: palette.textPrimary,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.onTap});
  final String label;
  final Widget value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: palette.textSecondary),
              ),
              const SizedBox(height: 4),
              DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
                child: value,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.showDivider = true,
  });
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Icon(icon, color: palette.textSecondary, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  Text(
                    trailing!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.warning,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, indent: 54, color: palette.divider),
      ],
    );
  }
}
