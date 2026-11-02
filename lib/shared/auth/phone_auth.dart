import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// What [sendPhoneCode] ended in: an SMS code is on its way
/// ([SmsCodeSent]), or Android verified the number on its own before one
/// was even needed ([PhoneVerifiedAutomatically] — already signed in).
sealed class PhoneCodeResult {
  const PhoneCodeResult();
}

class SmsCodeSent extends PhoneCodeResult {
  const SmsCodeSent(this.verificationId, this.resendToken, {this.attempt});
  final String verificationId;
  final int? resendToken;

  /// The verification this code belongs to. The OTP screen cancels it when
  /// it goes away, so a late Android auto-retrieval can't sign anyone in
  /// behind a screen that's gone.
  final PhoneVerificationAttempt? attempt;
}

class PhoneVerifiedAutomatically extends PhoneCodeResult {
  const PhoneVerifiedAutomatically();
}

/// One `verifyPhoneNumber` run. Firebase can call back long after the
/// screen that started it has moved on (a late `codeSent`, a late Android
/// auto-retrieval); once an attempt is cancelled — timed out, superseded by
/// a newer send, or its screen disposed — those callbacks are ignored.
class PhoneVerificationAttempt {
  PhoneVerificationAttempt._(this.id);

  final int id;
  bool _cancelled = false;

  bool get isActive => !_cancelled && identical(_currentAttempt, this);

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _log('attempt_cancelled', attempt: id);
  }
}

PhoneVerificationAttempt? _currentAttempt;
var _attemptCounter = 0;

/// How long [sendPhoneCode] waits for Firebase to send a code (or verify
/// instantly) before giving up with `quicky-otp-timeout`, so the button
/// never spins forever. 45 s: Firebase's own SMS path usually answers in
/// seconds, and Android's Play Integrity / reCAPTCHA fallback can take ~30.
const otpSendTimeout = Duration(seconds: 45);

/// How long checking a typed code may take before `quicky-verify-timeout`.
const otpVerifyTimeout = Duration(seconds: 30);

/// Minimum gap between two code requests for the same number from this
/// device (matches the OTP screen's resend countdown). Stops repeated taps,
/// back-and-retry and resend loops from requesting a stream of SMS — each
/// one is billed and counts toward Firebase's per-number throttling.
const otpResendCooldown = Duration(seconds: 30);

final _lastCodeSentAt = <String, DateTime>{};

/// The Firebase Auth calls phone sign-in needs — swapped for a fake in
/// tests (`test/phase_i8_otp_test.dart`).
abstract class PhoneAuthBackend {
  String? get currentUserPhone;
  bool get hasCurrentUser;
  Future<void> signOut();
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    int? forceResendingToken,
    required Duration timeout,
    required void Function(PhoneAuthCredential credential) verificationCompleted,
    required void Function(FirebaseAuthException e) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
  });
  Future<void> signInWithCredential(AuthCredential credential);
}

class _FirebasePhoneAuthBackend implements PhoneAuthBackend {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  @override
  String? get currentUserPhone => _auth.currentUser?.phoneNumber;

  @override
  bool get hasCurrentUser => _auth.currentUser != null;

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    int? forceResendingToken,
    required Duration timeout,
    required void Function(PhoneAuthCredential credential) verificationCompleted,
    required void Function(FirebaseAuthException e) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
  }) => _auth.verifyPhoneNumber(
    phoneNumber: phoneNumber,
    forceResendingToken: forceResendingToken,
    timeout: timeout,
    verificationCompleted: verificationCompleted,
    verificationFailed: verificationFailed,
    codeSent: codeSent,
    codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
  );

  @override
  Future<void> signInWithCredential(AuthCredential credential) => _auth.signInWithCredential(credential);
}

@visibleForTesting
PhoneAuthBackend phoneAuthBackend = _FirebasePhoneAuthBackend();

@visibleForTesting
DateTime Function() phoneAuthClock = DateTime.now;

/// Privacy-safe diagnostics: event names, Firebase error codes, attempt
/// numbers and timings only — never a phone number, OTP, verification id
/// or token. Replaceable (e.g. by a crash-reporting breadcrumb).
void Function(String event, {String? code, int? attempt, int? elapsedMs}) phoneAuthDiagnostics = _debugLog;

