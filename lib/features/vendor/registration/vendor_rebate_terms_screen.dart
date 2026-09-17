import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import 'vendor_registration_scaffold.dart';
import 'vendor_registration_state.dart';

/// Registration step 5 — Rebate Terms Acknowledgement (spec §5.5): the
/// Manager-negotiated rebate % (10-20 band) must be explicitly accepted
/// before the vendor can finish registering. This is the wizard's last
/// step — "Continue" hands off to the shared phone/OTP screen, whose OTP
/// success routes to `/auth/terms`, which is the one that actually fires
/// `completeRegistration()` (see auth_terms_screen.dart's doc comment).
class VendorRebateTermsScreen extends ConsumerStatefulWidget {
  const VendorRebateTermsScreen({super.key});

  @override
  ConsumerState<VendorRebateTermsScreen> createState() => _VendorRebateTermsScreenState();
}

class _VendorRebateTermsScreenState extends ConsumerState<VendorRebateTermsScreen> {
  bool _accepted = false;

  void _continue() {
    if (!_accepted) return;
    ref.read(vendorRegistrationProvider.notifier).update((d) => d.copyWith(rebateAccepted: true));
    context.go('/auth/phone?mode=register');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final rebatePercent = ref.watch(vendorRegistrationProvider).rebatePercent;
    return VendorRegistrationScaffold(
      step: 5,
      totalSteps: 5,
      title: 'Rebate terms',
      subtitle: 'Review the sourcing rebate your onboarding Manager has set for your store.',
      continueLabel: 'Accept & verify phone number',
      onContinue: _accepted ? _continue : null,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: LinearGradient(colors: palette.promoGradient), borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your rebate rate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('${rebatePercent.toStringAsFixed(0)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 40)),
              const SizedBox(height: 6),
              const Text(
                'of each order\'s item subtotal is routed to your Manager as a '
                'sourcing rebate, in line with the platform-wide 10-20% band.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'This rate is deducted automatically at settlement — you never need to '
          'pay it separately. It funds your Manager\'s local operations (onboarding, '
          'quality checks, dispute resolution) in your territory.',
          style: TextStyle(color: palette.textSecondary, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 24),
        InkWell(
          onTap: () => setState(() => _accepted = !_accepted),
          borderRadius: BorderRadius.circular(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: _accepted, onChanged: (v) => setState(() => _accepted = v ?? false)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'I acknowledge and accept the ${rebatePercent.toStringAsFixed(0)}% rebate terms.',
                    style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
