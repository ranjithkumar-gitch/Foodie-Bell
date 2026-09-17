import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_item.dart';
import '../models/coupon.dart';
import '../models/product.dart';
import 'firestore_carts_provider.dart';

class CartState {
  const CartState({this.items = const [], this.appliedCoupon});

  final List<CartItem> items;

  /// Set by `CartNotifier.applyCoupon` (`cart_screen.dart`) — deliberately
  /// not persisted to the `carts/{userId}` Firestore doc alongside [items]:
  /// a coupon is vendor/time-scoped and re-validating fresh on every apply
  /// is simpler and safer than trusting a stale persisted value across
  /// sessions.
  final Coupon? appliedCoupon;

  String? get vendorId => items.isEmpty ? null : items.first.vendorId;

  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => items.fold(0, (sum, i) => sum + i.lineTotal);

  bool get isEmpty => items.isEmpty;

  /// ₹ amount [appliedCoupon] discounts off [subtotal] — 0 when no coupon
  /// is applied or when none of the cart's items qualify (e.g. every
  /// matching item was removed after the coupon was applied). Computed off
  /// the matching items' subtotal, not the whole cart's, per
  /// [Coupon.appliesToProduct].
  double get couponDiscount {
    final coupon = appliedCoupon;
    if (coupon == null) return 0;
    final matchingSubtotal = items
        .where((i) => coupon.appliesToProduct(i.product.id))
        .fold<double>(0, (sum, i) => sum + i.lineTotal);
    if (matchingSubtotal <= 0) return 0;
    return coupon.discountType == CouponDiscountType.percentage
        ? matchingSubtotal * coupon.discountValue / 100
        : coupon.discountValue.clamp(0, matchingSubtotal);
  }

  CartState copyWith({List<CartItem>? items, Coupon? appliedCoupon, bool clearCoupon = false}) => CartState(
    items: items ?? this.items,
    appliedCoupon: clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
  );
}

/// Local state stays the source of truth for the UI — every mutation below
/// applies instantly, same as before — but each one also fires a
/// background write to `carts/{userId}` (`firestore_carts_provider.dart`)
/// so the cart survives logout/app-restart. [loadForUser]/[clearLocal] are
/// called from `session_controller.dart` on login/logout respectively,
/// mirroring how it already resets the Firestore *stream* providers on
/// those same transitions — deliberately a one-shot load rather than a
/// live stream, so this doesn't reintroduce the same class of staleness
/// bug `firestore_stream_reset.dart` exists to prevent.
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  String? _userId;

  /// Loads this user's saved cart once, on login. Only applies it if
  /// nothing's been added locally in the meantime — the load is async and
  /// a fast tap right after login could otherwise race it and get its item
  /// silently wiped out when the load resolves.
  Future<void> loadForUser(String userId) async {
    _userId = userId;
    final items = await loadCart(userId);
    if (!mounted || state.items.isNotEmpty) return;
    state = CartState(items: items);
  }

  /// Clears the in-memory cart on logout without touching the Firestore
  /// doc, so it's still there to restore on the next login.
  void clearLocal() {
    _userId = null;
    state = const CartState();
  }

  void _persist() {
    final userId = _userId;
    if (userId == null) return;
    saveCart(userId, state.items);
  }

  /// Returns false when the product belongs to a different vendor than
  /// what's already in the cart, so the UI can confirm clearing it first.
  bool addItem(Product product, {required String vendorId, required String vendorName, required double deliveryFee, required double rebatePercent}) {
    if (state.vendorId != null && state.vendorId != vendorId) {
      return false;
    }

    final existingIndex = state.items.indexWhere((c) => c.product.id == product.id);
    if (existingIndex >= 0) {
      final updated = [...state.items];
      updated[existingIndex] =
          updated[existingIndex].copyWith(quantity: updated[existingIndex].quantity + 1);
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [
        ...state.items,
        CartItem(product: product, vendorId: vendorId, vendorName: vendorName, deliveryFee: deliveryFee, rebatePercent: rebatePercent),
      ]);
    }
    _persist();
    return true;
  }

  void replaceWithItem(Product product, {required String vendorId, required String vendorName, required double deliveryFee, required double rebatePercent}) {
    state = CartState(items: [CartItem(product: product, vendorId: vendorId, vendorName: vendorName, deliveryFee: deliveryFee, rebatePercent: rebatePercent)]);
    _persist();
  }

  void increment(String productId) {
    state = state.copyWith(
      items: [
        for (final c in state.items)
          if (c.product.id == productId) c.copyWith(quantity: c.quantity + 1) else c,
      ],
    );
    _persist();
  }

  void decrement(String productId) {
    final index = state.items.indexWhere((c) => c.product.id == productId);
    if (index < 0) return;
    final current = state.items[index];
    if (current.quantity <= 1) {
      removeItem(productId);
      return;
    }
    final updated = [...state.items];
    updated[index] = current.copyWith(quantity: current.quantity - 1);
    state = state.copyWith(items: updated);
    _persist();
  }

  void removeItem(String productId) {
    state = state.copyWith(items: state.items.where((c) => c.product.id != productId).toList());
    _persist();
  }

  void clear() {
    state = const CartState();
    _persist();
  }

  /// Assumes the caller (`cart_screen.dart`'s `_applyCoupon`) already
  /// validated the coupon against the current cart — vendor match, live
  /// window, applies-to-something-in-cart, and not-already-redeemed.
  void applyCoupon(Coupon coupon) {
    state = state.copyWith(appliedCoupon: coupon);
  }

  void removeCoupon() {
    state = state.copyWith(clearCoupon: true);
  }

  int quantityOf(String productId) {
    final match = state.items.where((c) => c.product.id == productId);
    return match.isEmpty ? 0 : match.first.quantity;
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());
