import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../auth/logout_confirmation_sheet.dart';
import 'menu_tile.dart';

class RailItemData {
  const RailItemData({required this.icon, required this.selectedIcon, required this.label});

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// A secondary, non-tab destination surfaced in [RailDrawerShell]'s side
/// menu — a flat `GoRoute` (spec screens like Settlement History or Order
/// Oversight) rather than one of the shell's own indexed branches, so it's
/// pushed via [path] instead of [StatefulNavigationShell.goBranch].
class DrawerLinkData {
  const DrawerLinkData({required this.icon, required this.label, required this.path});

  final IconData icon;
  final String label;
  final String path;
}

/// Responsive shell for Manager/Admin (spec calls both "mobile + responsive
/// web"): a [NavigationRail] on wide viewports, a [Drawer] + top [AppBar] on
/// narrow ones. Wraps a [StatefulShellRoute.indexedStack] branch, same as
/// [BottomNavShell] does for the mobile-first roles.
///
/// Both layouts get a persistent top bar with a logout action — this is
/// Admin's only logout affordance (it has no Profile tab), and a
/// second, more convenient one for Manager alongside its existing
/// Profile-menu logout.
class RailDrawerShell extends ConsumerWidget {
  const RailDrawerShell({
    super.key,
    required this.navigationShell,
    required this.items,
    required this.title,
    this.extraItems = const [],
    this.extraItemsLabel = 'More',
  });

  final StatefulNavigationShell navigationShell;
  final List<RailItemData> items;
  final String title;

  /// Secondary destinations shown as [MenuTile] cards below the main tab
  /// list — reachable from the menu icon on every screen, not just one tab.
  /// Empty by default: only Manager passes these today.
  final List<DrawerLinkData> extraItems;
  final String extraItemsLabel;

  static const _wideBreakpoint = 900.0;

  void _onDestinationSelected(int index) =>
      navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  /// The [extraItems] section alone, as its own [Drawer] — used on wide
  /// layouts where [NavigationRail] (not a drawer) is already the primary
  /// nav, so only the secondary links need a drawer of their own. Flutter's
  /// [Scaffold] auto-adds the menu icon that opens it since neither layout
  /// sets an explicit `AppBar.leading`.
  Widget _extraLinksDrawer(BuildContext context) {
    final palette = context.colors;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text(
                extraItemsLabel,
                style: TextStyle(fontWeight: FontWeight.w800, color: palette.textSecondary, fontSize: 12.5, letterSpacing: 0.5),
              ),
            ),
            for (final item in extraItems)
              MenuTile(
                icon: item.icon,
                label: item.label,
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(item.path);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final currentLabel = items[navigationShell.currentIndex].label;
    final logoutAction = IconButton(
      onPressed: () => LogoutConfirmationSheet.show(context, ref),
      icon: const Icon(Icons.power_settings_new_rounded),
      tooltip: 'Log out',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        if (isWide) {
          return Scaffold(
            appBar: AppBar(title: Text(currentLabel), actions: [logoutAction]),
            drawer: extraItems.isEmpty ? null : _extraLinksDrawer(context),
            body: Row(
              children: [
                NavigationRail(
                  extended: constraints.maxWidth >= 1200,
                  backgroundColor: palette.surface,
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: palette.primary)),
                  ),
                  destinations: [
                    for (final item in items)
                      NavigationRailDestination(icon: Icon(item.icon), selectedIcon: Icon(item.selectedIcon), label: Text(item.label)),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: navigationShell),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(title), actions: [logoutAction]),
          drawer: Drawer(
            child: SafeArea(
              child: ListView(
                children: [
                  for (var i = 0; i < items.length; i++)
                    ListTile(
                      leading: Icon(items[i].icon, color: navigationShell.currentIndex == i ? palette.primary : palette.textSecondary),
                      title: Text(items[i].label),
                      selected: navigationShell.currentIndex == i,
                      onTap: () {
                        Navigator.of(context).pop();
                        _onDestinationSelected(i);
                      },
                    ),
                  if (extraItems.isNotEmpty) ...[
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Text(
                        extraItemsLabel,
                        style: TextStyle(fontWeight: FontWeight.w800, color: palette.textSecondary, fontSize: 12.5, letterSpacing: 0.5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          for (final item in extraItems)
                            MenuTile(
                              icon: item.icon,
                              label: item.label,
                              onTap: () {
                                Navigator.of(context).pop();
                                context.push(item.path);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          body: navigationShell,
        );
      },
    );
  }
}
