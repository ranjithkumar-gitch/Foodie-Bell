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

Review _reviewFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data() ?? const <String, dynamic>{};
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

/// How many reviews a list screen shows (newest first). Averages and counts
/// come from the server-kept `rating` on the vendor/driver record, so they
/// cover every review, not just these.
const reviewListLimit = 50;

Stream<List<Review>> _latest(Query<Map<String, dynamic>> query) => query
    .orderBy('createdAt', descending: true)
    .limit(reviewListLimit)
    .snapshots()
    .map((snapshot) => snapshot.docs.map(_reviewFromDoc).toList());

/// One shop's latest reviews (storefront, Vendor's own reviews screen).
final vendorReviewsProvider = StreamProvider.autoDispose.family<List<Review>, String>(
  (ref, vendorId) => _latest(reviewsCollection.where('vendorId', isEqualTo: vendorId)),
);

/// One Driver's latest reviews.
final driverReviewsProvider = StreamProvider.autoDispose.family<List<Review>, String>(
  (ref, driverId) => _latest(reviewsCollection.where('driverId', isEqualTo: driverId)),
);

/// The review of one order, if it has one (doc ID `rev-<orderId>`).
final reviewForOrderProvider = StreamProvider.autoDispose.family<Review?, String>((ref, orderId) {
  return reviewsCollection.doc('rev-$orderId').snapshots().map((doc) => doc.exists ? _reviewFromDoc(doc) : null);
});

/// Submits a new review (`rate_review_screen.dart`) — one per order, enforced
/// by that screen only offering the form when [reviewForOrderProvider]
/// finds none (and by firestore.rules: the doc ID is the order's).
Future<void> submitReview(Review review) => reviewsCollection.doc(review.id).set({
  ..._reviewToDoc(review),
  'createdAt': FieldValue.serverTimestamp(),
});
