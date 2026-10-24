import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/product.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/widgets/app_network_image.dart';
import '../../../shared/widgets/currency_text.dart';
import '../../../shared/widgets/quantity_stepper.dart';
import '../translation/translated_text.dart';

/// Row shown in a Vendor Storefront's product list (spec §4.7) — Swiggy/
/// Zomato's menu-row layout: veg mark, "Bestseller" tag, name, price and a
/// short description on the left; a larger photo on the right with the
/// ADD button / quantity stepper overlapping its bottom edge. Tapping the
/// row (anywhere but the button) calls [onTap] — the storefront opens the
/// product's detail sheet from it.
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.quantity,
    required this.onAdd,
    required this.onIncrement,
    required this.onDecrement,
    this.onTap,
    this.vendorClosed = false,
  });

  final Product product;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback? onTap;

  /// True when the vendor itself is currently closed ([Account.isOpen] ==
  /// false) — takes precedence over [Product.inStock] for what's shown,
  /// since "closed" explains why nothing here is orderable right now,
  /// rather than looking like every single item happens to be out of stock.
  final bool vendorClosed;

  static const _imageSize = 112.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final unavailable = vendorClosed || !product.inStock;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.isVeg != null || product.isPopular) ...[
                    Row(
                      children: [
                        if (product.isVeg != null) VegMark(isVeg: product.isVeg!),
                        if (product.isVeg != null && product.isPopular) const SizedBox(width: 8),
                        if (product.isPopular) const BestsellerTag(),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  TranslatedText(
                    product.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      CurrencyText(
                        product.price,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (product.unit.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: TranslatedText(
                            '· ${product.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: palette.textMuted, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (product.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TranslatedText(
                      product.description,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: _imageSize,
              height: _imageSize + 12,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Opacity(
                    opacity: unavailable ? 0.45 : 1,
                    child: AppNetworkImage(
                      url: product.imageUrl,
                      width: _imageSize,
                      height: _imageSize,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: vendorClosed
                        ? _UnavailableLabel(label: context.l10n.productVendorClosed)
                        : !product.inStock
                        ? _UnavailableLabel(label: context.l10n.productOutOfStock)
                        : quantity == 0
                        ? _AddButton(onTap: onAdd)
                        : QuantityStepper(
                            quantity: quantity,
                            onIncrement: onIncrement,
                            onDecrement: onDecrement,
                          ),
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

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Material(
      color: palette.surface,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.primary.withValues(alpha: 0.5)),
          ),
          child: Text(
            context.l10n.productAddButton,
            style: TextStyle(color: palette.primary, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.6),
          ),
        ),
      ),
    );
  }
}

class _UnavailableLabel extends StatelessWidget {
  const _UnavailableLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
      ),
      child: Text(label, style: TextStyle(color: palette.error, fontWeight: FontWeight.w700, fontSize: 11.5)),
    );
  }
}

/// The square-with-dot veg / non-veg mark Indian food menus use.
class VegMark extends StatelessWidget {
  const VegMark({super.key, required this.isVeg});

  final bool isVeg;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final color = isVeg ? palette.success : palette.error;
    return Container(
      width: 14,
      height: 14,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(border: Border.all(color: color, width: 1.3), borderRadius: BorderRadius.circular(3)),
      child: Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle))),
    );
  }
}

/// Small "★ Bestseller" tag for a vendor-flagged popular product
/// ([Product.isPopular]).
class BestsellerTag extends StatelessWidget {
  const BestsellerTag({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 12, color: palette.warning),
          const SizedBox(width: 2),
          Text(
            context.l10n.productBestseller,
            style: TextStyle(color: palette.warning, fontWeight: FontWeight.w800, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
