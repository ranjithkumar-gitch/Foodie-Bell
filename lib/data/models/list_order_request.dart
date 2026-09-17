/// Status machine for an "Order via Photo" request (Pharmacy/Kirana/
/// Vegetables vendors only): a User photographs the items they want, the
/// vendor quotes a price, the User pays in-app, and the vendor confirms
/// with a photo of the receipt — at which point a real `Order` is created
/// (`firestore_list_order_requests_provider.dart`'s
/// `acceptListOrderRequestAndCreateOrder`) so delivery/driver-assignment
/// reuses the platform's normal order pipeline instead of a second one.
enum ListOrderStatus { pending, quoted, paid, accepted, rejected, cancelled }

extension ListOrderStatusX on ListOrderStatus {
  String get label => switch (this) {
    ListOrderStatus.pending => 'Awaiting quote',
    ListOrderStatus.quoted => 'Quoted',
    ListOrderStatus.paid => 'Paid',
    ListOrderStatus.accepted => 'Confirmed',
    ListOrderStatus.rejected => 'Declined',
    ListOrderStatus.cancelled => 'Cancelled',
  };
}

/// A "Order via Photo" request. Deliberately starts unpriced — the User
/// just submits photo(s) of what they want plus a delivery address; the
/// vendor looks at the photos and sets [quotedAmount] themselves since
/// there's no catalogue match/pricing step for a handwritten/loose order.
/// Once the User pays and the vendor confirms with [receiptImageUrl], this
/// becomes a real `Order` ([orderId]) and further tracking (driver
/// assignment, delivery OTP, etc.) happens there instead of here.
class ListOrderRequest {
  const ListOrderRequest({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.imageUrls,
    required this.deliveryAddressLabel,
    required this.status,
    required this.createdAt,
    this.quotedAmount,
    this.receiptImageUrl,
    this.orderId,
  });

  final String id;
  final String vendorId;
  final String vendorName;
  final String userId;
  final String userName;
  final String userPhone;
  final List<String> imageUrls;
  final String deliveryAddressLabel;
  final ListOrderStatus status;
  final DateTime createdAt;

  /// Set by the vendor once they've looked at the photos (`pending -> quoted`).
  final double? quotedAmount;

  /// The vendor's photo of the receipt, set when they confirm
  /// (`paid -> accepted`) — the same moment [orderId] is stamped.
  final String? receiptImageUrl;

  /// The real `Order` created at `paid -> accepted`, once it exists. Null
  /// until then.
  final String? orderId;

  ListOrderRequest copyWith({
    ListOrderStatus? status,
    double? quotedAmount,
    String? receiptImageUrl,
    String? orderId,
  }) => ListOrderRequest(
    id: id,
    vendorId: vendorId,
    vendorName: vendorName,
    userId: userId,
    userName: userName,
    userPhone: userPhone,
    imageUrls: imageUrls,
    deliveryAddressLabel: deliveryAddressLabel,
    status: status ?? this.status,
    createdAt: createdAt,
    quotedAmount: quotedAmount ?? this.quotedAmount,
    receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
    orderId: orderId ?? this.orderId,
  );
}
