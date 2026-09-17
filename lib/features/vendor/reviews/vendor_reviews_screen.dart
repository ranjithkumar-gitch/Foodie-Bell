import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/firestore_reviews_provider.dart';
import '../../../shared/widgets/empty_state.dart';
import '../vendor_session.dart';

/// Reviews & Ratings received (spec §5.18) — real, live reviews
/// (`firestoreReviewsProvider`) filtered to this vendor's id, so a Vendor
/// can see exactly who rated which order (`Review.userName`/`orderId`).
class VendorReviewsScreen extends ConsumerWidget {
  const VendorReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final vendorId = ref.watch(currentVendorIdProvider);
    final reviewsAsync = ref.watch(firestoreReviewsProvider);
    final reviews = (reviewsAsync.valueOrNull ?? const []).where((r) => r.vendorId == vendorId).toList();

    final average = reviews.isEmpty ? 0.0 : reviews.map((r) => r.vendorRating).reduce((a, b) => a + b) / reviews.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Reviews & Ratings')),
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
                        Text('${reviews.length} review${reviews.length == 1 ? '' : 's'}', style: TextStyle(color: palette.textSecondary, fontSize: 12.5)),
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
                    ? const EmptyState(icon: Icons.reviews_outlined, title: 'No reviews yet', subtitle: "Once customers rate their orders, they'll show up here.")
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
                                    Text(DateFormat('MMM d').format(review.createdAt), style: TextStyle(fontSize: 11.5, color: palette.textMuted)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(children: List.generate(5, (i) => Icon(i < review.vendorRating ? Icons.star_rounded : Icons.star_border_rounded, color: palette.secondary, size: 16))),
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
