import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// What [SettlementPaymentSheet] returns: the amount, cash or UPI, and the
/// UPI reference (or a note for cash).
typedef SettlementPaymentInput = ({int amountPaise, bool upi, String? reference});

/// Amount, method and UPI reference for a settlement payment. The amount
/// starts at the server's outstanding figure; the Manager enters what
/// actually changed hands. Saving marks it settled: it counts at once, and
/// the other side has 24 hours to report a problem (2026-11-20).
class SettlementPaymentSheet extends StatefulWidget {
  const SettlementPaymentSheet({super.key, required this.title, required this.suggestedPaise, this.initialUpi = true});
  final String title;
  final int suggestedPaise;

  /// UPI selected to start with (cash for COD cash handed over).
  final bool initialUpi;

  @override
  State<SettlementPaymentSheet> createState() => _SettlementPaymentSheetState();
}

class _SettlementPaymentSheetState extends State<SettlementPaymentSheet> {
  late final _amount = TextEditingController(text: (widget.suggestedPaise / 100).toStringAsFixed(2));
  final _reference = TextEditingController();
  late bool _upi = widget.initialUpi;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _save() {
    final rupees = double.tryParse(_amount.text.trim());
    if (rupees == null || rupees <= 0) {
      setState(() => _error = 'Enter the amount.');
      return;
    }
    final reference = _reference.text.trim();
    if (_upi && reference.isEmpty) {
      setState(() => _error = 'Enter the UPI reference (UTR).');
      return;
    }
    Navigator.pop<SettlementPaymentInput>(context, (amountPaise: (rupees * 100).round(), upi: _upi, reference: reference.isEmpty ? null : reference));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ')),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: true, label: Text('UPI')), ButtonSegment(value: false, label: Text('Cash'))],
            selected: {_upi},
            onSelectionChanged: (s) => setState(() => _upi = s.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: _reference, decoration: InputDecoration(labelText: _upi ? 'UPI reference (UTR)' : 'Note (optional)')),
          if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: TextStyle(color: context.colors.error))],
          const SizedBox(height: 16),
          Text(
            'It counts as settled straight away. They and QuickMandi are notified, and they can report a problem within 24 hours.',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, child: const Text('Mark settled'))),
        ],
      ),
    );
  }
}
