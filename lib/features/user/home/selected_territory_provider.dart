import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/territory.dart';
import '../../../data/providers/firestore_territories_provider.dart';

/// The territory a User picked to browse (`home_screen.dart`'s "Deliver to"
/// picker, also read by `search_screen.dart`). `null` means "no explicit
/// pick yet this session" — callers fall back to [resolveDefaultTerritory]
/// in that case, so there's always something sensible shown before the
/// picker is ever opened, or before [hydrateSelectedTerritoryFromCache] has
/// had a chance to restore a previous session's pick.
final selectedTerritoryProvider = StateProvider<Territory?>((ref) => null);

/// The territory Home/Search show before the user has ever explicitly
/// picked one — "Chityal, Nalgonda" specifically, rather than just
/// whichever territory happens to sort first. Falls back to the first
/// loaded territory if that one isn't present (e.g. a different
/// environment/seed data).
const defaultTerritoryName = 'Chityal, Nalgonda';

Territory? resolveDefaultTerritory(List<Territory> territories) {
  if (territories.isEmpty) return null;
  return territories.firstWhere((t) => t.name == defaultTerritoryName, orElse: () => territories.first);
}

/// The last-picked territory id loaded from local storage at startup
/// (`main.dart`, before `runApp`) — overridden via `ProviderScope`, same
/// pattern as `cachedBrandThemeProvider`. Only consumed by
/// [hydrateSelectedTerritoryFromCache] below.
final cachedTerritoryIdProvider = Provider<String?>((ref) => null);

/// Restores a previous session's territory pick once territories first load
/// — without this, [selectedTerritoryProvider] resets to `null` on every
/// cold start and every screen falls back to the fixed default, even though
/// the device's FCM topic subscription (`fcm_topics.dart`) is otherwise
/// sticky and would stay on whatever was picked last time. Wired once at
/// the app root (`app.dart`), alongside `listenForBrandThemeChanges`/
/// `listenForTopicSync`. A no-op once the User has explicitly picked
/// something this session (never overwrites a real choice), and a no-op if
/// nothing was ever cached or the cached territory no longer exists.
void hydrateSelectedTerritoryFromCache(WidgetRef ref) {
  ref.listen(firestoreTerritoriesProvider, (previous, next) {
    final territories = next.valueOrNull;
    if (territories == null) return;
    if (ref.read(selectedTerritoryProvider) != null) return;
    final cachedId = ref.read(cachedTerritoryIdProvider);
    if (cachedId == null) return;
    for (final t in territories) {
      if (t.id == cachedId) {
        ref.read(selectedTerritoryProvider.notifier).state = t;
        return;
      }
    }
  });
}
