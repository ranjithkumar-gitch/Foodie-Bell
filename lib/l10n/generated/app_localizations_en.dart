// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String homeGreeting(Object name) {
    return 'Hungry, $name?';
  }

  @override
  String get searchHint => 'Search vendors or products';

  @override
  String get homeSelectedTerritoryLabel => 'Selected Territory';

  @override
  String get homeLoadingTerritories => 'Loading territories…';

  @override
  String get homeSelectTerritory => 'Select territory';

  @override
  String get homeSubtitle => 'Find the best vendors around you';

  @override
  String homeOrderingWindow(Object window) {
    return 'Ordering window: $window';
  }

  @override
  String get homeCheckVendorForHours => 'Check vendor for hours';

  @override
  String get homeCategoryOther => 'Other';

  @override
  String homeNoVendorsForCategory(Object category) {
    return 'No $category vendors yet';
  }

  @override
  String get homeNoVendorsYet => 'No vendors here yet';

  @override
  String get homeSelectTerritorySubtitle =>
      'Choose your delivery territory above to see vendors near you.';

  @override
  String homeNoVendorsSubtitle(Object territory) {
    return 'We don\'t have any vendors in $territory yet. Check back soon, or try a different territory.';
  }

  @override
  String get homeChangeTerritory => 'Change territory';

  @override
  String homeOrderIdLabel(Object orderId) {
    return 'Order $orderId';
  }

  @override
  String get homeAllChipLabel => 'All';

  @override
  String get homePromotedBadge => 'PROMOTED';

  @override
  String get homeOrderNowCta => 'Order Now';

  @override
  String get homeBrandBannerTitle => 'Support your local vendors';

  @override
  String get homeBrandBannerSubtitle =>
      'Every order helps a nearby vendor grow';

  @override
  String get storefrontClosedBadge => 'CLOSED';

  @override
  String get storefrontOpenNow => 'OPEN';

  @override
  String get productOutOfStock => 'Out of stock';

  @override
  String get productVendorClosed => 'Vendor closed';

  @override
  String get productAddButton => 'ADD';

  @override
  String get priceSubtotal => 'Subtotal';

  @override
  String get priceDeliveryFee => 'Delivery fee';

  @override
  String get pricePlatformFee => 'Platform fee';

  @override
  String get priceCouponDiscount => 'Coupon discount';

  @override
  String get priceTotal => 'Total';

  @override
  String get itemPricesInclusiveOfTaxes =>
      'Item prices are inclusive of applicable taxes.';

  @override
  String get pricesInclusiveOfTaxes => 'Prices inclusive of applicable taxes.';

  @override
  String get priceLegacyTax => 'Taxes (charged on this earlier order)';

  @override
  String get actionChange => 'Change';

  @override
  String get addressLabelHome => 'Home';

  @override
  String get addressLabelWork => 'Work';

  @override
  String get addressLabelOther => 'Other';

  @override
  String get cartTitle => 'Your Cart';

  @override
  String get cartClear => 'Clear';

  @override
  String get cartEmptyTitle => 'Your cart is empty';

  @override
  String get cartEmptySubtitle =>
      'Explore vendors near you and find something you need.';

  @override
  String get cartBrowseVendors => 'Browse Vendors';

  @override
  String get cartProceedToCheckout => 'Proceed to Checkout';

  @override
  String get cartCouponCodeHint => 'Enter coupon code';

  @override
  String get cartCouponApply => 'Apply';

  @override
  String get cartCouponViewAvailable => 'View available coupons';

  @override
  String get cartCouponRemove => 'Remove';

  @override
  String cartCouponAppliedLabel(Object code) {
    return 'Coupon $code applied';
  }

  @override
  String get cartCouponInvalidVendor =>
      'This coupon isn\'t valid for this vendor';

  @override
  String get cartCouponExpired => 'This coupon isn\'t active right now';

  @override
  String get cartCouponNotApplicable =>
      'This coupon doesn\'t apply to any item in your cart';

  @override
  String get cartCouponAlreadyUsed => 'You\'ve already used this coupon';

  @override
  String get cartCouponNotFound => 'Invalid coupon code';

  @override
  String get cartAvailableCouponsTitle => 'Available coupons';

  @override
  String get cartNoAvailableCoupons =>
      'No coupons available for this vendor right now';

  @override
  String get checkoutAddressTitle => 'Delivery Address';

  @override
  String get checkoutAddNewAddress => 'Add new address';

  @override
  String get checkoutDeliverHere => 'Deliver Here';

  @override
  String get checkoutPaymentTitle => 'Payment';

  @override
  String get checkoutDeliveryAddress => 'Delivery address';

  @override
  String get checkoutPaymentMethod => 'Payment method';

  @override
  String get paymentCod => 'Cash on Delivery';

  @override
  String get paymentCodSubtitle => 'Pay when your order arrives';

  @override
  String get paymentUpi => 'UPI';

  @override
  String get paymentComingSoon => 'Coming soon';

  @override
  String get paymentCard => 'Credit / Debit Card';

  @override
  String get paymentWallet => 'Wallet';

  @override
  String get paymentOnline => 'UPI / Cards';

  @override
  String get paymentOnlineSubtitle =>
      'UPI, credit / debit cards, netbanking & more';

  @override
  String get paymentCancelled =>
      'Payment cancelled. Your order was not placed.';

  @override
  String get paymentFailed =>
      'Payment could not be completed. Please try again.';

  @override
  String paymentOrderSaveFailed(Object paymentId) {
    return 'Your payment went through, but we couldn\'t place the order. Please contact support with payment ID $paymentId.';
  }

  @override
  String get paymentUpiSubtitle =>
      'Pay with GPay, PhonePe, Paytm or any UPI app';

  @override
  String get paymentChooseUpiApp => 'Choose a UPI app';

  @override
  String get paymentNoUpiApp =>
      'No UPI app found on this phone. Please install one or choose another payment method.';

  @override
  String get paymentUpiConfirmTitle => 'Did your payment go through?';

  @override
  String get paymentUpiConfirmMessage =>
      'We couldn\'t confirm the payment from your UPI app. Tap Yes only if the amount was debited.';

  @override
  String get paymentUpiConfirmNo => 'No';

  @override
  String get paymentUpiConfirmYes => 'Yes, I paid';

  @override
  String paymentUpiPending(Object transactionId) {
    return 'Your payment is pending. We\'ll confirm your order once it completes. Reference: $transactionId';
  }

  @override
  String get invoicePaymentPaid => 'Paid';

  @override
  String get invoicePaymentIdLabel => 'Payment ID';

  @override
  String get transactionsEmptyTitle => 'No transactions yet';

  @override
  String get transactionsEmptySubtitle => 'Your payments will show up here';

  @override
  String transactionPaidVia(Object method) {
    return 'Paid via $method';
  }

  @override
  String get checkoutOrderSummary => 'Order summary';

  @override
  String checkoutPlaceOrder(Object amount) {
    return 'Place Order · $amount';
  }

  @override
  String checkoutPayAndPlaceOrder(Object amount) {
    return 'Pay $amount';
  }

  @override
  String get orderSuccessTitle => 'Order placed!';

  @override
  String orderSuccessMessage(Object amount, Object vendorName) {
    return 'Your order for $amount from $vendorName has been confirmed and is being prepared.';
  }

  @override
  String get orderSuccessEstimatedDelivery => 'Estimated delivery';

  @override
  String get orderSuccessEtaRange => '25 - 35 min';

  @override
  String get orderSuccessTrackOrder => 'Track Order';

  @override
  String get orderSuccessBackToHome => 'Back to Home';

  @override
  String get searchRecentSearches => 'Recent searches';

  @override
  String get searchTrending => 'Trending';

  @override
  String get searchNoResultsTitle => 'No results found';

  @override
  String get searchNoResultsSubtitle => 'Try a different search term';

  @override
  String get searchProductsHeading => 'Products';

  @override
  String get searchVendorsHeading => 'Vendors';

  @override
  String get searchFallbackBiryani => 'Biryani';

  @override
  String get searchFallbackBurgers => 'Burgers';

  @override
  String get searchFallbackVitaminC => 'Vitamin C';

  @override
  String get searchFallbackFreshVegetables => 'Fresh Vegetables';

  @override
  String get searchFallbackMilkshake => 'Milkshake';

  @override
  String get errorPhoneDialer => 'Could not open the phone dialer.';

  @override
  String get orderTitleFallback => 'Order';

  @override
  String get orderNotFound => 'Order not found';

  @override
  String get orderDeliveryPartner => 'Your delivery partner';

  @override
  String get invoiceTitle => 'Invoice';

  @override
  String get invoicePaymentMethodLabel => 'Payment method';

  @override
  String get invoicePaymentStatusLabel => 'Payment status';

  @override
  String get invoicePaymentReceived => 'Received';

  @override
  String get invoicePaymentPending => 'Pending on delivery';

  @override
  String invoiceCouponLabel(Object code) {
    return 'Coupon ($code)';
  }

  @override
  String get thankYouMessage => 'Thank you for ordering with Quicky!';

  @override
  String orderEnjoyedMessage(Object vendorName) {
    return 'We hope you enjoyed your order from $vendorName.';
  }

  @override
  String get rateOrderQuestion => 'How was your order?';

  @override
  String rateOrderVendorOnly(Object vendorName) {
    return 'Rate $vendorName.';
  }

  @override
  String rateOrderVendorAndDriver(Object vendorName, Object driverName) {
    return 'Rate $vendorName and $driverName.';
  }

  @override
  String get rateButton => 'Rate';

  @override
  String get yourReviewTitle => 'Your review';

  @override
  String get myOrdersTitle => 'My Orders';

  @override
  String get ordersEmptyTitle => 'No orders yet';

  @override
  String get ordersEmptySubtitle => 'Orders you place will show up here.';

  @override
  String orderItemsSummary(int count, Object orderId) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0 · $orderId';
  }

  @override
  String get chatDriverFallback => 'Driver';

  @override
  String get storefrontVendorNotFound => 'Vendor not found.';

  @override
  String get storefrontNoRatings => 'No ratings';

  @override
  String storefrontRatingSummary(Object rating, Object count) {
    return '$rating ($count)';
  }

  @override
  String get storefrontClosedMessage =>
      'This vendor is currently closed and not accepting orders.';

  @override
  String get storefrontCategoryUnavailable =>
      'This shop\'s category isn\'t available in your area right now, so it can\'t take orders here.';

  @override
  String get storefrontNoProductsYet => 'No products yet';

  @override
  String storefrontCartItemsBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get storefrontViewCart => 'View Cart';

  @override
  String get storefrontStartNewCartTitle => 'Start a new cart?';

  @override
  String storefrontStartNewCartMessage(Object vendorName) {
    return 'Your cart has items from another vendor. Add items from $vendorName instead?';
  }

  @override
  String get actionCancel => 'Cancel';

  @override
  String get storefrontStartNew => 'Start New';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileGuestFallback => 'Guest';

  @override
  String get profileOrderHistory => 'Order History';

  @override
  String get profileSavedAddresses => 'Saved Addresses';

  @override
  String get profileWalletRefunds => 'Wallet & Refunds';

  @override
  String get profileWalletComingSoonMessage =>
      'We\'re building your Quicky wallet — refunds, credits, and cashback will land here soon.';

  @override
  String get profileHelpSupport => 'Help & Support';

  @override
  String get legalPrivacyTile => 'Privacy Policy';

  @override
  String get legalTermsTile => 'Terms & Conditions';

  @override
  String get profileLogOut => 'Log Out';

  @override
  String get profileComingSoonBadge => 'COMING SOON';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileLanguageDialogTitle => 'Choose language';

  @override
  String get profileCategorySettings => 'Settings';

  @override
  String get profileCategoryTransactions => 'Transactions';

  @override
  String get profileCategoryFoodDelivery => 'Food Delivery';

  @override
  String get profileTransactionHistory => 'Transaction History';

  @override
  String get editProfileTitle => 'Edit Profile';

  @override
  String get editProfilePhotoTitle => 'Update profile photo';

  @override
  String get editProfileFullName => 'Full name';

  @override
  String get editProfileYourNameHint => 'Your name';

  @override
  String get editProfileEmailOptional => 'Email (optional)';

  @override
  String get editProfileMobileNumber => 'Mobile number';

  @override
  String get editProfileNameRequired => 'Enter your name.';

  @override
  String get editProfileSaveChanges => 'Save changes';

  @override
  String get addressesScreenTitle => 'Saved Addresses';

  @override
  String get addressesEmptyTitle => 'No saved addresses';

  @override
  String get addressesEmptySubtitle => 'Add a delivery address to get started';

  @override
  String get addressesAddButton => 'Add Address';

  @override
  String get addressDefaultBadge => 'DEFAULT';

  @override
  String get addressNotServiceableBadge => 'NOT SERVICEABLE';

  @override
  String get addressRemoveTooltip => 'Remove address';

  @override
  String get addAddressTitle => 'Add Address';

  @override
  String get addAddressLabelHeading => 'Label';

  @override
  String get addAddressRecipientName => 'Recipient\'s name';

  @override
  String get fieldRequired => 'Required';

  @override
  String get addAddressPhoneNumber => 'Phone number';

  @override
  String get addAddressPhoneDigitsError => '10 digits';

  @override
  String get addAddressHouseStreet => 'House/flat & street';

  @override
  String get addAddressLandmarkOptional => 'Landmark (optional)';

  @override
  String get addAddressPincode => 'Pincode';

  @override
  String get addAddressPincodeDigitsError => '6 digits';

  @override
  String get addAddressCity => 'City';

  @override
  String get addAddressSaveButton => 'Save Address';

  @override
  String get addAddressPinHeading => 'Delivery location';

  @override
  String get addAddressPinRequired =>
      'Pin the exact delivery location on the map before saving.';

  @override
  String get addAddressPinFromAddress => 'Find the address above on the map';

  @override
  String get addAddressPinConfirmed => 'Location pinned on the map';

  @override
  String get addAddressPinChange => 'Adjust pin';

  @override
  String get addAddressPinNotFound =>
      'We couldn\'t find that address on the map. Check it, or use your current location.';

  @override
  String get pinScreenTitle => 'Confirm delivery location';

  @override
  String get pinScreenHint => 'Move the map so the pin sits on the entrance.';

  @override
  String get pinScreenConfirm => 'Confirm this location';

  @override
  String get addressNotPinned =>
      'Not pinned on the map yet. Pin it to get deliveries here.';

  @override
  String get addressPinThis => 'Pin this address';

  @override
  String get addressPinNotFoundTitle =>
      'Couldn\'t find this address on the map';

  @override
  String get addressPinNotFoundBody =>
      'Start from where your phone is now instead? You\'ll still move the pin to the exact spot and confirm it.';

  @override
  String get addressPinUseMyLocation => 'Start from my location';

  @override
  String get addressPinNotNow => 'Not now';

  @override
  String get addressPinNoLocation =>
      'We couldn\'t read your location. Turn on location (GPS) and allow it, then try again.';

  @override
  String get addressPinSaved => 'Address pinned.';

  @override
  String get checkoutAddressNeedsPin =>
      'Pin this address on the map before ordering.';

  @override
  String get cartItemsTotal => 'Items total';

  @override
  String get cartFeesAtCheckout =>
      'The delivery fee (by distance) and any platform fee are added at checkout.';

  @override
  String deliveryFeeFrom(Object amount) {
    return 'From $amount';
  }

  @override
  String get addAddressUseCurrentLocation => 'Use my current location';

  @override
  String get addAddressUpdateCurrentLocation => 'Update to my current location';

  @override
  String get addAddressGettingLocation => 'Getting your location…';

  @override
  String get addAddressLocationGpsOff =>
      'Turn on location (GPS) on your phone and try again.';

  @override
  String get addAddressLocationPermissionNeeded =>
      'Location permission is needed to pin this address. Allow it in your phone settings.';

  @override
  String get rateReviewTitle => 'Rate & Review';

  @override
  String get rateReviewSubmittedSnack => 'Thanks for your feedback!';

  @override
  String rateReviewRateEntity(Object name) {
    return 'Rate $name';
  }

  @override
  String get rateReviewAddComment => 'Add a comment';

  @override
  String get rateReviewCommentHint =>
      'Tell us about your experience (optional)';

  @override
  String get rateReviewAddPhotos => 'Add photos';

  @override
  String get rateReviewSubmitButton => 'Submit Review';

  @override
  String get reviewsScreenTitleFallback => 'Ratings & Reviews';

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '$count review',
    );
    return '$_temp0';
  }

  @override
  String get reviewsEmptyTitle => 'No reviews yet';

  @override
  String get reviewsEmptySubtitle =>
      'Be the first to rate an order from this vendor.';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsToday => 'Today';

  @override
  String get notificationsEarlier => 'Earlier';

  @override
  String get notifKindOrder => 'Order';

  @override
  String get notifKindPromo => 'Promo';

  @override
  String get notifKindUpdate => 'Update';

  @override
  String get notifOrderPickedUpTitle => 'Order picked up';

  @override
  String get notifOrderPickedUpBody =>
      'Your order ORD-1002 is on its way with Ravi.';

  @override
  String get notifPromoBellaTitle => '20% off at Bella Napoli';

  @override
  String get notifPromoBellaBody =>
      'Use code PIZZA20 on orders above ₹299 today only.';

  @override
  String get notifOrderDeliveredTitle => 'Order delivered';

  @override
  String get notifOrderDeliveredBody =>
      'ORD-1001 was delivered. Rate your experience!';

  @override
  String get notifSystemPincodeTitle => 'New pincode serviceable';

  @override
  String get notifSystemPincodeBody =>
      'We now deliver to Hitech City, Hyderabad.';

  @override
  String get notifPromoWeekendTitle => 'Weekend grocery sale';

  @override
  String get notifPromoWeekendBody =>
      'Up to 15% off at Daily Kirana Store this weekend.';

  @override
  String get notifOrderCancelledTitle => 'Order cancelled';

  @override
  String get notifOrderCancelledBody =>
      'ORD-0994 was cancelled and refunded to your wallet.';

  @override
  String get notifTime10MinAgo => '10 min ago';

  @override
  String get notifTime2HrAgo => '2 hr ago';

  @override
  String get notifTime5HrAgo => '5 hr ago';

  @override
  String get notifTimeYesterday => 'Yesterday';

  @override
  String get notifTime2DaysAgo => '2 days ago';

  @override
  String get notifTime4DaysAgo => '4 days ago';

  @override
  String get helpScreenTitle => 'Help & Support';

  @override
  String get helpFaqHeading => 'Frequently asked questions';

  @override
  String get helpFaq1Q => 'How do I track my order?';

  @override
  String get helpFaq1A =>
      'Open Orders from the bottom bar, tap an active order to see live status, driver details and delivery OTP.';

  @override
  String get helpFaq2Q => 'How do refunds work?';

  @override
  String get helpFaq2A =>
      'Cash orders that are cancelled are never charged. If you paid a shop by UPI and the order is cancelled or rejected, the shop returns the money to your UPI account; you can follow it under Profile → Refunds.';

  @override
  String get helpFaq3Q => 'Can I change my delivery address after ordering?';

  @override
  String get helpFaq3A =>
      'Once placed, an order\'s address can\'t be changed. Cancel and reorder if the vendor hasn\'t accepted yet.';

  @override
  String get helpFaq4Q => 'What payment methods are supported?';

  @override
  String get helpFaq4A =>
      'UPI, credit/debit cards, in-app Wallet and Cash on Delivery are all supported at checkout.';

  @override
  String get helpFaq5Q => 'How do I raise a complaint about an order?';

  @override
  String get helpFaq5A =>
      'Use \"Raise a Ticket\" below with your order ID in the description — our support team gets back within 24 hours.';

  @override
  String get helpRaiseTicketHeading => 'Raise a Ticket';

  @override
  String get helpSubjectLabel => 'Subject';

  @override
  String get helpDescribeIssueLabel => 'Describe your issue';

  @override
  String get helpSubmitTicketButton => 'Submit Ticket';

  @override
  String get helpTicketRaisedSnack =>
      'Ticket raised — our team will get back to you soon';

  @override
  String get helpYourTicketsHeading => 'Your tickets';

  @override
  String get helpYouFallback => 'You';

  @override
  String get helpNoManagerForTerritory =>
      'No manager is available for your territory yet. Please try again later.';

  @override
  String get referralScreenTitle => 'Refer & Earn';

  @override
  String get referralGiveGetTitle => 'Give ₹100, Get ₹100';

  @override
  String get referralGiveGetSubtitle =>
      'Share your code with friends. When they place their first order, you both get ₹100 in your Wallet.';

  @override
  String get referralYourCodeLabel => 'Your referral code';

  @override
  String get referralCodeCopiedSnack => 'Referral code copied';

  @override
  String get referralCopyCodeButton => 'Copy code';

  @override
  String get referralSharedDemoSnack => 'Shared! (demo — no real share sheet)';

  @override
  String get referralInviteFriendsButton => 'Invite friends';

  @override
  String get referralFriendsInvitedLabel => 'Friends invited';

  @override
  String get referralTotalEarnedLabel => 'Total earned';

  @override
  String get walletScreenTitle => 'Wallet & Refunds';

  @override
  String get refundsTitle => 'Refunds';

  @override
  String get refundsEmptyTitle => 'No refunds';

  @override
  String get refundsExplainer =>
      'If you paid a shop by UPI and the order was then cancelled or rejected, the shop owes you that money back to your UPI account. Those orders and their status show here.';

  @override
  String get walletBalanceLabel => 'Wallet balance';

  @override
  String get walletAutoCreditNote =>
      'Refunds and cashback are auto-credited here';

  @override
  String get walletTransactionHistory => 'Transaction history';

  @override
  String walletTxnRefund(Object orderId) {
    return 'Refund · $orderId';
  }

  @override
  String get walletTxnOrderCancelled => 'Order cancelled';

  @override
  String get walletTxnCashback => 'Cashback';

  @override
  String get walletTxnWeekendPromoBonus => 'Weekend promo bonus';

  @override
  String walletTxnOrderPayment(Object orderId) {
    return 'Order payment · $orderId';
  }

  @override
  String get walletTxnPaidViaWallet => 'Paid via wallet';

  @override
  String get walletTxnReferralBonus => 'Referral bonus';

  @override
  String get walletTxnFriendJoined => 'Friend joined using your code';

  @override
  String get editProfileCropPhotoTitle => 'Crop photo';

  @override
  String vendorEtaRange(int min, int max) {
    return '$min–$max mins';
  }

  @override
  String vendorEtaHours(int hours) {
    return '$hours hr';
  }

  @override
  String vendorEtaDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String vendorEtaDate(Object date) {
    return 'By $date';
  }

  @override
  String vendorDistanceKm(Object km) {
    return '$km km';
  }

  @override
  String vendorOfferUseCode(Object code) {
    return 'Use $code';
  }

  @override
  String get homeFilterOpenNow => 'Open now';

  @override
  String get homeFilterRating4 => 'Rated 4.0+';

  @override
  String get homeFilterPureVeg => 'Pure Veg';

  @override
  String get homeFilterNearest => 'Nearest';

  @override
  String get homeOrderAgainTitle => 'Order again';

  @override
  String get homeNoVendorsMatchFilters => 'No vendors match these filters';

  @override
  String get homeClearFilters => 'Clear filters';

  @override
  String homeCartBarFrom(Object vendorName) {
    return 'From $vendorName';
  }

  @override
  String get storefrontMenuSearchHint => 'Search in menu';

  @override
  String get storefrontVegOnly => 'Veg only';

  @override
  String get storefrontNoMenuMatches => 'No items match your search';

  @override
  String get storefrontOffersTitle => 'Offers for you';

  @override
  String get productBestseller => 'Bestseller';

  @override
  String get cartAddMoreItems => 'Add more items';

  @override
  String cartSavingsBanner(Object amount) {
    return 'You\'re saving $amount on this order';
  }

  @override
  String get cartBillDetails => 'Bill details';

  @override
  String get homeTrackPlacedTitle => 'Order placed!';

  @override
  String homeTrackPlacedSubtitle(Object vendorName) {
    return 'Waiting for $vendorName to accept your order';
  }

  @override
  String get homeTrackAcceptedTitle => 'Preparing your order';

  @override
  String homeTrackAcceptedSubtitle(Object vendorName) {
    return '$vendorName has accepted and is getting it ready';
  }

  @override
  String get homeTrackDriverAssignedTitle => 'Partner heading to the vendor';

  @override
  String homeTrackDriverAssignedSubtitle(Object driverName) {
    return '$driverName will pick up your order soon';
  }

  @override
  String get homeTrackPickedUpTitle => 'On the way to you';

  @override
  String homeTrackPickedUpSubtitle(Object driverName) {
    return '$driverName has picked up your order';
  }

  @override
  String get homeTrackDefaultDriver => 'Your delivery partner';

  @override
  String trackArrivingIn(Object time) {
    return 'Arriving in $time';
  }

  @override
  String trackReachingShopIn(Object time) {
    return 'Reaching the shop in $time';
  }

  @override
  String trackDistanceKm(Object km) {
    return '$km km away';
  }

  @override
  String trackLocationStale(Object ago) {
    return 'Location updated $ago';
  }

  @override
  String homeTrackItemsSummary(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0 · $total';
  }

  @override
  String get reasonItemsUnavailable => 'Items not available';

  @override
  String get reasonShopClosingSoon => 'Shop closing soon';

  @override
  String get reasonTooBusy => 'Too busy right now';

  @override
  String get reasonCannotPrepareInTime => 'Can\'t prepare in time';

  @override
  String get reasonOutsideServiceArea => 'Outside my delivery area';

  @override
  String get reasonOther => 'Other';

  @override
  String get reasonItemsOutOfStockAfterAccept =>
      'Items ran out after accepting';

  @override
  String get reasonEquipmentFailure => 'Equipment failure';

  @override
  String get reasonStaffUnavailable => 'Staff unavailable';

  @override
  String get reasonQualityIssue => 'Quality problem with the items';

  @override
  String get reasonCustomerRequestedViaShop =>
      'Customer asked the shop to cancel';

  @override
  String get reasonPricingError => 'Pricing mistake';

  @override
  String get reasonEmergencyClosure => 'Emergency closure';

  @override
  String get vendorAcceptConfirmTitle => 'Confirm you have every item';

  @override
  String get vendorAcceptConfirmCheckbox =>
      'I have all of these items and can prepare this order.';

  @override
  String get vendorAcceptButton => 'Accept order';

  @override
  String get vendorRejectTitle => 'Why can\'t you take this order?';

  @override
  String get vendorRejectNote =>
      'Not accepting an order is fine. It isn\'t counted as a cancellation and there\'s no charge.';

  @override
  String get vendorRejectButton => 'Reject order';

  @override
  String get remarkOptional => 'Remark (optional)';

  @override
  String get remarkRequired => 'Remark (required)';

  @override
  String get vendorOrdersPausedTitle => 'Your shop can\'t take new orders';

  @override
  String get vendorNoManagerBody =>
      'No Manager is assigned to your shop yet. Quicky will assign one; until then new orders are paused.';

  @override
  String get vendorManagerInactiveBody =>
      'Your Manager isn\'t active right now. Quicky is sorting this out. You can still see your account and decline orders, but new orders are paused.';

  @override
  String get vendorCancelButton => 'Cancel accepted order';

  @override
  String get vendorCancelTitle => 'Cancel this accepted order?';

  @override
  String get vendorCancelWarning =>
      'This counts as a cancellation after accepting. Your Manager will see it.';

  @override
  String vendorCancelChargeNoDriver(Object amount, Object percent, Object fee) {
    return 'Cancellation charge: $amount ($percent% of the $fee delivery fee, no driver assigned).';
  }

  @override
  String vendorCancelChargeWithDriver(
    Object amount,
    Object percent,
    Object fee,
    Object driverAmount,
  ) {
    return 'Cancellation charge: $amount ($percent% of the $fee delivery fee, a driver is assigned). $driverAmount of it goes to the driver.';
  }

  @override
  String get vendorCancelNoCharge =>
      'No cancellation charge applies to this order.';

  @override
  String vendorCancelRefundOwed(Object amount) {
    return 'You also owe the customer a $amount refund for their UPI payment.';
  }

  @override
  String get vendorCancelUpiBlocked =>
      'Cancelling a UPI-paid order isn\'t available yet. Please contact your Manager about this order.';

  @override
  String get vendorCancelRemarkHint =>
      'What happened? (at least 15 characters)';

  @override
  String get vendorCancelRemarkTooShort =>
      'Please describe what happened in at least 15 characters.';

  @override
  String get vendorCancelConfirm => 'Cancel order and accept the charge';

  @override
  String get vendorCancelConfirmNoCharge => 'Cancel order';

  @override
  String get vendorCancelChargeChanged =>
      'The charge changed (a driver was assigned or released). Please review the new amount.';

  @override
  String get vendorCancelDone => 'Order cancelled.';

  @override
  String get vendorCancellationCharges => 'Cancellation charges';

  @override
  String get orderCancelledByShop =>
      'The shop cancelled this order after accepting it.';

  @override
  String get driverCancellationComp => 'Cancellation compensation';

  @override
  String get chooseReason => 'Choose a reason.';

  @override
  String get cancelChargesCharged => 'Charged';

  @override
  String get cancelChargesPaid => 'Paid (confirmed)';

  @override
  String get cancelChargesOwed => 'Still owed';

  @override
  String get cancelChargesReversed => 'Reversed';

  @override
  String get cancelChargesWaived => 'Waived (was unpaid)';

  @override
  String get cancelRefundDue => 'Refund owed to you';

  @override
  String get cancelRefunded => 'Refunded to you';

  @override
  String get cancelRefundPending => 'Refund awaiting your confirmation';

  @override
  String get cancelChargesNone => 'No cancellation charges.';

  @override
  String get cancelChargesNote =>
      'Charged when you cancel an order after accepting it. Kept separate from your earnings.';

  @override
  String get driverCompEarned => 'Earned';

  @override
  String get driverCompPaid => 'Paid (confirmed)';

  @override
  String get driverCompPending => 'Pending';

  @override
  String get driverCompNone => 'No cancellation compensation yet.';

  @override
  String get driverCompNote =>
      'Paid when a shop cancels an order you were assigned. Kept separate from delivery fees.';

  @override
  String orderCancelledReason(Object reason) {
    return 'Reason: $reason';
  }

  @override
  String get refundCardTitle => 'Your refund';

  @override
  String get refundStatusDue => 'Refund owed';

  @override
  String get refundStatusAwaiting => 'Refund initiated — awaiting confirmation';

  @override
  String get refundStatusDisputed => 'Refund disputed';

  @override
  String get refundStatusReview => 'Review required';

  @override
  String get refundStatusConfirmed => 'Refund confirmed';

  @override
  String refundOwedToYou(Object amount) {
    return 'Owed to you: $amount';
  }

  @override
  String refundFromShop(Object shop) {
    return 'From $shop';
  }

  @override
  String refundReturnedSoFar(Object amount) {
    return '$amount returned so far.';
  }

  @override
  String get refundToOriginal => 'Refund to: the UPI account you paid from';

  @override
  String refundToUpi(Object upiId) {
    return 'Refund to: $upiId';
  }

  @override
  String get refundChangeUpi => 'Refund to a different UPI ID';

  @override
  String get refundUpiDialogTitle => 'UPI ID for your refund';

  @override
  String get refundUpiHint => 'name@bank';

  @override
  String get refundSave => 'Save';

  @override
  String get refundCancel => 'Cancel';

  @override
  String get refundSubmit => 'Submit';

  @override
  String get refundWaitingShop => 'The shop hasn\'t sent this refund yet.';

  @override
  String get refundPayerShop => 'The shop';

  @override
  String get refundPayerQuicky => 'Quicky';

  @override
  String refundSentClaim(
    Object payer,
    Object amount,
    Object date,
    Object reference,
  ) {
    return '$payer says it sent $amount on $date (UPI ref $reference). Did you receive it?';
  }

  @override
  String get refundReceived => 'I received it';

  @override
  String get refundNotReceived => 'Not received';

  @override
  String get refundDifferentAmount => 'Different amount';

  @override
  String get refundDifferentAmountTitle => 'How much did you receive?';

  @override
  String get refundAmountReceivedLabel => 'Amount received (₹)';

  @override
  String get refundNoteLabel => 'Note (optional)';

  @override
  String get refundNotReceivedTitle => 'Refund not received?';

  @override
  String get refundNotReceivedBody =>
      'Quicky will review it with the shop. Add anything that helps.';

  @override
  String get refundDisputedNote =>
      'You reported this refund didn\'t arrive as recorded. Quicky is reviewing it.';

  @override
  String get refundReviewNote => 'Quicky is reviewing this refund.';

  @override
  String refundConfirmedNote(Object amount) {
    return 'Refund confirmed: $amount returned.';
  }

  @override
  String get refundLoadError => 'Couldn\'t load the refund.';

  @override
  String get refundRetry => 'Retry';

  @override
  String get refundThanks => 'Thanks — we\'ve recorded your answer.';

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    return '$hours hr';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours hr $minutes min';
  }

  @override
  String storefrontHours(Object times, Object days) {
    return '$times · $days';
  }

  @override
  String get storefrontHoursEveryDay => 'Every day';

  @override
  String get storefrontHoursClosedAllWeek => 'Closed all week';

  @override
  String productCouponOffer(Object discount, Object code) {
    return '$discount with code $code';
  }

  @override
  String get vendorOfferSelectedItems => 'On selected items';

  @override
  String get pinScreenSearchHint => 'Search area, street or landmark';

  @override
  String get pinScreenSearchNoResults =>
      'Couldn\'t find that place. Try another name.';

  @override
  String get pinScreenMyLocation => 'Use my current location';

  @override
  String get accountDeleteTile => 'Delete account';

  @override
  String get accountDeleteConfirmTitle => 'Delete your account?';

  @override
  String get accountDeleteConfirmBody =>
      'Your profile and personal data will be permanently deleted once our team reviews your request. Records of past orders and payments are kept. This can\'t be undone.';

  @override
  String get accountDeleteReasonLabel => 'Reason (optional)';

  @override
  String get accountDeleteConfirmAction => 'Delete';

  @override
  String get accountDeleteCancel => 'Cancel';

  @override
  String get accountDeleteSubmittedTitle => 'Request submitted';

  @override
  String get accountDeleteSubmittedBody =>
      'Your account deletion request is under review by our admin team. It will be processed within 2–3 working days.';

  @override
  String get accountDeleteOk => 'OK';

  @override
  String get accountDeletePendingTitle => 'Account under review for deletion';

  @override
  String accountDeletePendingBody(Object date) {
    return 'Requested on $date. Your account will be deleted within 2–3 working days.';
  }

  @override
  String get accountDeletePendingBodyNoDate =>
      'Your account will be deleted within 2–3 working days.';

  @override
  String get accountDeleteCancelRequest => 'Cancel request';

  @override
  String get accountDeleteCancelling => 'Cancelling…';

  @override
  String get accountDeleteCancelledToast => 'Deletion request cancelled.';

  @override
  String get accountDeleteRejectedTitle => 'Your deletion request was declined';

  @override
  String accountDeleteRejectedBody(Object reason) {
    return '$reason You can contact Help & Support, or request again later.';
  }
}
