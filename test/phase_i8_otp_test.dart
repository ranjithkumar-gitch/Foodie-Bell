// Phase I.8 consolidated, Workstream A: OTP send/verify lifecycle —
// deadlines, late callbacks, duplicate completion, resend cooldown,
// superseded and cancelled attempts, error text and private diagnostics.
import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/shared/auth/phone_auth.dart';
import 'package:foodiebell/shared/widgets/otp_input_field.dart';

const _phone = '+919876543210';

/// Records each verifyPhoneNumber call's callbacks so a test can fire them
/// whenever (and however often) it likes.
class _Call {
  _Call(this.phoneNumber, this.resendToken, this.completed, this.failed, this.codeSent);
  final String phoneNumber;
  final int? resendToken;
  final void Function(PhoneAuthCredential) completed;
  final void Function(FirebaseAuthException) failed;
  final void Function(String, int?) codeSent;
}

class _FakeBackend implements PhoneAuthBackend {
  final calls = <_Call>[];
  var signIns = 0;
  var signOuts = 0;
  String? phone;
  Object? signInError;
  Duration signInDelay = Duration.zero;

  @override
  String? get currentUserPhone => phone;

  @override
  bool get hasCurrentUser => phone != null;

  @override
  Future<void> signOut() async {
    signOuts++;
    phone = null;
  }

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    int? forceResendingToken,
    required Duration timeout,
    required void Function(PhoneAuthCredential credential) verificationCompleted,
    required void Function(FirebaseAuthException e) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
  }) async {
    calls.add(_Call(phoneNumber, forceResendingToken, verificationCompleted, verificationFailed, codeSent));
  }

  @override
  Future<void> signInWithCredential(AuthCredential credential) async {
    if (signInDelay > Duration.zero) await Future<void>.delayed(signInDelay);
    if (signInError != null) throw signInError!;
    signIns++;
    phone = _phone;
  }
}

PhoneAuthCredential _credential() => PhoneAuthProvider.credential(verificationId: 'vid', smsCode: '123456');

late _FakeBackend _backend;
late DateTime _clock;
final _logs = <String>[];

