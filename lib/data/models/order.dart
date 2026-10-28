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

/// `online` is a Razorpay payment (`razorpay_service.dart`) — the User picks
/// UPI/card/netbanking inside Razorpay's own Checkout, which doesn't report
/// back which one was used, so it's recorded as just "online" rather than
/// guessed. `upi`/`card` remain for orders written before that.
enum PaymentMethod { upi, card, wallet, cod, online }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.online => 'Online',
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
    this.territoryId,
    this.deliveryAddressFull,
    this.deliveryAddressId,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.statusTimestamps = const {},
    this.status = OrderStatus.placed,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverLatitude,
    this.driverLongitude,
    this.driverLocationUpdatedAt,
    this.cancelReason,
    this.codPaymentReceived = false,
    this.couponCode,
    this.couponDiscount = 0,
    this.paymentId,
    this.paidAt,
    this.money,
    this.payment,
    this.deliveryIssue,
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

  /// The `addresses` doc this order was placed to — how the Driver side
  /// (`order_drop_off.dart`) reads the drop-off's full street address and
  /// pinned position straight off the saved address, rather than matching
  /// it by [deliveryAddressLabel] text. Null on orders placed before this
  /// was recorded.
  final String? deliveryAddressId;

  /// The delivery address's pinned position (`Address.latitude`/
  /// `longitude`), snapshotted when the order was placed — where the
  /// tracking map draws the drop-off. Null when that address had no pin
  /// (and on orders placed before this existed).
  final double? deliveryLatitude;
  final double? deliveryLongitude;
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

  /// The Vendor's territory, copied on at placement (`firestore.rules`
  /// checks it matches) — what a Manager's and a Driver's access to the
  /// order is scoped by.
  final String? territoryId;

  /// The delivery address written out in full at placement, so the Vendor
  /// and Driver never need to read the Customer's private address book.
  /// Null on orders placed before this was recorded.
  final String? deliveryAddressFull;

  /// The assigned Driver's last reported position
  /// (`driver_location_tracker.dart`), kept on the order itself so the
  /// Customer can follow their own delivery without being able to read any
  /// Driver's record. The pickup and delivery codes aren't on the order at
  /// all — see `order_codes_provider.dart`.
  final double? driverLatitude;
  final double? driverLongitude;
  final DateTime? driverLocationUpdatedAt;

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

  /// The Razorpay payment id (`pay_...`) for an order paid online at
  /// checkout (`razorpay_service.dart`) — the order is only ever written
  /// after Checkout reports success, so a non-null value here means the
  /// money was already collected. Null for COD orders.
  final String? paymentId;

  /// When this order's payment completed: Checkout success for an online
  /// order, the Driver confirming the cash for a COD one. Null for a COD
  /// order whose cash hasn't been collected yet (and for COD orders
  /// collected before this was stamped — see [paymentCompletedAt]).
  final DateTime? paidAt;

  bool get isCod => paymentMethod == PaymentMethod.cod;

  bool get isPaidOnline => paymentId != null;

  /// Money has actually changed hands — online at checkout, or cash handed
  /// to the Driver. A placed-but-uncollected COD order isn't paid.
  bool get isPaid => isPaidOnline || codPaymentReceived;

  /// [paidAt], falling back to the delivery time (cash is collected right
  /// before delivery is confirmed) and then [placedAt] for orders that
  /// predate [paidAt] being stamped.
  DateTime get paymentCompletedAt => paidAt ?? statusTimestamps[OrderStatus.delivered] ?? placedAt;

  /// When this order reached [status], falling back to [placedAt] for
  /// `placed` itself (which predates [statusTimestamps] existing) and
  /// null for any later status the order hasn't reached yet or that
  /// wasn't recorded (orders placed before this was tracked).
  DateTime? statusReachedAt(OrderStatus status) => statusTimestamps[status] ?? (status == OrderStatus.placed ? placedAt : null);

  /// Server money snapshot (Phase 2 orders); null on older orders.
  final OrderMoney? money;

  /// Payment state (Phase 2 orders); null on older orders.
  final OrderPayment? payment;
  final DeliveryIssue? deliveryIssue;

  /// What a Driver was paid per delivery before Phase 2, and the Manager's
  /// share of the commission then — used only for orders without [money],
  /// which are reported as they were, never recomputed.
  static const legacyDriverPayout = 20.0;
  static const legacyManagerSharePercent = 60.0;

  /// The commission on this order (₹): 10% of the item value after the
  /// Vendor's coupon, from [money]; older orders keep their stored rebate %.
  double get rebateAmount => money != null ? money!.commission / 100 : subtotal * rebatePercent / 100;

  /// The territory Manager's 60% of [rebateAmount].
  double get managerShare => money != null ? money!.managerShare / 100 : rebateAmount * legacyManagerSharePercent / 100;

  /// Quicky's 40% of [rebateAmount] (older orders: the rest of the rebate;
  /// their separate platform fee is reported on its own).
  double get quickyShare => money != null ? money!.quickyShare / 100 : rebateAmount - managerShare;

  /// What the Vendor is owed for the goods: item value less commission
  /// (older orders: subtotal less rebate, plus the GST they remit).
  double get vendorEntitlement => money != null ? money!.vendorEntitlement / 100 : subtotal - rebateAmount + gstAmount;

  /// What the Driver earns: the whole delivery fee (older orders: the flat
  /// payout they were promised).
  double get driverEntitlement => money != null ? money!.driverEntitlement / 100 : (driverId == null ? 0 : legacyDriverPayout);

  OrderPaymentStatus get paymentStatus =>
      payment?.status ?? (isCod ? (codPaymentReceived ? OrderPaymentStatus.collected : OrderPaymentStatus.payOnDelivery) : OrderPaymentStatus.unknown);

  /// A UPI order the Vendor hasn't yet confirmed the money for.
  bool get awaitingUpiVerification => paymentStatus == OrderPaymentStatus.awaitingVerification;

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
    deliveryAddressId: deliveryAddressId,
    deliveryLatitude: deliveryLatitude,
    deliveryLongitude: deliveryLongitude,
    paymentMethod: paymentMethod,
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    platformFee: platformFee,
    gstAmount: gstAmount,
    total: total,
    placedAt: placedAt,
    rebatePercent: rebatePercent,
    territoryId: territoryId,
    deliveryAddressFull: deliveryAddressFull,
    statusTimestamps: statusTimestamps,
    status: status ?? this.status,
    driverId: driverId ?? this.driverId,
    driverName: driverName ?? this.driverName,
    driverPhone: driverPhone ?? this.driverPhone,
    driverLatitude: driverLatitude,
    driverLongitude: driverLongitude,
    driverLocationUpdatedAt: driverLocationUpdatedAt,
    cancelReason: cancelReason ?? this.cancelReason,
    codPaymentReceived: codPaymentReceived ?? this.codPaymentReceived,
    couponCode: couponCode,
    couponDiscount: couponDiscount,
    paymentId: paymentId,
    paidAt: paidAt,
    money: money,
    payment: payment,
    deliveryIssue: deliveryIssue,
  );
}

