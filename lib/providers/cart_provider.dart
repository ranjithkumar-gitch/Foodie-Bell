import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_item.dart';
import '../models/menu_item.dart';
import '../models/restaurant.dart';

class CartState {
  const CartState({this.items = const []});

  final List<CartItem> items;

  String? get restaurantId => items.isEmpty ? null : items.first.restaurant.id;

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => items.fold(0, (sum, i) => sum + i.lineTotal);

  bool get isEmpty => items.isEmpty;

  CartState copyWith({List<CartItem>? items}) => CartState(items: items ?? this.items);
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  /// Returns false when the item belongs to a different restaurant than
  /// what's already in the cart, so the UI can confirm clearing it first.
  bool addItem(MenuItem item, Restaurant restaurant) {
    if (state.restaurantId != null && state.restaurantId != restaurant.id) {
      return false;
    }

    final existingIndex = state.items.indexWhere((c) => c.item.id == item.id);
    if (existingIndex >= 0) {
      final updated = [...state.items];
      updated[existingIndex] =
          updated[existingIndex].copyWith(quantity: updated[existingIndex].quantity + 1);
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [
        ...state.items,
        CartItem(item: item, restaurant: restaurant),
      ]);
    }
    return true;
  }

  void replaceWithItem(MenuItem item, Restaurant restaurant) {
    state = CartState(items: [CartItem(item: item, restaurant: restaurant)]);
  }

  void increment(String itemId) {
    state = state.copyWith(
      items: [
        for (final c in state.items)
          if (c.item.id == itemId) c.copyWith(quantity: c.quantity + 1) else c,
      ],
    );
  }

  void decrement(String itemId) {
    final index = state.items.indexWhere((c) => c.item.id == itemId);
    if (index < 0) return;
    final current = state.items[index];
    if (current.quantity <= 1) {
      removeItem(itemId);
      return;
    }
    final updated = [...state.items];
    updated[index] = current.copyWith(quantity: current.quantity - 1);
    state = state.copyWith(items: updated);
  }

  void removeItem(String itemId) {
    state = state.copyWith(items: state.items.where((c) => c.item.id != itemId).toList());
  }

  void clear() {
    state = const CartState();
  }

  int quantityOf(String itemId) {
    final match = state.items.where((c) => c.item.id == itemId);
    return match.isEmpty ? 0 : match.first.quantity;
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());
