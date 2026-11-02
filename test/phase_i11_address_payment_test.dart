import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/core/session/session_controller.dart';
import 'package:foodiebell/data/models/account.dart';
import 'package:foodiebell/data/models/address.dart';
import 'package:foodiebell/data/models/order.dart';
import 'package:foodiebell/data/providers/firestore_addresses_provider.dart';
import 'package:foodiebell/data/providers/settlement_provider.dart';
import 'package:foodiebell/features/user/addresses/addresses_screen.dart';
import 'package:foodiebell/features/user/addresses/pin_saved_address.dart';
import 'package:foodiebell/features/user/checkout/checkout_address_screen.dart';
import 'package:foodiebell/l10n/generated/app_localizations.dart';
import 'package:foodiebell/shared/widgets/upi_payment_card.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Phase I.1.1: recovering saved addresses without a usable pin, the
/// commission label parity with QuickyAdmin, and telling "payment
/// received", "refund owed" and "refund completed" apart.
const _customer = Account(id: 'c1', role: AppRole.user, name: 'Asha', phone: '9000000006');

Address _address(String id, {double? lat, double? lng}) => Address(
  id: id,
  label: AddressLabel.home,
  recipientName: 'Asha',
  recipientPhone: '9000000006',
  line1: '12 Main Road',
  pincode: '522001',
  city: 'Guntur',
  latitude: lat,
  longitude: lng,
);

class _SignedIn extends SessionController {
  _SignedIn(super.ref) {
    state = const SessionState(role: AppRole.user, stage: AuthStage.active, account: _customer);
  }
}

