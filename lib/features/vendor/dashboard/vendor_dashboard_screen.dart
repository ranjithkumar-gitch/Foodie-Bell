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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: () => context.push('/vendor/notifications'),
              ),
              const NotificationBellDot(),
            ],
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.power_settings_new_rounded),
            onPressed: () => LogoutConfirmationSheet.show(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                shopFrontPhotoUrl != null
                    ? AppNetworkImage(
                        url: shopFrontPhotoUrl,
                        width: 52,
                        height: 52,
                        borderRadius: BorderRadius.circular(14),
                      )
                    : Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: palette.primaryLight.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          vendor.category.icon,
                          color: palette.primary,
                          size: 26,
                        ),
                      ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account?.name ?? vendor.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        account?.category ?? vendor.category.label,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Switch(
                      value: account?.isOpen ?? true,
                      onChanged: (v) =>
                          confirmAndSetVendorOpen(context, ref, vendorId, v),
                    ),
                    Text(
                      (account?.isOpen ?? true) ? 'Open' : 'Closed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: (account?.isOpen ?? true)
                            ? palette.success
                            : palette.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Today's snapshot",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.5,
            children: [
              _KpiCard(
                label: "Today's orders",
                value: '${todaysOrders.length}',
                icon: Icons.receipt_long_rounded,
              ),
              _KpiCard(
                label: "Today's earnings",
                value: AppFormat.currency(todaysEarnings),
                icon: Icons.payments_rounded,
              ),
              _KpiCard(
                label: 'Pending settlement',
                value: AppFormat.currency(pendingSettlement),
                icon: Icons.account_balance_wallet_rounded,
              ),
              _KpiCard(
                label: vendorReviews.isEmpty
                    ? 'Rating'
                    : 'Rating (${vendorReviews.length})',
                value: vendorReviews.isEmpty
                    ? '—'
                    : averageRating.toStringAsFixed(1),
                icon: Icons.star_rounded,
                onTap: () => context.push('/vendor/reviews'),
              ),
            ],
          ),
          if (liveQueueCount > 0) ...[
            const SizedBox(height: 20),
            _NewOrdersBanner(
              count: liveQueueCount,
              onTap: () => context.go('/vendor/orders'),
            ),
          ],
          const SizedBox(height: 24),
          Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.pending_actions_rounded,
            label: 'Live Order Queue',
            trailing: liveQueueCount > 0 ? '$liveQueueCount waiting' : null,
            onTap: () => context.go('/vendor/orders'),
          ),
          _ActionTile(
            icon: Icons.storefront_rounded,
            label: 'Manage Catalogue',
            onTap: () => context.go('/vendor/catalogue'),
          ),
          _ActionTile(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Earnings & Settlement',
            onTap: () => context.push('/vendor/earnings'),
          ),
          _ActionTile(
            icon: Icons.campaign_outlined,
            label: 'Promotions',
            onTap: () => context.push('/vendor/promotions'),
          ),
          _ActionTile(
            icon: Icons.reviews_outlined,
            label: 'Reviews & Ratings',
            onTap: () => context.push('/vendor/reviews'),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: palette.primary, size: 20),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: palette.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: palette.textSecondary),
        ),
      ],
    );
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.border),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Prominent alert shown above Quick Actions whenever a placed order is
/// still waiting on this vendor's Accept/Reject decision — the trailing
/// "waiting" hint on the Live Order Queue tile below is easy to miss, so
/// this surfaces the same [count] as a banner nobody can scroll past
/// without noticing.
class _NewOrdersBanner extends StatelessWidget {
  const _NewOrdersBanner({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Material(
      color: palette.warning.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.warning.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.warning.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: palette.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count == 1
                          ? '1 new order waiting'
                          : '$count new orders waiting',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to review and accept',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.warning),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: palette.textSecondary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  Text(
                    trailing!,
                    style: TextStyle(
                      color: palette.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
