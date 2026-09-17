import 'product.dart';

/// A cart line — [product] is the real, Firestore-backed catalogue item;
/// the vendor fields are copied primitives (id/name/delivery fee/rebate),
/// not a live `Vendor`/`Account` reference — same shape `Order`/
/// `OrderLineItem` (`lib/data/models/order.dart`) already use one layer
/// later, so a cart survives whatever browsing-layer type produced it.
class CartItem {
  const CartItem({
    required this.product,
    required this.vendorId,
    required this.vendorName,
    required this.deliveryFee,
    required this.rebatePercent,
    this.quantity = 1,
  });

  final Product product;
  final String vendorId;
  final String vendorName;
  final double deliveryFee;
  final double rebatePercent;
  final int quantity;

  double get lineTotal => product.price * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
    product: product,
    vendorId: vendorId,
    vendorName: vendorName,
    deliveryFee: deliveryFee,
    rebatePercent: rebatePercent,
    quantity: quantity ?? this.quantity,
  );
}
