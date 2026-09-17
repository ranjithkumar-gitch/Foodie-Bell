/// Shared constants for the User role's browsing/cart screens — mirrors
/// `ManagerConstants`'s pattern of centralizing demo-fixed values.
class UserConstants {
  UserConstants._();

  /// Flat platform delivery fee applied to every order. Real Vendor
  /// accounts (`firestore_vendors_provider.dart`) have no per-vendor
  /// delivery-fee field — that was a mock-storefront-only concept — so a
  /// flat fee stands in until/unless that becomes a real
  /// Manager/Vendor-configurable value.
  static const defaultDeliveryFee = 20.0;
}
