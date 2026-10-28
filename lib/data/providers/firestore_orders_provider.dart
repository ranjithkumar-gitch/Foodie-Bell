import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/access_scope.dart';
import '../models/account.dart';
import '../models/order.dart';

/// The persistent order lifecycle every role reads a slice of (User
/// checkout, Vendor accept/reject, Driver assignment/pickup/delivery,
/// Manager/Admin oversight). One flat `orders` collection; each role's
/// query is scoped to what firestore.rules lets it read (see
/// [firestoreOrdersProvider]). Writes go through `order_actions.dart`.
const ordersCollectionPath = 'orders';

CollectionReference<Map<String, dynamic>> get ordersCollection =>
    FirebaseFirestore.instance.collection(ordersCollectionPath);

OrderLineItem _lineItemFromMap(Map<String, dynamic> data) => OrderLineItem(
  productId: data['productId'] as String? ?? '',
  name: data['name'] as String? ?? '',
  price: (data['price'] as num?)?.toDouble() ?? 0,
  imageUrl: data['imageUrl'] as String? ?? '',
  quantity: (data['quantity'] as num?)?.toInt() ?? 1,
  hsnCode: data['hsnCode'] as String?,
  gstRate: (data['gstRate'] as num?)?.toDouble(),
  gstAmount: (data['gstAmount'] as num?)?.toDouble(),
);

