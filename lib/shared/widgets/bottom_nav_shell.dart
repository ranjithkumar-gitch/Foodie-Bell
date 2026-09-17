import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

class BottomNavItemData {
  const BottomNavItemData({required this.icon, required this.label, this.badgeCount = 0});

  final IconData icon;
  final String label;
  final int badgeCount;
}

/// Bottom-nav shell for [StatefulShellRoute.indexedStack] branches — the
/// canonical mobile shell for User/Vendor/Driver (spec's mobile-first roles).
/// Generalized from the original app's `home_shell.dart` nav bar.
class BottomNavShell extends StatelessWidget {
  const BottomNavShell({super.key, required this.navigationShell, required this.items});

  final StatefulNavigationShell navigationShell;
  final List<BottomNavItemData> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < items.length; i++)
                  _NavItem(
                    data: items[i],
                    selected: navigationShell.currentIndex == i,
                    onTap: () => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.data, required this.selected, required this.onTap});

  final BottomNavItemData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final color = selected ? palette.primary : palette.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(data.icon, color: color, size: 24),
                if (data.badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(color: palette.error, shape: BoxShape.circle),
                      child: Text(
                        '${data.badgeCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(data.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
