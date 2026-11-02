/// Shared constants for the Manager role's screens.
class ManagerConstants {
  ManagerConstants._();

  // The commission split is never hardcoded in the app: each order carries
  // the server's snapshot of it (`Order.money`), and the live rate comes
  // from `pricingRatesProvider` (Phase I.8 removed the old 60/40 constants).
}
