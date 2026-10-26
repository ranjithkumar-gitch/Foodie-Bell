import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Direct UPI payments to a vendor's own UPI ID (`Account.upiIds`), through
/// whichever UPI app the User has installed — PhonePe, Google Pay, Paytm,
/// BHIM, ... — with the amount already filled in.
///
/// On Android this goes through `MainActivity.kt`'s `com.quickmandi/upi`
/// channel, which opens the app with `startActivityForResult` so its
/// response (SUCCESS/FAILURE/SUBMITTED + transaction id) comes back here.
/// iOS gives no such callback, so there the link is just opened and the
/// result is [UpiStatus.unknown] — the caller has to ask the User.
///
/// The response comes from the UPI app on the User's own phone, not from a
/// bank or payment gateway, so it is not proof of payment on its own — the
/// vendor should still see the money arrive in their UPI app.
const _channel = MethodChannel('com.quickmandi/upi');

class UpiApp {
  const UpiApp({required this.packageName, required this.name, this.icon});

  final String packageName;
  final String name;

  /// PNG bytes of the app's launcher icon.
  final Uint8List? icon;
}

enum UpiStatus { success, failure, submitted, cancelled, unknown }

class UpiPaymentResult {
  const UpiPaymentResult(this.status, {this.transactionId, this.transactionRef});

  final UpiStatus status;

  /// The UPI app's own transaction id (`txnId`) — shown on the User's
  /// payment history and the vendor's bank statement.
  final String? transactionId;
  final String? transactionRef;
}

/// UPI apps installed on this phone. Always empty off Android.
Future<List<UpiApp>> installedUpiApps() async {
  if (!Platform.isAndroid) return const [];
  final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>('getUpiApps') ?? const [];
  return [
    for (final app in raw)
      UpiApp(
        packageName: app['packageName'] as String,
        name: app['name'] as String,
        icon: app['icon'] as Uint8List?,
      ),
  ]..sort((a, b) => a.name.compareTo(b.name));
}

/// The standard `upi://pay` deep link every UPI app understands.
Uri buildUpiUri({
  required String upiId,
  required String payeeName,
  required double amount,
  required String transactionRef,
  required String note,
}) => Uri(
  scheme: 'upi',
  host: 'pay',
  queryParameters: {
    'pa': upiId,
    'pn': payeeName,
    'am': amount.toStringAsFixed(2),
    'cu': 'INR',
    'tr': transactionRef,
    'tn': note,
  },
);

/// Opens [app] (or, off Android, whatever handles `upi://`) to pay
/// [amount] to [upiId]. Throws [UpiAppNotFoundException] when no UPI app
/// can take the payment.
Future<UpiPaymentResult> payWithUpi({
  UpiApp? app,
  required String upiId,
  required String payeeName,
  required double amount,
  required String transactionRef,
  required String note,
}) async {
  final uri = buildUpiUri(
    upiId: upiId,
    payeeName: payeeName,
    amount: amount,
    transactionRef: transactionRef,
    note: note,
  );

  if (!Platform.isAndroid) {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) throw const UpiAppNotFoundException();
    return const UpiPaymentResult(UpiStatus.unknown);
  }

  final String? response;
  try {
    response = await _channel.invokeMethod<String>('pay', {
      'uri': uri.toString(),
      'packageName': app?.packageName,
    });
  } on PlatformException catch (e) {
    if (e.code == 'no_app') throw const UpiAppNotFoundException();
    rethrow;
  }
  return parseUpiResponse(response);
}

/// Parses a UPI app's response, e.g.
/// `txnId=AXI123&responseCode=00&Status=SUCCESS&txnRef=QK123`. Key casing
/// varies between apps, so keys are matched case-insensitively.
UpiPaymentResult parseUpiResponse(String? response) {
  if (response == null || response.trim().isEmpty) {
    return const UpiPaymentResult(UpiStatus.cancelled);
  }
  final fields = <String, String>{};
  for (final part in response.split('&')) {
    final eq = part.indexOf('=');
    if (eq <= 0) continue;
    fields[part.substring(0, eq).toLowerCase()] = Uri.decodeComponent(part.substring(eq + 1));
  }
  final status = switch ((fields['status'] ?? '').toUpperCase()) {
    'SUCCESS' => UpiStatus.success,
    'SUBMITTED' || 'PENDING' => UpiStatus.submitted,
    'FAILURE' || 'FAILED' => UpiStatus.failure,
    _ => UpiStatus.failure,
  };
  return UpiPaymentResult(
    status,
    transactionId: fields['txnid'],
    transactionRef: fields['txnref'],
  );
}

class UpiAppNotFoundException implements Exception {
  const UpiAppNotFoundException();
}

final _upiIdPattern = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');

/// Whether [value] looks like a UPI ID (`name@bank`). Can't confirm the
/// ID actually exists — only the UPI app can, at payment time.
bool isValidUpiId(String value) => _upiIdPattern.hasMatch(value.trim());

/// The UPI app a UPI ID was most likely created in, read off its handle
/// (`@ybl` → PhonePe, `@okaxis` → Google Pay, ...) — just a label to help
/// the vendor recognise their IDs, payments work the same whatever it says.
String upiAppLabel(String upiId) {
  final handle = upiId.split('@').last.toLowerCase();
  if (const {'ybl', 'ibl', 'axl'}.contains(handle)) return 'PhonePe';
  if (handle.startsWith('ok')) return 'Google Pay';
  if (const {'paytm', 'ptyes', 'ptaxis', 'pthdfc', 'ptsbi'}.contains(handle)) return 'Paytm';
  if (handle == 'upi') return 'BHIM';
  if (handle == 'apl' || handle == 'yapl' || handle == 'rapl') return 'Amazon Pay';
  return 'UPI';
}
