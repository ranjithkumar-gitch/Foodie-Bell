import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class ProfilePlaceholderScreen extends StatelessWidget {
  const ProfilePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: AppColors.promoGradient),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person_rounded, size: 34, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Alex Morgan', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white)),
                          const SizedBox(height: 3),
                          Text('alex.morgan@email.com',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _MenuTile(icon: Icons.receipt_long_rounded, label: 'Order History'),
              _MenuTile(icon: Icons.location_on_outlined, label: 'Saved Addresses'),
              _MenuTile(icon: Icons.payment_rounded, label: 'Payment Methods'),
              _MenuTile(icon: Icons.notifications_none_rounded, label: 'Notifications'),
              _MenuTile(icon: Icons.help_outline_rounded, label: 'Help & Support'),
              _MenuTile(icon: Icons.logout_rounded, label: 'Log Out', color: AppColors.accentRed),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, this.color});
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Icon(icon, color: color ?? AppColors.textSecondary, size: 22),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: color ?? AppColors.textPrimary))),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
