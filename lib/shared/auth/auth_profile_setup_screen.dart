import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/account_resolver.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/account.dart';
import '../error_reporting.dart';
import '../widgets/app_text_field.dart';
import 'auth_navigation.dart';
import '../widgets/busy_overlay.dart';

/// One login for everyone (2026-11-17): mobile number → OTP. A number with
/// no account yet lands here once, to say what we should call them; saving
/// creates the customer account from the *verified* number in this
/// session (`registerCustomer`), then carries on to where they were going.
class AuthProfileSetupScreen extends ConsumerStatefulWidget {
  const AuthProfileSetupScreen({super.key});

  @override
  ConsumerState<AuthProfileSetupScreen> createState() => _AuthProfileSetupScreenState();
}

class _AuthProfileSetupScreenState extends ConsumerState<AuthProfileSetupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  String get _phone {
    final p = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';
    return p.isEmpty ? '' : p;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    final email = _email.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      ref.read(sessionControllerProvider.notifier).selectRole(AppRole.user);
      final registration = await registerCustomerAccount(name: name, email: email.isEmpty ? null : email);
      if (!mounted) return;
      completeResolvedLogin(context, ref, registration.account);
    } on AccountResolutionException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyError(e, action: 'Saving your profile', stackTrace: st);
        });
      }
    }
  }

  /// Not now: sign the verified number out again and keep browsing.
  Future<void> _cancel() async {
    await runBusy(() => FirebaseAuth.instance.signOut());
    ref.read(sessionControllerProvider.notifier).logout();
    if (mounted) context.go('/user/home');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Not now', onPressed: _saving ? null : _cancel),
          title: const Text('Set up your profile'),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text('Welcome to Quicky!', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                _phone.isEmpty ? 'Your number is verified.' : 'Your number $_phone is verified. What should we call you?',
                style: TextStyle(color: palette.textSecondary),
              ),
              const SizedBox(height: 24),
              AppTextField(
                key: const Key('profileSetupName'),
                label: 'Your name',
                controller: _name,
                hint: 'e.g. Asha',
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 14),
              AppTextField(
                key: const Key('profileSetupEmail'),
                label: 'Email (optional)',
                controller: _email,
                hint: 'For receipts',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                key: const Key('profileSetupSave'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Continue'),
              ),
              const SizedBox(height: 12),
              Text(
                'By continuing you agree to Quicky’s Terms of Service and Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
