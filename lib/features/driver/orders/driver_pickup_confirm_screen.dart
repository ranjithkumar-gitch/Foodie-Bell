import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Active Delivery — Pickup Confirmation (spec §6 item 9): the vendor hands
/// the driver a handover code at pickup; entering it here (matched against
/// this specific order's `handoverCode`, NOT the shared demo OTP) performs
/// the `driverAssigned -> pickedUp` transition this role owns.
class DriverPickupConfirmScreen extends ConsumerStatefulWidget {
  const DriverPickupConfirmScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DriverPickupConfirmScreen> createState() => _DriverPickupConfirmScreenState();
}

class _DriverPickupConfirmScreenState extends ConsumerState<DriverPickupConfirmScreen> {
  final _codeController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _confirm(Order order) async {
    if (_codeController.text.trim() != order.handoverCode) {
      setState(() => _error = 'Incorrect code. Ask the vendor for the handover code shown on their order screen.');
      return;
    }
    setState(() => _error = null);
    try {
      await updateOrderStatus(order.id, OrderStatus.pickedUp);
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e, action: 'Confirming pickup', stackTrace: st));
      return;
    }
    if (!mounted) return;
    context.go('/driver/delivery/${order.id}/navigate-customer');
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
        title: const Text('Confirm pickup'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.qr_code_scanner_rounded, size: 40, color: palette.primary),
            const SizedBox(height: 16),
            Text('Enter the handover code', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Ask ${order.vendorName} for the 4-digit code to confirm you\'ve collected order ${order.id}.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            AppTextField(
              label: 'Handover code',
              controller: _codeController,
              hint: '4-digit code',
              keyboardType: TextInputType.number,
              prefixIcon: Icons.password_rounded,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(onPressed: () => _confirm(order), child: const Text('Confirm pickup')),
        ),
      ),
    );
  }
}
