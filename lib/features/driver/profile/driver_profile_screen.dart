import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/firestore_reviews_provider.dart';
import '../../../shared/auth/logout_confirmation_sheet.dart';
import '../registration/driver_registration_controller.dart' show DriverVehicleTypeX;
import 'driver_profile_controller.dart';

/// Profile & Vehicle Details (spec §6 item 15): account summary, current
/// vehicle on file, and the menu into Availability/Notifications/Support.
class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final account = ref.watch(sessionControllerProvider.select((s) => s.account));
    final vehicle = ref.watch(driverProfileProvider);
    final myReviews = (ref.watch(firestoreReviewsProvider).valueOrNull ?? const [])
        .where((r) => r.driverId == account?.id && r.driverRating != null)
        .toList();
    final averageRating = myReviews.isEmpty ? 0.0 : myReviews.map((r) => r.driverRating!).reduce((a, b) => a + b) / myReviews.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(gradient: LinearGradient(colors: palette.promoGradient), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Icon(Icons.two_wheeler_rounded, size: 30, color: palette.primary)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account?.name ?? 'Driver', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                      const SizedBox(height: 3),
                      Text('+91 ${account?.phone ?? ''}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                      if (myReviews.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text('${averageRating.toStringAsFixed(1)} (${myReviews.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Vehicle on file', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
            child: Row(
              children: [
                Icon(Icons.two_wheeler_rounded, color: palette.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle.vehicleType.label, style: TextStyle(fontWeight: FontWeight.w800, color: palette.textPrimary)),
                      Text(vehicle.vehicleRegNumber, style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                    ],
                  ),
                ),
                TextButton(onPressed: () => context.push('/driver/profile/edit'), child: const Text('Edit')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _MenuTile(icon: Icons.description_outlined, label: 'My Documents', onTap: () => context.push('/driver/profile/documents')),
          _MenuTile(icon: Icons.reviews_outlined, label: 'My Ratings', onTap: () => context.push('/driver/reviews')),
          _MenuTile(icon: Icons.event_available_rounded, label: 'Availability & Shift Preferences', onTap: () => context.push('/driver/availability')),
          _MenuTile(icon: Icons.notifications_none_rounded, label: 'Notifications', onTap: () => context.push('/driver/notifications')),
          _MenuTile(icon: Icons.receipt_long_rounded, label: 'Order History', onTap: () => context.go('/driver/history')),
          _MenuTile(icon: Icons.help_outline_rounded, label: 'Help & Support', onTap: () => context.push('/driver/help')),
          _MenuTile(icon: Icons.logout_rounded, label: 'Log Out', color: palette.error, onTap: () => LogoutConfirmationSheet.show(context, ref)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap, this.color});
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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
            child: Row(
              children: [
                Icon(icon, color: color ?? palette.textSecondary, size: 22),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color ?? palette.textPrimary))),
                Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
