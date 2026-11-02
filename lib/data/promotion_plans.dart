/// A fixed-price promotion duration tier — Admin-set pricing (spec's
/// promotion revenue stream), picked by the Vendor on
/// `vendor_promotions_screen.dart`'s request form.
class PromotionPlan {
  const PromotionPlan({required this.days, required this.price});

  final int days;
  final double price;
}

const promotionPlans = [
  PromotionPlan(days: 3, price: 300),
  PromotionPlan(days: 5, price: 400),
  PromotionPlan(days: 7, price: 500),
  PromotionPlan(days: 10, price: 700),
  PromotionPlan(days: 15, price: 1000),
];

/// Paid promotions are paused: their fees can't yet be recorded through
/// the server (no ledger entry, no audit — the Manager's "payment received"
/// was a plain client write), so nothing new is charged and no payment is
/// confirmed from the app until that exists (Phase I finding P1-9).
/// Promotions already marked paid can still be approved, and live ones keep
/// showing. Turn back on only together with a server-recorded payment.
const kPaidPromotionsEnabled = false;
