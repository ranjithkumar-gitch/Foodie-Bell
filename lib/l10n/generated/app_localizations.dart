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
  /// **'Every order helps a nearby shop grow'**
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

  /// No description provided for @priceGst.
  ///
  /// In en, this message translates to:
  /// **'GST'**
  String get priceGst;

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

  /// No description provided for @invoiceHsnGst.
  ///
  /// In en, this message translates to:
  /// **'HSN {hsn} · GST {rate}%'**
  String invoiceHsnGst(Object hsn, Object rate);

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
  /// **'Refunds for cancelled orders are credited to your in-app Wallet automatically, usually within a few minutes.'**
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
