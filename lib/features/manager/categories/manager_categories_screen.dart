import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/providers/firestore_categories_provider.dart';
import '../../../data/providers/firestore_territories_provider.dart';
import '../../../shared/error_reporting.dart';
import '../../../shared/widgets/empty_state.dart';
import '../manager_session.dart';

/// Territory Categories — which categories are available in the Manager's
/// territory (a category turned off stops showing on User Home there,
/// `categoriesForTerritory`, and drops out of the "Add Vendor" picker).
///
/// Phase I.5.1: read-only. A territory can have several Managers, so its
/// category settings are the Super Admin's; the rules refuse a Manager's
/// change (`territories` update is Super Admin only).
class ManagerCategoriesScreen extends ConsumerWidget {
  const ManagerCategoriesScreen({super.key});

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
                    'Categories available in ${territory.name}. Only Quicky (the Super Admin) can turn a category on or off for the territory — contact Quicky to change one.',
                    key: const Key('categoriesReadOnlyNotice'),
                    style: TextStyle(color: palette.textSecondary, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  for (final category in categories) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
                      // Shown as a switch for familiarity, but disabled.
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Icon(category.icon, color: palette.primary),
                        title: Text(category.name, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                        subtitle: Text(territory.disabledCategoryIds.contains(category.id) ? 'Off in this territory' : 'Available'),
                        value: !territory.disabledCategoryIds.contains(category.id),
                        activeThumbColor: palette.primary,
                        onChanged: null,
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
