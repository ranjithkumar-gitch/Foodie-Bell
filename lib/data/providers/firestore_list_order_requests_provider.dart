import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/list_order_request.dart';
import '../models/order.dart';
import 'firestore_orders_provider.dart' show ordersCollection, orderToDoc;

/// Real, persistent "Order via Photo" requests (`list_order_capture_screen.dart`
/// on the User side, the "Photo Orders" tab of `vendor_order_queue_screen.dart`
/// on the Vendor side) — same flat-collection-filtered-client-side pattern as
/// `firestore_reviews_provider.dart`/`firestore_promotions_provider.dart`, to
/// avoid needing a composite index for `vendorId`/`userId` filtering.
const listOrderRequestsCollectionPath = 'list_order_requests';

CollectionReference<Map<String, dynamic>> get listOrderRequestsCollection =>
    FirebaseFirestore.instance.collection(listOrderRequestsCollectionPath);

Map<String, dynamic> _requestToDoc(ListOrderRequest request) => {
  'vendorId': request.vendorId,
  'vendorName': request.vendorName,
  'userId': request.userId,
  'userName': request.userName,
  'userPhone': request.userPhone,
  'imageUrls': request.imageUrls,
  'deliveryAddressLabel': request.deliveryAddressLabel,
  'status': request.status.name,
  'quotedAmount': request.quotedAmount,
  'receiptImageUrl': request.receiptImageUrl,
  'orderId': request.orderId,
};

ListOrderRequest _requestFromDoc(
  QueryDocumentSnapshot<Map<String, dynamic>> doc,
) => _requestFromData(doc.id, doc.data());

ListOrderRequest _requestFromData(String id, Map<String, dynamic> data) {
  return ListOrderRequest(
    id: id,
    vendorId: data['vendorId'] as String? ?? '',
    vendorName: data['vendorName'] as String? ?? '',
    userId: data['userId'] as String? ?? '',
    userName: data['userName'] as String? ?? '',
    userPhone: data['userPhone'] as String? ?? '',
    imageUrls: (data['imageUrls'] as List<dynamic>? ?? const [])
        .map((e) => e as String)
        .toList(),
    deliveryAddressLabel: data['deliveryAddressLabel'] as String? ?? '',
    status: ListOrderStatus.values.firstWhere(
      (s) => s.name == data['status'],
      orElse: () => ListOrderStatus.pending,
    ),
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    quotedAmount: (data['quotedAmount'] as num?)?.toDouble(),
    receiptImageUrl: data['receiptImageUrl'] as String?,
    orderId: data['orderId'] as String?,
  );
}

/// Every photo-order request network-wide — the User side filters to its
/// own `userId`, the Vendor side to its own `vendorId`, same as
/// [firestoreReviewsProvider]/`firestoreOrdersProvider`.
final firestoreListOrderRequestsProvider =
    StreamProvider<List<ListOrderRequest>>((ref) {
      return listOrderRequestsCollection.snapshots().map((snapshot) {
        final requests = snapshot.docs.map(_requestFromDoc).toList();
        final createdAtById = {
          for (final doc in snapshot.docs)
            doc.id: doc.data()['createdAt'] as Timestamp?,
        };
        requests.sort((a, b) {
          final aTime = createdAtById[a.id];
          final bTime = createdAtById[b.id];
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        return requests;
      });
    });

/// A single photo-order request, live — used by the User's status/tracking
/// screen so it doesn't depend on the unfiltered stream having synced yet
/// (same reasoning as `orderByIdProvider`).
final listOrderRequestByIdProvider = StreamProvider.family<ListOrderRequest?, String>((ref, id) {
  return listOrderRequestsCollection.doc(id).snapshots().map((doc) {
    final data = doc.data();
    return data == null ? null : _requestFromData(doc.id, data);
  });
});

Future<void> submitListOrderRequest(ListOrderRequest request) =>
    listOrderRequestsCollection.doc(request.id).set({
      ..._requestToDoc(request),
      'createdAt': FieldValue.serverTimestamp(),
    });

/// Vendor sets a price after looking at the photos (`pending -> quoted`).
Future<void> quoteListOrderRequest(String id, double amount) =>
    listOrderRequestsCollection.doc(id).update({
      'status': ListOrderStatus.quoted.name,
      'quotedAmount': amount,
    });

/// User completes the (simulated) in-app payment (`quoted -> paid`).
Future<void> markListOrderRequestPaid(String id) =>
    listOrderRequestsCollection.doc(id).update({
      'status': ListOrderStatus.paid.name,
    });

/// Vendor declines a request that hasn't been quoted yet.
Future<void> declineListOrderRequest(String id) =>
    listOrderRequestsCollection.doc(id).update({
      'status': ListOrderStatus.rejected.name,
    });

/// User backs out before paying (from `pending` or `quoted`).
Future<void> cancelListOrderRequest(String id) =>
    listOrderRequestsCollection.doc(id).update({
      'status': ListOrderStatus.cancelled.name,
    });

/// Vendor confirms a paid request with a photo of the receipt
/// (`paid -> accepted`) — atomically stamps the request and creates the
/// real `Order` that driver assignment/delivery now tracks, so the two
/// documents can never end up out of sync with each other.
Future<void> acceptListOrderRequestAndCreateOrder({
  required String requestId,
  required String receiptImageUrl,
  required Order order,
}) async {
  final batch = FirebaseFirestore.instance.batch();
  batch.update(listOrderRequestsCollection.doc(requestId), {
    'status': ListOrderStatus.accepted.name,
    'receiptImageUrl': receiptImageUrl,
    'orderId': order.id,
  });
  batch.set(ordersCollection.doc(order.id), orderToDoc(order));
  await batch.commit();
}
