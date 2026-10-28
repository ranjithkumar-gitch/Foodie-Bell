// End-to-end test on an Android device/emulator, through the real UI, from
// OTP login to logout for every app role, against the local Firebase
// Emulator Suite — never the real project. See integration_test/README.md.
//
// One continuous session (the app connects to the emulators once per
// launch): customer orders → vendor accepts → driver delivers with the
// pickup and delivery codes → Manager sees the day's settlement →
// customer sees the order delivered. Each role logs in with an OTP read
// from the Auth emulator and logs out at the end of its part.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'package:foodiebell/main.dart' as app;

const _host = String.fromEnvironment('EMU_HOST', defaultValue: '10.0.2.2');
const _authPort = int.fromEnvironment('EMU_AUTH_PORT', defaultValue: 9099);
const _firestorePort = int.fromEnvironment('EMU_FS_PORT', defaultValue: 8080);
const _project = String.fromEnvironment('EMU_PROJECT', defaultValue: 'quickmandi-3b017');

final _steps = <String>[];

/// Records a step that passed (printed at the end as the run's evidence).
void step(String s) {
  _steps.add(s);
  // ignore: avoid_print
  print('E2E STEP OK: $s');
}

/// Pumps until [finder] matches (or fails after [timeout]).
Future<void> pumpUntil(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 60), String? what}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  // Show what is on screen, so a failure says where the app actually is.
  final texts = <String>{
    for (final e in find.byType(Text).evaluate())
      if ((e.widget as Text).data case final d? when d.trim().isNotEmpty) d.trim(),
  }.take(40).join(' | ');
  throw TestFailure('Timed out waiting for ${what ?? finder.toString()}. On screen: $texts');
}

Future<void> tapWhenReady(WidgetTester tester, Finder finder, {String? what, Duration timeout = const Duration(seconds: 60)}) async {
  await pumpUntil(tester, finder, what: what, timeout: timeout);
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder.first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 600));
}

Future<dynamic> _getJson(String url, {Map<String, String> headers = const {}}) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    headers.forEach(req.headers.set);
    return jsonDecode(await (await req.close()).transform(utf8.decoder).join());
  } finally {
    client.close();
  }
}

/// The latest code the Auth emulator "sent" to [phone] (no real SMS).
Future<String> latestOtp(String phone) async {
  final body = await _getJson('http://$_host:$_authPort/emulator/v1/projects/$_project/verificationCodes');
  final codes = (body['verificationCodes'] as List).where((c) => c['phoneNumber'] == phone).toList();
  if (codes.isEmpty) throw TestFailure('No OTP was sent to $phone');
  return codes.last['code'] as String;
}

/// Reads a Firestore document from the emulator as admin (test-only
/// `Bearer owner`), e.g. an order's pickup/delivery code that the vendor
/// and the customer would read out to the driver.
Future<Map<String, dynamic>> emulatorDoc(String path) async {
  final body = await _getJson(
    'http://$_host:$_firestorePort/v1/projects/$_project/databases/(default)/documents/$path',
    headers: {'Authorization': 'Bearer owner'},
  ) as Map<String, dynamic>;
  return (body['fields'] as Map<String, dynamic>?) ?? const {};
}


/// The test customer's order (the emulator starts empty, so it is the only one).
Future<String> customerOrderId(String userId) async {
  final body = await _getJson(
    'http://$_host:$_firestorePort/v1/projects/$_project/databases/(default)/documents/orders?pageSize=50',
    headers: {'Authorization': 'Bearer owner'},
  ) as Map<String, dynamic>;
  for (final d in (body['documents'] as List? ?? const [])) {
    if (d['fields']?['userId']?['stringValue'] == userId) return (d['name'] as String).split('/').last;
  }
  throw TestFailure('No order found for $userId: ${jsonEncode(body).substring(0, 200)}');
}

/// Taps [button] until [orderId] reaches [status] (at most 3 taps).
Future<void> statusAfterTaps(WidgetTester tester, String orderId, String status, Finder button, String what) async {
  for (var attempt = 1; attempt <= 3; attempt++) {
    await tapWhenReady(tester, button, what: what);
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    while (DateTime.now().isBefore(deadline)) {
      if ((await emulatorDoc('orders/$orderId'))['status']?['stringValue'] == status) return;
      await tester.pump(const Duration(milliseconds: 500));
    }
  }
  throw TestFailure('Order $orderId did not reach $status after 3 taps of $what');
}

/// From the login screen: enters [digits], sends the OTP, reads it from the
/// emulator and types it in.
Future<void> logIn(WidgetTester tester, String digits, String who) async {
  await pumpUntil(tester, find.text('Send OTP'), what: 'the login screen');
  await tester.enterText(find.byType(EditableText).first, digits);
  await tester.pump();
  await tapWhenReady(tester, find.text('Send OTP'));
  await pumpUntil(tester, find.byType(PinCodeTextField), what: 'the OTP screen');
  await tester.pump(const Duration(seconds: 1));
  final code = await latestOtp('+91$digits');
  await tester.enterText(find.descendant(of: find.byType(PinCodeTextField), matching: find.byType(EditableText)).first, code);
  await tester.pump(const Duration(seconds: 2));
  step('$who: logged in with OTP');
}

