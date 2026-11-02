import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/models/order.dart';
import 'package:foodiebell/data/models/product.dart';
import 'package:foodiebell/data/models/review.dart';
import 'package:foodiebell/data/providers/cart_provider.dart';
import 'package:foodiebell/data/providers/firestore_orders_provider.dart';
import 'package:foodiebell/data/providers/firestore_reviews_provider.dart';
import 'package:foodiebell/features/user/cart/cart_screen.dart';
import 'package:foodiebell/data/models/category.dart';
import 'package:foodiebell/data/models/vendor.dart';
import 'package:foodiebell/data/providers/firestore_categories_provider.dart';
import 'package:foodiebell/data/providers/firestore_products_provider.dart';
import 'package:foodiebell/features/user/orders/order_detail_screen.dart';
import 'package:foodiebell/features/vendor/catalogue/vendor_add_edit_product_screen.dart';
import 'package:foodiebell/features/vendor/vendor_session.dart';
import 'package:foodiebell/l10n/generated/app_localizations.dart';
import 'package:foodiebell/shared/widgets/currency_text.dart';

/// Phase I.4.3: catalogue prices are tax-inclusive. The invoice and the
/// cart say so, show no item-GST line, and the total is the server's
/// (`money.customerTotal`): items + delivery fee + platform fee. An order
/// from the earlier client-priced flow keeps the tax it actually recorded.
final en = lookupAppLocalizations(const Locale('en'));
final te = lookupAppLocalizations(const Locale('te'));

String rs(double rupees) => AppFormat.currency(rupees);

/// The server's money snapshot (integer paise), as `computeOrderMoney`
/// writes it: ₹150 of items, an optional coupon, ₹30 delivery, ₹5 platform
/// fee; 10% commission on the eligible item value, split 60/40.
OrderMoney _money({int couponPaise = 0}) {
  final eligible = 15000 - couponPaise;
  final commission = (eligible * 1000 + 5000) ~/ 10000;
  final manager = (commission * 6000 + 5000) ~/ 10000;
  return OrderMoney.tryParse({
    'itemsSubtotal': 15000, 'couponDiscount': couponPaise, 'eligibleItemValue': eligible, 'deliveryFee': 3000, 'platformFee': 500,
    'customerTotal': eligible + 3000 + 500, 'commission': commission, 'managerShare': manager, 'quickyShare': commission - manager,
    'vendorEntitlement': eligible - commission, 'driverEntitlement': 3000, 'quickyRevenue': commission - manager + 500,
  })!;
}

Order _order({bool serverPriced = true, double gstAmount = 0, double total = 185, double coupon = 0}) => Order(
  id: 'ORD-TAX00001',
  vendorId: 'v1',
  vendorName: 'Ganesh Tiffins',
  userId: 'c1',
  userName: 'Asha',
  userPhone: '9000000006',
  items: const [OrderLineItem(productId: 'p50', name: 'Idli plate', price: 50, imageUrl: '', quantity: 3)],
  deliveryAddressLabel: 'Home',
  paymentMethod: PaymentMethod.cod,
  status: OrderStatus.delivered,
  subtotal: 150,
  deliveryFee: 30,
  platformFee: 5,
  gstAmount: gstAmount,
  total: total,
  couponDiscount: coupon,
  couponCode: coupon > 0 ? 'SAVE10' : null,
  placedAt: DateTime(2026, 10, 31),
  rebatePercent: 10,
  money: serverPriced ? _money(couponPaise: (coupon * 100).round()) : null,
);

