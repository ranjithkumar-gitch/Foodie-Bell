import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';

/// Cash Collection Screen (spec §6 item 12) — COD orders only. Shown between
/// "Arrived at Customer" and Delivery Confirmation so the driver explicitly
/// acknowledges collecting the exact order total before handing the parcel
/// over. Persists [Order.codPaymentReceived] — independent of `status`,
/// which only reaches `delivered` once the next screen's OTP/photo is
/// confirmed.
class DriverCashCollectionScreen extends ConsumerStatefulWidget {
  const DriverCashCollectionScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DriverCashCollectionScreen> createState() => _DriverCashCollectionScreenState();
}

class _DriverCashCollectionScreenState extends ConsumerState<DriverCashCollectionScreen> {
  bool _confirming = false;
  String? _error;

  Future<void> _confirmCollected(Order order) async {
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      await markCodPaymentReceived(order.id);
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _confirming = false;
        _error = friendlyError(e, action: 'Confirming cash collected', stackTrace: st);
      });
      return;
    }
    if (!mounted) return;
    context.go('/driver/delivery/${order.id}/delivery-confirm');
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
        title: const Text('Collect cash'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: palette.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: palette.warning)),
              child: Column(
                children: [
                  Icon(Icons.payments_rounded, size: 40, color: palette.warning),
                  const SizedBox(height: 14),
                  Text('Collect from ${order.userName}', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  CurrencyText(order.total, style: TextStyle(color: palette.textPrimary, fontWeight: FontWeight.w900, fontSize: 34)),
                  const SizedBox(height: 6),
                  Text('Cash on Delivery · Order ${order.id}', style: TextStyle(color: palette.textMuted, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Count the cash before handing over the order, then confirm you\'ve collected it in full.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _confirming ? null : () => _confirmCollected(order),
              child: _confirming
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                  : const Text('Confirm Collected'),
            ),
          ],
        ),
      ),
    );
  }
}
