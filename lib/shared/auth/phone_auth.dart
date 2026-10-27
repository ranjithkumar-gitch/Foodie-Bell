import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// What [sendPhoneCode] ended in: an SMS code is on its way
/// ([SmsCodeSent]), or Android verified the number on its own before one
/// was even needed ([PhoneVerifiedAutomatically] — already signed in).
sealed class PhoneCodeResult {
  const PhoneCodeResult();
}

class SmsCodeSent extends PhoneCodeResult {
  const SmsCodeSent(this.verificationId, this.resendToken);
  final String verificationId;
  final int? resendToken;
}

class PhoneVerifiedAutomatically extends PhoneCodeResult {
  const PhoneVerifiedAutomatically();
}

/// Starts Firebase Phone Auth for [phoneNumber] (E.164, e.g. `+91…`) and
/// completes once Firebase either sends the code or verifies instantly.
/// Throws [FirebaseAuthException] on failure — [phoneAuthErrorMessage] turns
/// that into something to show.
///
/// Pass the last [SmsCodeSent.resendToken] as [resendToken] when resending,
/// so Firebase treats it as a resend rather than a fresh attempt.
///
/// Android can also auto-retrieve the SMS *after* the code was sent, while
/// the OTP screen is already up. That late sign-in happens here too; the
/// OTP screen notices it through `authStateChanges()` rather than a callback.
///
/// Any session still signed in beforehand (e.g. an anonymous one from an
/// older build) is signed out first, so the verified phone user is the only
/// identity the next step ever sees.
Future<PhoneCodeResult> sendPhoneCode(String phoneNumber, {int? resendToken}) async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null && auth.currentUser!.phoneNumber != phoneNumber) {
    await auth.signOut();
  }
  final completer = Completer<PhoneCodeResult>();
  await auth.verifyPhoneNumber(
    phoneNumber: phoneNumber,
    forceResendingToken: resendToken,
    timeout: const Duration(seconds: 60),
    verificationCompleted: (credential) async {
      try {
        await auth.signInWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
        return;
      }
      if (!completer.isCompleted) completer.complete(const PhoneVerifiedAutomatically());
    },
    verificationFailed: (e) {
      if (!completer.isCompleted) completer.completeError(e);
    },
    codeSent: (verificationId, token) {
      if (!completer.isCompleted) completer.complete(SmsCodeSent(verificationId, token));
    },
    codeAutoRetrievalTimeout: (_) {},
  );
  return completer.future;
}

/// Signs in with the 6-digit [smsCode] the person typed for [verificationId].
Future<void> signInWithPhoneCode(String verificationId, String smsCode) =>
    FirebaseAuth.instance.signInWithCredential(
      PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode),
    );

/// User-facing text for every phone-auth failure Firebase reports.
String phoneAuthErrorMessage(FirebaseAuthException e) => switch (e.code) {
  'invalid-verification-code' => 'Incorrect code. Please check it and try again.',
  'session-expired' || 'code-expired' || 'invalid-verification-id' || 'missing-verification-id' =>
    'This code has expired. Tap "Resend code" to get a new one.',
  'too-many-requests' => 'Too many attempts from this device. Please wait a while and try again.',
  'quota-exceeded' => "We can't send more codes right now. Please try again later.",
  'network-request-failed' => 'No internet connection. Check your network and try again.',
  'invalid-phone-number' || 'missing-phone-number' => "That mobile number isn't valid.",
  'user-disabled' => 'This number has been blocked. Please contact support.',
  'captcha-check-failed' || 'web-context-cancelled' || 'web-context-already-presented' =>
    'Verification was cancelled. Please try again.',
  'app-not-authorized' || 'missing-client-identifier' || 'invalid-app-credential' || 'missing-app-credential' =>
    "This app can't verify phone numbers yet. Please contact support.",
  _ => 'Verification failed. Please try again.',
};
