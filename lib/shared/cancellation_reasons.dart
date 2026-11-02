import '../l10n/generated/app_localizations.dart';

/// Pre-acceptance rejection reasons — the server's `PRE_ACCEPTANCE_REASONS`
/// (QuickyAdmin `functions/orders.js`). PROVISIONAL beta list, pending
/// business sign-off.
const preAcceptanceReasons = ['itemsUnavailable', 'shopClosingSoon', 'tooBusy', 'cannotPrepareInTime', 'outsideServiceArea', 'other'];

/// Post-acceptance cancellation reasons — the server's `POST_ACCEPTANCE_REASONS`.
const postAcceptanceReasons = [
  'itemsOutOfStockAfterAccept', 'equipmentFailure', 'staffUnavailable', 'qualityIssue',
  'customerRequestedViaShop', 'pricingError', 'emergencyClosure', 'other',
];

/// Minimum remark length for a post-acceptance cancellation (server: 15).
const cancelRemarkMin = 15;

String reasonLabel(AppLocalizations l10n, String code) => switch (code) {
  'itemsUnavailable' => l10n.reasonItemsUnavailable,
  'shopClosingSoon' => l10n.reasonShopClosingSoon,
  'tooBusy' => l10n.reasonTooBusy,
  'cannotPrepareInTime' => l10n.reasonCannotPrepareInTime,
  'outsideServiceArea' => l10n.reasonOutsideServiceArea,
  'itemsOutOfStockAfterAccept' => l10n.reasonItemsOutOfStockAfterAccept,
  'equipmentFailure' => l10n.reasonEquipmentFailure,
  'staffUnavailable' => l10n.reasonStaffUnavailable,
  'qualityIssue' => l10n.reasonQualityIssue,
  'customerRequestedViaShop' => l10n.reasonCustomerRequestedViaShop,
  'pricingError' => l10n.reasonPricingError,
  'emergencyClosure' => l10n.reasonEmergencyClosure,
  _ => l10n.reasonOther,
};
