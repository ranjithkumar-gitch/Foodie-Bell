import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/widgets/currency_text.dart';

/// Order Placed / Confirmation (spec §4.11).
class OrderSuccessScreen extends ConsumerWidget {
  const OrderSuccessScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final orderAsync = ref.watch(orderByIdProvider(orderId));
    final order = orderAsync.valueOrNull;

    if (order == null) {
      return Scaffold(
        backgroundColor: palette.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(color: palette.primaryLight.withValues(alpha: 0.25), shape: BoxShape.circle),
                child: Icon(Icons.check_circle_rounded, color: palette.success, size: 84),
              ),
              const SizedBox(height: 32),
              Text(context.l10n.orderSuccessTitle, style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(order.id, style: TextStyle(color: palette.textMuted, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text(
                context.l10n.orderSuccessMessage(AppFormat.currency(order.total), order.vendorName),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.border)),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: palette.primaryLight.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.delivery_dining_rounded, color: palette.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.l10n.orderSuccessEstimatedDelivery, style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 2),
                          Text(context.l10n.orderSuccessEtaRange, style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/user/order/$orderId'),
                  child: Text(context.l10n.orderSuccessTrackOrder),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/user/home'),
                  child: Text(context.l10n.orderSuccessBackToHome),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