void _debugLog(String event, {String? code, int? attempt, int? elapsedMs}) {
  debugPrint(
    'phone_auth: $event'
    '${attempt == null ? '' : ' attempt=$attempt'}'
    '${code == null ? '' : ' code=$code'}'
    '${elapsedMs == null ? '' : ' ms=$elapsedMs'}',
  );
}

void _log(String event, {String? code, int? attempt, int? elapsedMs}) =>
    phoneAuthDiagnostics(event, code: code, attempt: attempt, elapsedMs: elapsedMs);

/// Forgets cooldowns and the current attempt (tests only).
@visibleForTesting
void resetPhoneAuthState() {
  _lastCodeSentAt.clear();
  _currentAttempt?.cancel();
  _currentAttempt = null;
}

/// Starts Firebase Phone Auth for [phoneNumber] (E.164, e.g. `+91…`) and
/// completes once Firebase either sends the code or verifies instantly.
/// Throws [FirebaseAuthException] on failure — [phoneAuthErrorMessage] turns
/// that into something to show. Besides Firebase's own codes it throws
/// `quicky-otp-timeout` (no answer within [otpSendTimeout]) and
/// `quicky-otp-cooldown` (a code went to this number less than
/// [otpResendCooldown] ago; the message says how long to wait).
///
/// Pass the last [SmsCodeSent.resendToken] as [resendToken] when resending,
/// so Firebase treats it as a resend rather than a fresh attempt.
///
/// Android can also auto-retrieve the SMS *after* the code was sent, while
/// the OTP screen is already up. That late sign-in happens here too (unless
/// the attempt was cancelled); the OTP screen notices it through
/// `authStateChanges()` rather than a callback.
///
/// Any session still signed in beforehand (e.g. an anonymous one from an
/// older build) is signed out first, so the verified phone user is the only
/// identity the next step ever sees.
Future<PhoneCodeResult> sendPhoneCode(String phoneNumber, {int? resendToken, Duration timeout = otpSendTimeout}) async {
  final now = phoneAuthClock();
  final last = _lastCodeSentAt[phoneNumber];
  if (last != null) {
    final wait = otpResendCooldown - now.difference(last);
    if (wait > Duration.zero) {
      final seconds = (wait.inMilliseconds / 1000).ceil();
      _log('send_blocked_cooldown', elapsedMs: wait.inMilliseconds);
      throw FirebaseAuthException(
        code: 'quicky-otp-cooldown',
        message: 'Please wait $seconds s before requesting another code.',
      );
    }
  }

  final backend = phoneAuthBackend;
  if (backend.hasCurrentUser && backend.currentUserPhone != phoneNumber) {
    await backend.signOut();
  }

  // A newer send supersedes any earlier attempt still waiting on Firebase.
  _currentAttempt?.cancel();
  final attempt = PhoneVerificationAttempt._(++_attemptCounter);
  _currentAttempt = attempt;
  final completer = Completer<PhoneCodeResult>();
  final started = phoneAuthClock();
  int elapsed() => phoneAuthClock().difference(started).inMilliseconds;
  _log(resendToken == null ? 'send_start' : 'resend_start', attempt: attempt.id);

  // Firebase may report the same auto-verification more than once.
  var autoVerifying = false;

  void fail(FirebaseAuthException e) {
    if (completer.isCompleted) return;
    completer.completeError(e);
  }

  // Not awaited: the deadline below must cover the platform call itself,
  // not only the callbacks it later makes.
  unawaited(
    backend
        .verifyPhoneNumber(
          phoneNumber: phoneNumber,
          forceResendingToken: resendToken,
          // Android's SMS auto-retrieval window; the person can always type the
          // code by hand meanwhile and after.
          timeout: const Duration(seconds: 60),
          verificationCompleted: (credential) async {
            if (!attempt.isActive) {
              _log('late_auto_verification_ignored', attempt: attempt.id, elapsedMs: elapsed());
              return;
            }
            if (autoVerifying) {
              _log('duplicate_auto_verification_ignored', attempt: attempt.id);
              return;
            }
            autoVerifying = true;
            try {
              await backend.signInWithCredential(credential);
            } on FirebaseAuthException catch (e) {
              _log('auto_verification_failed', code: e.code, attempt: attempt.id);
              fail(e);
              return;
            }
            _log('auto_verified', attempt: attempt.id, elapsedMs: elapsed());
            if (!completer.isCompleted) completer.complete(const PhoneVerifiedAutomatically());
          },
          verificationFailed: (e) {
            _log('send_failed', code: e.code, attempt: attempt.id, elapsedMs: elapsed());
            if (!attempt.isActive) return;
            fail(e);
          },
          codeSent: (verificationId, token) {
            if (!attempt.isActive || completer.isCompleted) {
              _log('late_code_sent_ignored', attempt: attempt.id, elapsedMs: elapsed());
              return;
            }
            _lastCodeSentAt[phoneNumber] = phoneAuthClock();
            _log('code_sent', attempt: attempt.id, elapsedMs: elapsed());
            completer.complete(SmsCodeSent(verificationId, token, attempt: attempt));
          },
          codeAutoRetrievalTimeout: (_) => _log('auto_retrieval_window_closed', attempt: attempt.id),
        )
        .catchError((Object e) {
          final error = e is FirebaseAuthException ? e : FirebaseAuthException(code: 'unknown');
          _log('send_failed', code: error.code, attempt: attempt.id, elapsedMs: elapsed());
          fail(error);
        }),
  );

  try {
    return await completer.future.timeout(timeout);
  } on TimeoutException {
    attempt.cancel();
    _log('send_timeout', attempt: attempt.id, elapsedMs: elapsed());
    throw FirebaseAuthException(code: 'quicky-otp-timeout');
  } on FirebaseAuthException {
    attempt.cancel();
    rethrow;
  }
}

