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
  String get homePromotedBadge => 'PROMOTED';

  @override
  String get homeOrderNowCta => 'Order Now';

  @override
  String get homeBrandBannerTitle => 'Support your local vendors';

  @override
  String get homeBrandBannerSubtitle => 'Every order helps a nearby shop grow';

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
  String get priceGst => 'GST';

  @override
  String get priceCouponDiscount => 'Coupon discount';

  @override
  String get priceTotal => 'Total';

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
  String get checkoutOrderSummary => 'Order summary';

  @override
  String checkoutPlaceOrder(Object amount) {
    return 'Place Order · $amount';
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
  String invoiceHsnGst(Object hsn, Object rate) {
    return 'HSN $hsn · GST $rate%';
  }

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
  String get profileLogOut => 'Log Out';

  @override
  String get profileComingSoonBadge => 'COMING SOON';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileLanguageDialogTitle => 'Choose language';

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
      'Refunds for cancelled orders are credited to your in-app Wallet automatically, usually within a few minutes.';

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
}
