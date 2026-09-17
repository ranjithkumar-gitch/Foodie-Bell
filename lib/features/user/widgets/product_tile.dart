import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/product.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/quantity_stepper.dart';
import '../translation/translated_text.dart';

/// Row shown in a Vendor Storefront's product grid/list (spec §4.7).
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
    this.vendorClosed = false,
  });

  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  /// True when the vendor itself is currently closed ([Account.isOpen] ==
  /// false) — takes precedence over [Product.inStock] for what's shown,
  /// since "closed" explains why nothing here is orderable right now,
  /// rather than looking like every single item happens to be out of stock.
  final bool vendorClosed;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppNetworkImage(url: product.imageUrl, width: 84, height: 84, borderRadius: BorderRadius.circular(14)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (product.isVeg != null) ...[_VegDot(isVeg: product.isVeg!), const SizedBox(width: 6)],
                    Expanded(
                      child: TranslatedText(product.name, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TranslatedText(product.description, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                TranslatedText(product.unit, style: TextStyle(fontSize: 11, color: palette.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CurrencyText(product.price, style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (vendorClosed)
                      Text(context.l10n.productVendorClosed, style: TextStyle(color: palette.error, fontWeight: FontWeight.w700, fontSize: 12))
                    else if (!product.inStock)
                      Text(context.l10n.productOutOfStock, style: TextStyle(color: palette.error, fontWeight: FontWeight.w700, fontSize: 12))
                    else if (quantity == 0)
                      _AddButton(onTap: onAdd)
                    else
                      QuantityStepper(quantity: quantity, onIncrement: onIncrement, onDecrement: onDecrement, compact: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: palette.primaryLight.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
        child: Text(context.l10n.productAddButton, style: TextStyle(color: palette.primary, fontWeight: FontWeight.w800, fontSize: 12.5)),
      ),
    );
  }
}

class _VegDot extends StatelessWidget {
  const _VegDot({required this.isVeg});

  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final color = isVeg ? palette.success : palette.error;
    return Container(
      width: 13,
      height: 13,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(border: Border.all(color: color, width: 1.2), borderRadius: BorderRadius.circular(3)),
      child: Center(child: Container(width: 5, height: 5, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
    );
  }
}
