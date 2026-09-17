/// The platform-wide order lifecycle (spec's "golden loop": Discover → Order
/// → Accept → Assign → Pickup → Deliver → Settle). Every role reads or
/// writes a slice of this same status list: User tracking, Vendor queue,
/// Driver delivery flow, Manager settlement, Admin oversight.
enum OrderStatus { placed, vendorAccepted, driverAssigned, pickedUp, delivered, cancelled, rejected }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.placed => 'Order Placed',
    OrderStatus.vendorAccepted => 'Vendor Accepted',
    OrderStatus.driverAssigned => 'Driver Assigned',
    OrderStatus.pickedUp => 'Picked Up',
    OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Cancelled',
    OrderStatus.rejected => 'Rejected',
  };

  bool get isTerminal => this == OrderStatus.delivered || this == OrderStatus.cancelled || this == OrderStatus.rejected;
}

enum PaymentMethod { upi, card, wallet, cod }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.upi => 'UPI',
    PaymentMethod.card => 'Card',
    PaymentMethod.wallet => 'Wallet',
    PaymentMethod.cod => 'Cash on Delivery',
  };
}

class OrderLineItem {
  const OrderLineItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.quantity,
    this.hsnCode,
    this.gstRate,
    this.gstAmount,
  });

  final String productId;
  final String name;
  final double price;
  final String imageUrl;
  final int quantity;

  /// GST resolved and snapshotted at the moment this order was placed
  /// (`resolveProductGst`, `checkout_payment_screen.dart`) — kept as its
  /// own frozen copy on the order rather than re-resolved from the live
  /// product later, since HSN codes/rates change over time and a past
  /// invoice must keep reflecting the rate that actually applied at
  /// purchase (`GST_HSN_IMPLEMENTATION.md` §6). Null on orders placed
  /// before this existed.
  final String? hsnCode;

  /// Percentage, e.g. `5`, `12`, `18`.
  final double? gstRate;

  /// Absolute GST amount for this line (`lineTotal * gstRate / 100`) —
  /// stored rather than recomputed so rounding is frozen too.
  final double? gstAmount;

  double get lineTotal => price * quantity;
}

/// A single order as it moves through the platform lifecycle. Frozen shape
/// so User/Vendor/Driver/Manager/Admin screens all mutate the same record
/// via `firestoreOrdersProvider` instead of five disconnected copies.
class Order {
  const Order({
    required this.id,
    required this.vendorId,
    required this.vendorName,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.items,
    required this.deliveryAddressLabel,
    required this.paymentMethod,
    required this.subtotal,
    required this.deliveryFee,
    required this.platformFee,
    required this.gstAmount,
    required this.total,
    required this.placedAt,
    required this.rebatePercent,
    this.statusTimestamps = const {},
    this.status = OrderStatus.placed,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.handoverCode = '4821',
    this.deliveryOtp = '7734',
    this.cancelReason,
    this.codPaymentReceived = false,
    this.couponCode,
    this.couponDiscount = 0,
  });

  final String id;
  final String vendorId;
  final String vendorName;
  final String userId;
  final String userName;
  final String userPhone;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final List<OrderLineItem> items;
  final OrderStatus status;

  /// When this order first reached each status it's passed through so
  /// far — set once per status by `updateOrderStatus`/`cancelOrder`
  /// (`firestore_orders_provider.dart`) via a dotted-field Firestore
  /// update, never overwritten once recorded. Read via [statusReachedAt];
  /// empty for orders placed before this was tracked, or for a status the
  /// order hasn't reached yet.
  final Map<OrderStatus, DateTime> statusTimestamps;
  final String deliveryAddressLabel;
  final PaymentMethod paymentMethod;
  final double subtotal;
  final double deliveryFee;
  final double platformFee;

  /// Sum of every line item's [OrderLineItem.gstAmount], snapshotted at
  /// order placement time and included in [total] — see
  /// [OrderLineItem.gstAmount]'s doc comment for why this is frozen rather
  /// than re-resolved. 0 for orders placed before GST tracking existed.
  final double gstAmount;
  final double total;
  final DateTime placedAt;

  /// Handed to the Driver by the Vendor at pickup, confirmed by Driver's app.
  final String handoverCode;

  /// Shown to the User during tracking, confirmed by Driver at drop-off.
  final String deliveryOtp;

  /// % of order value routed to the Manager, negotiated 10-20 band (spec §5.5, §7.11).
  final double rebatePercent;
  final String? cancelReason;

  /// The redeemed coupon's code (`coupon.dart`), snapshotted at order
  /// placement time so a later change/deletion of the coupon doc never
  /// changes what a past invoice shows. Null when no coupon was applied.
  final String? couponCode;

  /// Absolute ₹ amount [couponCode] discounted off this order, already
  /// subtracted from [total] — shown as its own invoice line wherever the
  /// order's price breakdown is displayed. 0 when no coupon was applied.
  final double couponDiscount;

  /// Confirmed by the Driver on the Cash Collection screen when handing
  /// over a COD order — independent of [status] reaching `delivered`,
  /// since a driver collects cash first and only then confirms the
  /// delivery OTP/photo.
  final bool codPaymentReceived;

  bool get isCod => paymentMethod == PaymentMethod.cod;

  /// When this order reached [status], falling back to [placedAt] for
  /// `placed` itself (which predates [statusTimestamps] existing) and
  /// null for any later status the order hasn't reached yet or that
  /// wasn't recorded (orders placed before this was tracked).
  DateTime? statusReachedAt(OrderStatus status) => statusTimestamps[status] ?? (status == OrderStatus.placed ? placedAt : null);

  double get rebateAmount => subtotal * rebatePercent / 100;

  Order copyWith({
    OrderStatus? status,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? cancelReason,
    bool? codPaymentReceived,
  }) => Order(
    id: id,
    vendorId: vendorId,
    vendorName: vendorName,
    userId: userId,
    userName: userName,
    userPhone: userPhone,
    items: items,
    deliveryAddressLabel: deliveryAddressLabel,
    paymentMethod: paymentMethod,
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    platformFee: platformFee,
    gstAmount: gstAmount,
    total: total,
    placedAt: placedAt,
    rebatePercent: rebatePercent,
    statusTimestamps: statusTimestamps,
    status: status ?? this.status,
    driverId: driverId ?? this.driverId,
    driverName: driverName ?? this.driverName,
    driverPhone: driverPhone ?? this.driverPhone,
    handoverCode: handoverCode,
    deliveryOtp: deliveryOtp,
    cancelReason: cancelReason ?? this.cancelReason,
    codPaymentReceived: codPaymentReceived ?? this.codPaymentReceived,
    couponCode: couponCode,
    couponDiscount: couponDiscount,
  );
}
