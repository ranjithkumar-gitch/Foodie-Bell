/// A User's post-delivery rating for a vendor + driver (spec §4.15 "Rate &
/// Review") — real, Firestore-persisted (`firestore_reviews_provider.dart`),
/// visible to the reviewed Vendor (their own "Reviews & Ratings" screen) and
/// to every other User browsing that vendor's storefront.
class Review {
  const Review({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.userName,
    required this.vendorId,
    required this.vendorRating,
    required this.createdAt,
    this.driverId,
    this.driverRating,
    this.comment,
    this.photoUrls = const [],
  });

  final String id;
  final String orderId;

  /// The reviewing User — shown alongside the review on the Vendor's own
  /// "Reviews & Ratings" screen and on the public storefront review list.
  final String userId;
  final String userName;

  final String vendorId;
  final int vendorRating;
  final String? driverId;
  final int? driverRating;
  final String? comment;
  final List<String> photoUrls;
  final DateTime createdAt;
}
