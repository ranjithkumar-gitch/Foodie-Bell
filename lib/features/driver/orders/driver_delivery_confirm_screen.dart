import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/order_codes_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/app_text_field.dart';

/// Delivery Confirmation (spec §6 item 11): the customer reads the driver
/// the delivery code shown on their own tracking screen. The server checks
/// it (`confirmDeliveryCode`) and performs the `pickedUp -> delivered`
/// transition — the Driver's app never sees the code itself, and there's no
/// way to mark an order delivered without it. If the customer can't be
/// reached, the Driver contacts their Manager instead.
class DriverDeliveryConfirmScreen extends ConsumerStatefulWidget {
  const DriverDeliveryConfirmScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DriverDeliveryConfirmScreen> createState() => _DriverDeliveryConfirmScreenState();
}

class _DriverDeliveryConfirmScreenState extends ConsumerState<DriverDeliveryConfirmScreen> {
  final _otpController = TextEditingController();
  String? _error;
  bool _confirming = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _markDelivered(Order order) async {
    setState(() {
      _error = null;
      _confirming = true;
    });
    try {
      final check = await confirmDeliveryCode(order.id, _otpController.text.trim());
      if (!mounted) return;
      if (!check.ok) {
        setState(() => _error = 'Incorrect code. Ask the customer for the delivery code on their tracking screen.'
            '${check.attemptsLeft == null ? '' : ' ${check.attemptsLeft} tries left.'}');
        return;
      }
    } catch (e, st) {
      if (!mounted) return;
      setState(() => _error = _codeError(e, action: 'Confirming delivery', stackTrace: st));
      return;
    } finally {
      if (mounted) setState(() => _confirming = false);
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
        leading: BackButton(onPressed: () => context.go('/driver/delivery/${order.id}/navigate-customer')),
        title: const Text('Confirm delivery'),
        actions: [IconButton(icon: const Icon(Icons.home_rounded), tooltip: 'Back to dashboard', onPressed: () => context.go('/driver/home'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          Icon(Icons.task_alt_rounded, size: 40, color: palette.primary),
          const SizedBox(height: 16),
          Text('Confirm handover to ${order.userName}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Ask the customer for the delivery code on their tracking screen. If they can\'t be reached, contact your Manager.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          AppTextField(
            label: 'Delivery OTP',
            controller: _otpController,
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(onPressed: _confirming ? null : () => _markDelivered(order), child: const Text('Mark Delivered')),
        ),
      ),
    );
  }
}

String _codeError(Object e, {required String action, StackTrace? stackTrace}) => e is FirebaseFunctionsException
    ? (e.message ?? 'Could not confirm. Please try again.')
    : friendlyError(e, action: action, stackTrace: stackTrace);
