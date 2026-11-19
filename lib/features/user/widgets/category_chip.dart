import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../translation/translated_text.dart';

/// A signature accent per launch category (2026-11-20, replacing the
/// illustrated badge images), keyed by [Category.id]. Any category Admin
/// adds later uses the brand primary.
const _categoryAccents = <String, Color>{
  'food': Color(0xFFE8590C), // warm orange
  'pharmacy': Color(0xFF1971C2), // clinical blue
  'kirana': Color(0xFFB7791F), // grocery amber
  'vegetables': Color(0xFF2F9E44), // fresh green
};

Color categoryAccent(String? categoryId, Color fallback) => _categoryAccents[categoryId] ?? fallback;

/// One category filter pill on Home: a tinted icon disc plus the name.
/// Unselected it's a quiet outlined pill; selected it fills with the
/// category's accent (gradient, soft glow) and the icon disc turns white —
/// so the active filter reads at a glance while scrolling.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.categoryId,
    this.translate = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  /// Picks the accent colour; null (the "All" chip) uses the brand primary.
  final String? categoryId;

  /// True for a real Admin-authored category name (catalogue content,
  /// machine-translated via `TranslatedText`) — false for a caller passing
  /// an already-localized app string, which must never be run back through
  /// the English→Telugu translator a second time.
  final bool translate;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final accent = categoryAccent(categoryId, palette.primary);
    final darker = Color.lerp(accent, Colors.black, 0.22)!;
    final labelStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
      color: selected ? Colors.white : palette.textPrimary,
    );
    final text = translate
        ? TranslatedText(label, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis)
        : Text(label, style: labelStyle, maxLines: 1, overflow: TextOverflow.ellipsis);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: selected ? LinearGradient(colors: [accent, darker], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          color: selected ? null : palette.surface,
          border: Border.all(color: selected ? Colors.transparent : palette.border, width: 1.2),
          boxShadow: selected
              ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))]
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? Colors.white : accent.withValues(alpha: 0.12),
                    ),
                    child: Icon(icon, size: 17, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: text),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
