import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/time_ago.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/firestore_drivers_provider.dart';
import '../../../data/providers/firestore_reviews_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../driver_session.dart';

/// Ratings received on delivered orders (spec §4.15's driver half of Rate &
/// Review) — the latest reviews naming this driver; the average and count
/// are the server-kept totals over all of them.
/// Mirrors `vendor_reviews_screen.dart`'s shape.
class DriverReviewsScreen extends ConsumerWidget {
  const DriverReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final driverId = ref.watch(currentDriverAccountProvider).id;
    final reviewsAsync = ref.watch(driverReviewsProvider(driverId));
    final reviews = (reviewsAsync.valueOrNull ?? const []).where((r) => r.driverRating != null).toList();

    final average = ref.watch(liveDriverAccountProvider(driverId))?.ratingAverage ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('My Ratings')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
              child: Row(
                children: [
                  Text(average.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 34, color: palette.textPrimary)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: List.generate(5, (i) => Icon(i < average.round() ? Icons.star_rounded : Icons.star_border_rounded, color: palette.secondary, size: 18))),
                        const SizedBox(height: 4),
                        Text('${reviews.length} rating${reviews.length == 1 ? '' : 's'}', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: reviewsAsync.isLoading && reviews.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : reviews.isEmpty
                    ? const EmptyState(icon: Icons.reviews_outlined, title: 'No ratings yet', subtitle: "Once customers rate your deliveries, they'll show up here.")
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: reviews.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          final review = reviews[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(review.userName, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary))),
                                    TimeAgoText(review.createdAt, style: TextStyle(fontSize: 11.5, color: palette.textMuted)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(children: List.generate(5, (i) => Icon(i < review.driverRating! ? Icons.star_rounded : Icons.star_border_rounded, color: palette.secondary, size: 16))),
                                if (review.comment != null) ...[
                                  const SizedBox(height: 8),
                                  Text(review.comment!, style: TextStyle(color: palette.textSecondary)),
                                ],
                                const SizedBox(height: 6),
                                Text('Order ${review.orderId}', style: TextStyle(fontSize: 11, color: palette.textMuted)),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