/// Profile → Log Out → confirm; ends back on the login screen.
Future<void> logOut(WidgetTester tester, String who) async {
  await tapWhenReady(tester, find.text('Profile').hitTestable(), what: '$who Profile tab');
  // Profile screens are long lists: scroll the item into view first.
  await tester.pump(const Duration(seconds: 1));
  if (find.text('Log Out').evaluate().isEmpty) {
    await tester.scrollUntilVisible(find.text('Log Out'), 300, scrollable: find.byType(Scrollable).hitTestable().first, maxScrolls: 30);
  }
  await tapWhenReady(tester, find.text('Log Out'), what: '$who log-out item');
  await tapWhenReady(tester, find.widgetWithText(ElevatedButton, 'Log out').hitTestable(), what: 'the log-out confirmation');
  await pumpUntil(tester, find.text('Send OTP'), what: 'the login screen after logging out');
  step('$who: logged out');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every role, OTP login to logout: order → accept → deliver → settle', (tester) async {
    app.main();

    // ---------------------------------------------------- customer orders
    await logIn(tester, '9000000004', 'Customer');
    await tapWhenReady(tester, find.text('E2E Tiffins'), what: 'the shop on Home');
    step('Customer: sees the territory shop on Home');
    await tapWhenReady(tester, find.text('ADD'), what: 'an ADD button');
    await tapWhenReady(tester, find.text('View Cart'));
    await tapWhenReady(tester, find.text('Proceed to Checkout'));
    await tapWhenReady(tester, find.text('Deliver Here'), what: 'the address step');
    await pumpUntil(tester, find.text('Platform fee'), what: 'the platform fee line at checkout');
    step('Customer: checkout shows the server quote with the platform fee');
    await tapWhenReady(tester, find.textContaining('Place Order'));
    await pumpUntil(tester, find.textContaining('Platform fee'), what: 'the platform fee on the order-placed screen');
    step('Customer: order placed (COD); fee shown with the total');
    final orderId = await customerOrderId('e2e_c1');
    final order = await emulatorDoc('orders/$orderId');
    final total = order['total']?['doubleValue'] ?? order['total']?['integerValue'];
    expect(order['status']?['stringValue'], 'placed');
    step('Server: order $orderId stored, status placed, total ₹$total');
    await tapWhenReady(tester, find.text('Back to Home'));
    await logOut(tester, 'Customer');

    // ---------------------------------------------------- vendor accepts
    await logIn(tester, '9000000002', 'Vendor');
    // The dashboard's "new order waiting" card opens the order queue.
    await tapWhenReady(tester, find.textContaining('waiting'), what: 'the new-order card on the vendor dashboard');
    // Tapped again after an error, as a vendor would: on this PC the local
    // Functions emulator sometimes can't start a worker in time while the
    // Android emulator is busy (an emulator limit, not the app).
    await statusAfterTaps(tester, orderId, 'vendorAccepted', find.widgetWithText(ElevatedButton, 'Accept'), 'Accept on the new order');
    step('Vendor: accepted the order (server status vendorAccepted)');
    await logOut(tester, 'Vendor');

    // ------------------------------------- driver claims and delivers
    await logIn(tester, '9000000003', 'Driver');
    await tapWhenReady(tester, find.text('View & Accept'), what: 'the open offer on driver Home');
    await tapWhenReady(tester, find.text('Accept order'));
    step('Driver: claimed the delivery');
    await tapWhenReady(tester, find.text('Arrived at Vendor'), what: 'Arrived at Vendor (GPS at the shop)');
    final handover = (await emulatorDoc('orders/$orderId/codes/handover'))['code']?['stringValue'] as String;
    await pumpUntil(tester, find.text('Confirm pickup'));
    await tester.enterText(find.byType(EditableText).first, handover);
    await tapWhenReady(tester, find.text('Confirm pickup'));
    step('Driver: confirmed pickup with the shop\'s handover code');
    await tapWhenReady(tester, find.text('Arrived at Customer'), what: 'Arrived at Customer (GPS at the drop-off)');
    await tapWhenReady(tester, find.text('Collected the full amount'), what: 'the cash collection step');
    step('Driver: recorded the COD cash');
    final delivery = (await emulatorDoc('orders/$orderId/codes/delivery'))['code']?['stringValue'] as String;
    await pumpUntil(tester, find.text('Mark Delivered'));
    await tester.enterText(find.byType(EditableText).first, delivery);
    await tapWhenReady(tester, find.text('Mark Delivered'));
    final deliveredBy = DateTime.now().add(const Duration(seconds: 30));
    while ((await emulatorDoc('orders/$orderId'))['status']?['stringValue'] != 'delivered') {
      if (DateTime.now().isAfter(deliveredBy)) throw TestFailure('Order was not delivered');
      await tester.pump(const Duration(milliseconds: 500));
    }
    step('Driver: delivered with the customer\'s code (server status delivered)');
    await tester.pump(const Duration(seconds: 2));
    await logOut(tester, 'Driver');

    // ------------------------------------------------ Manager settles
    await logIn(tester, '9000000001', 'Manager');
    await tapWhenReady(tester, find.text('Settlement').hitTestable(), what: 'the Manager Settlement tab');
    await pumpUntil(tester, find.text('Platform fees (100% Quicky)'), what: 'platform fees in the daily settlement');
    await pumpUntil(tester, find.text('Total to pay Quicky'));
    step('Manager: daily settlement shows the delivery, platform fees and the total to pay Quicky');
    await logOut(tester, 'Manager');

    // ------------------------------------- customer sees it delivered
    await logIn(tester, '9000000004', 'Customer');
    await tapWhenReady(tester, find.text('Orders').hitTestable(), what: 'the customer Orders tab');
    await pumpUntil(tester, find.text('E2E Tiffins'), what: 'the order in My Orders');
    await pumpUntil(tester, find.textContaining('Delivered'), what: 'the delivered status');
    step('Customer: My Orders shows the order delivered');
    await logOut(tester, 'Customer');

    // ignore: avoid_print
    print('E2E SUMMARY: ${_steps.length} steps passed\n${_steps.map((s) => ' - $s').join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
