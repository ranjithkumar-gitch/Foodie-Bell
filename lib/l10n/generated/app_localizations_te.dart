// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String homeGreeting(Object name) {
    return 'ఆకలిగా ఉందా, $name?';
  }

  @override
  String get searchHint => 'వెండార్లు లేదా ఉత్పత్తులను వెతకండి';

  @override
  String get homeSelectedTerritoryLabel => 'ఎంచుకున్న ప్రాంతం';

  @override
  String get homeLoadingTerritories => 'ప్రాంతాలు లోడ్ అవుతున్నాయి…';

  @override
  String get homeSelectTerritory => 'ప్రాంతాన్ని ఎంచుకోండి';

  @override
  String get homeSubtitle => 'మీ చుట్టుపక్కల ఉత్తమ విక్రేతలను కనుగొనండి';

  @override
  String homeOrderingWindow(Object window) {
    return 'ఆర్డర్ సమయం: $window';
  }

  @override
  String get homeCheckVendorForHours => 'సమయాల కోసం విక్రేతను తనిఖీ చేయండి';

  @override
  String get homeCategoryOther => 'ఇతర';

  @override
  String homeNoVendorsForCategory(Object category) {
    return 'ఇంకా $category విక్రేతలు లేరు';
  }

  @override
  String get homeNoVendorsYet => 'ఇక్కడ ఇంకా విక్రేతలు లేరు';

  @override
  String get homeSelectTerritorySubtitle =>
      'మీ దగ్గర్లోని విక్రేతలను చూడటానికి పైన మీ డెలివరీ ప్రాంతాన్ని ఎంచుకోండి.';

  @override
  String homeNoVendorsSubtitle(Object territory) {
    return '$territoryలో మనకు ఇంకా విక్రేతలు లేరు. త్వరలో మళ్ళీ చూడండి, లేదా వేరే ప్రాంతాన్ని ప్రయత్నించండి.';
  }

  @override
  String get homeChangeTerritory => 'ప్రాంతాన్ని మార్చండి';

  @override
  String homeOrderIdLabel(Object orderId) {
    return 'ఆర్డర్ $orderId';
  }

  @override
  String get homeAllChipLabel => 'అన్నీ';

  @override
  String get homePromotedBadge => 'ప్రమోట్ చేయబడింది';

  @override
  String get homeOrderNowCta => 'ఇప్పుడు ఆర్డర్ చేయండి';

  @override
  String get homeBrandBannerTitle => 'మీ స్థానిక వ్యాపారులకు మద్దతు ఇవ్వండి';

  @override
  String get homeBrandBannerSubtitle =>
      'మీ ప్రతి ఆర్డర్ దగ్గరలోని వెండార్‌కి సహాయపడుతుంది';

  @override
  String get storefrontClosedBadge => 'మూసివేయబడింది';

  @override
  String get storefrontOpenNow => 'తెరిచి ఉంది';

  @override
  String get productOutOfStock => 'స్టాక్ లేదు';

  @override
  String get productVendorClosed => 'విక్రేత మూసివేయబడింది';

  @override
  String get productAddButton => 'జోడించు';

  @override
  String get priceSubtotal => 'ఉప మొత్తం';

  @override
  String get priceDeliveryFee => 'డెలివరీ ఫీజు';

  @override
  String get pricePlatformFee => 'ప్లాట్‌ఫారమ్ ఫీజు';

  @override
  String get priceCouponDiscount => 'కూపన్ డిస్కౌంట్';

  @override
  String get priceTotal => 'మొత్తం';

  @override
  String get itemPricesInclusiveOfTaxes =>
      'వస్తువుల ధరల్లో వర్తించే పన్నులు కలిపే ఉన్నాయి.';

  @override
  String get pricesInclusiveOfTaxes => 'ధరల్లో వర్తించే పన్నులు కలిపే ఉన్నాయి.';

  @override
  String get priceLegacyTax => 'పన్నులు (ఈ పాత ఆర్డర్‌పై వసూలు చేసినవి)';

  @override
  String get actionChange => 'మార్చు';

  @override
  String get addressLabelHome => 'ఇల్లు';

  @override
  String get addressLabelWork => 'పని స్థలం';

  @override
  String get addressLabelOther => 'ఇతర';

  @override
  String get cartTitle => 'మీ కార్ట్';

  @override
  String get cartClear => 'క్లియర్';

  @override
  String get cartEmptyTitle => 'మీ కార్ట్ ఖాళీగా ఉంది';

  @override
  String get cartEmptySubtitle =>
      'మీ చుట్టుపక్కల విక్రేతలను చూసి మీకు కావాల్సినది కనుగొనండి.';

  @override
  String get cartBrowseVendors => 'విక్రేతలను చూడండి';

  @override
  String get cartProceedToCheckout => 'చెక్అవుట్‌కు వెళ్ళండి';

  @override
  String get cartCouponCodeHint => 'కూపన్ కోడ్‌ను నమోదు చేయండి';

  @override
  String get cartCouponApply => 'వర్తింపజేయండి';

  @override
  String get cartCouponViewAvailable => 'అందుబాటులో ఉన్న కూపన్‌లను చూడండి';

  @override
  String get cartCouponRemove => 'తీసివేయండి';

  @override
  String cartCouponAppliedLabel(Object code) {
    return 'కూపన్ $code వర్తింపజేయబడింది';
  }

  @override
  String get cartCouponInvalidVendor => 'ఈ కూపన్ ఈ విక్రేతకు చెల్లదు';

  @override
  String get cartCouponExpired => 'ఈ కూపన్ ప్రస్తుతం చురుకుగా లేదు';

  @override
  String get cartCouponNotApplicable =>
      'ఈ కూపన్ మీ కార్ట్‌లోని ఏ వస్తువుకు వర్తించదు';

  @override
  String get cartCouponAlreadyUsed => 'మీరు ఇప్పటికే ఈ కూపన్‌ను ఉపయోగించారు';

  @override
  String get cartCouponNotFound => 'చెల్లని కూపన్ కోడ్';

  @override
  String get cartAvailableCouponsTitle => 'అందుబాటులో ఉన్న కూపన్‌లు';

  @override
  String get cartNoAvailableCoupons =>
      'ఈ విక్రేత కోసం ప్రస్తుతం కూపన్‌లు అందుబాటులో లేవు';

  @override
  String get checkoutAddressTitle => 'డెలివరీ చిరునామా';

  @override
  String get checkoutAddNewAddress => 'కొత్త చిరునామాను జోడించండి';

  @override
  String get checkoutDeliverHere => 'ఇక్కడ డెలివర్ చేయండి';

  @override
  String get checkoutPaymentTitle => 'చెల్లింపు';

  @override
  String get checkoutDeliveryAddress => 'డెలివరీ చిరునామా';

  @override
  String get checkoutPaymentMethod => 'చెల్లింపు విధానం';

  @override
  String get paymentCod => 'డెలివరీ సమయంలో నగదు చెల్లింపు';

  @override
  String get paymentCodSubtitle => 'మీ ఆర్డర్ వచ్చినప్పుడు చెల్లించండి';

  @override
  String get paymentUpi => 'UPI';

  @override
  String get paymentComingSoon => 'త్వరలో వస్తుంది';

  @override
  String get paymentCard => 'క్రెడిట్ / డెబిట్ కార్డ్';

  @override
  String get paymentWallet => 'వాలెట్';

  @override
  String get paymentOnline => 'UPI / కార్డ్‌లు';

  @override
  String get paymentOnlineSubtitle =>
      'UPI, క్రెడిట్ / డెబిట్ కార్డ్‌లు, నెట్‌బ్యాంకింగ్ మరియు మరిన్ని';

  @override
  String get paymentCancelled =>
      'చెల్లింపు రద్దు చేయబడింది. మీ ఆర్డర్ చేయబడలేదు.';

  @override
  String get paymentFailed =>
      'చెల్లింపు పూర్తి కాలేదు. దయచేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String paymentOrderSaveFailed(Object paymentId) {
    return 'మీ చెల్లింపు పూర్తయింది, కానీ ఆర్డర్ చేయలేకపోయాము. దయచేసి పేమెంట్ ID $paymentIdతో సపోర్ట్‌ను సంప్రదించండి.';
  }

  @override
  String get paymentUpiSubtitle =>
      'GPay, PhonePe, Paytm లేదా ఏదైనా UPI యాప్‌తో చెల్లించండి';

  @override
  String get paymentChooseUpiApp => 'UPI యాప్‌ను ఎంచుకోండి';

  @override
  String get paymentNoUpiApp =>
      'ఈ ఫోన్‌లో UPI యాప్ కనిపించలేదు. దయచేసి ఒకటి ఇన్‌స్టాల్ చేయండి లేదా వేరే చెల్లింపు పద్ధతిని ఎంచుకోండి.';

  @override
  String get paymentUpiConfirmTitle => 'మీ చెల్లింపు పూర్తయిందా?';

  @override
  String get paymentUpiConfirmMessage =>
      'మీ UPI యాప్ నుండి చెల్లింపును నిర్ధారించలేకపోయాము. మొత్తం డెబిట్ అయితేనే అవును నొక్కండి.';

  @override
  String get paymentUpiConfirmNo => 'లేదు';

  @override
  String get paymentUpiConfirmYes => 'అవును, చెల్లించాను';

  @override
  String paymentUpiPending(Object transactionId) {
    return 'మీ చెల్లింపు పెండింగ్‌లో ఉంది. అది పూర్తయిన తర్వాత మీ ఆర్డర్‌ను నిర్ధారిస్తాము. రిఫరెన్స్: $transactionId';
  }

  @override
  String get invoicePaymentPaid => 'చెల్లించారు';

  @override
  String get invoicePaymentIdLabel => 'పేమెంట్ ID';

  @override
  String get transactionsEmptyTitle => 'ఇంకా లావాదేవీలు లేవు';

  @override
  String get transactionsEmptySubtitle => 'మీ చెల్లింపులు ఇక్కడ కనిపిస్తాయి';

  @override
  String transactionPaidVia(Object method) {
    return '$method ద్వారా చెల్లించారు';
  }

  @override
  String get checkoutOrderSummary => 'ఆర్డర్ సారాంశం';

  @override
  String checkoutPlaceOrder(Object amount) {
    return 'ఆర్డర్ చేయండి · $amount';
  }

  @override
  String checkoutPayAndPlaceOrder(Object amount) {
    return '$amount చెల్లించండి';
  }

  @override
  String get orderSuccessTitle => 'ఆర్డర్ చేయబడింది!';

  @override
  String orderSuccessMessage(Object amount, Object vendorName) {
    return '$vendorName నుండి $amount విలువైన మీ ఆర్డర్ నిర్ధారించబడింది మరియు సిద్ధం చేయబడుతోంది.';
  }

  @override
  String get orderSuccessEstimatedDelivery => 'అంచనా డెలివరీ సమయం';

  @override
  String get orderSuccessEtaRange => '25 - 35 నిమిషాలు';

  @override
  String get orderSuccessTrackOrder => 'ఆర్డర్‌ను ట్రాక్ చేయండి';

  @override
  String get orderSuccessBackToHome => 'హోమ్‌కు తిరిగి వెళ్ళండి';

  @override
  String get searchRecentSearches => 'ఇటీవలి శోధనలు';

  @override
  String get searchTrending => 'ట్రెండింగ్';

  @override
  String get searchNoResultsTitle => 'ఫలితాలు కనుగొనబడలేదు';

  @override
  String get searchNoResultsSubtitle => 'వేరే శోధన పదాన్ని ప్రయత్నించండి';

  @override
  String get searchProductsHeading => 'ఉత్పత్తులు';

  @override
  String get searchVendorsHeading => 'విక్రేతలు';

  @override
  String get searchFallbackBiryani => 'బిర్యానీ';

  @override
  String get searchFallbackBurgers => 'బర్గర్లు';

  @override
  String get searchFallbackVitaminC => 'విటమిన్ సి';

  @override
  String get searchFallbackFreshVegetables => 'తాజా కూరగాయలు';

  @override
  String get searchFallbackMilkshake => 'మిల్క్‌షేక్';

  @override
  String get errorPhoneDialer => 'ఫోన్ డయలర్‌ను తెరవలేకపోయాము.';

  @override
  String get orderTitleFallback => 'ఆర్డర్';

  @override
  String get orderNotFound => 'ఆర్డర్ కనుగొనబడలేదు';

  @override
  String get orderDeliveryPartner => 'మీ డెలివరీ భాగస్వామి';

  @override
  String get invoiceTitle => 'ఇన్వాయిస్';

  @override
  String get invoicePaymentMethodLabel => 'చెల్లింపు విధానం';

  @override
  String get invoicePaymentStatusLabel => 'చెల్లింపు స్థితి';

  @override
  String get invoicePaymentReceived => 'అందుకున్నాము';

  @override
  String get invoicePaymentPending => 'డెలివరీ సమయంలో పెండింగ్';

  @override
  String invoiceCouponLabel(Object code) {
    return 'కూపన్ ($code)';
  }

  @override
  String get thankYouMessage => 'QuickMandiలో ఆర్డర్ చేసినందుకు ధన్యవాదాలు!';

  @override
  String orderEnjoyedMessage(Object vendorName) {
    return '$vendorName నుండి మీ ఆర్డర్ మీకు నచ్చిందని ఆశిస్తున్నాము.';
  }

  @override
  String get rateOrderQuestion => 'మీ ఆర్డర్ ఎలా ఉంది?';

  @override
  String rateOrderVendorOnly(Object vendorName) {
    return '$vendorNameని రేట్ చేయండి.';
  }

  @override
  String rateOrderVendorAndDriver(Object vendorName, Object driverName) {
    return '$vendorName మరియు $driverNameలను రేట్ చేయండి.';
  }

  @override
  String get rateButton => 'రేట్ చేయండి';

  @override
  String get yourReviewTitle => 'మీ సమీక్ష';

  @override
  String get myOrdersTitle => 'నా ఆర్డర్లు';

  @override
  String get ordersEmptyTitle => 'ఇంకా ఆర్డర్లు లేవు';

  @override
  String get ordersEmptySubtitle => 'మీరు చేసే ఆర్డర్లు ఇక్కడ కనిపిస్తాయి.';

  @override
  String orderItemsSummary(int count, Object orderId) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count వస్తువులు',
      one: '$count వస్తువు',
    );
    return '$_temp0 · $orderId';
  }

  @override
  String get chatDriverFallback => 'డ్రైవర్';

  @override
  String get storefrontVendorNotFound => 'విక్రేత కనుగొనబడలేదు.';

  @override
  String get storefrontNoRatings => 'రేటింగ్‌లు లేవు';

  @override
  String storefrontRatingSummary(Object rating, Object count) {
    return '$rating ($count)';
  }

  @override
  String get storefrontClosedMessage =>
      'ఈ విక్రేత ప్రస్తుతం మూసివేయబడింది మరియు ఆర్డర్‌లను స్వీకరించడం లేదు.';

  @override
  String get storefrontCategoryUnavailable =>
      'ఈ దుకాణం విభాగం ప్రస్తుతం మీ ప్రాంతంలో అందుబాటులో లేదు, కాబట్టి ఇక్కడ ఆర్డర్‌లు తీసుకోలేదు.';

  @override
  String get storefrontNoProductsYet => 'ఇంకా ఉత్పత్తులు లేవు';

  @override
  String storefrontCartItemsBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count వస్తువులు',
      one: '$count వస్తువు',
    );
    return '$_temp0';
  }

  @override
  String get storefrontViewCart => 'కార్ట్‌ను చూడండి';

  @override
  String get storefrontStartNewCartTitle => 'కొత్త కార్ట్ ప్రారంభించాలా?';

  @override
  String storefrontStartNewCartMessage(Object vendorName) {
    return 'మీ కార్ట్‌లో వేరే విక్రేత నుండి వస్తువులు ఉన్నాయి. బదులుగా $vendorName నుండి వస్తువులను జోడించాలా?';
  }

  @override
  String get actionCancel => 'రద్దు చేయండి';

  @override
  String get storefrontStartNew => 'కొత్తగా ప్రారంభించండి';

  @override
  String get profileTitle => 'ప్రొఫైల్';

  @override
  String get profileGuestFallback => 'అతిథి';

  @override
  String get profileOrderHistory => 'ఆర్డర్ చరిత్ర';

  @override
  String get profileSavedAddresses => 'సేవ్ చేసిన చిరునామాలు';

  @override
  String get profileWalletRefunds => 'వాలెట్ & రీఫండ్‌లు';

  @override
  String get profileWalletComingSoonMessage =>
      'మేము మీ QuickMandi వాలెట్‌ను నిర్మిస్తున్నాము — రీఫండ్‌లు, క్రెడిట్‌లు మరియు క్యాష్‌బ్యాక్ త్వరలో ఇక్కడ వస్తాయి.';

  @override
  String get profileHelpSupport => 'సహాయం & మద్దతు';

  @override
  String get legalPrivacyTile => 'గోప్యతా విధానం';

  @override
  String get legalTermsTile => 'నిబంధనలు & షరతులు';

  @override
  String get profileLogOut => 'లాగ్ అవుట్';

  @override
  String get profileComingSoonBadge => 'త్వరలో వస్తుంది';

  @override
  String get profileLanguage => 'భాష';

  @override
  String get profileLanguageDialogTitle => 'భాషను ఎంచుకోండి';

  @override
  String get profileCategorySettings => 'సెట్టింగ్‌లు';

  @override
  String get profileCategoryTransactions => 'లావాదేవీలు';

  @override
  String get profileCategoryFoodDelivery => 'ఫుడ్ డెలివరీ';

  @override
  String get profileTransactionHistory => 'లావాదేవీల చరిత్ర';

  @override
  String get editProfileTitle => 'ప్రొఫైల్‌ను సవరించండి';

  @override
  String get editProfilePhotoTitle => 'ప్రొఫైల్ ఫోటోను నవీకరించండి';

  @override
  String get editProfileFullName => 'పూర్తి పేరు';

  @override
  String get editProfileYourNameHint => 'మీ పేరు';

  @override
  String get editProfileEmailOptional => 'ఇమెయిల్ (ఐచ్ఛికం)';

  @override
  String get editProfileMobileNumber => 'మొబైల్ నంబర్';

  @override
  String get editProfileNameRequired => 'మీ పేరును నమోదు చేయండి.';

  @override
  String get editProfileSaveChanges => 'మార్పులను సేవ్ చేయండి';

  @override
  String get addressesScreenTitle => 'సేవ్ చేసిన చిరునామాలు';

  @override
  String get addressesEmptyTitle => 'సేవ్ చేసిన చిరునామాలు లేవు';

  @override
  String get addressesEmptySubtitle =>
      'ప్రారంభించడానికి డెలివరీ చిరునామాను జోడించండి';

  @override
  String get addressesAddButton => 'చిరునామాను జోడించండి';

  @override
  String get addressDefaultBadge => 'డిఫాల్ట్';

  @override
  String get addressNotServiceableBadge => 'సేవ అందుబాటులో లేదు';

  @override
  String get addressRemoveTooltip => 'చిరునామాను తొలగించండి';

  @override
  String get addAddressTitle => 'చిరునామాను జోడించండి';

  @override
  String get addAddressLabelHeading => 'లేబుల్';

  @override
  String get addAddressRecipientName => 'స్వీకర్త పేరు';

  @override
  String get fieldRequired => 'అవసరం';

  @override
  String get addAddressPhoneNumber => 'ఫోన్ నంబర్';

  @override
  String get addAddressPhoneDigitsError => '10 అంకెలు';

  @override
  String get addAddressHouseStreet => 'ఇల్లు/ఫ్లాట్ & వీధి';

  @override
  String get addAddressLandmarkOptional => 'ల్యాండ్‌మార్క్ (ఐచ్ఛికం)';

  @override
  String get addAddressPincode => 'పిన్‌కోడ్';

  @override
  String get addAddressPincodeDigitsError => '6 అంకెలు';

  @override
  String get addAddressCity => 'నగరం';

  @override
  String get addAddressSaveButton => 'చిరునామాను సేవ్ చేయండి';

  @override
  String get addAddressPinHeading => 'డెలివరీ స్థానం';

  @override
  String get addAddressPinRequired =>
      'సేవ్ చేసే ముందు మ్యాప్‌లో ఖచ్చితమైన డెలివరీ స్థానాన్ని పిన్ చేయండి.';

  @override
  String get addAddressPinFromAddress => 'పై చిరునామాను మ్యాప్‌లో చూపించండి';

  @override
  String get addAddressPinConfirmed => 'మ్యాప్‌లో స్థానం పిన్ చేయబడింది';

  @override
  String get addAddressPinChange => 'పిన్ మార్చండి';

  @override
  String get addAddressPinNotFound =>
      'ఆ చిరునామా మ్యాప్‌లో దొరకలేదు. చిరునామాను సరిచూడండి, లేదా మీ ప్రస్తుత స్థానాన్ని ఉపయోగించండి.';

  @override
  String get pinScreenTitle => 'డెలివరీ స్థానాన్ని నిర్ధారించండి';

  @override
  String get pinScreenHint => 'పిన్ ప్రవేశ ద్వారం మీద ఉండేలా మ్యాప్‌ను జరపండి.';

  @override
  String get pinScreenConfirm => 'ఈ స్థానాన్ని నిర్ధారించండి';

  @override
  String get addressNotPinned =>
      'ఇంకా మ్యాప్‌లో పిన్ చేయలేదు. ఇక్కడ డెలివరీ కోసం పిన్ చేయండి.';

  @override
  String get addressPinThis => 'ఈ చిరునామాను పిన్ చేయండి';

  @override
  String get addressPinNotFoundTitle => 'ఈ చిరునామా మ్యాప్‌లో దొరకలేదు';

  @override
  String get addressPinNotFoundBody =>
      'బదులుగా మీ ఫోన్ ఇప్పుడు ఉన్న చోటు నుండి మొదలుపెట్టాలా? ఖచ్చితమైన చోటుకు పిన్‌ను మీరే జరిపి నిర్ధారించాలి.';

  @override
  String get addressPinUseMyLocation => 'నా స్థానం నుండి మొదలుపెట్టు';

  @override
  String get addressPinNotNow => 'ఇప్పుడు కాదు';

  @override
  String get addressPinNoLocation =>
      'మీ స్థానాన్ని చదవలేకపోయాం. లొకేషన్ (GPS) ఆన్ చేసి అనుమతించి, మళ్ళీ ప్రయత్నించండి.';

  @override
  String get addressPinSaved => 'చిరునామా పిన్ చేయబడింది.';

  @override
  String get checkoutAddressNeedsPin =>
      'ఆర్డర్ చేసే ముందు ఈ చిరునామాను మ్యాప్‌లో పిన్ చేయండి.';

  @override
  String get cartItemsTotal => 'వస్తువుల మొత్తం';

  @override
  String get cartFeesAtCheckout =>
      'దూరాన్ని బట్టి డెలివరీ ఫీజు, ప్లాట్‌ఫామ్ ఫీజు (ఉంటే) చెక్అవుట్‌లో కలుపబడతాయి.';

  @override
  String deliveryFeeFrom(Object amount) {
    return '$amount నుండి';
  }

  @override
  String get addAddressUseCurrentLocation =>
      'నా ప్రస్తుత లొకేషన్‌ను ఉపయోగించండి';

  @override
  String get addAddressUpdateCurrentLocation =>
      'నా ప్రస్తుత లొకేషన్‌కు అప్‌డేట్ చేయండి';

  @override
  String get addAddressGettingLocation => 'మీ లొకేషన్‌ను పొందుతోంది…';

  @override
  String get addAddressLocationGpsOff =>
      'మీ ఫోన్‌లో లొకేషన్ (GPS) ఆన్ చేసి మళ్లీ ప్రయత్నించండి.';

  @override
  String get addAddressLocationPermissionNeeded =>
      'ఈ చిరునామాను పిన్ చేయడానికి లొకేషన్ అనుమతి అవసరం. మీ ఫోన్ సెట్టింగ్‌లలో అనుమతించండి.';

  @override
  String get rateReviewTitle => 'రేట్ & సమీక్ష';

  @override
  String get rateReviewSubmittedSnack => 'మీ అభిప్రాయానికి ధన్యవాదాలు!';

  @override
  String rateReviewRateEntity(Object name) {
    return '$nameని రేట్ చేయండి';
  }

  @override
  String get rateReviewAddComment => 'వ్యాఖ్యను జోడించండి';

  @override
  String get rateReviewCommentHint =>
      'మీ అనుభవం గురించి మాకు చెప్పండి (ఐచ్ఛికం)';

  @override
  String get rateReviewAddPhotos => 'ఫోటోలను జోడించండి';

  @override
  String get rateReviewSubmitButton => 'సమీక్షను సమర్పించండి';

  @override
  String get reviewsScreenTitleFallback => 'రేటింగ్‌లు & సమీక్షలు';

  @override
  String reviewsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count సమీక్షలు',
      one: '$count సమీక్ష',
    );
    return '$_temp0';
  }

  @override
  String get reviewsEmptyTitle => 'ఇంకా సమీక్షలు లేవు';

  @override
  String get reviewsEmptySubtitle =>
      'ఈ విక్రేత నుండి ఆర్డర్‌ను రేట్ చేసిన మొదటి వ్యక్తి మీరే అవ్వండి.';

  @override
  String get notificationsTitle => 'నోటిఫికేషన్‌లు';

  @override
  String get notificationsToday => 'ఈరోజు';

  @override
  String get notificationsEarlier => 'గతంలో';

  @override
  String get notifKindOrder => 'ఆర్డర్';

  @override
  String get notifKindPromo => 'ప్రమో';

  @override
  String get notifKindUpdate => 'అప్‌డేట్';

  @override
  String get notifOrderPickedUpTitle => 'ఆర్డర్ తీసుకోబడింది';

  @override
  String get notifOrderPickedUpBody => 'మీ ఆర్డర్ ORD-1002 రవితో దారిలో ఉంది.';

  @override
  String get notifPromoBellaTitle => 'Bella Napoliలో 20% తగ్గింపు';

  @override
  String get notifPromoBellaBody =>
      '₹299 పైన ఆర్డర్‌లపై ఈరోజు మాత్రమే PIZZA20 కోడ్‌ను వాడండి.';

  @override
  String get notifOrderDeliveredTitle => 'ఆర్డర్ డెలివర్ చేయబడింది';

  @override
  String get notifOrderDeliveredBody =>
      'ORD-1001 డెలివర్ చేయబడింది. మీ అనుభవాన్ని రేట్ చేయండి!';

  @override
  String get notifSystemPincodeTitle => 'కొత్త పిన్‌కోడ్ సేవలో ఉంది';

  @override
  String get notifSystemPincodeBody =>
      'మేము ఇప్పుడు హైదరాబాద్‌లోని హైటెక్ సిటీకి డెలివరీ చేస్తున్నాము.';

  @override
  String get notifPromoWeekendTitle => 'వారాంతపు కిరాణా సేల్';

  @override
  String get notifPromoWeekendBody =>
      'ఈ వారాంతంలో Daily Kirana Storeలో 15% వరకు తగ్గింపు.';

  @override
  String get notifOrderCancelledTitle => 'ఆర్డర్ రద్దు చేయబడింది';

  @override
  String get notifOrderCancelledBody =>
      'ORD-0994 రద్దు చేయబడింది మరియు మీ వాలెట్‌కు రీఫండ్ చేయబడింది.';

  @override
  String get notifTime10MinAgo => '10 నిమిషాల క్రితం';

  @override
  String get notifTime2HrAgo => '2 గంటల క్రితం';

  @override
  String get notifTime5HrAgo => '5 గంటల క్రితం';

  @override
  String get notifTimeYesterday => 'నిన్న';

  @override
  String get notifTime2DaysAgo => '2 రోజుల క్రితం';

  @override
  String get notifTime4DaysAgo => '4 రోజుల క్రితం';

  @override
  String get helpScreenTitle => 'సహాయం & మద్దతు';

  @override
  String get helpFaqHeading => 'తరచుగా అడిగే ప్రశ్నలు';

  @override
  String get helpFaq1Q => 'నా ఆర్డర్‌ను ఎలా ట్రాక్ చేయాలి?';

  @override
  String get helpFaq1A =>
      'దిగువ బార్ నుండి ఆర్డర్‌లను తెరవండి, లైవ్ స్థితి, డ్రైవర్ వివరాలు మరియు డెలివరీ OTPని చూడటానికి యాక్టివ్ ఆర్డర్‌ను నొక్కండి.';

  @override
  String get helpFaq2Q => 'రీఫండ్‌లు ఎలా పని చేస్తాయి?';

  @override
  String get helpFaq2A =>
      'రద్దు చేసిన క్యాష్ ఆర్డర్‌లకు ఎలాంటి చార్జీ ఉండదు. మీరు UPI ద్వారా దుకాణానికి చెల్లించిన ఆర్డర్ రద్దు అయినా లేదా తిరస్కరించబడినా, దుకాణం ఆ మొత్తాన్ని మీ UPI ఖాతాకు తిరిగి చెల్లిస్తుంది; ప్రొఫైల్ → రీఫండ్‌లు లో దాని స్థితి చూడవచ్చు.';

  @override
  String get helpFaq3Q =>
      'ఆర్డర్ చేసిన తర్వాత నా డెలివరీ చిరునామాను మార్చవచ్చా?';

  @override
  String get helpFaq3A =>
      'ఒకసారి ఆర్డర్ చేసిన తర్వాత, చిరునామాను మార్చలేరు. విక్రేత ఇంకా అంగీకరించకపోతే రద్దు చేసి మళ్ళీ ఆర్డర్ చేయండి.';

  @override
  String get helpFaq4Q => 'ఏ చెల్లింపు విధానాలు మద్దతు ఇవ్వబడతాయి?';

  @override
  String get helpFaq4A =>
      'చెక్అవుట్ వద్ద UPI, క్రెడిట్/డెబిట్ కార్డులు, యాప్‌లోని వాలెట్ మరియు డెలివరీ సమయంలో నగదు చెల్లింపు అన్నీ మద్దతు ఇవ్వబడతాయి.';

  @override
  String get helpFaq5Q => 'ఆర్డర్ గురించి ఫిర్యాదును ఎలా చేయాలి?';

  @override
  String get helpFaq5A =>
      'వివరణలో మీ ఆర్డర్ ఐడితో దిగువన ఉన్న \"టికెట్ లేవనెత్తండి\"ను ఉపయోగించండి — మా మద్దతు బృందం 24 గంటల్లో తిరిగి సంప్రదిస్తుంది.';

  @override
  String get helpRaiseTicketHeading => 'టికెట్ లేవనెత్తండి';

  @override
  String get helpSubjectLabel => 'విషయం';

  @override
  String get helpDescribeIssueLabel => 'మీ సమస్యను వివరించండి';

  @override
  String get helpSubmitTicketButton => 'టికెట్‌ను సమర్పించండి';

  @override
  String get helpTicketRaisedSnack =>
      'టికెట్ లేవనెత్తబడింది — మా బృందం త్వరలో మిమ్మల్ని సంప్రదిస్తుంది';

  @override
  String get helpYourTicketsHeading => 'మీ టికెట్‌లు';

  @override
  String get helpYouFallback => 'మీరు';

  @override
  String get helpNoManagerForTerritory =>
      'మీ ప్రాంతానికి ఇంకా మేనేజర్ అందుబాటులో లేరు. దయచేసి తర్వాత మళ్ళీ ప్రయత్నించండి.';

  @override
  String get referralScreenTitle => 'రెఫర్ చేసి సంపాదించండి';

  @override
  String get referralGiveGetTitle => '₹100 ఇవ్వండి, ₹100 పొందండి';

  @override
  String get referralGiveGetSubtitle =>
      'మీ కోడ్‌ను స్నేహితులతో పంచుకోండి. వారు తమ మొదటి ఆర్డర్ చేసినప్పుడు, మీరిద్దరూ మీ వాలెట్‌లో ₹100 పొందుతారు.';

  @override
  String get referralYourCodeLabel => 'మీ రెఫరల్ కోడ్';

  @override
  String get referralCodeCopiedSnack => 'రెఫరల్ కోడ్ కాపీ చేయబడింది';

  @override
  String get referralCopyCodeButton => 'కోడ్‌ను కాపీ చేయండి';

  @override
  String get referralSharedDemoSnack =>
      'షేర్ చేయబడింది! (డెమో — నిజమైన షేర్ షీట్ లేదు)';

  @override
  String get referralInviteFriendsButton => 'స్నేహితులను ఆహ్వానించండి';

  @override
  String get referralFriendsInvitedLabel => 'ఆహ్వానించిన స్నేహితులు';

  @override
  String get referralTotalEarnedLabel => 'మొత్తం సంపాదన';

  @override
  String get walletScreenTitle => 'వాలెట్ & రీఫండ్‌లు';

  @override
  String get refundsTitle => 'రీఫండ్‌లు';

  @override
  String get refundsEmptyTitle => 'రీఫండ్‌లు లేవు';

  @override
  String get refundsExplainer =>
      'మీరు UPI ద్వారా దుకాణానికి చెల్లించిన తర్వాత ఆర్డర్ రద్దు అయినా లేదా తిరస్కరించబడినా, ఆ మొత్తాన్ని దుకాణం మీ UPI ఖాతాకు తిరిగి చెల్లించాలి. అలాంటి ఆర్డర్‌లు, వాటి స్థితి ఇక్కడ కనిపిస్తాయి.';

  @override
  String get walletBalanceLabel => 'వాలెట్ బ్యాలెన్స్';

  @override
  String get walletAutoCreditNote =>
      'రీఫండ్‌లు మరియు క్యాష్‌బ్యాక్ ఇక్కడ స్వయంచాలకంగా జమ చేయబడతాయి';

  @override
  String get walletTransactionHistory => 'లావాదేవీ చరిత్ర';

  @override
  String walletTxnRefund(Object orderId) {
    return 'రీఫండ్ · $orderId';
  }

  @override
  String get walletTxnOrderCancelled => 'ఆర్డర్ రద్దు చేయబడింది';

  @override
  String get walletTxnCashback => 'క్యాష్‌బ్యాక్';

  @override
  String get walletTxnWeekendPromoBonus => 'వారాంతపు ప్రమో బోనస్';

  @override
  String walletTxnOrderPayment(Object orderId) {
    return 'ఆర్డర్ చెల్లింపు · $orderId';
  }

  @override
  String get walletTxnPaidViaWallet => 'వాలెట్ ద్వారా చెల్లించారు';

  @override
  String get walletTxnReferralBonus => 'రెఫరల్ బోనస్';

  @override
  String get walletTxnFriendJoined => 'మీ కోడ్‌ను ఉపయోగించి స్నేహితుడు చేరారు';

  @override
  String get editProfileCropPhotoTitle => 'ఫోటోను క్రాప్ చేయండి';

  @override
  String vendorEtaRange(int min, int max) {
    return '$min–$max నిమిషాలు';
  }

  @override
  String vendorEtaHours(int hours) {
    return '$hours గం.';
  }

  @override
  String vendorEtaDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days రోజులు',
      one: '1 రోజు',
    );
    return '$_temp0';
  }

  @override
  String vendorEtaDate(Object date) {
    return '$date నాటికి';
  }

  @override
  String vendorDistanceKm(Object km) {
    return '$km కి.మీ';
  }

  @override
  String vendorOfferUseCode(Object code) {
    return '$code వాడండి';
  }

  @override
  String get homeFilterOpenNow => 'ఇప్పుడు తెరిచి ఉంది';

  @override
  String get homeFilterRating4 => 'రేటింగ్ 4.0+';

  @override
  String get homeFilterPureVeg => 'శుద్ధ శాకాహారం';

  @override
  String get homeFilterNearest => 'దగ్గరలో';

  @override
  String get homeOrderAgainTitle => 'మళ్ళీ ఆర్డర్ చేయండి';

  @override
  String get homeNoVendorsMatchFilters => 'ఈ ఫిల్టర్లకు సరిపోయే వెండార్లు లేరు';

  @override
  String get homeClearFilters => 'ఫిల్టర్లు తీసివేయండి';

  @override
  String homeCartBarFrom(Object vendorName) {
    return '$vendorName నుండి';
  }

  @override
  String get storefrontMenuSearchHint => 'మెనూలో వెతకండి';

  @override
  String get storefrontVegOnly => 'శాకాహారం మాత్రమే';

  @override
  String get storefrontNoMenuMatches => 'మీ శోధనకు సరిపోయే ఐటెమ్‌లు లేవు';

  @override
  String get storefrontOffersTitle => 'మీ కోసం ఆఫర్లు';

  @override
  String get productBestseller => 'బెస్ట్‌సెల్లర్';

  @override
  String get cartAddMoreItems => 'మరిన్ని ఐటెమ్‌లు జోడించండి';

  @override
  String cartSavingsBanner(Object amount) {
    return 'ఈ ఆర్డర్‌పై మీరు $amount ఆదా చేస్తున్నారు';
  }

  @override
  String get cartBillDetails => 'బిల్లు వివరాలు';

  @override
  String get homeTrackPlacedTitle => 'ఆర్డర్ చేయబడింది!';

  @override
  String homeTrackPlacedSubtitle(Object vendorName) {
    return '$vendorName మీ ఆర్డర్‌ను అంగీకరించే వరకు వేచి ఉంది';
  }

  @override
  String get homeTrackAcceptedTitle => 'మీ ఆర్డర్ సిద్ధమవుతోంది';

  @override
  String homeTrackAcceptedSubtitle(Object vendorName) {
    return '$vendorName అంగీకరించి సిద్ధం చేస్తున్నారు';
  }

  @override
  String get homeTrackDriverAssignedTitle =>
      'డెలివరీ పార్ట్‌నర్ వెండార్ వద్దకు వెళ్తున్నారు';

  @override
  String homeTrackDriverAssignedSubtitle(Object driverName) {
    return '$driverName త్వరలో మీ ఆర్డర్‌ను తీసుకుంటారు';
  }

  @override
  String get homeTrackPickedUpTitle => 'మీ వద్దకు వస్తోంది';

  @override
  String homeTrackPickedUpSubtitle(Object driverName) {
    return '$driverName మీ ఆర్డర్‌ను తీసుకున్నారు';
  }

  @override
  String get homeTrackDefaultDriver => 'మీ డెలివరీ పార్ట్‌నర్';

  @override
  String trackArrivingIn(Object time) {
    return '$timeలో వస్తారు';
  }

  @override
  String trackReachingShopIn(Object time) {
    return '$timeలో షాప్‌కు చేరుకుంటారు';
  }

  @override
  String trackDistanceKm(Object km) {
    return '$km కి.మీ దూరంలో';
  }

  @override
  String trackLocationStale(Object ago) {
    return 'లొకేషన్ అప్‌డేట్: $ago';
  }

  @override
  String homeTrackItemsSummary(int count, Object total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ఐటెమ్‌లు',
      one: '$count ఐటెమ్',
    );
    return '$_temp0 · $total';
  }

  @override
  String get reasonItemsUnavailable => 'వస్తువులు అందుబాటులో లేవు';

  @override
  String get reasonShopClosingSoon => 'దుకాణం త్వరలో మూసివేస్తున్నాం';

  @override
  String get reasonTooBusy => 'ప్రస్తుతం చాలా బిజీగా ఉన్నాం';

  @override
  String get reasonCannotPrepareInTime => 'సమయానికి సిద్ధం చేయలేం';

  @override
  String get reasonOutsideServiceArea => 'నా డెలివరీ ప్రాంతం బయట';

  @override
  String get reasonOther => 'ఇతర';

  @override
  String get reasonItemsOutOfStockAfterAccept =>
      'అంగీకరించిన తర్వాత వస్తువులు అయిపోయాయి';

  @override
  String get reasonEquipmentFailure => 'పరికరాల వైఫల్యం';

  @override
  String get reasonStaffUnavailable => 'సిబ్బంది అందుబాటులో లేరు';

  @override
  String get reasonQualityIssue => 'వస్తువుల నాణ్యతలో సమస్య';

  @override
  String get reasonCustomerRequestedViaShop =>
      'కస్టమర్ దుకాణాన్ని రద్దు చేయమన్నారు';

  @override
  String get reasonPricingError => 'ధరలో పొరపాటు';

  @override
  String get reasonEmergencyClosure => 'అత్యవసర మూసివేత';

  @override
  String get vendorAcceptConfirmTitle =>
      'అన్ని వస్తువులు ఉన్నాయని నిర్ధారించండి';

  @override
  String get vendorAcceptConfirmCheckbox =>
      'ఈ వస్తువులన్నీ నా దగ్గర ఉన్నాయి, ఈ ఆర్డర్‌ను సిద్ధం చేయగలను.';

  @override
  String get vendorAcceptButton => 'ఆర్డర్‌ను అంగీకరించు';

  @override
  String get vendorRejectTitle => 'ఈ ఆర్డర్‌ను ఎందుకు తీసుకోలేరు?';

  @override
  String get vendorRejectNote =>
      'ఆర్డర్‌ను అంగీకరించకపోవడం పరవాలేదు. ఇది రద్దుగా లెక్కించబడదు, ఎలాంటి చార్జీ ఉండదు.';

  @override
  String get vendorRejectButton => 'ఆర్డర్‌ను తిరస్కరించు';

  @override
  String get remarkOptional => 'వ్యాఖ్య (ఐచ్ఛికం)';

  @override
  String get remarkRequired => 'వ్యాఖ్య (తప్పనిసరి)';

  @override
  String get vendorOrdersPausedTitle =>
      'మీ షాప్ ప్రస్తుతం కొత్త ఆర్డర్లు స్వీకరించదు';

  @override
  String get vendorNoManagerBody =>
      'మీ షాప్‌కు ఇంకా మేనేజర్‌ను కేటాయించలేదు. QuickMandi త్వరలో కేటాయిస్తుంది; అప్పటి వరకు కొత్త ఆర్డర్లు నిలిపివేయబడతాయి.';

  @override
  String get vendorManagerInactiveBody =>
      'మీ మేనేజర్ ప్రస్తుతం యాక్టివ్‌గా లేరు. QuickMandi దీన్ని పరిష్కరిస్తోంది. మీరు మీ ఖాతాను చూడవచ్చు, ఆర్డర్లను తిరస్కరించవచ్చు, కానీ కొత్త ఆర్డర్లు నిలిపివేయబడ్డాయి.';

  @override
  String get vendorCancelButton => 'అంగీకరించిన ఆర్డర్‌ను రద్దు చేయి';

  @override
  String get vendorCancelTitle => 'అంగీకరించిన ఈ ఆర్డర్‌ను రద్దు చేయాలా?';

  @override
  String get vendorCancelWarning =>
      'ఇది అంగీకరించిన తర్వాత రద్దుగా లెక్కించబడుతుంది. మీ మేనేజర్ దీన్ని చూస్తారు.';

  @override
  String vendorCancelChargeNoDriver(Object amount, Object percent, Object fee) {
    return 'రద్దు చార్జీ: $amount ($fee డెలివరీ ఫీజులో $percent%, డ్రైవర్ కేటాయించబడలేదు).';
  }

  @override
  String vendorCancelChargeWithDriver(
    Object amount,
    Object percent,
    Object fee,
    Object driverAmount,
  ) {
    return 'రద్దు చార్జీ: $amount ($fee డెలివరీ ఫీజులో $percent%, డ్రైవర్ కేటాయించబడ్డారు). అందులో $driverAmount డ్రైవర్‌కు వెళ్తుంది.';
  }

  @override
  String get vendorCancelNoCharge => 'ఈ ఆర్డర్‌కు రద్దు చార్జీ లేదు.';

  @override
  String vendorCancelRefundOwed(Object amount) {
    return 'కస్టమర్ UPI చెల్లింపుకు $amount రీఫండ్ కూడా మీరు చెల్లించాలి.';
  }

  @override
  String get vendorCancelUpiBlocked =>
      'UPI ద్వారా చెల్లించిన ఆర్డర్‌ను రద్దు చేయడం ఇంకా అందుబాటులో లేదు. ఈ ఆర్డర్ గురించి మీ మేనేజర్‌ను సంప్రదించండి.';

  @override
  String get vendorCancelRemarkHint => 'ఏమి జరిగింది? (కనీసం 15 అక్షరాలు)';

  @override
  String get vendorCancelRemarkTooShort =>
      'ఏమి జరిగిందో కనీసం 15 అక్షరాల్లో వివరించండి.';

  @override
  String get vendorCancelConfirm => 'ఆర్డర్‌ను రద్దు చేసి చార్జీని అంగీకరించు';

  @override
  String get vendorCancelConfirmNoCharge => 'ఆర్డర్‌ను రద్దు చేయి';

  @override
  String get vendorCancelChargeChanged =>
      'చార్జీ మారింది (డ్రైవర్ కేటాయించబడ్డారు లేదా విడుదలయ్యారు). కొత్త మొత్తాన్ని చూడండి.';

  @override
  String get vendorCancelDone => 'ఆర్డర్ రద్దు చేయబడింది.';

  @override
  String get vendorCancellationCharges => 'రద్దు చార్జీలు';

  @override
  String get orderCancelledByShop =>
      'అంగీకరించిన తర్వాత దుకాణం ఈ ఆర్డర్‌ను రద్దు చేసింది.';

  @override
  String get driverCancellationComp => 'రద్దు పరిహారం';

  @override
  String get chooseReason => 'ఒక కారణాన్ని ఎంచుకోండి.';

  @override
  String get cancelChargesCharged => 'విధించినవి';

  @override
  String get cancelChargesPaid => 'చెల్లించినవి (నిర్ధారించబడినవి)';

  @override
  String get cancelChargesOwed => 'ఇంకా బాకీ';

  @override
  String get cancelChargesReversed => 'రద్దు చేయబడినవి';

  @override
  String get cancelChargesWaived => 'మాఫీ చేయబడినది (చెల్లించనిది)';

  @override
  String get cancelRefundDue => 'మీకు తిరిగి రావాల్సినది';

  @override
  String get cancelRefunded => 'మీకు తిరిగి ఇచ్చినది';

  @override
  String get cancelRefundPending => 'మీ నిర్ధారణ కోసం వేచి ఉన్న రీఫండ్';

  @override
  String get cancelChargesNone => 'రద్దు చార్జీలు లేవు.';

  @override
  String get cancelChargesNote =>
      'అంగీకరించిన తర్వాత ఆర్డర్‌ను రద్దు చేస్తే విధించబడుతుంది. మీ సంపాదన నుండి వేరుగా ఉంచబడుతుంది.';

  @override
  String get driverCompEarned => 'సంపాదించినది';

  @override
  String get driverCompPaid => 'చెల్లించినది (నిర్ధారించబడినది)';

  @override
  String get driverCompPending => 'పెండింగ్';

  @override
  String get driverCompNone => 'ఇంకా రద్దు పరిహారం లేదు.';

  @override
  String get driverCompNote =>
      'మీకు కేటాయించిన ఆర్డర్‌ను దుకాణం రద్దు చేస్తే చెల్లించబడుతుంది. డెలివరీ ఫీజుల నుండి వేరుగా ఉంచబడుతుంది.';

  @override
  String orderCancelledReason(Object reason) {
    return 'కారణం: $reason';
  }

  @override
  String get refundCardTitle => 'మీ రీఫండ్';

  @override
  String get refundStatusDue => 'రీఫండ్ చెల్లించాల్సి ఉంది';

  @override
  String get refundStatusAwaiting =>
      'రీఫండ్ పంపబడింది — మీ నిర్ధారణ కోసం వేచి ఉంది';

  @override
  String get refundStatusDisputed => 'రీఫండ్‌పై వివాదం';

  @override
  String get refundStatusReview => 'సమీక్ష అవసరం';

  @override
  String get refundStatusConfirmed => 'రీఫండ్ నిర్ధారించబడింది';

  @override
  String refundOwedToYou(Object amount) {
    return 'మీకు రావాల్సినది: $amount';
  }

  @override
  String refundFromShop(Object shop) {
    return '$shop నుండి';
  }

  @override
  String refundReturnedSoFar(Object amount) {
    return 'ఇప్పటివరకు $amount తిరిగి వచ్చింది.';
  }

  @override
  String get refundToOriginal => 'రీఫండ్: మీరు చెల్లించిన UPI ఖాతాకు';

  @override
  String refundToUpi(Object upiId) {
    return 'రీఫండ్: $upiId';
  }

  @override
  String get refundChangeUpi => 'వేరే UPI IDకి రీఫండ్ పొందండి';

  @override
  String get refundUpiDialogTitle => 'మీ రీఫండ్ కోసం UPI ID';

  @override
  String get refundUpiHint => 'name@bank';

  @override
  String get refundSave => 'సేవ్ చేయండి';

  @override
  String get refundCancel => 'రద్దు';

  @override
  String get refundSubmit => 'సమర్పించండి';

  @override
  String get refundWaitingShop => 'దుకాణం ఇంకా ఈ రీఫండ్ పంపలేదు.';

  @override
  String get refundPayerShop => 'దుకాణం';

  @override
  String get refundPayerQuicky => 'QuickMandi';

  @override
  String refundSentClaim(
    Object payer,
    Object amount,
    Object date,
    Object reference,
  ) {
    return '$payer $dateన $amount పంపినట్లు చెబుతోంది (UPI రిఫరెన్స్ $reference). మీకు అందిందా?';
  }

  @override
  String get refundReceived => 'నాకు అందింది';

  @override
  String get refundNotReceived => 'అందలేదు';

  @override
  String get refundDifferentAmount => 'వేరే మొత్తం';

  @override
  String get refundDifferentAmountTitle => 'మీకు ఎంత అందింది?';

  @override
  String get refundAmountReceivedLabel => 'అందిన మొత్తం (₹)';

  @override
  String get refundNoteLabel => 'గమనిక (ఐచ్ఛికం)';

  @override
  String get refundNotReceivedTitle => 'రీఫండ్ అందలేదా?';

  @override
  String get refundNotReceivedBody =>
      'QuickMandi దుకాణంతో కలిసి దీనిని సమీక్షిస్తుంది. ఉపయోగపడే వివరాలు జోడించండి.';

  @override
  String get refundDisputedNote =>
      'ఈ రీఫండ్ నమోదైనట్లుగా అందలేదని మీరు తెలిపారు. QuickMandi దీనిని సమీక్షిస్తోంది.';

  @override
  String get refundReviewNote => 'QuickMandi ఈ రీఫండ్‌ను సమీక్షిస్తోంది.';

  @override
  String refundConfirmedNote(Object amount) {
    return 'రీఫండ్ నిర్ధారించబడింది: $amount తిరిగి వచ్చింది.';
  }

  @override
  String get refundLoadError => 'రీఫండ్‌ను లోడ్ చేయలేకపోయాం.';

  @override
  String get refundRetry => 'మళ్లీ ప్రయత్నించండి';

  @override
  String get refundThanks => 'ధన్యవాదాలు — మీ సమాధానం నమోదైంది.';

  @override
  String durationMinutes(int minutes) {
    return '$minutes ని.';
  }

  @override
  String durationHours(int hours) {
    return '$hours గం.';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours గం. $minutes ని.';
  }

  @override
  String storefrontHours(Object times, Object days) {
    return '$times · $days';
  }

  @override
  String get storefrontHoursEveryDay => 'ప్రతి రోజు';

  @override
  String get storefrontHoursClosedAllWeek => 'వారమంతా మూసి ఉంటుంది';

  @override
  String productCouponOffer(Object discount, Object code) {
    return '$code కోడ్‌తో $discount';
  }

  @override
  String get vendorOfferSelectedItems => 'ఎంపిక చేసిన వస్తువులపై';

  @override
  String get pinScreenSearchHint => 'ప్రాంతం, వీధి లేదా ల్యాండ్‌మార్క్ వెతకండి';

  @override
  String get pinScreenSearchNoResults =>
      'ఆ ప్రదేశం దొరకలేదు. మరో పేరుతో ప్రయత్నించండి.';

  @override
  String get pinScreenMyLocation => 'నా ప్రస్తుత స్థానం ఉపయోగించండి';

  @override
  String get accountDeleteTile => 'ఖాతాను తొలగించండి';

  @override
  String get accountDeleteConfirmTitle => 'మీ ఖాతాను తొలగించాలా?';

  @override
  String get accountDeleteConfirmBody =>
      'మా బృందం మీ అభ్యర్థనను సమీక్షించిన తర్వాత మీ ప్రొఫైల్ మరియు వ్యక్తిగత సమాచారం శాశ్వతంగా తొలగించబడుతుంది. గత ఆర్డర్లు మరియు చెల్లింపుల రికార్డులు అలాగే ఉంటాయి. దీన్ని రద్దు చేయలేరు.';

  @override
  String get accountDeleteReasonLabel => 'కారణం (ఐచ్ఛికం)';

  @override
  String get accountDeleteConfirmAction => 'తొలగించండి';

  @override
  String get accountDeleteCancel => 'రద్దు చేయండి';

  @override
  String get accountDeleteSubmittedTitle => 'అభ్యర్థన సమర్పించబడింది';

  @override
  String get accountDeleteSubmittedBody =>
      'మీ ఖాతా తొలగింపు అభ్యర్థనను మా అడ్మిన్ బృందం సమీక్షిస్తోంది. ఇది 2–3 పని దినాల్లో పూర్తవుతుంది.';

  @override
  String get accountDeleteOk => 'సరే';

  @override
  String get accountDeletePendingTitle => 'ఖాతా తొలగింపు సమీక్షలో ఉంది';

  @override
  String accountDeletePendingBody(Object date) {
    return '$dateన అభ్యర్థించారు. మీ ఖాతా 2–3 పని దినాల్లో తొలగించబడుతుంది.';
  }

  @override
  String get accountDeletePendingBodyNoDate =>
      'మీ ఖాతా 2–3 పని దినాల్లో తొలగించబడుతుంది.';

  @override
  String get accountDeleteCancelRequest => 'అభ్యర్థనను రద్దు చేయండి';

  @override
  String get accountDeleteCancelling => 'రద్దు చేస్తోంది…';

  @override
  String get accountDeleteCancelledToast =>
      'తొలగింపు అభ్యర్థన రద్దు చేయబడింది.';

  @override
  String get accountDeleteRejectedTitle =>
      'మీ తొలగింపు అభ్యర్థన తిరస్కరించబడింది';

  @override
  String accountDeleteRejectedBody(Object reason) {
    return '$reason మీరు సహాయం & మద్దతును సంప్రదించవచ్చు, లేదా తర్వాత మళ్లీ అభ్యర్థించవచ్చు.';
  }

  @override
  String get invoiceDownload => 'ఇన్‌వాయిస్ డౌన్‌లోడ్ చేయండి';

  @override
  String get invoiceDownloadFailed =>
      'ఇన్‌వాయిస్ తయారు చేయలేకపోయాం. మళ్ళీ ప్రయత్నించండి.';
}
