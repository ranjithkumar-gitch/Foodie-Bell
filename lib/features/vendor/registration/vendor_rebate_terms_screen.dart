import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/settlement_provider.dart';
import 'vendor_registration_scaffold.dart';
import 'vendor_registration_state.dart';

/// Registration step 5 — Commission terms: the global commission every
/// shop pays (live from `app_config/pricing`, set only by the Super Admin;
/// public read, so it shows before sign-in) must be explicitly accepted
/// before the vendor can finish registering. There's no per-vendor rate.
/// This is the wizard's last step — "Continue" hands off to the shared
/// phone/OTP screen, whose OTP success routes to `/auth/terms`, which is
/// the one that actually fires `completeRegistration()` (see
/// auth_terms_screen.dart's doc comment).
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
    final rates = ref.watch(pricingRatesProvider);
    final rate = rates == null ? null : '${formatPercent(rates.commissionPercent)}%';
    return VendorRegistrationScaffold(
      step: 5,
      totalSteps: 5,
      title: 'Commission terms',
      subtitle: 'QuickMandi charges every shop the same commission on the items it sells.',
      continueLabel: 'Accept & verify phone number',
      onContinue: _accepted && rates != null ? _continue : null,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: LinearGradient(colors: palette.promoGradient), borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current commission', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              rate == null
                  ? const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(color: Colors.white)))
                  : Text(rate, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 40)),
              const SizedBox(height: 6),
              const Text(
                'of each order\'s item value (after your own coupon). Set by QuickMandi for all '
                'shops; a change applies only to orders placed after it.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Cash orders: your Manager pays you the item value minus the commission. '
          'UPI orders: the customer pays you directly, and you pay your Manager the '
          'commission plus the delivery fee and any platform fee. Every amount comes '
          'from your daily settlement.',
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
                    'I accept the ${rate ?? 'current'} commission terms.',
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
