import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../translation/translated_text.dart';

/// The 4 categories Quicky launches with ([VendorCategory]/seed data in
/// `mock_categories.dart`) each have a bundled illustrated badge — a real,
/// designed asset with its own caption baked in, not a generic glyph — so
/// Home's category rail can use those instead of a Material icon. Keyed by
/// [Category.id], which is `VendorCategory.name` for every seeded category.
/// Any category Admin adds beyond these 4 has no matching asset and falls
/// back to its plain icon ([CategoryChip.icon]) instead.
const _categoryImageAssets = <String, String>{
  'food': 'assets/images/food_logo.png',
  'pharmacy': 'assets/images/pharmacy_logo.png',
  'kirana': 'assets/images/kirana_logo.png',
  'vegetables': 'assets/images/vegitables_logo.png',
};

String? categoryImageAsset(String categoryId) =>
    _categoryImageAssets[categoryId];

/// A single category filter on Home. Renders the category's real badge
/// image full-width-aligned (equal `Expanded` share of the row, see
/// `home_screen.dart`) when one exists — the badge already has its label
/// baked into the artwork, so no separate [label] is drawn alongside it.
/// Falls back to an icon + [label] for a category with no bundled asset.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    this.imageAsset,
    required this.selected,
    required this.onTap,
    this.translate = false,
  });

  final String label;
  final IconData icon;
  final String? imageAsset;
  final bool selected;
  final VoidCallback onTap;

  /// True for a real Admin-authored category name (catalogue content,
  /// machine-translated via `TranslatedText`) — false for a caller passing
  /// an already-localized app string, which must never be run back through
  /// the English→Telugu translator a second time. Only relevant when
  /// [imageAsset] is null and [label] actually renders.
  final bool translate;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final badge = AspectRatio(
      aspectRatio: 470 / 535,
      child: imageAsset != null
          ? Image.asset(imageAsset!, fit: BoxFit.contain)
          : Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.surfaceMuted,
                border: Border.all(color: palette.border),
              ),
              child: Icon(icon, size: 22, color: palette.primary),
            ),
    );
    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: palette.textSecondary,
    );
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? palette.primary : Colors.transparent,
                  width: 2.4,
                ),
              ),
              child: badge,
            ),
            if (imageAsset == null) ...[
              const SizedBox(height: 6),
              translate
                  ? TranslatedText(
                      label,
                      style: labelStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    )
                  : Text(
                      label,
                      style: labelStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
            ],
          ],
        ),
      ),
    );
  }
}