Future<void> _pumpInvoice(WidgetTester tester, Order order, {Locale locale = const Locale('en')}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      orderByIdProvider.overrideWith((ref, _) => Stream.value(order)),
      reviewForOrderProvider.overrideWith((ref, _) => Stream<Review?>.value(null)),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: OrderDetailScreen(orderId: order.id),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('invoice', () {
    testWidgets('₹150 items + ₹30 delivery + ₹5 platform fee = ₹185; no GST line; the tax-inclusive note', (tester) async {
      await _pumpInvoice(tester, _order());
      expect(find.text(en.invoiceTitle), findsOneWidget);
      expect(find.textContaining('Tax invoice'), findsNothing, reason: 'not labelled a tax invoice');
      for (final (label, value) in [(en.priceSubtotal, 150.0), (en.priceDeliveryFee, 30.0), (en.pricePlatformFee, 5.0), (en.priceTotal, 185.0)]) {
        expect(find.text(label), findsWidgets, reason: label);
        expect(find.text(rs(value)), findsWidgets, reason: '$label $value');
      }
      expect(find.text('3x'), findsOneWidget);
      expect(find.byKey(const Key('invoiceTaxInclusiveNote')), findsOneWidget);
      expect(find.text(en.itemPricesInclusiveOfTaxes), findsOneWidget);
      for (final word in ['GST', 'CGST', 'SGST', 'IGST', 'HSN']) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
      expect(find.text(en.priceLegacyTax), findsNothing);
    });

    testWidgets('a coupon is shown as a discount; the total stays the server figure', (tester) async {
      await _pumpInvoice(tester, _order(coupon: 15, total: 170));
      expect(find.textContaining('SAVE10'), findsOneWidget);
      expect(find.text(rs(-15)), findsOneWidget);
      expect(find.text(rs(170)), findsWidgets);
      expect(find.textContaining('GST'), findsNothing);
    });

    testWidgets('a stray legacy GST field on a server-priced order is never shown or added', (tester) async {
      final o = _order(gstAmount: 7);
      expect(o.legacyTaxCharged, 0);
      await _pumpInvoice(tester, o);
      expect(find.text(en.priceLegacyTax), findsNothing);
      expect(find.text(rs(7)), findsNothing);
      expect(find.text(rs(185)), findsWidgets);
    });

    testWidgets('an order from the earlier client-priced flow keeps the tax it recorded (history unchanged)', (tester) async {
      final o = _order(serverPriced: false, gstAmount: 9, total: 194);
      expect(o.legacyTaxCharged, 9);
      await _pumpInvoice(tester, o);
      expect(find.text(en.priceLegacyTax), findsOneWidget);
      expect(find.text(rs(9)), findsOneWidget);
      expect(find.text(rs(194)), findsWidgets, reason: 'not repriced');
    });

    testWidgets('Telugu', (tester) async {
      await _pumpInvoice(tester, _order(), locale: const Locale('te'));
      expect(find.text(te.itemPricesInclusiveOfTaxes), findsOneWidget);
      expect(te.itemPricesInclusiveOfTaxes, isNot(en.itemPricesInclusiveOfTaxes));
      expect(te.pricesInclusiveOfTaxes, isNot(en.pricesInclusiveOfTaxes));
      expect(te.priceLegacyTax, isNot(en.priceLegacyTax));
    });
  });

  testWidgets('the cart says item prices are tax-inclusive', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(cartProvider.notifier).addItem(
      const Product(id: 'p50', name: 'Idli plate', description: '', price: 50, imageUrl: '', subCategory: 'Tiffin'),
      vendorId: 'v1',
      vendorName: 'Shop',
      deliveryFee: 30,
      rebatePercent: 10,
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: const CartScreen()),
    ));
    await tester.pump();
    expect(find.byKey(const Key('cartTaxInclusiveNote')), findsOneWidget);
    expect(find.text(en.pricesInclusiveOfTaxes), findsOneWidget);
    expect(find.textContaining('GST'), findsNothing);
  });

  test('the strings removed from the app are gone; the new ones exist in both languages', () {
    for (final l in [en, te]) {
      expect(l.itemPricesInclusiveOfTaxes, isNotEmpty);
      expect(l.pricesInclusiveOfTaxes, isNotEmpty);
    }
    expect(en.itemPricesInclusiveOfTaxes, 'Item prices are inclusive of applicable taxes.');
    expect(en.pricesInclusiveOfTaxes, 'Prices inclusive of applicable taxes.');
  });

  group('vendor product editing', () {
    // An existing product that still carries GST/HSN fields from the earlier flow.
    const legacy = Product(id: 'p1', name: 'Idli plate', description: '', price: 50, imageUrl: '', subCategory: 'Tiffin', taxCategoryId: 'tc-food-5');
    Future<void> pump(WidgetTester tester, {String? productId}) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentVendorIdProvider.overrideWithValue('v1'),
          currentVendorCategoryProvider.overrideWithValue(VendorCategory.food),
          vendorProductsProvider.overrideWith((ref, _) => Stream.value(const [legacy])),
          firestoreCategoriesProvider.overrideWith((ref) => Stream.value(const <Category>[])),
        ],
        child: MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: VendorAddEditProductScreen(productId: productId)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a new product: the price is the final selling price, inclusive of taxes; no tax picker', (tester) async {
      await pump(tester);
      expect(find.byKey(const Key('priceTaxInclusiveHint')), findsOneWidget);
      expect(find.text('Enter the final selling price, inclusive of applicable taxes.'), findsOneWidget);
      for (final word in ['GST', 'HSN', 'Tax category']) {
        expect(find.textContaining(word), findsNothing, reason: word);
      }
    });

    testWidgets('editing an existing product shows its price unchanged, with no tax controls', (tester) async {
      await pump(tester, productId: 'p1');
      expect(find.text('50'), findsOneWidget, reason: 'the stored price, never adjusted');
      expect(find.byKey(const Key('priceTaxInclusiveHint')), findsOneWidget);
      expect(find.textContaining('GST'), findsNothing);
    });
  });
}