Widget _app(Widget home, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

List<Override> _signedInWith(List<Address> addresses) => [
  sessionControllerProvider.overrideWith((ref) => _SignedIn(ref)),
  firestoreAddressesProvider.overrideWith((ref, userId) => Stream.value(addresses)),
];

Order _order(Map<String, dynamic> payment) => Order(
  id: 'ORD-TEST0001',
  vendorId: 'v1',
  vendorName: 'Shop',
  userId: 'c1',
  userName: 'Asha',
  userPhone: '9000000006',
  items: const [],
  deliveryAddressLabel: 'Home',
  paymentMethod: PaymentMethod.upi,
  status: OrderStatus.rejected,
  subtotal: 100,
  deliveryFee: 20,
  platformFee: 5,
  gstAmount: 0,
  total: 125,
  placedAt: DateTime(2026, 10, 29),
  rebatePercent: 10,
  payment: OrderPayment.tryParse({'amountPaise': 12500, ...payment}),
);

/// Drives [pinSavedAddressFlow] from a real widget, with fake look-up, GPS,
/// map and save steps; reports what happened.
class _Flow {
  LatLng? lookUpResult;
  LatLng? deviceResult;
  LatLng? mapResult;
  final starts = <LatLng>[];
  final saves = <(String, LatLng)>[];
  var deviceAsked = 0;
  Address? result;

  Widget button(Address address) => Consumer(
    builder: (context, ref, _) => Scaffold(
      body: ElevatedButton(
        onPressed: () async => result = await pinSavedAddressFlow(
          context,
          ref,
          address,
          lookUp: (_) async => lookUpResult,
          deviceStart: () async {
            deviceAsked++;
            return deviceResult;
          },
          confirmOnMap: (_, start) async {
            starts.add(start);
            return mapResult;
          },
          save: (id, pin) async => saves.add((id, pin)),
        ),
        child: const Text('go'),
      ),
    ),
  );
}

void main() {
  group('commission labels match QuickyAdmin', () {
    // Same basis-point fixtures as QuickyAdmin test/commission_display_test.dart
    // (`percentLabel`), which adds the "%".
    const shared = {1000: '10', 1250: '12.5', 1225: '12.25', 950: '9.5', 1005: '10.05', 6000: '60', 5500: '55'};

    test('formatPercent agrees with the admin panel for the same pricing', () {
      shared.forEach((bps, label) => expect(formatPercent(bps / 100), label, reason: '$bps'));
      final rates = PricingRates.from({'commissionBps': 1250, 'managerShareBps': 5500});
      expect('${formatPercent(rates.commissionPercent)}%', '12.5%');
      expect(rates.managerShareLabel, '55%');
    });

    final money = File('../QuickyAdmin/functions/lib/money.js');
    test('with no pricing doc both show the server default (functions/lib/money.js)', () {
      final source = money.readAsStringSync();
      int bps(String key) => int.parse(RegExp('$key:\\s*(\\d+)').firstMatch(source)!.group(1)!);
      final rates = PricingRates.from(null);
      expect(rates.commissionPercent, bps('commissionBps') / 100);
      // Phase I.8: the server's built-in split stays 6000 (not silently
      // changed), but it isn't the approved 50/50 — the app doesn't quote it.
      expect(bps('managerShareBps'), 6000);
      expect(rates.managerSharePercent, isNull);
    }, skip: money.existsSync() ? false : 'QuickyAdmin checkout not found next to this repo');
  });

  group('delivery pin validity (functions/routing.js rule)', () {
    test('accepts real points, rejects missing, out-of-range, non-finite and (0, 0)', () {
      expect(isValidDeliveryPin(16.3067, 80.4365), isTrue);
      expect(isValidDeliveryPin(-90, 180), isTrue);
      for (final (lat, lng) in [(null, 80.0), (16.0, null), (91.0, 80.0), (16.0, 181.0), (double.nan, 80.0), (16.0, double.infinity), (0.0, 0.0)]) {
        expect(isValidDeliveryPin(lat, lng), isFalse, reason: '($lat, $lng)');
      }
      expect(_address('a').hasValidPin, isFalse);
      expect(_address('a').withPin(16.3, 80.4).hasValidPin, isTrue);
    });
  });

  group('"Pin this address"', () {
    testWidgets('starts at the typed address and saves only the confirmed pin', (tester) async {
      final flow = _Flow()
        ..lookUpResult = const LatLng(16.30, 80.43)
        ..mapResult = const LatLng(16.31, 80.44);
      await tester.pumpWidget(_app(flow.button(_address('a1'))));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(flow.starts, [const LatLng(16.30, 80.43)]);
      expect(flow.deviceAsked, 0, reason: 'the phone position is never used unasked');
      expect(flow.saves, [('a1', const LatLng(16.31, 80.44))]);
      expect(flow.result!.latitude, 16.31);
      expect(find.text('Address pinned.'), findsOneWidget);
    });

    testWidgets('closing the map saves nothing', (tester) async {
      final flow = _Flow()..lookUpResult = const LatLng(16.30, 80.43);
      await tester.pumpWidget(_app(flow.button(_address('a1'))));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(flow.saves, isEmpty);
      expect(flow.result, isNull);
    });

    testWidgets('address not found: asks before using the phone position; "Not now" stops', (tester) async {
      final flow = _Flow();
      await tester.pumpWidget(_app(flow.button(_address('a1'))));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't find this address on the map"), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect([flow.deviceAsked, flow.starts.length, flow.saves.length], [0, 0, 0]);
    });

    testWidgets('address not found: with consent, starts from the phone — still confirmed on the map', (tester) async {
      final flow = _Flow()
        ..deviceResult = const LatLng(16.29, 80.42)
        ..mapResult = const LatLng(16.295, 80.425);
      await tester.pumpWidget(_app(flow.button(_address('a1'))));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start from my location'));
      await tester.pumpAndSettle();
      expect(flow.starts, [const LatLng(16.29, 80.42)]);
      expect(flow.saves, [('a1', const LatLng(16.295, 80.425))]);
    });

    testWidgets('an invalid confirmed point is not saved', (tester) async {
      final flow = _Flow()
        ..lookUpResult = const LatLng(16.30, 80.43)
        ..mapResult = const LatLng(0, 0);
      await tester.pumpWidget(_app(flow.button(_address('a1'))));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(flow.saves, isEmpty);
    });

    testWidgets('saved addresses offer it only for addresses without a usable pin', (tester) async {
      await tester.pumpWidget(_app(
        const AddressesScreen(),
        overrides: _signedInWith([_address('old'), _address('ok', lat: 16.3, lng: 80.4)]),
      ));
      await tester.pump();
      expect(find.text('Pin this address'), findsOneWidget);
      expect(find.textContaining('Not pinned on the map yet'), findsOneWidget);
    });
  });

  group('checkout needs a valid pin', () {
    Finder deliverHere() => find.widgetWithText(ElevatedButton, 'Deliver Here');

    testWidgets('an unpinned address cannot be delivered to', (tester) async {
      await tester.pumpWidget(_app(const CheckoutAddressScreen(), overrides: _signedInWith([_address('old')])));
      await tester.pump();
      await tester.pump();
      expect(tester.widget<ElevatedButton>(deliverHere()).onPressed, isNull);
      expect(find.text('Pin this address on the map before ordering.'), findsOneWidget);
      expect(find.text('Pin this address'), findsOneWidget);
    });

    testWidgets('a pinned address is picked by default and can be delivered to', (tester) async {
      await tester.pumpWidget(_app(
        const CheckoutAddressScreen(),
        overrides: _signedInWith([_address('old'), _address('ok', lat: 16.3, lng: 80.4)]),
      ));
      await tester.pump();
      await tester.pump();
      expect(tester.widget<ElevatedButton>(deliverHere()).onPressed, isNotNull);
      expect(find.text('Pin this address on the map before ordering.'), findsNothing);
    });
  });

  group('payment received vs refund owed vs refund completed', () {
    test('each state has its own label and tone', () {
      expect([OrderPaymentStatus.verified.label, OrderPaymentStatus.verified.tone], ['Payment received', PaymentTone.received]);
      expect([OrderPaymentStatus.collected.label, OrderPaymentStatus.collected.tone], ['Payment received (cash)', PaymentTone.received]);
      expect([OrderPaymentStatus.refundDue.label, OrderPaymentStatus.refundDue.tone], ['Refund owed', PaymentTone.refundOwed]);
      expect([OrderPaymentStatus.refunded.label, OrderPaymentStatus.refunded.tone], ['Refund confirmed', PaymentTone.refundCompleted]);
      // Nothing else claims money was received or returned.
      for (final s in OrderPaymentStatus.values) {
        final claims = s.label.startsWith('Payment received') || s.label.startsWith('Refund confirmed');
        expect(claims, const {OrderPaymentStatus.verified, OrderPaymentStatus.collected, OrderPaymentStatus.refunded}.contains(s), reason: s.name);
      }
    });

    testWidgets('UPI card: a refund that is owed is not presented as done', (tester) async {
      await tester.pumpWidget(_app(Scaffold(body: SingleChildScrollView(child: UpiPaymentCard(order: _order({'status': 'refundDue'}))))));
      expect(find.text('Refund owed'), findsOneWidget);
      expect(find.textContaining('owes it back'), findsOneWidget);
      expect(find.textContaining('will be returned'), findsNothing);
      expect(find.text('Refund confirmed'), findsNothing);
    });

    testWidgets('UPI card: a completed refund and a received payment', (tester) async {
      await tester.pumpWidget(_app(Scaffold(body: SingleChildScrollView(child: UpiPaymentCard(order: _order({'status': 'refunded'}))))));
      expect(find.text('Refund confirmed'), findsOneWidget);
      await tester.pumpWidget(_app(Scaffold(body: SingleChildScrollView(child: UpiPaymentCard(order: _order({'status': 'verified'}))))));
      expect(find.text('Payment received'), findsOneWidget);
    });
  });
}
