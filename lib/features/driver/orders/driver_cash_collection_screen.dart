import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/order_actions.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/currency_text.dart';

/// Cash Collection Screen (spec §6 item 12) — COD orders only. Shown between
/// "Arrived at Customer" and Delivery Confirmation so the Driver records how
/// much cash they actually took (`recordCodCollection`) before handing the
/// parcel over. Less than the total is allowed but flagged: the Driver still
/// owes the full total in the day's settlement until the Manager resolves
/// the shortfall. Recording the cash doesn't settle it — the Driver hands
/// all cash to the Manager, who pays the Driver's delivery earnings back.
class DriverCashCollectionScreen extends ConsumerStatefulWidget {
  const DriverCashCollectionScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<DriverCashCollectionScreen> createState() => _DriverCashCollectionScreenState();
}

class _DriverCashCollectionScreenState extends ConsumerState<DriverCashCollectionScreen> {
  bool _confirming = false;
  String? _error;

  Future<void> _record(Order order, int amountPaise) async {
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      await recordCodCollection(order.id, amountPaise);
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _confirming = false;
        _error = e is OrderActionException ? e.message : friendlyError(e, action: 'Recording cash collected', stackTrace: st);
      });
      return;
    }
    if (!mounted) return;
    context.go('/driver/delivery/${order.id}/delivery-confirm');
  }

  int _duePaise(Order order) => order.money?.customerTotal ?? (order.total * 100).round();

  /// The Customer paid less than the total: record what was actually taken.
  Future<void> _recordLess(Order order) async {
    final controller = TextEditingController();
    final rupees = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('How much cash did you get?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Manager will be told about the difference.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(prefixText: '₹ '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Back')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, double.tryParse(controller.text.trim())), child: const Text('Save')),
        ],
      ),
    );
    if (rupees == null || rupees < 0) return;
    final paise = (rupees * 100).round();
    if (paise > _duePaise(order)) {
      setState(() => _error = 'That is more than the order total.');
      return;
    }
    await _record(order, paise);
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
        title: const Text('Collect cash'),
        actions: [IconButton(icon: const Icon(Icons.home_rounded), tooltip: 'Back to dashboard', onPressed: () => context.go('/driver/home'))],
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
            TextButton(
              onPressed: _confirming ? null : () => _recordLess(order),
              child: const Text('Customer paid less'),
            ),
            const SizedBox(height: 6),
            ElevatedButton(
              onPressed: _confirming ? null : () => _record(order, _duePaise(order)),
              child: _confirming
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4))
                  : const Text('Collected the full amount'),
            ),
          ],
        ),
      ),
    );
  }
}