/// An order's money, in paise, worked out by the server when the order was
/// placed (`placeOrder`, QuickyAdmin `functions/money.js`) and never changed
/// afterwards. The authority for every amount and split; null on orders
/// placed before Phase 2, which fall back to the legacy fields (see the
/// getters on [Order]).
class OrderMoney {
  const OrderMoney({
    required this.itemsSubtotal,
    required this.couponDiscount,
    required this.eligibleItemValue,
    required this.deliveryFee,
    this.platformFee = 0,
    required this.customerTotal,
    required this.commission,
    required this.managerShare,
    required this.quickyShare,
    required this.vendorEntitlement,
    required this.driverEntitlement,
  });

  final int itemsSubtotal;
  final int couponDiscount;

  /// Items after the Vendor's coupon — what the 10% commission is taken on.
  final int eligibleItemValue;
  final int deliveryFee;

  /// Quicky's fixed platform fee on this order (0 when it was off), as
  /// charged at the time — 100% Quicky's, outside the commission base.
  final int platformFee;
  final int customerTotal;
  final int commission;
  final int managerShare;
  final int quickyShare;
  final int vendorEntitlement;
  final int driverEntitlement;

  static OrderMoney? tryParse(Object? raw) {
    if (raw is! Map) return null;
    int p(String key) => (raw[key] as num?)?.toInt() ?? 0;
    return OrderMoney(
      itemsSubtotal: p('itemsSubtotal'),
      couponDiscount: p('couponDiscount'),
      eligibleItemValue: p('eligibleItemValue'),
      deliveryFee: p('deliveryFee'),
      platformFee: p('platformFee'),
      customerTotal: p('customerTotal'),
      commission: p('commission'),
      managerShare: p('managerShare'),
      quickyShare: p('quickyShare'),
      vendorEntitlement: p('vendorEntitlement'),
      driverEntitlement: p('driverEntitlement'),
    );
  }
}

/// Where the order's money is, separate from [OrderStatus]:
///  - UPI: the Customer pays the Vendor directly; the Vendor confirms it
///    arrived ([verified]) before accepting. Confirmation is the Vendor's
///    own check of their account — not bank-level proof.
///  - COD: [payOnDelivery] until the Driver records the cash ([collected]).
enum OrderPaymentStatus { awaitingVerification, verified, disputed, failed, unpaidCancelled, refundDue, refunded, payOnDelivery, collected, unknown }

class OrderPayment {
  const OrderPayment({
    required this.status,
    this.vendorUpiId,
    this.amountPaise,
    this.customerReference,
    this.collectedPaise,
    this.shortfallPaise,
    this.issueReason,
  });

  final OrderPaymentStatus status;

  /// The Vendor UPI ID the Customer was asked to pay, as it was at placement.
  final String? vendorUpiId;
  final int? amountPaise;

  /// The UPI reference (UTR) the Customer typed in — their claim, for the
  /// Vendor to match against their account; it proves nothing by itself.
  final String? customerReference;
  final int? collectedPaise;
  final int? shortfallPaise;
  final String? issueReason;

  static OrderPayment? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final status = OrderPaymentStatus.values.where((s) => s.name == raw['status']).firstOrNull ?? OrderPaymentStatus.unknown;
    final issue = raw['issue'];
    return OrderPayment(
      status: status,
      vendorUpiId: raw['vendorUpiId'] as String?,
      amountPaise: (raw['amountPaise'] as num?)?.toInt(),
      customerReference: raw['customerReference'] as String?,
      collectedPaise: (raw['collectedPaise'] as num?)?.toInt(),
      shortfallPaise: (raw['shortfallPaise'] as num?)?.toInt(),
      issueReason: issue is Map ? issue['reason'] as String? : null,
    );
  }
}

/// A Driver's report that a picked-up order couldn't be delivered, waiting
/// for the territory's Manager (`resolveDeliveryIssue`).
class DeliveryIssue {
  const DeliveryIssue({required this.reason, required this.resolved});
  final String reason;
  final bool resolved;

  static DeliveryIssue? tryParse(Object? raw) {
    if (raw is! Map) return null;
    return DeliveryIssue(reason: raw['reason'] as String? ?? '', resolved: raw['resolvedAt'] != null);
  }
}
