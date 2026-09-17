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
  String get homePromotedBadge => 'ప్రమోట్ చేయబడింది';

  @override
  String get homeOrderNowCta => 'ఇప్పుడు ఆర్డర్ చేయండి';

  @override
  String get homeBrandBannerTitle => 'మీ స్థానిక వ్యాపారులకు మద్దతు ఇవ్వండి';

  @override
  String get homeBrandBannerSubtitle =>
      'మీ ప్రతి ఆర్డర్ దగ్గరలోని దుకాణానికి సహాయపడుతుంది';

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
  String get priceGst => 'GST';

  @override
  String get priceCouponDiscount => 'కూపన్ డిస్కౌంట్';

  @override
  String get priceTotal => 'మొత్తం';

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
  String get checkoutOrderSummary => 'ఆర్డర్ సారాంశం';

  @override
  String checkoutPlaceOrder(Object amount) {
    return 'ఆర్డర్ చేయండి · $amount';
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
  String invoiceHsnGst(Object hsn, Object rate) {
    return 'HSN $hsn · GST $rate%';
  }

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
  String get thankYouMessage => 'Quickyలో ఆర్డర్ చేసినందుకు ధన్యవాదాలు!';

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
      'మేము మీ Quicky వాలెట్‌ను నిర్మిస్తున్నాము — రీఫండ్‌లు, క్రెడిట్‌లు మరియు క్యాష్‌బ్యాక్ త్వరలో ఇక్కడ వస్తాయి.';

  @override
  String get profileHelpSupport => 'సహాయం & మద్దతు';

  @override
  String get profileLogOut => 'లాగ్ అవుట్';

  @override
  String get profileComingSoonBadge => 'త్వరలో వస్తుంది';

  @override
  String get profileLanguage => 'భాష';

  @override
  String get profileLanguageDialogTitle => 'భాషను ఎంచుకోండి';

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
      'రద్దు చేయబడిన ఆర్డర్‌లకు రీఫండ్‌లు మీ యాప్‌లోని వాలెట్‌కు స్వయంచాలకంగా, సాధారణంగా కొన్ని నిమిషాల్లో జమ చేయబడతాయి.';

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
}