/// Cancels the newest verification, if it's still waiting — e.g. the
/// phone screen was left mid-send. Late callbacks from it are ignored.
void cancelPendingPhoneVerification() => _currentAttempt?.cancel();

/// Signs in with the 6-digit [smsCode] the person typed for [verificationId].
/// Gives up after [otpVerifyTimeout] with `quicky-verify-timeout`; if the
/// sign-in still lands afterwards, the OTP screen picks it up through
/// `authStateChanges()`.
Future<void> signInWithPhoneCode(String verificationId, String smsCode, {Duration timeout = otpVerifyTimeout}) async {
  try {
    await phoneAuthBackend
        .signInWithCredential(PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode))
        .timeout(timeout);
    _log('code_verified');
  } on TimeoutException {
    _log('verify_timeout');
    throw FirebaseAuthException(code: 'quicky-verify-timeout');
  } on FirebaseAuthException catch (e) {
    _log('verify_failed', code: e.code);
    rethrow;
  }
}

/// User-facing text for every phone-auth failure Firebase reports.
String phoneAuthErrorMessage(FirebaseAuthException e) => switch (e.code) {
  'invalid-verification-code' => 'Incorrect code. Please check it and try again.',
  'session-expired' ||
  'code-expired' ||
  'invalid-verification-id' ||
  'missing-verification-id' => 'This code has expired. Tap "Resend code" to get a new one.',
  'too-many-requests' => 'Too many attempts from this device. Please wait a while and try again.',
  'quota-exceeded' => "We can't send more codes right now. Please try again later.",
  'network-request-failed' => 'No internet connection. Check your network and try again.',
  'invalid-phone-number' || 'missing-phone-number' => "That mobile number isn't valid.",
  'user-disabled' => 'This number has been blocked. Please contact support.',
  'captcha-check-failed' ||
  'web-context-cancelled' ||
  'web-context-already-presented' => 'Verification was cancelled. Please try again.',
  'app-not-authorized' ||
  'missing-client-identifier' ||
  'invalid-app-credential' ||
  'missing-app-credential' => "This app can't verify phone numbers yet. Please contact support.",
  'quicky-otp-timeout' => 'Sending the code is taking too long. Check your connection and try again.',
  'quicky-verify-timeout' => 'Checking the code is taking too long. Check your connection and try again.',
  'quicky-otp-cooldown' => e.message ?? 'Please wait a moment before requesting another code.',
  _ => 'Verification failed. Please try again.',
};