void main() {
  setUp(() {
    _backend = _FakeBackend();
    phoneAuthBackend = _backend;
    _clock = DateTime(2026, 11, 2, 12);
    phoneAuthClock = () => _clock;
    _logs.clear();
    phoneAuthDiagnostics = (event, {code, attempt, elapsedMs}) => _logs.add('$event $code $attempt $elapsedMs');
    resetPhoneAuthState();
  });

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  group('send', () {
    test('success: the code is sent and the attempt stays active for the OTP screen', () async {
      final f = sendPhoneCode(_phone);
      await flush();
      _backend.calls.single.codeSent('vid-1', 7);
      final r = await f as SmsCodeSent;
      expect([r.verificationId, r.resendToken], ['vid-1', 7]);
      expect(r.attempt!.isActive, isTrue);
    });

    test('a delayed answer within the deadline still succeeds', () async {
      final f = sendPhoneCode(_phone, timeout: const Duration(milliseconds: 300));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      _backend.calls.single.codeSent('vid-1', 1);
      expect(await f, isA<SmsCodeSent>());
    });

    test('no answer: a bounded timeout instead of an endless spinner; a late code is ignored', () async {
      final f = sendPhoneCode(_phone, timeout: const Duration(milliseconds: 50));
      await expectLater(f, throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'quicky-otp-timeout')));
      _backend.calls.single.codeSent('vid-late', 1); // arrives after the deadline
      _backend.calls.single.completed(_credential()); // late auto-retrieval
      await flush();
      expect(_backend.signIns, 0, reason: 'a timed-out attempt never signs in');
      expect(_logs.any((l) => l.startsWith('late_code_sent_ignored')), isTrue);
      expect(_logs.any((l) => l.startsWith('late_auto_verification_ignored')), isTrue);
      // No cooldown: the code never arrived, so retrying straight away is allowed.
      final retry = sendPhoneCode(_phone);
      await flush();
      _backend.calls.last.codeSent('vid-2', 2);
      expect(await retry, isA<SmsCodeSent>());
    });

    test('the default deadline is 45 s', () {
      expect(otpSendTimeout, const Duration(seconds: 45));
    });

    for (final code in ['invalid-phone-number', 'too-many-requests', 'quota-exceeded', 'network-request-failed']) {
      test('failure "$code" surfaces once, with friendly text', () async {
        final f = sendPhoneCode(_phone);
        await flush();
        _backend.calls.single.failed(FirebaseAuthException(code: code));
        _backend.calls.single.failed(FirebaseAuthException(code: 'unknown')); // a second report is ignored
        await expectLater(f, throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', code)));
        expect(phoneAuthErrorMessage(FirebaseAuthException(code: code)), isNot('Verification failed. Please try again.'));
      });
    }

    test('a platform error from verifyPhoneNumber itself is reported, not swallowed', () async {
      phoneAuthBackend = _ThrowingBackend();
      await expectLater(sendPhoneCode(_phone), throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'app-not-authorized')));
    });

    test('Android instant verification completes once, even if Firebase reports it twice', () async {
      final f = sendPhoneCode(_phone);
      await flush();
      _backend.calls.single.completed(_credential());
      _backend.calls.single.completed(_credential());
      expect(await f, isA<PhoneVerifiedAutomatically>());
      await flush();
      expect(_backend.signIns, 1);
    });

    test('auto-retrieval after the code was sent still signs in while the OTP screen is up', () async {
      final f = sendPhoneCode(_phone);
      await flush();
      _backend.calls.single.codeSent('vid-1', 1);
      await f;
      _backend.calls.single.completed(_credential());
      await flush();
      expect(_backend.signIns, 1);
    });

    test('a different signed-in number is signed out first; the same one is kept', () async {
      _backend.phone = '+911111111111';
      unawaited(sendPhoneCode(_phone).catchError((_) => const PhoneVerifiedAutomatically()));
      await flush();
      expect(_backend.signOuts, 1);
      resetPhoneAuthState();
      _backend.phone = _phone;
      unawaited(sendPhoneCode(_phone).catchError((_) => const PhoneVerifiedAutomatically()));
      await flush();
      expect(_backend.signOuts, 1);
      resetPhoneAuthState();
    });
  });

  group('resend', () {
    test('cooldown: no second code for the same number within 30 s; allowed afterwards; other numbers unaffected', () async {
      final f = sendPhoneCode(_phone);
      await flush();
      _backend.calls.single.codeSent('vid-1', 9);
      await f;

      _clock = _clock.add(const Duration(seconds: 12));
      await expectLater(
        sendPhoneCode(_phone, resendToken: 9),
        throwsA(isA<FirebaseAuthException>()
            .having((e) => e.code, 'code', 'quicky-otp-cooldown')
            .having((e) => phoneAuthErrorMessage(e), 'text', contains('18 s'))),
      );
      expect(_backend.calls, hasLength(1), reason: 'no request reached Firebase');

      final other = sendPhoneCode('+919999999999');
      await flush();
      _backend.calls.last.codeSent('vid-o', 1);
      expect(await other, isA<SmsCodeSent>());

      _clock = _clock.add(const Duration(seconds: 19));
      final again = sendPhoneCode(_phone, resendToken: 9);
      await flush();
      expect(_backend.calls.last.resendToken, 9, reason: 'the resend token is passed on');
      _backend.calls.last.codeSent('vid-2', 10);
      expect((await again as SmsCodeSent).verificationId, 'vid-2');
    });

    test('a newer send supersedes the old attempt: its late auto-retrieval is ignored', () async {
      final first = sendPhoneCode(_phone);
      await flush();
      _backend.calls[0].codeSent('vid-1', 1);
      final a1 = (await first as SmsCodeSent).attempt!;
      _clock = _clock.add(const Duration(seconds: 31));
      final second = sendPhoneCode(_phone, resendToken: 1);
      await flush();
      _backend.calls[1].codeSent('vid-2', 2);
      final a2 = (await second as SmsCodeSent).attempt!;
      expect([a1.isActive, a2.isActive], [false, true]);
      _backend.calls[0].completed(_credential());
      await flush();
      expect(_backend.signIns, 0);
    });
  });

  group('screen disposal', () {
    test('cancelling the attempt (OTP screen disposed) blocks a later auto sign-in', () async {
      final f = sendPhoneCode(_phone);
      await flush();
      _backend.calls.single.codeSent('vid-1', 1);
      final attempt = (await f as SmsCodeSent).attempt!;
      attempt.cancel();
      _backend.calls.single.completed(_credential());
      await flush();
      expect(_backend.signIns, 0);
    });

    test('leaving the phone screen mid-send: the pending send never completes into a navigation', () async {
      final f = sendPhoneCode(_phone, timeout: const Duration(milliseconds: 200));
      await flush();
      cancelPendingPhoneVerification();
      _backend.calls.single.codeSent('vid-1', 1);
      await expectLater(f, throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'quicky-otp-timeout')));
    });

    test('the screens cancel on dispose and guard resend', () {
      final otp = File('lib/shared/auth/auth_otp_screen.dart').readAsStringSync();
      expect(otp, contains('_attempt?.cancel();'));
      expect(otp, contains('if (_resending || _finishing) return;'));
      for (final f in ['lib/shared/auth/auth_login_screen.dart', 'lib/shared/auth/auth_phone_screen.dart']) {
        final src = File(f).readAsStringSync();
        expect(src, contains('cancelPendingPhoneVerification();'), reason: f);
        expect(src, contains('attempt: attempt,'), reason: f);
      }
    });
  });

  group('verify', () {
    test('an incorrect code gives a clear message', () async {
      _backend.signInError = FirebaseAuthException(code: 'invalid-verification-code');
      await expectLater(signInWithPhoneCode('vid', '000000'), throwsA(isA<FirebaseAuthException>()));
      expect(phoneAuthErrorMessage(FirebaseAuthException(code: 'invalid-verification-code')), contains('Incorrect code'));
      expect(phoneAuthErrorMessage(FirebaseAuthException(code: 'session-expired')), contains('Resend code'));
    });

    test('a hanging verification times out instead of spinning', () async {
      _backend.signInDelay = const Duration(seconds: 5);
      await expectLater(
        signInWithPhoneCode('vid', '123456', timeout: const Duration(milliseconds: 50)),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'quicky-verify-timeout')),
      );
      expect(otpVerifyTimeout, const Duration(seconds: 30));
    });
  });

  test('diagnostics never contain the phone number, OTP or verification id', () async {
    final f = sendPhoneCode(_phone);
    await flush();
    _backend.calls.single.codeSent('vid-secret', 1);
    await f;
    _backend.signInError = FirebaseAuthException(code: 'invalid-verification-code');
    await expectLater(signInWithPhoneCode('vid-secret', '654321'), throwsA(anything));
    final all = _logs.join('\n');
    expect(all, isNot(contains('9876543210')));
    expect(all, isNot(contains('654321')));
    expect(all, isNot(contains('vid-secret')));
    expect(all, contains('code_sent'));
    expect(all, contains('verify_failed invalid-verification-code'));
  });

  testWidgets('the resend link has a 30 s countdown and fires once per tap', (tester) async {
    var resends = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: OtpInputField(onCompleted: (_) {}, onResend: () => resends++))));
    expect(find.text('Resend code'), findsNothing);
    expect(find.textContaining('Resend code in 00:30'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await tester.tap(find.text('Resend code'));
    await tester.pump();
    await tester.tap(find.textContaining('Resend code'), warnIfMissed: false);
    await tester.pump();
    expect(resends, 1);
    expect(find.textContaining('Resend code in'), findsOneWidget);
  });
}

class _ThrowingBackend extends _FakeBackend {
  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    int? forceResendingToken,
    required Duration timeout,
    required void Function(PhoneAuthCredential credential) verificationCompleted,
    required void Function(FirebaseAuthException e) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
  }) async =>
      throw FirebaseAuthException(code: 'app-not-authorized');
}
