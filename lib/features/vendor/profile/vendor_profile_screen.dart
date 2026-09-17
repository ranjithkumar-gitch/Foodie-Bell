import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/vendor.dart';
import '../../../data/models/vendor_document.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../shared/auth/logout_confirmation_sheet.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../vendor_session.dart';

/// Store Profile & Hours Editor (spec §5.17) hub — vendor identity, open/
/// closed status, and links out to every other secondary Vendor screen not
/// on the bottom nav (mirrors `ProfileScreen`'s hub pattern in the User role).
class VendorProfileScreen extends ConsumerWidget {
  const VendorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final sessionAccount = ref.watch(
      sessionControllerProvider.select((s) => s.account),
    );
    // The session's Account is a snapshot from login/last status change —
    // it won't reflect a document the Vendor just uploaded while still
    // `pendingReview` (that only updates Firestore/mock directly, see
    // `vendor_document_checklist.dart`), so look the live record up the
    // same way `vendor_documents_status_screen.dart` does rather than
    // trusting the session snapshot for anything document-related.
    final account = sessionAccount == null ? null : ref.watch(liveVendorAccountProvider(sessionAccount.id)) ?? sessionAccount;
    final vendorId = ref.watch(currentVendorIdProvider);
    final vendor = ref.watch(currentVendorProvider);
    final shopFrontPhotoUrl = account?.documentUrl(VendorDocumentType.shopFrontPhoto);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Profile'),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/vendor/profile/edit'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: palette.promoGradient),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                shopFrontPhotoUrl != null
                    ? AppNetworkImage(url: shopFrontPhotoUrl, width: 60, height: 60, borderRadius: BorderRadius.circular(16))
                    : Container(
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
                      ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account?.name ?? vendor.name,
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        account?.phone ?? vendor.category.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch(
                      value: account?.isOpen ?? true,
                      onChanged: (v) => confirmAndSetVendorOpen(context, ref, vendorId, v),
                    ),
                    Text(
                      (account?.isOpen ?? true) ? 'Open' : 'Closed',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _MenuTile(
            icon: Icons.schedule_rounded,
            label: 'Edit Store Hours',
            onTap: () => context.push('/vendor/profile/hours'),
          ),
          _MenuTile(
            icon: Icons.description_outlined,
            label: 'My Documents',
            onTap: () => context.push('/vendor/profile/documents'),
          ),
          _MenuTile(
            icon: Icons.receipt_long_rounded,
            label: 'Orders',
            onTap: () => context.go('/vendor/orders'),
          ),
          _MenuTile(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Earnings & Settlement',
            onTap: () => context.push('/vendor/earnings'),
          ),
          _MenuTile(
            icon: Icons.campaign_outlined,
            label: 'Promotions',
            onTap: () => context.push('/vendor/promotions'),
          ),
          _MenuTile(
            icon: Icons.category_outlined,
            label: 'Category Manager',
            onTap: () => context.push('/vendor/catalogue/categories'),
          ),
          _MenuTile(
            icon: Icons.reviews_outlined,
            label: 'Reviews & Ratings',
            onTap: () => context.push('/vendor/reviews'),
          ),
          _MenuTile(
            icon: Icons.notifications_none_rounded,
            label: 'Notifications',
            onTap: () => context.push('/vendor/notifications'),
          ),
          _MenuTile(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            onTap: () => context.push('/vendor/help'),
          ),
          _MenuTile(
            icon: Icons.logout_rounded,
            label: 'Log Out',
            color: palette.error,
            onTap: () => LogoutConfirmationSheet.show(context, ref),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

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
                Icon(icon, color: color ?? palette.textSecondary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color ?? palette.textPrimary,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
