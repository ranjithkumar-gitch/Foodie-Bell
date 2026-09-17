import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/review.dart';

/// Real, persistent post-delivery ratings (spec §4.15) — replaces the old
/// `mockReviewsProvider` (in-memory, per-session only) so a review is
/// actually visible to the reviewed Vendor and to every other User browsing
/// that vendor's storefront, not just within the reviewer's own session.
/// One flat collection, filtered client-side by `vendorId`/`orderId` the
/// same way `firestoreOrdersProvider` is filtered by `vendorId` elsewhere,
/// to avoid needing a composite index.
const reviewsCollectionPath = 'reviews';

CollectionReference<Map<String, dynamic>> get reviewsCollection =>
    FirebaseFirestore.instance.collection(reviewsCollectionPath);

Map<String, dynamic> _reviewToDoc(Review review) => {
  'orderId': review.orderId,
  'userId': review.userId,
  'userName': review.userName,
  'vendorId': review.vendorId,
  'vendorRating': review.vendorRating,
  'driverId': review.driverId,
  'driverRating': review.driverRating,
  'comment': review.comment,
  'photoUrls': review.photoUrls,
};

Review _reviewFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  return Review(
    id: doc.id,
    orderId: data['orderId'] as String? ?? '',
    userId: data['userId'] as String? ?? '',
    userName: data['userName'] as String? ?? 'A Quicky customer',
    vendorId: data['vendorId'] as String? ?? '',
    vendorRating: (data['vendorRating'] as num?)?.toInt() ?? 0,
    driverId: data['driverId'] as String?,
    driverRating: (data['driverRating'] as num?)?.toInt(),
    comment: data['comment'] as String?,
    photoUrls: (data['photoUrls'] as List<dynamic>? ?? const []).map((u) => u.toString()).toList(),
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );
}

/// Every review network-wide — `vendor_reviews_screen.dart`,
/// `order_detail_screen.dart` (has-this-order-been-reviewed check), and
/// User's public storefront reviews section all filter this client-side.
final firestoreReviewsProvider = StreamProvider<List<Review>>((ref) {
  return reviewsCollection.snapshots().map((snapshot) {
    final reviews = snapshot.docs.map(_reviewFromDoc).toList();
    final createdAtById = {for (final doc in snapshot.docs) doc.id: doc.data()['createdAt'] as Timestamp?};
    reviews.sort((a, b) {
      final aTime = createdAtById[a.id];
      final bTime = createdAtById[b.id];
      if (aTime == null && bTime == null) return 0;
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      return bTime.compareTo(aTime);
    });
    return reviews;
  });
});

/// Submits a new review (`rate_review_screen.dart`) — one per order, enforced
/// by that screen only offering the form when no existing review for the
/// order is found in [firestoreReviewsProvider].
Future<void> submitReview(Review review) => reviewsCollection.doc(review.id).set({
  ..._reviewToDoc(review),
  'createdAt': FieldValue.serverTimestamp(),
});
