import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';
import 'auth_navigation.dart';
import 'auth_otp_screen.dart';
import 'otp_config.dart';
import 'user_registration_draft.dart';

/// Phone entry for both the OTP-login path and the phone-verification step
/// of registration. `mode` threads through as a query param so `/auth/otp`
/// knows which session method to call once the code is verified.
///
/// For a registering User specifically, the number field is pre-filled from
/// `userRegistrationDraftProvider` (staged by `auth_register_screen.dart`)
/// so they aren't asked to type the same number twice — they can still
/// correct it here before sending the OTP. Whatever's actually sent gets
/// re-staged into the draft as raw digits (`setPhone`), which is also the
/// format Vendor/Driver/the phone-lookup functions store/query
/// (`firestore_vendors_provider.dart`, `firestore_users_provider.dart`) —
/// never the `+91`-prefixed form Firebase itself uses.
///
/// While `kUseDynamicOtp` is off (`otp_config.dart`), "Send OTP" skips
/// Firebase entirely and just pushes straight to the OTP screen, which
/// accepts the fixed [kDemoOtp] for any number. Once that flag flips on,
/// this kicks off real Firebase phone verification instead — `codeSent`
/// hands the opaque `verificationId` to [AuthOtpScreen] via go_router's
/// `extra:` (it's not a display value, so a query param would be the wrong
/// fit). Android's SMS auto-retrieval can skip manual entry entirely
/// (`verificationCompleted`); when that fires this screen completes the
/// sign-in itself via [completePhoneAuth] rather than still pushing the OTP
/// screen.
class AuthPhoneScreen extends ConsumerStatefulWidget {
  const AuthPhoneScreen({super.key, this.mode = 'login'});

  final String mode;

  @override
  ConsumerState<AuthPhoneScreen> createState() => _AuthPhoneScreenState();
}

class _AuthPhoneScreenState extends ConsumerState<AuthPhoneScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'register' &&
        ref.read(sessionControllerProvider).role == AppRole.user) {
      final draftPhone = ref.read(userRegistrationDraftProvider).phone;
      if (draftPhone.isNotEmpty) _controller.text = draftPhone;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final digits = _controller.text.trim();
    if (digits.length != 10 || int.tryParse(digits) == null) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });

    if (widget.mode == 'register' &&
        ref.read(sessionControllerProvider).role == AppRole.user) {
      ref.read(userRegistrationDraftProvider.notifier).setPhone(digits);
    }

    final phone = '+91$digits';

    if (!kUseDynamicOtp) {
      setState(() => _sending = false);
      if (!mounted) return;
      context.push(
        '/auth/otp?mode=${widget.mode}',
        extra: OtpScreenArgs(verificationId: null, phoneNumber: phone),
      );
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (credential) async {
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (!mounted) return;
          setState(() {
            _sending = false;
            _error = e.message ?? 'Verification failed. Please try again.';
          });
          return;
        }
        if (!mounted) return;
        await completePhoneAuth(context, ref, widget.mode);
      },
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() {
          _sending = false;
          _error = e.message ?? 'Could not send the code. Please try again.';
        });
      },
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() => _sending = false);
        context.push(
          '/auth/otp?mode=${widget.mode}',
          extra: OtpScreenArgs(
            verificationId: verificationId,
            phoneNumber: phone,
            resendToken: resendToken,
          ),
        );
      },
      codeAutoRetrievalTimeout: (verificationId) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final role = ref.watch(sessionControllerProvider).role;

    return Scaffold(
      appBar: AppBar(title: const Text('Enter your mobile number')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role == null
                  ? "We'll send you a one-time code to verify it's you."
                  : "We'll send a one-time code to verify your ${role.label} account.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Text(
              'Mobile number',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+91',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    // Plain numeric keypad, not the phone dialer layout —
                    // matches the register screen's own mobile-number field
                    // and the OTP field right after this one.
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    enabled: !_sending,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      hintText: '10-digit mobile number',
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(
                  color: palette.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(
            onPressed: _sending ? null : _sendOtp,
            child: _sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.4,
                    ),
                  )
                : const Text('Send OTP'),
          ),
        ),
      ),
    );
  }
}
