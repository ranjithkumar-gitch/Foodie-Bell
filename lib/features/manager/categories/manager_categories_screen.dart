import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/firestore_categories_provider.dart';
import '../../../data/providers/firestore_territories_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/empty_state.dart';
import '../manager_session.dart';

/// Territory Categories — a Manager turning categories on/off for their own
/// territory, on top of (never overriding) Admin's own global active/
/// inactive call on each [Category]. A category turned off here stops
/// showing on User Home for this territory specifically
/// (`categoriesForTerritory`, `home_screen.dart`) and drops out of this
/// Manager's own "Add Vendor" category picker
/// (`manager_vendor_create_screen.dart`) — every other territory is
/// unaffected.
class ManagerCategoriesScreen extends ConsumerWidget {
  const ManagerCategoriesScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, {required String territoryId, required List<String> disabledCategoryIds, required String categoryId, required bool enabled}) async {
    final next = enabled
        ? disabledCategoryIds.where((id) => id != categoryId).toList()
        : [...disabledCategoryIds, categoryId];
    try {
      await setTerritoryDisabledCategories(territoryId, next);
    } catch (e, st) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, action: 'Updating category', stackTrace: st))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final managerAccount = ref.watch(currentManagerAccountProvider);
    final territoriesAsync = ref.watch(firestoreTerritoriesProvider);
    final categoriesAsync = ref.watch(activeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Territory Categories')),
      body: territoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(friendlyError(e, action: 'Loading territory', stackTrace: st))),
        data: (territories) {
          final territory = territories.where((t) => t.name == managerAccount.territory).firstOrNull;
          if (territory == null) {
            return const EmptyState(icon: Icons.map_outlined, title: 'No territory found', subtitle: "This account isn't assigned to a territory yet.");
          }
          return categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text(friendlyError(e, action: 'Loading categories', stackTrace: st))),
            data: (categories) {
              if (categories.isEmpty) {
                return const EmptyState(icon: Icons.category_outlined, title: 'No categories yet', subtitle: 'Ask Admin to add or activate a category first.');
              }
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Turn a category off to hide it from User Home in ${territory.name} only — every other territory keeps seeing it.',
                    style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  for (final category in categories) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(category.icon, color: palette.primary),
                        title: Text(category.name, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                        value: !territory.disabledCategoryIds.contains(category.id),
                        activeThumbColor: palette.primary,
                        onChanged: (enabled) => _toggle(
                          context,
                          ref,
                          territoryId: territory.id,
                          disabledCategoryIds: territory.disabledCategoryIds,
                          categoryId: category.id,
                          enabled: enabled,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
