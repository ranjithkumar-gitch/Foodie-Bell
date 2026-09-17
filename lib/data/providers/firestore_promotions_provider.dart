import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/promotion.dart';

/// Vendor promotion requests — one flat `promotions` collection, same
/// pattern as `orders`/`products`. Every role's screen filters this
/// client-side by its own field (`vendorId` for Vendor, `territory` for
/// Manager/Home, unfiltered-but-grouped-by-territory for Admin).
const promotionsCollectionPath = 'promotions';

CollectionReference<Map<String, dynamic>> get promotionsCollection =>
    FirebaseFirestore.instance.collection(promotionsCollectionPath);

Map<String, dynamic> _promotionToDoc(Promotion promo) => {
  'vendorId': promo.vendorId,
  'vendorName': promo.vendorName,
  'vendorPhotoUrl': promo.vendorPhotoUrl,
  'promoImageUrl': promo.promoImageUrl,
  'territory': promo.territory,
  'category': promo.category,
  'tagline': promo.tagline,
  'discountLabel': promo.discountLabel,
  'status': promo.status.name,
  'paymentReceived': promo.paymentReceived,
  'requestedAt': Timestamp.fromDate(promo.requestedAt),
  'reviewedAt': promo.reviewedAt == null
      ? null
      : Timestamp.fromDate(promo.reviewedAt!),
  'rejectionReason': promo.rejectionReason,
  'startDate': Timestamp.fromDate(promo.startDate),
  'durationDays': promo.durationDays,
  'price': promo.price,
};

Promotion _promotionFromDoc(String id, Map<String, dynamic> data) => Promotion(
  id: id,
  vendorId: data['vendorId'] as String? ?? '',
  vendorName: data['vendorName'] as String? ?? '',
  vendorPhotoUrl: data['vendorPhotoUrl'] as String?,
  promoImageUrl: data['promoImageUrl'] as String?,
  territory: data['territory'] as String? ?? '',
  category: data['category'] as String?,
  tagline: data['tagline'] as String?,
  discountLabel: data['discountLabel'] as String?,
  // `.values.byName` throws on any status string outside the enum (e.g. a
  // stray "ended" — never written by this app's own code, but Firestore
  // enforces no schema, so a hand-edited or legacy doc can carry one).
  // Falling back to `rejected` rather than throwing keeps that one doc
  // correctly off Home/Manager's live lists without poisoning the whole
  // stream for every other promotion — see the per-doc try/catch below.
  status: PromotionStatus.values.firstWhere(
    (s) => s.name == data['status'],
    orElse: () => PromotionStatus.rejected,
  ),
  paymentReceived: data['paymentReceived'] as bool? ?? false,
  requestedAt: (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
  rejectionReason: data['rejectionReason'] as String?,
  // Fallbacks cover promotion docs created before these fields existed —
  // start immediately, and no recorded price rather than crashing on a null
  // cast. A missing/null `durationDays` means an open-ended run (the
  // default for a QuickyAdmin-created promotion) rather than a fabricated
  // duration — see [Promotion.isOpenEnded].
  startDate:
      (data['startDate'] as Timestamp?)?.toDate() ??
      (data['requestedAt'] as Timestamp?)?.toDate() ??
      DateTime.now(),
  durationDays: (data['durationDays'] as num?)?.toInt(),
  price: (data['price'] as num?)?.toDouble() ?? 0,
);

/// Every promotion request on the platform, live. A single unparseable doc
/// is skipped, not fatal to the whole list — otherwise one bad document
/// (e.g. a status string outside the enum) would blank every promotion off
/// Home/Manager's queue, not just the bad one.
final firestorePromotionsProvider = StreamProvider<List<Promotion>>((ref) {
  return promotionsCollection.snapshots().map(
    (snapshot) => snapshot.docs
        .map((doc) => _tryPromotionFromDoc(doc.id, doc.data()))
        .whereType<Promotion>()
        .toList(),
  );
});

Promotion? _tryPromotionFromDoc(String id, Map<String, dynamic> data) {
  try {
    return _promotionFromDoc(id, data);
  } catch (e, st) {
    debugPrint('promotions: skipped unparseable doc $id: $e\n$st');
    return null;
  }
}

Future<void> requestPromotion({
  required String vendorId,
  required String vendorName,
  required String territory,
  required DateTime startDate,
  required int durationDays,
  required double price,
  String? vendorPhotoUrl,
  String? promoImageUrl,
  String? category,
  String? tagline,
  String? discountLabel,
}) => promotionsCollection.add(
  _promotionToDoc(
    Promotion(
      id: '',
      vendorId: vendorId,
      vendorName: vendorName,
      vendorPhotoUrl: vendorPhotoUrl,
      promoImageUrl: promoImageUrl,
      territory: territory,
      category: category,
      tagline: tagline,
      discountLabel: discountLabel,
      requestedAt: DateTime.now(),
      startDate: startDate,
      durationDays: durationDays,
      price: price,
    ),
  ),
);

/// Admin-created promotion (`admin_promotion_create_screen.dart`) — unlike
/// [requestPromotion] (a Vendor's request, which starts `pending` and waits
/// on a Territory Manager's payment confirmation + approval), this goes
/// straight to `active` since Admin is authorizing it directly. Called once
/// per targeted territory, so an Admin picking several territories (or
/// `kAllTerritoriesLabel` for "All Territories") produces one document per
/// call — the caller loops.
Future<void> createAdminPromotion({
  required String vendorId,
  required String vendorName,
  required String territory,
  required DateTime startDate,
  required int durationDays,
  required double price,
  String? vendorPhotoUrl,
  String? promoImageUrl,
  String? category,
  String? tagline,
}) => promotionsCollection.add(
  _promotionToDoc(
    Promotion(
      id: '',
      vendorId: vendorId,
      vendorName: vendorName,
      vendorPhotoUrl: vendorPhotoUrl,
      promoImageUrl: promoImageUrl,
      territory: territory,
      category: category,
      tagline: tagline,
      requestedAt: DateTime.now(),
      startDate: startDate,
      durationDays: durationDays,
      price: price,
      status: PromotionStatus.active,
      paymentReceived: true,
      reviewedAt: DateTime.now(),
    ),
  ),
);

Future<void> markPromotionPaymentReceived(String promotionId) =>
    promotionsCollection.doc(promotionId).update({'paymentReceived': true});

/// Only meaningful once [Promotion.paymentReceived] is true — the caller
/// (`manager_promotion_approvals_screen.dart`) gates the Approve action on
/// that already, this doesn't re-check it server-side since there's no
/// Cloud Functions layer in this build to enforce it centrally.
Future<void> approvePromotion(String promotionId) =>
    promotionsCollection.doc(promotionId).update({
      'status': PromotionStatus.active.name,
      'reviewedAt': Timestamp.now(),
    });

Future<void> rejectPromotion(String promotionId, String reason) =>
    promotionsCollection.doc(promotionId).update({
      'status': PromotionStatus.rejected.name,
      'reviewedAt': Timestamp.now(),
      'rejectionReason': reason,
    });
