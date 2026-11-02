import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('te'),
  ];

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hungry, {name}?'**
  String homeGreeting(Object name);

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search vendors or products'**
  String get searchHint;

  /// No description provided for @homeSelectedTerritoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected Territory'**
  String get homeSelectedTerritoryLabel;

  /// No description provided for @homeLoadingTerritories.
  ///
  /// In en, this message translates to:
  /// **'Loading territories…'**
  String get homeLoadingTerritories;

  /// No description provided for @homeSelectTerritory.
  ///
  /// In en, this message translates to:
  /// **'Select territory'**
  String get homeSelectTerritory;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find the best vendors around you'**
  String get homeSubtitle;

  /// No description provided for @homeOrderingWindow.
  ///
  /// In en, this message translates to:
  /// **'Ordering window: {window}'**
  String homeOrderingWindow(Object window);

  /// No description provided for @homeCheckVendorForHours.
  ///
  /// In en, this message translates to:
  /// **'Check vendor for hours'**
  String get homeCheckVendorForHours;

  /// No description provided for @homeCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get homeCategoryOther;

  /// No description provided for @homeNoVendorsForCategory.
  ///
  /// In en, this message translates to:
  /// **'No {category} vendors yet'**
  String homeNoVendorsForCategory(Object category);

  /// No description provided for @homeNoVendorsYet.
  ///
  /// In en, this message translates to:
  /// **'No vendors here yet'**
  String get homeNoVendorsYet;

  /// No description provided for @homeSelectTerritorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your delivery territory above to see vendors near you.'**
  String get homeSelectTerritorySubtitle;

  /// No description provided for @homeNoVendorsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We don\'t have any vendors in {territory} yet. Check back soon, or try a different territory.'**
  String homeNoVendorsSubtitle(Object territory);

  /// No description provided for @homeChangeTerritory.
  ///
  /// In en, this message translates to:
  /// **'Change territory'**
  String get homeChangeTerritory;

  /// No description provided for @homeOrderIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Order {orderId}'**
  String homeOrderIdLabel(Object orderId);

  /// No description provided for @homeAllChipLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get homeAllChipLabel;

  /// No description provided for @homePromotedBadge.
  ///
  /// In en, this message translates to:
  /// **'PROMOTED'**
  String get homePromotedBadge;

  /// No description provided for @homeOrderNowCta.
  ///
  /// In en, this message translates to:
  /// **'Order Now'**
  String get homeOrderNowCta;

  /// No description provided for @homeBrandBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Support your local vendors'**
  String get homeBrandBannerTitle;

  /// No description provided for @homeBrandBannerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every order helps a nearby vendor grow'**
  String get homeBrandBannerSubtitle;

  /// No description provided for @storefrontClosedBadge.
  ///
  /// In en, this message translates to:
  /// **'CLOSED'**
  String get storefrontClosedBadge;

  /// No description provided for @storefrontOpenNow.
  ///
  /// In en, this message translates to:
  /// **'OPEN'**
  String get storefrontOpenNow;

  /// No description provided for @productOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get productOutOfStock;

  /// No description provided for @productVendorClosed.
  ///
  /// In en, this message translates to:
  /// **'Vendor closed'**
  String get productVendorClosed;

  /// No description provided for @productAddButton.
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get productAddButton;

  /// No description provided for @priceSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get priceSubtotal;

  /// No description provided for @priceDeliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery fee'**
  String get priceDeliveryFee;

  /// No description provided for @pricePlatformFee.
  ///
  /// In en, this message translates to:
  /// **'Platform fee'**
  String get pricePlatformFee;

  /// No description provided for @priceCouponDiscount.
  ///
  /// In en, this message translates to:
  /// **'Coupon discount'**
  String get priceCouponDiscount;

  /// No description provided for @priceTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get priceTotal;

  /// No description provided for @itemPricesInclusiveOfTaxes.
  ///
  /// In en, this message translates to:
  /// **'Item prices are inclusive of applicable taxes.'**
  String get itemPricesInclusiveOfTaxes;

  /// No description provided for @pricesInclusiveOfTaxes.
  ///
  /// In en, this message translates to:
  /// **'Prices inclusive of applicable taxes.'**
  String get pricesInclusiveOfTaxes;

  /// No description provided for @priceLegacyTax.
  ///
  /// In en, this message translates to:
  /// **'Taxes (charged on this earlier order)'**
  String get priceLegacyTax;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// No description provided for @addressLabelHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get addressLabelHome;

  /// No description provided for @addressLabelWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get addressLabelWork;

  /// No description provided for @addressLabelOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get addressLabelOther;

  /// No description provided for @cartTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Cart'**
  String get cartTitle;

  /// No description provided for @cartClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get cartClear;

  /// No description provided for @cartEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty'**
  String get cartEmptyTitle;

  /// No description provided for @cartEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore vendors near you and find something you need.'**
  String get cartEmptySubtitle;

  /// No description provided for @cartBrowseVendors.
  ///
  /// In en, this message translates to:
  /// **'Browse Vendors'**
  String get cartBrowseVendors;

  /// No description provided for @cartProceedToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Checkout'**
  String get cartProceedToCheckout;

  /// No description provided for @cartCouponCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter coupon code'**
  String get cartCouponCodeHint;

  /// No description provided for @cartCouponApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get cartCouponApply;

  /// No description provided for @cartCouponViewAvailable.
  ///
  /// In en, this message translates to:
  /// **'View available coupons'**
  String get cartCouponViewAvailable;

  /// No description provided for @cartCouponRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get cartCouponRemove;

  /// No description provided for @cartCouponAppliedLabel.
  ///
  /// In en, this message translates to:
  /// **'Coupon {code} applied'**
  String cartCouponAppliedLabel(Object code);

  /// No description provided for @cartCouponInvalidVendor.
  ///
  /// In en, this message translates to:
  /// **'This coupon isn\'t valid for this vendor'**
  String get cartCouponInvalidVendor;

  /// No description provided for @cartCouponExpired.
  ///
  /// In en, this message translates to:
  /// **'This coupon isn\'t active right now'**
  String get cartCouponExpired;

  /// No description provided for @cartCouponNotApplicable.
  ///
  /// In en, this message translates to:
  /// **'This coupon doesn\'t apply to any item in your cart'**
  String get cartCouponNotApplicable;

  /// No description provided for @cartCouponAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already used this coupon'**
  String get cartCouponAlreadyUsed;

  /// No description provided for @cartCouponNotFound.
  ///
  /// In en, this message translates to:
  /// **'Invalid coupon code'**
  String get cartCouponNotFound;

  /// No description provided for @cartAvailableCouponsTitle.
  ///
  /// In en, this message translates to:
  /// **'Available coupons'**
  String get cartAvailableCouponsTitle;

  /// No description provided for @cartNoAvailableCoupons.
  ///
  /// In en, this message translates to:
  /// **'No coupons available for this vendor right now'**
  String get cartNoAvailableCoupons;

  /// No description provided for @checkoutAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get checkoutAddressTitle;

  /// No description provided for @checkoutAddNewAddress.
  ///
  /// In en, this message translates to:
  /// **'Add new address'**
  String get checkoutAddNewAddress;

  /// No description provided for @checkoutDeliverHere.
  ///
  /// In en, this message translates to:
  /// **'Deliver Here'**
  String get checkoutDeliverHere;

  /// No description provided for @checkoutPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get checkoutPaymentTitle;

  /// No description provided for @checkoutDeliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery address'**
  String get checkoutDeliveryAddress;

  /// No description provided for @checkoutPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get checkoutPaymentMethod;

  /// No description provided for @paymentCod.
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery'**
  String get paymentCod;

  /// No description provided for @paymentCodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay when your order arrives'**
  String get paymentCodSubtitle;

  /// No description provided for @paymentUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get paymentUpi;

  /// No description provided for @paymentComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get paymentComingSoon;

  /// No description provided for @paymentCard.
  ///
  /// In en, this message translates to:
  /// **'Credit / Debit Card'**
  String get paymentCard;

  /// No description provided for @paymentWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get paymentWallet;

  /// No description provided for @paymentOnline.
  ///
  /// In en, this message translates to:
  /// **'UPI / Cards'**
  String get paymentOnline;

  /// No description provided for @paymentOnlineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'UPI, credit / debit cards, netbanking & more'**
  String get paymentOnlineSubtitle;

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled. Your order was not placed.'**
  String get paymentCancelled;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment could not be completed. Please try again.'**
  String get paymentFailed;

  /// No description provided for @paymentOrderSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Your payment went through, but we couldn\'t place the order. Please contact support with payment ID {paymentId}.'**
  String paymentOrderSaveFailed(Object paymentId);

  /// No description provided for @paymentUpiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay with GPay, PhonePe, Paytm or any UPI app'**
  String get paymentUpiSubtitle;

  /// No description provided for @paymentChooseUpiApp.
  ///
  /// In en, this message translates to:
  /// **'Choose a UPI app'**
  String get paymentChooseUpiApp;

  /// No description provided for @paymentNoUpiApp.
  ///
  /// In en, this message translates to:
  /// **'No UPI app found on this phone. Please install one or choose another payment method.'**
  String get paymentNoUpiApp;

  /// No description provided for @paymentUpiConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Did your payment go through?'**
  String get paymentUpiConfirmTitle;

  /// No description provided for @paymentUpiConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm the payment from your UPI app. Tap Yes only if the amount was debited.'**
  String get paymentUpiConfirmMessage;

  /// No description provided for @paymentUpiConfirmNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get paymentUpiConfirmNo;

  /// No description provided for @paymentUpiConfirmYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, I paid'**
  String get paymentUpiConfirmYes;

  /// No description provided for @paymentUpiPending.
  ///
  /// In en, this message translates to:
  /// **'Your payment is pending. We\'ll confirm your order once it completes. Reference: {transactionId}'**
  String paymentUpiPending(Object transactionId);

  /// No description provided for @invoicePaymentPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get invoicePaymentPaid;

  /// No description provided for @invoicePaymentIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment ID'**
  String get invoicePaymentIdLabel;

  /// No description provided for @transactionsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get transactionsEmptyTitle;

  /// No description provided for @transactionsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your payments will show up here'**
  String get transactionsEmptySubtitle;

  /// No description provided for @transactionPaidVia.
  ///
  /// In en, this message translates to:
  /// **'Paid via {method}'**
  String transactionPaidVia(Object method);

  /// No description provided for @checkoutOrderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order summary'**
  String get checkoutOrderSummary;

  /// No description provided for @checkoutPlaceOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order · {amount}'**
  String checkoutPlaceOrder(Object amount);

  /// No description provided for @checkoutPayAndPlaceOrder.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String checkoutPayAndPlaceOrder(Object amount);

  /// No description provided for @orderSuccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Order placed!'**
  String get orderSuccessTitle;

  /// No description provided for @orderSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Your order for {amount} from {vendorName} has been confirmed and is being prepared.'**
  String orderSuccessMessage(Object amount, Object vendorName);

  /// No description provided for @orderSuccessEstimatedDelivery.
  ///
  /// In en, this message translates to:
  /// **'Estimated delivery'**
  String get orderSuccessEstimatedDelivery;

  /// No description provided for @orderSuccessEtaRange.
  ///
  /// In en, this message translates to:
  /// **'25 - 35 min'**
  String get orderSuccessEtaRange;

  /// No description provided for @orderSuccessTrackOrder.
  ///
  /// In en, this message translates to:
  /// **'Track Order'**
  String get orderSuccessTrackOrder;

  /// No description provided for @orderSuccessBackToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get orderSuccessBackToHome;

  /// No description provided for @searchRecentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecentSearches;

  /// No description provided for @searchTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get searchTrending;

  /// No description provided for @searchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResultsTitle;

  /// No description provided for @searchNoResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term'**
  String get searchNoResultsSubtitle;

  /// No description provided for @searchProductsHeading.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get searchProductsHeading;

  /// No description provided for @searchVendorsHeading.
  ///
  /// In en, this message translates to:
  /// **'Vendors'**
  String get searchVendorsHeading;

  /// No description provided for @searchFallbackBiryani.
  ///
  /// In en, this message translates to:
  /// **'Biryani'**
  String get searchFallbackBiryani;

  /// No description provided for @searchFallbackBurgers.
  ///
  /// In en, this message translates to:
  /// **'Burgers'**
  String get searchFallbackBurgers;

  /// No description provided for @searchFallbackVitaminC.
  ///
  /// In en, this message translates to:
  /// **'Vitamin C'**
  String get searchFallbackVitaminC;

  /// No description provided for @searchFallbackFreshVegetables.
  ///
  /// In en, this message translates to:
  /// **'Fresh Vegetables'**
  String get searchFallbackFreshVegetables;

  /// No description provided for @searchFallbackMilkshake.
  ///
  /// In en, this message translates to:
  /// **'Milkshake'**
  String get searchFallbackMilkshake;

  /// No description provided for @errorPhoneDialer.
  ///
  /// In en, this message translates to:
  /// **'Could not open the phone dialer.'**
  String get errorPhoneDialer;

  /// No description provided for @orderTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get orderTitleFallback;

  /// No description provided for @orderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found'**
  String get orderNotFound;

  /// No description provided for @orderDeliveryPartner.
  ///
  /// In en, this message translates to:
  /// **'Your delivery partner'**
  String get orderDeliveryPartner;

  /// No description provided for @invoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get invoiceTitle;

  /// No description provided for @invoicePaymentMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get invoicePaymentMethodLabel;

  /// No description provided for @invoicePaymentStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment status'**
  String get invoicePaymentStatusLabel;

  /// No description provided for @invoicePaymentReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get invoicePaymentReceived;

  /// No description provided for @invoicePaymentPending.
  ///
  /// In en, this message translates to:
  /// **'Pending on delivery'**
  String get invoicePaymentPending;

  /// No description provided for @invoiceCouponLabel.
  ///
  /// In en, this message translates to:
  /// **'Coupon ({code})'**
  String invoiceCouponLabel(Object code);

  /// No description provided for @thankYouMessage.
  ///
  /// In en, this message translates to:
  /// **'Thank you for ordering with Quicky!'**
  String get thankYouMessage;

  /// No description provided for @orderEnjoyedMessage.
  ///
  /// In en, this message translates to:
  /// **'We hope you enjoyed your order from {vendorName}.'**
  String orderEnjoyedMessage(Object vendorName);

  /// No description provided for @rateOrderQuestion.
  ///
  /// In en, this message translates to:
  /// **'How was your order?'**
  String get rateOrderQuestion;

  /// No description provided for @rateOrderVendorOnly.
  ///
  /// In en, this message translates to:
  /// **'Rate {vendorName}.'**
  String rateOrderVendorOnly(Object vendorName);

  /// No description provided for @rateOrderVendorAndDriver.
  ///
  /// In en, this message translates to:
  /// **'Rate {vendorName} and {driverName}.'**
  String rateOrderVendorAndDriver(Object vendorName, Object driverName);

  /// No description provided for @rateButton.
  ///
  /// In en, this message translates to:
  /// **'Rate'**
  String get rateButton;

  /// No description provided for @yourReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Your review'**
  String get yourReviewTitle;

  /// No description provided for @myOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrdersTitle;

  /// No description provided for @ordersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get ordersEmptyTitle;

  /// No description provided for @ordersEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Orders you place will show up here.'**
  String get ordersEmptySubtitle;

  /// No description provided for @orderItemsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} item} other{{count} items}} · {orderId}'**
  String orderItemsSummary(int count, Object orderId);

  /// No description provided for @chatDriverFallback.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get chatDriverFallback;

  /// No description provided for @storefrontVendorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Vendor not found.'**
  String get storefrontVendorNotFound;

  /// No description provided for @storefrontNoRatings.
  ///
  /// In en, this message translates to:
  /// **'No ratings'**
  String get storefrontNoRatings;

  /// No description provided for @storefrontRatingSummary.
  ///
  /// In en, this message translates to:
  /// **'{rating} ({count})'**
  String storefrontRatingSummary(Object rating, Object count);

  /// No description provided for @storefrontClosedMessage.
  ///
  /// In en, this message translates to:
  /// **'This vendor is currently closed and not accepting orders.'**
  String get storefrontClosedMessage;

  /// No description provided for @storefrontCategoryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This shop\'s category isn\'t available in your area right now, so it can\'t take orders here.'**
  String get storefrontCategoryUnavailable;

  /// No description provided for @storefrontNoProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get storefrontNoProductsYet;

  /// No description provided for @storefrontCartItemsBadge.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} item} other{{count} items}}'**
  String storefrontCartItemsBadge(int count);

  /// No description provided for @storefrontViewCart.
  ///
  /// In en, this message translates to:
  /// **'View Cart'**
  String get storefrontViewCart;

  /// No description provided for @storefrontStartNewCartTitle.
  ///
  /// In en, this message translates to:
  /// **'Start a new cart?'**
  String get storefrontStartNewCartTitle;

  /// No description provided for @storefrontStartNewCartMessage.
  ///
  /// In en, this message translates to:
  /// **'Your cart has items from another vendor. Add items from {vendorName} instead?'**
  String storefrontStartNewCartMessage(Object vendorName);

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @storefrontStartNew.
  ///
  /// In en, this message translates to:
  /// **'Start New'**
  String get storefrontStartNew;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileGuestFallback.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get profileGuestFallback;

  /// No description provided for @profileOrderHistory.
  ///
  /// In en, this message translates to:
  /// **'Order History'**
  String get profileOrderHistory;

  /// No description provided for @profileSavedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get profileSavedAddresses;

  /// No description provided for @profileWalletRefunds.
  ///
  /// In en, this message translates to:
  /// **'Wallet & Refunds'**
  String get profileWalletRefunds;

  /// No description provided for @profileWalletComingSoonMessage.
  ///
  /// In en, this message translates to:
  /// **'We\'re building your Quicky wallet — refunds, credits, and cashback will land here soon.'**
  String get profileWalletComingSoonMessage;

  /// No description provided for @profileHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get profileHelpSupport;

  /// No description provided for @profileLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get profileLogOut;

  /// No description provided for @profileComingSoonBadge.
  ///
  /// In en, this message translates to:
  /// **'COMING SOON'**
  String get profileComingSoonBadge;

  /// No description provided for @profileLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguage;

  /// No description provided for @profileLanguageDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose language'**
  String get profileLanguageDialogTitle;

  /// No description provided for @profileCategorySettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileCategorySettings;

  /// No description provided for @profileCategoryTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get profileCategoryTransactions;

  /// No description provided for @profileCategoryFoodDelivery.
  ///
  /// In en, this message translates to:
  /// **'Food Delivery'**
  String get profileCategoryFoodDelivery;

  /// No description provided for @profileTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get profileTransactionHistory;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfileTitle;

  /// No description provided for @editProfilePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Update profile photo'**
  String get editProfilePhotoTitle;

  /// No description provided for @editProfileFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get editProfileFullName;

  /// No description provided for @editProfileYourNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get editProfileYourNameHint;

  /// No description provided for @editProfileEmailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get editProfileEmailOptional;

  /// No description provided for @editProfileMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get editProfileMobileNumber;

  /// No description provided for @editProfileNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name.'**
  String get editProfileNameRequired;

  /// No description provided for @editProfileSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get editProfileSaveChanges;

  /// No description provided for @addressesScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get addressesScreenTitle;

  /// No description provided for @addressesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses'**
  String get addressesEmptyTitle;

  /// No description provided for @addressesEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a delivery address to get started'**
  String get addressesEmptySubtitle;

  /// No description provided for @addressesAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add Address'**
  String get addressesAddButton;

  /// No description provided for @addressDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get addressDefaultBadge;

  /// No description provided for @addressNotServiceableBadge.
  ///
  /// In en, this message translates to:
  /// **'NOT SERVICEABLE'**
  String get addressNotServiceableBadge;

  /// No description provided for @addressRemoveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove address'**
  String get addressRemoveTooltip;

  /// No description provided for @addAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Address'**
  String get addAddressTitle;

  /// No description provided for @addAddressLabelHeading.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get addAddressLabelHeading;

  /// No description provided for @addAddressRecipientName.
  ///
  /// In en, this message translates to:
  /// **'Recipient\'s name'**
  String get addAddressRecipientName;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @addAddressPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get addAddressPhoneNumber;

  /// No description provided for @addAddressPhoneDigitsError.
  ///
  /// In en, this message translates to:
  /// **'10 digits'**
  String get addAddressPhoneDigitsError;

  /// No description provided for @addAddressHouseStreet.
  ///
  /// In en, this message translates to:
  /// **'House/flat & street'**
  String get addAddressHouseStreet;

  /// No description provided for @addAddressLandmarkOptional.
  ///
  /// In en, this message translates to:
  /// **'Landmark (optional)'**
  String get addAddressLandmarkOptional;

  /// No description provided for @addAddressPincode.
  ///
  /// In en, this message translates to:
  /// **'Pincode'**
  String get addAddressPincode;

  /// No description provided for @addAddressPincodeDigitsError.
  ///
  /// In en, this message translates to:
  /// **'6 digits'**
  String get addAddressPincodeDigitsError;

  /// No description provided for @addAddressCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get addAddressCity;

  /// No description provided for @addAddressSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save Address'**
  String get addAddressSaveButton;

  /// No description provided for @addAddressPinHeading.
  ///
  /// In en, this message translates to:
  /// **'Delivery location'**
  String get addAddressPinHeading;

  /// No description provided for @addAddressPinRequired.
  ///
  /// In en, this message translates to:
  /// **'Pin the exact delivery location on the map before saving.'**
  String get addAddressPinRequired;

  /// No description provided for @addAddressPinFromAddress.
  ///
  /// In en, this message translates to:
  /// **'Find the address above on the map'**
  String get addAddressPinFromAddress;

  /// No description provided for @addAddressPinConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Location pinned on the map'**
  String get addAddressPinConfirmed;

  /// No description provided for @addAddressPinChange.
  ///
  /// In en, this message translates to:
  /// **'Adjust pin'**
  String get addAddressPinChange;

  /// No description provided for @addAddressPinNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that address on the map. Check it, or use your current location.'**
  String get addAddressPinNotFound;

  /// No description provided for @pinScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm delivery location'**
  String get pinScreenTitle;

  /// No description provided for @pinScreenHint.
  ///
  /// In en, this message translates to:
  /// **'Move the map so the pin sits on the entrance.'**
  String get pinScreenHint;

  /// No description provided for @pinScreenConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm this location'**
  String get pinScreenConfirm;

  /// No description provided for @addressNotPinned.
  ///
  /// In en, this message translates to:
  /// **'Not pinned on the map yet. Pin it to get deliveries here.'**
  String get addressNotPinned;

  /// No description provided for @addressPinThis.
  ///
  /// In en, this message translates to:
  /// **'Pin this address'**
  String get addressPinThis;

  /// No description provided for @addressPinNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find this address on the map'**
  String get addressPinNotFoundTitle;

  /// No description provided for @addressPinNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'Start from where your phone is now instead? You\'ll still move the pin to the exact spot and confirm it.'**
  String get addressPinNotFoundBody;

  /// No description provided for @addressPinUseMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Start from my location'**
  String get addressPinUseMyLocation;

  /// No description provided for @addressPinNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get addressPinNotNow;

  /// No description provided for @addressPinNoLocation.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read your location. Turn on location (GPS) and allow it, then try again.'**
  String get addressPinNoLocation;

  /// No description provided for @addressPinSaved.
  ///
  /// In en, this message translates to:
  /// **'Address pinned.'**
  String get addressPinSaved;

  /// No description provided for @checkoutAddressNeedsPin.
  ///
  /// In en, this message translates to:
  /// **'Pin this address on the map before ordering.'**
  String get checkoutAddressNeedsPin;

  /// No description provided for @cartItemsTotal.
  ///
  /// In en, this message translates to:
  /// **'Items total'**
  String get cartItemsTotal;

  /// No description provided for @cartFeesAtCheckout.
  ///
  /// In en, this message translates to:
  /// **'The delivery fee (by distance) and any platform fee are added at checkout.'**
  String get cartFeesAtCheckout;

  /// No description provided for @deliveryFeeFrom.
  ///
  /// In en, this message translates to:
  /// **'From {amount}'**
  String deliveryFeeFrom(Object amount);

  /// No description provided for @addAddressUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get addAddressUseCurrentLocation;

  /// No description provided for @addAddressUpdateCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Update to my current location'**
  String get addAddressUpdateCurrentLocation;

  /// No description provided for @addAddressGettingLocation.
  ///
  /// In en, this message translates to:
  /// **'Getting your location…'**
  String get addAddressGettingLocation;

  /// No description provided for @addAddressLocationGpsOff.
  ///
  /// In en, this message translates to:
  /// **'Turn on location (GPS) on your phone and try again.'**
  String get addAddressLocationGpsOff;

  /// No description provided for @addAddressLocationPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Location permission is needed to pin this address. Allow it in your phone settings.'**
  String get addAddressLocationPermissionNeeded;

  /// No description provided for @rateReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate & Review'**
  String get rateReviewTitle;

  /// No description provided for @rateReviewSubmittedSnack.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your feedback!'**
  String get rateReviewSubmittedSnack;

  /// No description provided for @rateReviewRateEntity.
  ///
  /// In en, this message translates to:
  /// **'Rate {name}'**
  String rateReviewRateEntity(Object name);

  /// No description provided for @rateReviewAddComment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get rateReviewAddComment;

  /// No description provided for @rateReviewCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your experience (optional)'**
  String get rateReviewCommentHint;

  /// No description provided for @rateReviewAddPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get rateReviewAddPhotos;

  /// No description provided for @rateReviewSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get rateReviewSubmitButton;

  /// No description provided for @reviewsScreenTitleFallback.
  ///
  /// In en, this message translates to:
  /// **'Ratings & Reviews'**
  String get reviewsScreenTitleFallback;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} review} other{{count} reviews}}'**
  String reviewsCount(int count);

  /// No description provided for @reviewsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get reviewsEmptyTitle;

  /// No description provided for @reviewsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Be the first to rate an order from this vendor.'**
  String get reviewsEmptySubtitle;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notificationsToday;

  /// No description provided for @notificationsEarlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notificationsEarlier;

  /// No description provided for @notifKindOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get notifKindOrder;

  /// No description provided for @notifKindPromo.
  ///
  /// In en, this message translates to:
  /// **'Promo'**
  String get notifKindPromo;

  /// No description provided for @notifKindUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get notifKindUpdate;

  /// No description provided for @notifOrderPickedUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Order picked up'**
  String get notifOrderPickedUpTitle;

  /// No description provided for @notifOrderPickedUpBody.
  ///
  /// In en, this message translates to:
  /// **'Your order ORD-1002 is on its way with Ravi.'**
  String get notifOrderPickedUpBody;

  /// No description provided for @notifPromoBellaTitle.
  ///
  /// In en, this message translates to:
  /// **'20% off at Bella Napoli'**
  String get notifPromoBellaTitle;

  /// No description provided for @notifPromoBellaBody.
  ///
  /// In en, this message translates to:
  /// **'Use code PIZZA20 on orders above ₹299 today only.'**
  String get notifPromoBellaBody;

  /// No description provided for @notifOrderDeliveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Order delivered'**
  String get notifOrderDeliveredTitle;

  /// No description provided for @notifOrderDeliveredBody.
  ///
  /// In en, this message translates to:
  /// **'ORD-1001 was delivered. Rate your experience!'**
  String get notifOrderDeliveredBody;

  /// No description provided for @notifSystemPincodeTitle.
  ///
  /// In en, this message translates to:
  /// **'New pincode serviceable'**
  String get notifSystemPincodeTitle;

  /// No description provided for @notifSystemPincodeBody.
  ///
  /// In en, this message translates to:
  /// **'We now deliver to Hitech City, Hyderabad.'**
  String get notifSystemPincodeBody;

  /// No description provided for @notifPromoWeekendTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekend grocery sale'**
  String get notifPromoWeekendTitle;

  /// No description provided for @notifPromoWeekendBody.
  ///
  /// In en, this message translates to:
  /// **'Up to 15% off at Daily Kirana Store this weekend.'**
  String get notifPromoWeekendBody;

  /// No description provided for @notifOrderCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get notifOrderCancelledTitle;

  /// No description provided for @notifOrderCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'ORD-0994 was cancelled and refunded to your wallet.'**
  String get notifOrderCancelledBody;

  /// No description provided for @notifTime10MinAgo.
  ///
  /// In en, this message translates to:
  /// **'10 min ago'**
  String get notifTime10MinAgo;

  /// No description provided for @notifTime2HrAgo.
  ///
  /// In en, this message translates to:
  /// **'2 hr ago'**
  String get notifTime2HrAgo;

  /// No description provided for @notifTime5HrAgo.
  ///
  /// In en, this message translates to:
  /// **'5 hr ago'**
  String get notifTime5HrAgo;

  /// No description provided for @notifTimeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get notifTimeYesterday;

  /// No description provided for @notifTime2DaysAgo.
  ///
  /// In en, this message translates to:
  /// **'2 days ago'**
  String get notifTime2DaysAgo;

  /// No description provided for @notifTime4DaysAgo.
  ///
  /// In en, this message translates to:
  /// **'4 days ago'**
  String get notifTime4DaysAgo;

  /// No description provided for @helpScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpScreenTitle;

  /// No description provided for @helpFaqHeading.
  ///
  /// In en, this message translates to:
  /// **'Frequently asked questions'**
  String get helpFaqHeading;

  /// No description provided for @helpFaq1Q.
  ///
  /// In en, this message translates to:
  /// **'How do I track my order?'**
  String get helpFaq1Q;

  /// No description provided for @helpFaq1A.
  ///
  /// In en, this message translates to:
  /// **'Open Orders from the bottom bar, tap an active order to see live status, driver details and delivery OTP.'**
  String get helpFaq1A;

  /// No description provided for @helpFaq2Q.
  ///
  /// In en, this message translates to:
  /// **'How do refunds work?'**
  String get helpFaq2Q;

  /// No description provided for @helpFaq2A.
  ///
  /// In en, this message translates to:
  /// **'Cash orders that are cancelled are never charged. If you paid a shop by UPI and the order is cancelled or rejected, the shop returns the money to your UPI account; you can follow it under Profile → Refunds.'**
  String get helpFaq2A;

  /// No description provided for @helpFaq3Q.
  ///
  /// In en, this message translates to:
  /// **'Can I change my delivery address after ordering?'**
  String get helpFaq3Q;

  /// No description provided for @helpFaq3A.
  ///
  /// In en, this message translates to:
  /// **'Once placed, an order\'s address can\'t be changed. Cancel and reorder if the vendor hasn\'t accepted yet.'**
  String get helpFaq3A;

  /// No description provided for @helpFaq4Q.
  ///
  /// In en, this message translates to:
  /// **'What payment methods are supported?'**
  String get helpFaq4Q;

  /// No description provided for @helpFaq4A.
  ///
  /// In en, this message translates to:
  /// **'UPI, credit/debit cards, in-app Wallet and Cash on Delivery are all supported at checkout.'**
  String get helpFaq4A;

  /// No description provided for @helpFaq5Q.
  ///
  /// In en, this message translates to:
  /// **'How do I raise a complaint about an order?'**
  String get helpFaq5Q;

  /// No description provided for @helpFaq5A.
  ///
  /// In en, this message translates to:
  /// **'Use \"Raise a Ticket\" below with your order ID in the description — our support team gets back within 24 hours.'**
  String get helpFaq5A;

  /// No description provided for @helpRaiseTicketHeading.
  ///
  /// In en, this message translates to:
  /// **'Raise a Ticket'**
  String get helpRaiseTicketHeading;

  /// No description provided for @helpSubjectLabel.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get helpSubjectLabel;

  /// No description provided for @helpDescribeIssueLabel.
  ///
  /// In en, this message translates to:
  /// **'Describe your issue'**
  String get helpDescribeIssueLabel;

  /// No description provided for @helpSubmitTicketButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Ticket'**
  String get helpSubmitTicketButton;

  /// No description provided for @helpTicketRaisedSnack.
  ///
  /// In en, this message translates to:
  /// **'Ticket raised — our team will get back to you soon'**
  String get helpTicketRaisedSnack;

  /// No description provided for @helpYourTicketsHeading.
  ///
  /// In en, this message translates to:
  /// **'Your tickets'**
  String get helpYourTicketsHeading;

  /// No description provided for @helpYouFallback.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get helpYouFallback;

  /// No description provided for @helpNoManagerForTerritory.
  ///
  /// In en, this message translates to:
  /// **'No manager is available for your territory yet. Please try again later.'**
  String get helpNoManagerForTerritory;

  /// No description provided for @referralScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Refer & Earn'**
  String get referralScreenTitle;

  /// No description provided for @referralGiveGetTitle.
  ///
  /// In en, this message translates to:
  /// **'Give ₹100, Get ₹100'**
  String get referralGiveGetTitle;

  /// No description provided for @referralGiveGetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share your code with friends. When they place their first order, you both get ₹100 in your Wallet.'**
  String get referralGiveGetSubtitle;

  /// No description provided for @referralYourCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Your referral code'**
  String get referralYourCodeLabel;

  /// No description provided for @referralCodeCopiedSnack.
  ///
  /// In en, this message translates to:
  /// **'Referral code copied'**
  String get referralCodeCopiedSnack;

  /// No description provided for @referralCopyCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get referralCopyCodeButton;

  /// No description provided for @referralSharedDemoSnack.
  ///
  /// In en, this message translates to:
  /// **'Shared! (demo — no real share sheet)'**
  String get referralSharedDemoSnack;

  /// No description provided for @referralInviteFriendsButton.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get referralInviteFriendsButton;

  /// No description provided for @referralFriendsInvitedLabel.
  ///
  /// In en, this message translates to:
  /// **'Friends invited'**
  String get referralFriendsInvitedLabel;

  /// No description provided for @referralTotalEarnedLabel.
  ///
  /// In en, this message translates to:
  /// **'Total earned'**
  String get referralTotalEarnedLabel;

  /// No description provided for @walletScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallet & Refunds'**
  String get walletScreenTitle;

  /// No description provided for @refundsTitle.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get refundsTitle;

  /// No description provided for @refundsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No refunds'**
  String get refundsEmptyTitle;

  /// No description provided for @refundsExplainer.
  ///
  /// In en, this message translates to:
  /// **'If you paid a shop by UPI and the order was then cancelled or rejected, the shop owes you that money back to your UPI account. Those orders and their status show here.'**
  String get refundsExplainer;

  /// No description provided for @walletBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet balance'**
  String get walletBalanceLabel;

  /// No description provided for @walletAutoCreditNote.
  ///
  /// In en, this message translates to:
  /// **'Refunds and cashback are auto-credited here'**
  String get walletAutoCreditNote;

  /// No description provided for @walletTransactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction history'**
  String get walletTransactionHistory;

  /// No description provided for @walletTxnRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund · {orderId}'**
  String walletTxnRefund(Object orderId);

  /// No description provided for @walletTxnOrderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get walletTxnOrderCancelled;

  /// No description provided for @walletTxnCashback.
  ///
  /// In en, this message translates to:
  /// **'Cashback'**
  String get walletTxnCashback;

  /// No description provided for @walletTxnWeekendPromoBonus.
  ///
  /// In en, this message translates to:
  /// **'Weekend promo bonus'**
  String get walletTxnWeekendPromoBonus;

  /// No description provided for @walletTxnOrderPayment.
  ///
  /// In en, this message translates to:
  /// **'Order payment · {orderId}'**
  String walletTxnOrderPayment(Object orderId);

  /// No description provided for @walletTxnPaidViaWallet.
  ///
  /// In en, this message translates to:
  /// **'Paid via wallet'**
  String get walletTxnPaidViaWallet;

  /// No description provided for @walletTxnReferralBonus.
  ///
  /// In en, this message translates to:
  /// **'Referral bonus'**
  String get walletTxnReferralBonus;

  /// No description provided for @walletTxnFriendJoined.
  ///
  /// In en, this message translates to:
  /// **'Friend joined using your code'**
  String get walletTxnFriendJoined;

  /// No description provided for @editProfileCropPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop photo'**
  String get editProfileCropPhotoTitle;

  /// No description provided for @vendorEtaRange.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} mins'**
  String vendorEtaRange(int min, int max);

  /// No description provided for @vendorDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String vendorDistanceKm(Object km);

  /// No description provided for @vendorOfferUseCode.
  ///
  /// In en, this message translates to:
  /// **'Use {code}'**
  String vendorOfferUseCode(Object code);

  /// No description provided for @homeFilterOpenNow.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get homeFilterOpenNow;

  /// No description provided for @homeFilterRating4.
  ///
  /// In en, this message translates to:
  /// **'Rated 4.0+'**
  String get homeFilterRating4;

  /// No description provided for @homeFilterPureVeg.
  ///
  /// In en, this message translates to:
  /// **'Pure Veg'**
  String get homeFilterPureVeg;

  /// No description provided for @homeFilterNearest.
  ///
  /// In en, this message translates to:
  /// **'Nearest'**
  String get homeFilterNearest;

  /// No description provided for @homeOrderAgainTitle.
  ///
  /// In en, this message translates to:
  /// **'Order again'**
  String get homeOrderAgainTitle;

  /// No description provided for @homeNoVendorsMatchFilters.
  ///
  /// In en, this message translates to:
  /// **'No vendors match these filters'**
  String get homeNoVendorsMatchFilters;

  /// No description provided for @homeClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get homeClearFilters;

  /// No description provided for @homeCartBarFrom.
  ///
  /// In en, this message translates to:
  /// **'From {vendorName}'**
  String homeCartBarFrom(Object vendorName);

  /// No description provided for @storefrontMenuSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search in menu'**
  String get storefrontMenuSearchHint;

  /// No description provided for @storefrontVegOnly.
  ///
  /// In en, this message translates to:
  /// **'Veg only'**
  String get storefrontVegOnly;

  /// No description provided for @storefrontNoMenuMatches.
  ///
  /// In en, this message translates to:
  /// **'No items match your search'**
  String get storefrontNoMenuMatches;

  /// No description provided for @storefrontOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'Offers for you'**
  String get storefrontOffersTitle;

  /// No description provided for @productBestseller.
  ///
  /// In en, this message translates to:
  /// **'Bestseller'**
  String get productBestseller;

  /// No description provided for @cartAddMoreItems.
  ///
  /// In en, this message translates to:
  /// **'Add more items'**
  String get cartAddMoreItems;

  /// No description provided for @cartSavingsBanner.
  ///
  /// In en, this message translates to:
  /// **'You\'re saving {amount} on this order'**
  String cartSavingsBanner(Object amount);

  /// No description provided for @cartBillDetails.
  ///
  /// In en, this message translates to:
  /// **'Bill details'**
  String get cartBillDetails;

  /// No description provided for @homeTrackPlacedTitle.
  ///
  /// In en, this message translates to:
  /// **'Order placed!'**
  String get homeTrackPlacedTitle;

  /// No description provided for @homeTrackPlacedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {vendorName} to accept your order'**
  String homeTrackPlacedSubtitle(Object vendorName);

  /// No description provided for @homeTrackAcceptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Preparing your order'**
  String get homeTrackAcceptedTitle;

  /// No description provided for @homeTrackAcceptedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{vendorName} has accepted and is getting it ready'**
  String homeTrackAcceptedSubtitle(Object vendorName);

  /// No description provided for @homeTrackDriverAssignedTitle.
  ///
  /// In en, this message translates to:
  /// **'Partner heading to the vendor'**
  String get homeTrackDriverAssignedTitle;

  /// No description provided for @homeTrackDriverAssignedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{driverName} will pick up your order soon'**
  String homeTrackDriverAssignedSubtitle(Object driverName);

  /// No description provided for @homeTrackPickedUpTitle.
  ///
  /// In en, this message translates to:
  /// **'On the way to you'**
  String get homeTrackPickedUpTitle;

  /// No description provided for @homeTrackPickedUpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{driverName} has picked up your order'**
  String homeTrackPickedUpSubtitle(Object driverName);

  /// No description provided for @homeTrackDefaultDriver.
  ///
  /// In en, this message translates to:
  /// **'Your delivery partner'**
  String get homeTrackDefaultDriver;

  /// No description provided for @trackArrivingIn.
  ///
  /// In en, this message translates to:
  /// **'Arriving in {minutes} min'**
  String trackArrivingIn(int minutes);

  /// No description provided for @trackReachingShopIn.
  ///
  /// In en, this message translates to:
  /// **'Reaching the shop in {minutes} min'**
  String trackReachingShopIn(int minutes);

  /// No description provided for @trackDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String trackDistanceKm(Object km);

  /// No description provided for @trackLocationStale.
  ///
  /// In en, this message translates to:
  /// **'Location updated {ago}'**
  String trackLocationStale(Object ago);

  /// No description provided for @homeTrackItemsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} item} other{{count} items}} · {total}'**
  String homeTrackItemsSummary(int count, Object total);

  /// No description provided for @reasonItemsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Items not available'**
  String get reasonItemsUnavailable;

  /// No description provided for @reasonShopClosingSoon.
  ///
  /// In en, this message translates to:
  /// **'Shop closing soon'**
  String get reasonShopClosingSoon;

  /// No description provided for @reasonTooBusy.
  ///
  /// In en, this message translates to:
  /// **'Too busy right now'**
  String get reasonTooBusy;

  /// No description provided for @reasonCannotPrepareInTime.
  ///
  /// In en, this message translates to:
  /// **'Can\'t prepare in time'**
  String get reasonCannotPrepareInTime;

  /// No description provided for @reasonOutsideServiceArea.
  ///
  /// In en, this message translates to:
  /// **'Outside my delivery area'**
  String get reasonOutsideServiceArea;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reasonOther;

  /// No description provided for @reasonItemsOutOfStockAfterAccept.
  ///
  /// In en, this message translates to:
  /// **'Items ran out after accepting'**
  String get reasonItemsOutOfStockAfterAccept;

  /// No description provided for @reasonEquipmentFailure.
  ///
  /// In en, this message translates to:
  /// **'Equipment failure'**
  String get reasonEquipmentFailure;

  /// No description provided for @reasonStaffUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Staff unavailable'**
  String get reasonStaffUnavailable;

  /// No description provided for @reasonQualityIssue.
  ///
  /// In en, this message translates to:
  /// **'Quality problem with the items'**
  String get reasonQualityIssue;

  /// No description provided for @reasonCustomerRequestedViaShop.
  ///
  /// In en, this message translates to:
  /// **'Customer asked the shop to cancel'**
  String get reasonCustomerRequestedViaShop;

  /// No description provided for @reasonPricingError.
  ///
  /// In en, this message translates to:
  /// **'Pricing mistake'**
  String get reasonPricingError;

  /// No description provided for @reasonEmergencyClosure.
  ///
  /// In en, this message translates to:
  /// **'Emergency closure'**
  String get reasonEmergencyClosure;

  /// No description provided for @vendorAcceptConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm you have every item'**
  String get vendorAcceptConfirmTitle;

  /// No description provided for @vendorAcceptConfirmCheckbox.
  ///
  /// In en, this message translates to:
  /// **'I have all of these items and can prepare this order.'**
  String get vendorAcceptConfirmCheckbox;

  /// No description provided for @vendorAcceptButton.
  ///
  /// In en, this message translates to:
  /// **'Accept order'**
  String get vendorAcceptButton;

  /// No description provided for @vendorRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Why can\'t you take this order?'**
  String get vendorRejectTitle;

  /// No description provided for @vendorRejectNote.
  ///
  /// In en, this message translates to:
  /// **'Not accepting an order is fine. It isn\'t counted as a cancellation and there\'s no charge.'**
  String get vendorRejectNote;

  /// No description provided for @vendorRejectButton.
  ///
  /// In en, this message translates to:
  /// **'Reject order'**
  String get vendorRejectButton;

  /// No description provided for @remarkOptional.
  ///
  /// In en, this message translates to:
  /// **'Remark (optional)'**
  String get remarkOptional;

  /// No description provided for @remarkRequired.
  ///
  /// In en, this message translates to:
  /// **'Remark (required)'**
  String get remarkRequired;

  /// No description provided for @vendorOrdersPausedTitle.
  ///
  /// In en, this message translates to:
  /// **'Your shop can\'t take new orders'**
  String get vendorOrdersPausedTitle;

  /// No description provided for @vendorNoManagerBody.
  ///
  /// In en, this message translates to:
  /// **'No Manager is assigned to your shop yet. Quicky will assign one; until then new orders are paused.'**
  String get vendorNoManagerBody;

  /// No description provided for @vendorManagerInactiveBody.
  ///
  /// In en, this message translates to:
  /// **'Your Manager isn\'t active right now. Quicky is sorting this out. You can still see your account and decline orders, but new orders are paused.'**
  String get vendorManagerInactiveBody;

  /// No description provided for @vendorCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel accepted order'**
  String get vendorCancelButton;

  /// No description provided for @vendorCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this accepted order?'**
  String get vendorCancelTitle;

  /// No description provided for @vendorCancelWarning.
  ///
  /// In en, this message translates to:
  /// **'This counts as a cancellation after accepting. Your Manager will see it.'**
  String get vendorCancelWarning;

  /// No description provided for @vendorCancelChargeNoDriver.
  ///
  /// In en, this message translates to:
  /// **'Cancellation charge: {amount} ({percent}% of the {fee} delivery fee, no driver assigned).'**
  String vendorCancelChargeNoDriver(Object amount, Object percent, Object fee);

  /// No description provided for @vendorCancelChargeWithDriver.
  ///
  /// In en, this message translates to:
  /// **'Cancellation charge: {amount} ({percent}% of the {fee} delivery fee, a driver is assigned). {driverAmount} of it goes to the driver.'**
  String vendorCancelChargeWithDriver(
    Object amount,
    Object percent,
    Object fee,
    Object driverAmount,
  );

  /// No description provided for @vendorCancelNoCharge.
  ///
  /// In en, this message translates to:
  /// **'No cancellation charge applies to this order.'**
  String get vendorCancelNoCharge;

  /// No description provided for @vendorCancelRefundOwed.
  ///
  /// In en, this message translates to:
  /// **'You also owe the customer a {amount} refund for their UPI payment.'**
  String vendorCancelRefundOwed(Object amount);

  /// No description provided for @vendorCancelUpiBlocked.
  ///
  /// In en, this message translates to:
  /// **'Cancelling a UPI-paid order isn\'t available yet. Please contact your Manager about this order.'**
  String get vendorCancelUpiBlocked;

  /// No description provided for @vendorCancelRemarkHint.
  ///
  /// In en, this message translates to:
  /// **'What happened? (at least 15 characters)'**
  String get vendorCancelRemarkHint;

  /// No description provided for @vendorCancelRemarkTooShort.
  ///
  /// In en, this message translates to:
  /// **'Please describe what happened in at least 15 characters.'**
  String get vendorCancelRemarkTooShort;

  /// No description provided for @vendorCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel order and accept the charge'**
  String get vendorCancelConfirm;

  /// No description provided for @vendorCancelConfirmNoCharge.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get vendorCancelConfirmNoCharge;

  /// No description provided for @vendorCancelChargeChanged.
  ///
  /// In en, this message translates to:
  /// **'The charge changed (a driver was assigned or released). Please review the new amount.'**
  String get vendorCancelChargeChanged;

  /// No description provided for @vendorCancelDone.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled.'**
  String get vendorCancelDone;

  /// No description provided for @vendorCancellationCharges.
  ///
  /// In en, this message translates to:
  /// **'Cancellation charges'**
  String get vendorCancellationCharges;

  /// No description provided for @orderCancelledByShop.
  ///
  /// In en, this message translates to:
  /// **'The shop cancelled this order after accepting it.'**
  String get orderCancelledByShop;

  /// No description provided for @driverCancellationComp.
  ///
  /// In en, this message translates to:
  /// **'Cancellation compensation'**
  String get driverCancellationComp;

  /// No description provided for @chooseReason.
  ///
  /// In en, this message translates to:
  /// **'Choose a reason.'**
  String get chooseReason;

  /// No description provided for @cancelChargesCharged.
  ///
  /// In en, this message translates to:
  /// **'Charged'**
  String get cancelChargesCharged;

  /// No description provided for @cancelChargesPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid (confirmed)'**
  String get cancelChargesPaid;

  /// No description provided for @cancelChargesOwed.
  ///
  /// In en, this message translates to:
  /// **'Still owed'**
  String get cancelChargesOwed;

  /// No description provided for @cancelChargesReversed.
  ///
  /// In en, this message translates to:
  /// **'Reversed'**
  String get cancelChargesReversed;

  /// No description provided for @cancelChargesWaived.
  ///
  /// In en, this message translates to:
  /// **'Waived (was unpaid)'**
  String get cancelChargesWaived;

  /// No description provided for @cancelRefundDue.
  ///
  /// In en, this message translates to:
  /// **'Refund owed to you'**
  String get cancelRefundDue;

  /// No description provided for @cancelRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded to you'**
  String get cancelRefunded;

  /// No description provided for @cancelRefundPending.
  ///
  /// In en, this message translates to:
  /// **'Refund awaiting your confirmation'**
  String get cancelRefundPending;

  /// No description provided for @cancelChargesNone.
  ///
  /// In en, this message translates to:
  /// **'No cancellation charges.'**
  String get cancelChargesNone;

  /// No description provided for @cancelChargesNote.
  ///
  /// In en, this message translates to:
  /// **'Charged when you cancel an order after accepting it. Kept separate from your earnings.'**
  String get cancelChargesNote;

  /// No description provided for @driverCompEarned.
  ///
  /// In en, this message translates to:
  /// **'Earned'**
  String get driverCompEarned;

  /// No description provided for @driverCompPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid (confirmed)'**
  String get driverCompPaid;

  /// No description provided for @driverCompPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get driverCompPending;

  /// No description provided for @driverCompNone.
  ///
  /// In en, this message translates to:
  /// **'No cancellation compensation yet.'**
  String get driverCompNone;

  /// No description provided for @driverCompNote.
  ///
  /// In en, this message translates to:
  /// **'Paid when a shop cancels an order you were assigned. Kept separate from delivery fees.'**
  String get driverCompNote;

  /// No description provided for @orderCancelledReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String orderCancelledReason(Object reason);

  /// No description provided for @refundCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Your refund'**
  String get refundCardTitle;

  /// No description provided for @refundStatusDue.
  ///
  /// In en, this message translates to:
  /// **'Refund owed'**
  String get refundStatusDue;

  /// No description provided for @refundStatusAwaiting.
  ///
  /// In en, this message translates to:
  /// **'Refund initiated — awaiting confirmation'**
  String get refundStatusAwaiting;

  /// No description provided for @refundStatusDisputed.
  ///
  /// In en, this message translates to:
  /// **'Refund disputed'**
  String get refundStatusDisputed;

  /// No description provided for @refundStatusReview.
  ///
  /// In en, this message translates to:
  /// **'Review required'**
  String get refundStatusReview;

  /// No description provided for @refundStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Refund confirmed'**
  String get refundStatusConfirmed;

  /// No description provided for @refundOwedToYou.
  ///
  /// In en, this message translates to:
  /// **'Owed to you: {amount}'**
  String refundOwedToYou(Object amount);

  /// No description provided for @refundFromShop.
  ///
  /// In en, this message translates to:
  /// **'From {shop}'**
  String refundFromShop(Object shop);

  /// No description provided for @refundReturnedSoFar.
  ///
  /// In en, this message translates to:
  /// **'{amount} returned so far.'**
  String refundReturnedSoFar(Object amount);

  /// No description provided for @refundToOriginal.
  ///
  /// In en, this message translates to:
  /// **'Refund to: the UPI account you paid from'**
  String get refundToOriginal;

  /// No description provided for @refundToUpi.
  ///
  /// In en, this message translates to:
  /// **'Refund to: {upiId}'**
  String refundToUpi(Object upiId);

  /// No description provided for @refundChangeUpi.
  ///
  /// In en, this message translates to:
  /// **'Refund to a different UPI ID'**
  String get refundChangeUpi;

  /// No description provided for @refundUpiDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'UPI ID for your refund'**
  String get refundUpiDialogTitle;

  /// No description provided for @refundUpiHint.
  ///
  /// In en, this message translates to:
  /// **'name@bank'**
  String get refundUpiHint;

  /// No description provided for @refundSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get refundSave;

  /// No description provided for @refundCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get refundCancel;

  /// No description provided for @refundSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get refundSubmit;

  /// No description provided for @refundWaitingShop.
  ///
  /// In en, this message translates to:
  /// **'The shop hasn\'t sent this refund yet.'**
  String get refundWaitingShop;

  /// No description provided for @refundPayerShop.
  ///
  /// In en, this message translates to:
  /// **'The shop'**
  String get refundPayerShop;

  /// No description provided for @refundPayerQuicky.
  ///
  /// In en, this message translates to:
  /// **'Quicky'**
  String get refundPayerQuicky;

  /// No description provided for @refundSentClaim.
  ///
  /// In en, this message translates to:
  /// **'{payer} says it sent {amount} on {date} (UPI ref {reference}). Did you receive it?'**
  String refundSentClaim(
    Object payer,
    Object amount,
    Object date,
    Object reference,
  );

  /// No description provided for @refundReceived.
  ///
  /// In en, this message translates to:
  /// **'I received it'**
  String get refundReceived;

  /// No description provided for @refundNotReceived.
  ///
  /// In en, this message translates to:
  /// **'Not received'**
  String get refundNotReceived;

  /// No description provided for @refundDifferentAmount.
  ///
  /// In en, this message translates to:
  /// **'Different amount'**
  String get refundDifferentAmount;

  /// No description provided for @refundDifferentAmountTitle.
  ///
  /// In en, this message translates to:
  /// **'How much did you receive?'**
  String get refundDifferentAmountTitle;

  /// No description provided for @refundAmountReceivedLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount received (₹)'**
  String get refundAmountReceivedLabel;

  /// No description provided for @refundNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get refundNoteLabel;

  /// No description provided for @refundNotReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Refund not received?'**
  String get refundNotReceivedTitle;

  /// No description provided for @refundNotReceivedBody.
  ///
  /// In en, this message translates to:
  /// **'Quicky will review it with the shop. Add anything that helps.'**
  String get refundNotReceivedBody;

  /// No description provided for @refundDisputedNote.
  ///
  /// In en, this message translates to:
  /// **'You reported this refund didn\'t arrive as recorded. Quicky is reviewing it.'**
  String get refundDisputedNote;

  /// No description provided for @refundReviewNote.
  ///
  /// In en, this message translates to:
  /// **'Quicky is reviewing this refund.'**
  String get refundReviewNote;

  /// No description provided for @refundConfirmedNote.
  ///
  /// In en, this message translates to:
  /// **'Refund confirmed: {amount} returned.'**
  String refundConfirmedNote(Object amount);

  /// No description provided for @refundLoadError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the refund.'**
  String get refundLoadError;

  /// No description provided for @refundRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get refundRetry;

  /// No description provided for @refundThanks.
  ///
  /// In en, this message translates to:
  /// **'Thanks — we\'ve recorded your answer.'**
  String get refundThanks;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
