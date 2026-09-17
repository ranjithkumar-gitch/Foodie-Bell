import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Big, prominent delivery-OTP display — same gradient-card treatment as
/// the Vendor's handover-code screen (`vendor_handover_screen.dart`), just
/// for the code the User reads out to the Driver at drop-off instead of the
/// one the Vendor reads out at pickup. Shared between the User's Order
/// Detail/Tracking screen and Home (when there's an in-progress delivery),
/// so the two never drift apart visually.
class DeliveryOtpCard extends StatelessWidget {
  const DeliveryOtpCard({super.key, required this.otp});

  final String otp;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: LinearGradient(colors: palette.promoGradient), borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Icon(Icons.password_rounded, color: Colors.white, size: 36),
          const SizedBox(height: 12),
          const Text('Share this code with your delivery partner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Text(otp, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 44, letterSpacing: 6)),
        ],
      ),
    );
  }
}
