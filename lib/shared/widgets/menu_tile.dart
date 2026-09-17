import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A bordered, icon-leading, chevron-trailing card — the standard "menu row"
/// look reused across every role's Profile page and, now, Manager's Drawer
/// quick-links section (`rail_drawer_shell.dart`), so both surfaces read as
/// the same visual language rather than two different menu styles.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  /// An extra widget between the label and the chevron — e.g. a count pill.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: color ?? palette.textSecondary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color ?? palette.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
                Icon(Icons.chevron_right_rounded, color: palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