Order _orderFromDoc(String id, Map<String, dynamic> data) => Order(
  id: id,
  vendorId: data['vendorId'] as String? ?? '',
  vendorName: data['vendorName'] as String? ?? '',
  userId: data['userId'] as String? ?? '',
  userName: data['userName'] as String? ?? '',
  userPhone: data['userPhone'] as String? ?? '',
  driverId: data['driverId'] as String?,
  driverName: data['driverName'] as String?,
  driverPhone: data['driverPhone'] as String?,
  items: [for (final raw in (data['items'] as List<dynamic>? ?? const [])) _lineItemFromMap(Map<String, dynamic>.from(raw as Map))],
  status: OrderStatus.values.byName(data['status'] as String? ?? 'placed'),
  deliveryAddressLabel: data['deliveryAddressLabel'] as String? ?? '',
  deliveryAddressId: data['deliveryAddressId'] as String?,
  deliveryLatitude: (data['deliveryLatitude'] as num?)?.toDouble(),
  deliveryLongitude: (data['deliveryLongitude'] as num?)?.toDouble(),
  paymentMethod: PaymentMethod.values.byName(data['paymentMethod'] as String? ?? 'cod'),
  subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0,
  deliveryFee: (data['deliveryFee'] as num?)?.toDouble() ?? 0,
  platformFee: (data['platformFee'] as num?)?.toDouble() ?? 0,
  gstAmount: (data['gstAmount'] as num?)?.toDouble() ?? 0,
  total: (data['total'] as num?)?.toDouble() ?? 0,
  placedAt: (data['placedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  statusTimestamps: {
    for (final entry in (data['statusTimestamps'] as Map<String, dynamic>? ?? const {}).entries)
      // A just-written stamp is a pending server timestamp (null) until the
      // write is acknowledged — skip it rather than fail the whole order.
      if (entry.value is Timestamp && OrderStatus.values.any((s) => s.name == entry.key))
        OrderStatus.values.byName(entry.key): (entry.value as Timestamp).toDate(),
  },
  territoryId: data['territoryId'] as String?,
  deliveryAddressFull: data['deliveryAddressFull'] as String?,
  driverLatitude: (data['driverLatitude'] as num?)?.toDouble(),
  driverLongitude: (data['driverLongitude'] as num?)?.toDouble(),
  driverLocationUpdatedAt: (data['driverLocationUpdatedAt'] as Timestamp?)?.toDate(),
  rebatePercent: (data['rebatePercent'] as num?)?.toDouble() ?? 0,
  cancelReason: data['cancelReason'] as String?,
  codPaymentReceived: data['codPaymentReceived'] as bool? ?? false,
  couponCode: data['couponCode'] as String?,
  couponDiscount: (data['couponDiscount'] as num?)?.toDouble() ?? 0,
  paymentId: data['paymentId'] as String?,
  paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
  money: OrderMoney.tryParse(data['money']),
  payment: OrderPayment.tryParse(data['payment']),
  deliveryIssue: DeliveryIssue.tryParse(data['deliveryIssue']),
);

List<Order> _ordersOf(QuerySnapshot<Map<String, dynamic>> snapshot) =>
    [for (final doc in snapshot.docs) _orderFromDoc(doc.id, doc.data())];

/// Statuses of an order still in progress — a small set at any moment,
/// unlike an account's whole history, so it's what the live listeners read.
final activeOrderStatusNames = [
  for (final s in OrderStatus.values)
    if (!s.isTerminal) s.name,
];

/// The field that scopes [scope]'s orders, as `firestore.rules` requires:
/// the account's own orders, or the Manager's territory. Null for roles
/// with no order list (Super Admin uses QuickyAdmin).
(String, String)? _orderScopeField(AccessScope scope) => switch (scope.role) {
  AppRole.user => ('userId', scope.accountId),
  AppRole.vendor => ('vendorId', scope.accountId),
  AppRole.driver => ('driverId', scope.accountId),
  AppRole.manager => scope.territoryId == null ? null : ('territoryId', scope.territoryId!),
  AppRole.admin => null,
};

/// Orders still in progress that the signed-in account may see, live:
///  - Customer / Vendor: their own unfinished orders.
///  - Driver: their current deliveries, plus — once approved — open offers
///    (Vendor-accepted, unassigned) in their territory.
///  - Manager: every unfinished order in their territory.
/// Finished orders are read a page at a time ([orderHistoryProvider]) and
/// totals come from the server's read models (`earnings_provider.dart`), so
/// no screen listens to an account's whole order history (Phase 3).
final activeOrdersProvider = StreamProvider<List<Order>>((ref) {
  final scope = ref.watch(accessScopeProvider);
  if (scope == null) return Stream.value(const []);
  final scoped = _orderScopeField(scope);
  if (scoped == null) return Stream.value(const []);
  final (field, value) = scoped;
  final mine = ordersCollection
      .where(field, isEqualTo: value)
      .where('status', whereIn: activeOrderStatusNames)
      .snapshots()
      .map(_ordersOf);
  final territoryId = scope.territoryId;
  if (scope.role != AppRole.driver || !scope.isActive || territoryId == null) return mine;
  return mergeQueryStreams([
    mine,
    ordersCollection
        .where('territoryId', isEqualTo: territoryId)
        .where('status', isEqualTo: OrderStatus.vendorAccepted.name)
        .snapshots()
        .map(_ordersOf),
  ], (order) => order.id);
});

/// Today's orders (placed since local midnight) for the signed-in Vendor or
/// Manager, live while a dashboard is open.
final todaysOrdersProvider = StreamProvider.autoDispose<List<Order>>((ref) {
  final scope = ref.watch(accessScopeProvider);
  final scoped = scope == null ? null : _orderScopeField(scope);
  if (scoped == null) return Stream.value(const []);
  final now = DateTime.now();
  return ordersCollection
      .where(scoped.$1, isEqualTo: scoped.$2)
      .where('placedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(now.year, now.month, now.day)))
      .orderBy('placedAt', descending: true)
      .snapshots()
      .map(_ordersOf);
});

/// Which part of an account's order history a list shows.
enum OrderHistoryFilter {
  all(null),
  finished(['delivered', 'cancelled', 'rejected']),
  delivered(['delivered']),
  cancelled(['cancelled', 'rejected']);

  const OrderHistoryFilter(this.statuses);
  final List<String>? statuses;
}

Query<Map<String, dynamic>>? _historyQuery(AccessScope? scope, OrderHistoryFilter filter) {
  final scoped = scope == null ? null : _orderScopeField(scope);
  if (scoped == null) return null;
  var query = ordersCollection.where(scoped.$1, isEqualTo: scoped.$2);
  final statuses = filter.statuses;
  if (statuses != null) {
    query = statuses.length == 1 ? query.where('status', isEqualTo: statuses.single) : query.where('status', whereIn: statuses);
  }
  return query;
}

class OrderHistoryState {
  const OrderHistoryState({this.orders = const [], this.loading = false, this.hasMore = true, this.error});
  final List<Order> orders;
  final bool loading;
  final bool hasMore;
  final Object? error;

  OrderHistoryState copyWith({List<Order>? orders, bool? loading, bool? hasMore, Object? error}) =>
      OrderHistoryState(orders: orders ?? this.orders, loading: loading ?? this.loading, hasMore: hasMore ?? this.hasMore, error: error);
}

/// The signed-in account's orders, newest first, [pageSize] at a time —
/// one-time reads, so a long history costs only the pages actually opened.
class OrderHistoryController extends StateNotifier<OrderHistoryState> {
  OrderHistoryController(this._query, {this.pageSize = 20}) : super(const OrderHistoryState()) {
    if (_query == null) {
      state = const OrderHistoryState(hasMore: false);
    } else {
      loadMore();
    }
  }

  final Query<Map<String, dynamic>>? _query;
  final int pageSize;
  DocumentSnapshot<Map<String, dynamic>>? _last;

  Future<void> loadMore() async {
    final query = _query;
    if (query == null || state.loading || !state.hasMore) return;
    state = state.copyWith(loading: true);
    try {
      var page = query.orderBy('placedAt', descending: true).limit(pageSize);
      if (_last != null) page = page.startAfterDocument(_last!);
      final snapshot = await page.get();
      if (!mounted) return;
      if (snapshot.docs.isNotEmpty) _last = snapshot.docs.last;
      state = OrderHistoryState(
        orders: [...state.orders, ..._ordersOf(snapshot)],
        hasMore: snapshot.docs.length == pageSize,
      );
    } catch (e) {
      if (mounted) state = state.copyWith(loading: false, error: e);
    }
  }

  /// Starts again from the newest order (pull to refresh).
  Future<void> refresh() async {
    _last = null;
    state = const OrderHistoryState();
    await loadMore();
  }
}

final orderHistoryProvider =
    StateNotifierProvider.autoDispose.family<OrderHistoryController, OrderHistoryState, OrderHistoryFilter>((ref, filter) {
      return OrderHistoryController(_historyQuery(ref.watch(accessScopeProvider), filter));
    });

/// [history] (one-time pages) with every in-progress order replaced by its
/// live copy from [active] — so statuses keep moving on a history list —
/// newest first.
List<Order> withLiveOrders(List<Order> active, List<Order> history) {
  final byId = {for (final o in history) o.id: o, for (final o in active) o.id: o};
  return byId.values.toList()..sort((a, b) => b.placedAt.compareTo(a.placedAt));
}

/// How many of the signed-in account's orders match [filter] — a server-side
/// count (one read per 1,000 orders), not a download.
final orderCountProvider = FutureProvider.autoDispose.family<int, OrderHistoryFilter>((ref, filter) async {
  final query = _historyQuery(ref.watch(accessScopeProvider), filter);
  if (query == null) return 0;
  final result = await query.count().get();
  return result.count ?? 0;
});

/// A single order, live — used by screens that navigate straight to one
/// order (checkout success, order/vendor/driver detail screens). Disposed
/// when its screen closes.
final orderByIdProvider = StreamProvider.autoDispose.family<Order?, String>((ref, orderId) {
  return ordersCollection.doc(orderId).snapshots().map((doc) {
    final data = doc.data();
    return data == null ? null : _orderFromDoc(doc.id, data);
  });
});

// Orders are created and moved through their lifecycle only by the Cloud
// Functions (`order_actions.dart`); firestore.rules lets the app write
// nothing on an order.

/// The assigned Driver's live position (`order_tracking/{orderId}`, opened
/// and closed by the server). Kept off the order itself so a position
/// update every few seconds doesn't run the order triggers or resend the
/// whole order to everyone watching it.
class DriverPosition {
  const DriverPosition({required this.latitude, required this.longitude, this.updatedAt});
  final double latitude;
  final double longitude;
  final DateTime? updatedAt;
}

DocumentReference<Map<String, dynamic>> _trackingDoc(String orderId) =>
    FirebaseFirestore.instance.collection('order_tracking').doc(orderId);

/// The Driver's position on [orderId], live, for the Customer's map — null
/// until the first fix (or when no Driver is assigned).
final driverPositionProvider = StreamProvider.autoDispose.family<DriverPosition?, String>((ref, orderId) {
  return _trackingDoc(orderId).snapshots().map((doc) {
    final data = doc.data();
    final lat = (data?['latitude'] as num?)?.toDouble();
    final lng = (data?['longitude'] as num?)?.toDouble();
    if (data == null || data['active'] != true || lat == null || lng == null) return null;
    return DriverPosition(latitude: lat, longitude: lng, updatedAt: (data['updatedAt'] as Timestamp?)?.toDate());
  });
});

/// The assigned Driver reporting their position (`driver_location_tracker.dart`).
Future<void> updateOrderDriverLocation(String orderId, {required double latitude, required double longitude}) =>
    _trackingDoc(orderId).update({
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    });
