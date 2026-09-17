import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Delivery Confirmation (spec §6 item 11): OTP entry compared to this
/// order's `deliveryOtp` (shown to the User on their own tracking screen),
/// OR a photo-proof-of-delivery affordance as a fallback when the customer
/// isn't reachable for the code. Either path performs the `pickedUp ->
/// delivered` transition this role owns.
class DriverDeliveryConfirmScreen extends ConsumerStatefulWidget {
  const DriverDeliveryConfirmScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DriverDeliveryConfirmScreen> createState() => _DriverDeliveryConfirmScreenState();
}

class _DriverDeliveryConfirmScreenState extends ConsumerState<DriverDeliveryConfirmScreen> {
  final _otpController = TextEditingController();
  String? _photoFileName;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _pickProofPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
    if (picked != null) setState(() => _photoFileName = picked.name);
  }

  Future<void> _markDelivered(Order order) async {
    final otpMatches = _otpController.text.trim() == order.deliveryOtp;
    if (!otpMatches && _photoFileName == null) {
      setState(() => _error = 'Enter the delivery OTP, or attach a photo of the handover as proof.');
      return;
    }
    setState(() => _error = null);
    try {
      await updateOrderStatus(order.id, OrderStatus.delivered);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e, action: 'Confirming delivery', stackTrace: st));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order ${order.id} delivered — nice work!')));
    context.go('/driver/home');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final order = ref.watch(orderByIdProvider(widget.orderId)).valueOrNull;
    if (order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.home_rounded), tooltip: 'Back to dashboard', onPressed: () => context.go('/driver/home')),
        title: const Text('Confirm delivery'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Icon(Icons.task_alt_rounded, size: 40, color: palette.primary),
          const SizedBox(height: 16),
          Text('Confirm handover to ${order.userName}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Ask the customer for their delivery OTP, or attach a photo of the handover if they\'re unavailable.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          AppTextField(
            label: 'Delivery OTP',
            controller: _otpController,
            hint: '4-digit code',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.password_rounded,
          ),
          const SizedBox(height: 20),
          Row(children: [Expanded(child: Divider(color: palette.border)), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('OR', style: TextStyle(color: palette.textMuted, fontWeight: FontWeight.w700))), Expanded(child: Divider(color: palette.border))]),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickProofPhoto,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _photoFileName != null ? palette.primaryLight.withValues(alpha: 0.14) : palette.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _photoFileName != null ? palette.primary : palette.border),
              ),
              child: Row(
                children: [
                  Icon(_photoFileName != null ? Icons.check_circle_rounded : Icons.camera_alt_outlined, color: _photoFileName != null ? palette.primary : palette.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Photo proof of delivery', style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                        const SizedBox(height: 2),
                        Text(_photoFileName ?? 'Tap to capture a photo', style: TextStyle(fontSize: 12.5, color: _photoFileName != null ? palette.primary : palette.textSecondary), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(onPressed: () => _markDelivered(order), child: const Text('Mark Delivered')),
        ),
      ),
    );
  }
}
