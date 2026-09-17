import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';
import '../../data/providers/firestore_users_provider.dart';
import '../error_reporting.dart';
import 'auth_navigation.dart';
import 'user_registration_draft.dart';

/// Terms gate — the final step before an account activates.
///
/// Assumed ordering for User registration: phone → OTP → **terms** → home.
/// [AuthOtpScreen] deliberately does NOT call `completeRegistration()`
/// itself in register mode; it routes here instead, and this screen is the
/// one that actually fires `completeRegistration()`/`completeLogin()` once
/// the checkbox is ticked. Vendor/Driver/Manager's own registration flow (a
/// later agent's work) can land here directly as its last step too, with or
/// without going through phone/OTP first — this screen only depends on
/// `session.role` and the `mode` query param, not on how the caller got here.
///
/// For `role == AppRole.user` in register mode specifically, this is also
/// where the real Firestore `users` doc actually gets written — the
/// name/email typed on `auth_register_screen.dart` and the phone verified
/// on `/auth/phone`/`/auth/otp` were only staged in
/// `userRegistrationDraftProvider` until now, so this button tap is the
/// one moment they become a real persisted account.
class AuthTermsScreen extends ConsumerStatefulWidget {
  const AuthTermsScreen({super.key, this.mode = 'register'});

  final String mode;

  @override
  ConsumerState<AuthTermsScreen> createState() => _AuthTermsScreenState();
}

class _AuthTermsScreenState extends ConsumerState<AuthTermsScreen> {
  bool _agreed = false;
  bool _submitting = false;
  String? _error;

  void _showFakeDoc(String title) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const SingleChildScrollView(
          child: Text(
            'This is placeholder legal text for the Quicky demo. In a real build, '
            'this would link to the hosted Terms of Service / Privacy Policy document.',
          ),
        ),
        actions: [TextButton(onPressed: () => context.pop(), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _submit() async {
    final notifier = ref.read(sessionControllerProvider.notifier);
    final role = ref.read(sessionControllerProvider).role;

    if (widget.mode == 'login') {
      notifier.completeLogin();
    } else if (role == AppRole.user) {
      setState(() {
        _submitting = true;
        _error = null;
      });
      final draft = ref.read(userRegistrationDraftProvider);
      try {
        final docRef = await usersCollection.add({
          ...accountToUserDoc(Account(id: '', role: AppRole.user, name: draft.name, phone: draft.phone, email: draft.email)),
          'createdAt': FieldValue.serverTimestamp(),
        });
        final account = Account(id: docRef.id, role: AppRole.user, name: draft.name, phone: draft.phone, email: draft.email);
        notifier.completeRegistration(account: account);
        ref.read(userRegistrationDraftProvider.notifier).reset();
      } catch (e, st) {
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _error = friendlyError(e, action: 'Creating account', stackTrace: st);
        });
        return;
      }
      if (!mounted) return;
      setState(() => _submitting = false);
    } else {
      notifier.completeRegistration();
    }

    if (!mounted) return;
    final session = ref.read(sessionControllerProvider);
    final resolvedRole = session.role;
    if (resolvedRole != null) routeByStage(context, resolvedRole, session.stage);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final textStyle = TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w500);
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Privacy')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.gavel_rounded, size: 40, color: palette.primary),
            const SizedBox(height: 16),
            Text('Almost there', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Please review and accept our terms to finish setting up your account.', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            InkWell(
              onTap: () => setState(() => _agreed = !_agreed),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Wrap(
                          children: [
                            Text('I agree to the ', style: textStyle),
                            GestureDetector(
                              onTap: () => _showFakeDoc('Terms of Service'),
                              child: Text('Terms of Service', style: textStyle.copyWith(color: palette.primary, fontWeight: FontWeight.w700)),
                            ),
                            Text(' and ', style: textStyle),
                            GestureDetector(
                              onTap: () => _showFakeDoc('Privacy Policy'),
                              child: Text('Privacy Policy', style: textStyle.copyWith(color: palette.primary, fontWeight: FontWeight.w700)),
                            ),
                            Text('.', style: textStyle),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _agreed && !_submitting ? _submit : null,
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                  : const Text('Agree & continue'),
            ),
          ],
        ),
      ),
    );
  }
}
