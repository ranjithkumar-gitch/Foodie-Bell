import 'menu_item.dart';
import 'restaurant.dart';

class CartItem {
  const CartItem({
    required this.item,
    required this.restaurant,
    this.quantity = 1,
  });

  final MenuItem item;
  final Restaurant restaurant;
  final int quantity;

  double get lineTotal => item.price * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      item: item,
      restaurant: restaurant,
      quantity: quantity ?? this.quantity,
    );
  }
}
