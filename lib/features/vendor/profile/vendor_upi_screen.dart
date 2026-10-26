import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/payments/upi_service.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../shared/error_reporting.dart';
import '../vendor_session.dart';

/// "UPI for payments": the UPI IDs customers pay this shop on when they
/// choose UPI at checkout. Any UPI app's ID works (PhonePe, Google Pay,
/// Paytm, BHIM, ...). The first one is where payments go; the others are
/// kept so the Vendor can switch with one tap. See [Account.upiIds].
class VendorUpiScreen extends ConsumerStatefulWidget {
  const VendorUpiScreen({super.key});

  @override
  ConsumerState<VendorUpiScreen> createState() => _VendorUpiScreenState();
}

class _VendorUpiScreenState extends ConsumerState<VendorUpiScreen> {
  static const _kMaxUpiIds = 5;
  bool _saving = false;

  Future<void> _save(List<String> upiIds, {required String successMessage}) async {
    setState(() => _saving = true);
    try {
      await setCurrentVendorUpiIds(ref, ref.read(currentVendorIdProvider), upiIds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, action: 'Saving UPI ID', stackTrace: st))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add(List<String> current) async {
    final upiId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddUpiSheet(existing: current),
    );
    if (upiId == null) return;
    await _save([...current, upiId], successMessage: 'UPI ID added');
  }

  Future<void> _remove(List<String> current, String upiId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this UPI ID?'),
        content: Text(upiId),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _save([...current]..remove(upiId), successMessage: 'UPI ID removed');
  }

  Future<void> _makePrimary(List<String> current, String upiId) =>
      _save([upiId, ...current.where((u) => u != upiId)], successMessage: 'Payments will now come to $upiId');

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final sessionAccount = ref.watch(sessionControllerProvider.select((s) => s.account));
    final account = sessionAccount == null
        ? null
        : ref.watch(liveVendorAccountProvider(sessionAccount.id)) ?? sessionAccount;
    final upiIds = account?.upiIds ?? const <String>[];

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: const Text('UPI for payments')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            'Customers who pay by UPI will pay directly to your UPI ID. You can use the UPI ID from PhonePe, Google Pay, Paytm or any UPI app.',
            style: TextStyle(fontSize: 15, height: 1.4, color: palette.textSecondary),
          ),
          const SizedBox(height: 20),
          if (upiIds.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.qr_code_2_rounded, size: 44, color: palette.textMuted),
                  const SizedBox(height: 10),
                  Text(
                    'No UPI ID added yet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You need a UPI ID to accept orders.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14.5, color: palette.textSecondary),
                  ),
                ],
              ),
            )
          else
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < upiIds.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: palette.divider),
                    _UpiRow(
                      upiId: upiIds[i],
                      isPrimary: i == 0,
                      enabled: !_saving,
                      onMakePrimary: () => _makePrimary(upiIds, upiIds[i]),
                      onRemove: () => _remove(upiIds, upiIds[i]),
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (upiIds.length < _kMaxUpiIds)
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _add(upiIds),
              icon: const Icon(Icons.add_rounded),
              label: Text(upiIds.isEmpty ? 'Add UPI ID' : 'Add another UPI ID'),
            ),
          if (upiIds.length > 1) ...[
            const SizedBox(height: 16),
            Text(
              'Payments always go to the UPI ID marked "Payments come here".',
              style: TextStyle(fontSize: 14, color: palette.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpiRow extends StatelessWidget {
  const _UpiRow({
    required this.upiId,
    required this.isPrimary,
    required this.enabled,
    required this.onMakePrimary,
    required this.onRemove,
  });

  final String upiId;
  final bool isPrimary;
  final bool enabled;
  final VoidCallback onMakePrimary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upiAppLabel(upiId),
                  style: TextStyle(fontSize: 13.5, color: palette.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  upiId,
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: palette.textPrimary),
                ),
                const SizedBox(height: 6),
                if (isPrimary)
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 18, color: palette.success),
                      const SizedBox(width: 6),
                      Text(
                        'Payments come here',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: palette.success),
                      ),
                    ],
                  )
                else
                  InkWell(
                    onTap: enabled ? onMakePrimary : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Use this for payments',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.primary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: enabled ? onRemove : null,
            icon: Icon(Icons.delete_outline_rounded, color: palette.error),
          ),
        ],
      ),
    );
  }
}

class _AddUpiSheet extends StatefulWidget {
  const _AddUpiSheet({required this.existing});
  final List<String> existing;

  @override
  State<_AddUpiSheet> createState() => _AddUpiSheetState();
}

class _AddUpiSheetState extends State<_AddUpiSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final upiId = _controller.text.trim().toLowerCase();
    if (!isValidUpiId(upiId)) {
      setState(() => _error = 'Enter a valid UPI ID, like 9876543210@ybl');
      return;
    }
    if (widget.existing.contains(upiId)) {
      setState(() => _error = 'This UPI ID is already added');
      return;
    }
    Navigator.pop(context, upiId);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final typed = _controller.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add UPI ID', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Open PhonePe, Google Pay or Paytm, go to your profile, and copy your UPI ID.',
                style: TextStyle(fontSize: 15, height: 1.4, color: palette.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. 9876543210@ybl',
                  errorText: _error,
                ),
                onChanged: (_) => setState(() => _error = null),
                onSubmitted: (_) => _submit(),
              ),
              if (_error == null && isValidUpiId(typed)) ...[
                const SizedBox(height: 8),
                Text(
                  '${upiAppLabel(typed)} UPI ID',
                  style: TextStyle(fontSize: 14, color: palette.success, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _submit, child: const Text('Save UPI ID')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
