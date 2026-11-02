import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/order.dart';
import '../../../data/providers/firestore_drivers_provider.dart';
import '../../../data/providers/firestore_orders_provider.dart';
import '../../../data/providers/order_actions.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/time_ago.dart';

/// Whether a Manager may move [order]'s delivery: the server's
/// `reassignDriver` takes only an order assigned to a Driver and not yet
/// picked up (`driverAssigned`), in the Manager's own territory (checked
/// server-side; the Manager's order list is already territory-scoped).
bool canReassignDriver(Order order) => order.status == OrderStatus.driverAssigned && order.driverId != null;

/// Drivers [order] can be handed to: approved (`active`), not deleted, in
/// the order's territory, and not the Driver who has it now — the same
/// checks `reassignDriver` makes (`activeDriver` in `functions/orders.js`).
/// Online ones first.
List<Account> reassignableDrivers(List<Account> drivers, Order order) => [
  for (final d in drivers)
    if (d.status == AccountStatus.active && d.deletedAt == null && d.territoryId == order.territoryId && d.id != order.driverId) d,
]..sort((a, b) => (b.isOnline ? 1 : 0) - (a.isOnline ? 1 : 0));

/// Opens [ReassignDriverSheet] for [order].
Future<void> showReassignDriverSheet(BuildContext context, Order order) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => ReassignDriverSheet(order: order),
);

/// Manager: move a waiting delivery to another active Driver of the
/// territory, or release it (no Driver — it goes back to the territory's
/// open offers). A reason is required; the server records every change in
/// the order's history (`driverReassigned`), shown at the bottom.
class ReassignDriverSheet extends ConsumerStatefulWidget {
  const ReassignDriverSheet({super.key, required this.order, this.reassign = reassignDriver});

  final Order order;

  /// The `reassignDriver` call; replaceable in tests.
  final Future<void> Function(String orderId, {String? driverId, required String reason}) reassign;

  @override
  ConsumerState<ReassignDriverSheet> createState() => _ReassignDriverSheetState();
}

/// The release choice in the picker (no Driver).
const _release = '';

class _ReassignDriverSheetState extends ConsumerState<ReassignDriverSheet> {
  final _reason = TextEditingController();
  String? _choice;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  bool get _ready => _choice != null && _reason.text.trim().isNotEmpty && !_busy;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.reassign(widget.order.id, driverId: _choice == _release ? null : _choice, reason: _reason.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (e, st) {
      if (mounted) setState(() => _error = e is OrderActionException ? e.message : friendlyError(e, action: 'Reassigning driver', stackTrace: st));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final order = widget.order;
    final driversAsync = ref.watch(firestoreDriversProvider);
    final drivers = reassignableDrivers(driversAsync.valueOrNull ?? const [], order);
    final history = (ref.watch(orderEventsProvider(order.id)).valueOrNull ?? const <OrderEvent>[])
        .where((e) => e.type == 'driverReassigned')
        .toList();
    String nameOf(Object? driverId) {
      if (driverId == null) return 'no driver';
      final all = driversAsync.valueOrNull ?? const <Account>[];
      return all.where((d) => d.id == driverId).map((d) => d.name).firstOrNull ?? '$driverId';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reassign delivery · ${order.id}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Now with ${order.driverName ?? 'a driver'}. Only possible before pickup.', style: TextStyle(color: palette.textSecondary)),
              const SizedBox(height: 12),
              if (driversAsync.isLoading && !driversAsync.hasValue)
                const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
              else if (drivers.isEmpty)
                Text('No other active driver in your territory.', style: TextStyle(color: palette.textMuted)),
              RadioGroup<String>(
                groupValue: _choice,
                onChanged: (v) {
                  if (!_busy) setState(() => _choice = v);
                },
                child: Column(
                  children: [
                    for (final d in drivers)
                      RadioListTile<String>(
                        value: d.id,
                        contentPadding: EdgeInsets.zero,
                        title: Text(d.name),
                        subtitle: Text(d.isOnline ? 'Online' : 'Offline'),
                      ),
                    RadioListTile<String>(
                      value: _release,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Release (no driver)'),
                      subtitle: const Text('Back to open offers for your territory’s drivers'),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: _reason,
                enabled: !_busy,
                maxLength: 300,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Reason (required)', hintText: 'e.g. Driver’s bike broke down'),
              ),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: palette.error, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _ready ? _submit : null,
                  child: _busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_choice == _release ? 'Release delivery' : 'Reassign delivery'),
                ),
              ),
              if (history.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Reassignment history', style: Theme.of(context).textTheme.titleSmall),
                for (final e in history)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded, size: 18),
                    title: Text('${nameOf(e.details['from'])} → ${nameOf(e.details['to'])}'),
                    subtitle: Text([if (e.details['reason'] != null) '${e.details['reason']}', if (e.at != null) timeAgo(e.at!)].join(' · ')),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
