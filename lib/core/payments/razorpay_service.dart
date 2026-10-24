import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

/// Razorpay's *public* Key ID — safe to ship in the app (it only identifies
/// the merchant account to Checkout). The matching Key Secret must never be
/// bundled here: anything in an APK/IPA can be extracted, and the secret is
/// what authorizes captures/refunds/order creation. It belongs on a server
/// (Cloud Functions) only. Overridable per build with
/// `--dart-define=RAZORPAY_KEY_ID=rzp_live_...` so going live doesn't need a
/// code change.
const razorpayKeyId = String.fromEnvironment('RAZORPAY_KEY_ID', defaultValue: 'rzp_test_Tg9QiJ7aakPoRo');

/// Thrown by [RazorpayService.pay] when Checkout closes without a completed
/// payment. [cancelled] separates "User backed out" (not an error worth
/// alarming them about) from a real failure.
class RazorpayPaymentException implements Exception {
  const RazorpayPaymentException({required this.cancelled, this.message});

  final bool cancelled;
  final String? message;

  @override
  String toString() => 'RazorpayPaymentException(cancelled: $cancelled, message: $message)';
}

/// Wraps the `razorpay_flutter` plugin's event-listener API in a single
/// awaitable [pay] call, so a screen doesn't have to manage listeners or
/// their cleanup itself. One instance for the app's lifetime
/// ([razorpayServiceProvider]) — only one Checkout can be open at a time.
class RazorpayService {
  RazorpayService() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  final Razorpay _razorpay = Razorpay();
  Completer<String>? _pending;

  /// Opens Razorpay Checkout and completes with the Razorpay payment id
  /// (`pay_...`) once the payment goes through. Which method to pay with
  /// (UPI, card, netbanking…) is picked inside Checkout itself, from
  /// whatever's enabled on the Razorpay account — nothing is restricted
  /// here, so a method that's switched off in the dashboard just doesn't
  /// appear instead of failing the whole payment. Throws
  /// [RazorpayPaymentException] if it's cancelled or fails. [amount] is in
  /// rupees — converted to paise here, since that's the unit Razorpay
  /// expects.
  Future<String> pay({
    required double amount,
    required String orderId,
    required String description,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
  }) {
    if (_pending != null && !_pending!.isCompleted) {
      throw StateError('A payment is already in progress.');
    }
    final completer = Completer<String>();
    _pending = completer;

    _razorpay.open({
      'key': razorpayKeyId,
      'amount': (amount * 100).round(),
      'currency': 'INR',
      'name': 'Quicky',
      'description': description,
      // Shows up against the payment in the Razorpay dashboard, so a
      // payment can be traced back to its order even if the app never got
      // to write the order doc (crash/kill right after paying).
      'notes': {'orderId': orderId},
      'prefill': {
        'name': ?customerName,
        'contact': ?customerPhone,
        'email': ?customerEmail,
      },
    });
    return completer.future;
  }

  void _onSuccess(PaymentSuccessResponse response) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    final paymentId = response.paymentId;
    if (paymentId == null) {
      pending.completeError(const RazorpayPaymentException(cancelled: false, message: 'Missing payment id'));
    } else {
      pending.complete(paymentId);
    }
  }

  void _onError(PaymentFailureResponse response) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    pending.completeError(RazorpayPaymentException(cancelled: response.code == Razorpay.PAYMENT_CANCELLED, message: response.message));
  }

  // No `external.wallets` are passed to Checkout, so this shouldn't fire —
  // treated as a failed attempt if it ever does, so `pay` never hangs.
  void _onExternalWallet(ExternalWalletResponse response) {
    final pending = _pending;
    if (pending == null || pending.isCompleted) return;
    pending.completeError(RazorpayPaymentException(cancelled: false, message: 'Unsupported wallet: ${response.walletName}'));
  }

  void dispose() => _razorpay.clear();
}

final razorpayServiceProvider = Provider<RazorpayService>((ref) {
  final service = RazorpayService();
  ref.onDispose(service.dispose);
  return service;
});
