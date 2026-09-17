import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/tax_category.dart';
import '../../data/models/vendor.dart';
import '../../data/providers/firestore_tax_categories_provider.dart';

/// GST/HSN section for Add/Edit Product forms (both
/// `admin_global_product_edit_screen.dart` and
/// `vendor_add_edit_product_screen.dart`) — shows the tax category this
/// product would inherit, *suggested* from [category] + [productSubCategory]
/// via `suggestTaxCategory` but never assigned silently: the caller's
/// [taxCategoryId] only changes when the person taps "Use this" or picks a
/// different bracket, so retyping the sub-category field doesn't yank a
/// deliberate choice out from under them. A "Custom HSN/GST" toggle below
/// covers the rarer case where this one SKU needs to differ from every
/// bracket on offer (`Product.gstOverride`).
class TaxCategoryField extends ConsumerStatefulWidget {
  const TaxCategoryField({
    super.key,
    required this.category,
    required this.productSubCategory,
    required this.taxCategoryId,
    required this.onTaxCategoryIdChanged,
    required this.gstOverride,
    required this.onGstOverrideChanged,
  });

  final VendorCategory category;
  final String productSubCategory;
  final String? taxCategoryId;
  final ValueChanged<String?> onTaxCategoryIdChanged;
  final GstOverride? gstOverride;
  final ValueChanged<GstOverride?> onGstOverrideChanged;

  @override
  ConsumerState<TaxCategoryField> createState() => _TaxCategoryFieldState();
}

class _TaxCategoryFieldState extends ConsumerState<TaxCategoryField> {
  late bool _overrideEnabled = widget.gstOverride != null;
  late final _hsnController = TextEditingController(text: widget.gstOverride?.hsnCode ?? '');
  late final _rateController = TextEditingController(text: widget.gstOverride?.gstRate.toStringAsFixed(widget.gstOverride?.gstRate == widget.gstOverride?.gstRate.roundToDouble() ? 0 : 1) ?? '');
  late final _reasonController = TextEditingController(text: widget.gstOverride?.reason ?? '');

  @override
  void dispose() {
    _hsnController.dispose();
    _rateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _emitOverride() {
    if (!_overrideEnabled) {
      widget.onGstOverrideChanged(null);
      return;
    }
    final hsn = _hsnController.text.trim();
    final rate = double.tryParse(_rateController.text.trim());
    final reason = _reasonController.text.trim();
    widget.onGstOverrideChanged(hsn.isEmpty || rate == null || reason.isEmpty ? null : GstOverride(hsnCode: hsn, gstRate: rate, reason: reason));
  }

  Future<void> _pickCategory(List<TaxCategory> options) async {
    final picked = await showModalBottomSheet<TaxCategory>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TaxCategoryPickerSheet(options: options, selectedId: widget.taxCategoryId),
    );
    if (picked != null) widget.onTaxCategoryIdChanged(picked.id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final allCategories = ref.watch(firestoreTaxCategoriesProvider).valueOrNull ?? const [];
    final active = allCategories.where((c) => c.isActive).toList();
    final selected = widget.taxCategoryId == null ? null : allCategories.firstOrNull((c) => c.id == widget.taxCategoryId);
    final suggested = suggestTaxCategory(allCategories, widget.category, widget.productSubCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tax (GST)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: palette.textPrimary)),
        const SizedBox(height: 8),
        if (active.isEmpty)
          Text('No tax categories set up yet — see Admin > Tax Categories.', style: TextStyle(color: palette.textMuted, fontSize: 12))
        else if (selected != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(12), border: Border.all(color: palette.border)),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 18, color: palette.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selected.name, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('HSN ${selected.hsnCode} · ${_rateLabel(selected.gstRate)}% GST', style: TextStyle(color: palette.textSecondary, fontSize: 11.5)),
                    ],
                  ),
                ),
                TextButton(onPressed: () => _pickCategory(active), child: const Text('Change')),
              ],
            ),
          )
        else if (suggested != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: palette.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: palette.primary.withValues(alpha: 0.4))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: palette.primary),
                    const SizedBox(width: 6),
                    Text('Suggested tax category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: palette.primary)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(suggested.name, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                Text('HSN ${suggested.hsnCode} · ${_rateLabel(suggested.gstRate)}% GST', style: TextStyle(color: palette.textSecondary, fontSize: 11.5)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: () => _pickCategory(active), child: const Text('Choose different')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(onPressed: () => widget.onTaxCategoryIdChanged(suggested.id), child: const Text('Use this')),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: () => _pickCategory(active),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(12), border: Border.all(color: palette.border)),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 18, color: palette.textSecondary),
                  const SizedBox(width: 10),
                  Text('Select a tax category', style: TextStyle(fontWeight: FontWeight.w600, color: palette.textSecondary)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _overrideEnabled,
          onChanged: (v) => setState(() {
            _overrideEnabled = v ?? false;
            _emitOverride();
          }),
          title: const Text('Custom HSN/GST for this product', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: const Text('Only for a SKU that\'s a genuine exception to its tax category.', style: TextStyle(fontSize: 11.5)),
        ),
        if (_overrideEnabled) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _hsnController,
                  onChanged: (_) => _emitOverride(),
                  decoration: const InputDecoration(labelText: 'HSN / SAC code'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => _emitOverride(),
                  decoration: const InputDecoration(labelText: 'GST %'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            onChanged: (_) => _emitOverride(),
            decoration: const InputDecoration(labelText: 'Reason', hintText: 'Why does this SKU differ?'),
          ),
        ],
      ],
    );
  }
}

String _rateLabel(double rate) => rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : rate.toString();

extension on Iterable<TaxCategory> {
  TaxCategory? firstOrNull(bool Function(TaxCategory) test) {
    for (final c in this) {
      if (test(c)) return c;
    }
    return null;
  }
}

class _TaxCategoryPickerSheet extends StatelessWidget {
  const _TaxCategoryPickerSheet({required this.options, required this.selectedId});
  final List<TaxCategory> options;
  final String? selectedId;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        decoration: BoxDecoration(color: palette.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Text('Select tax category', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final category in options)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(category.name, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                      subtitle: Text('HSN ${category.hsnCode} · ${_rateLabel(category.gstRate)}% GST', style: TextStyle(color: palette.textSecondary, fontSize: 12)),
                      trailing: category.id == selectedId ? Icon(Icons.check_circle_rounded, color: palette.primary) : null,
                      onTap: () => Navigator.pop(context, category),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
