import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/territory.dart';
import '../../data/providers/firestore_territories_provider.dart';
import '../../data/providers/territory_cache.dart';
import '../../features/user/home/selected_territory_provider.dart';
import '../session/session_controller.dart';

/// FCM topic wiring for the territory-scoped push notification feature
/// (Admin's "Send Notification" screen in QuickyAdmin, `push_notification_screen.dart`).
///
/// Every actively-signed-in User device subscribes to [kAllUsersTopic],
/// plus exactly one territory topic at a time tracking
/// `selectedTerritoryProvider` (`home_screen.dart`'s "Deliver to" picker) —
/// see [listenForTopicSync], wired once at the app root, which reacts to
/// both login/logout and territory changes from one place. Subscribing/
/// unsubscribing is a device-local FCM SDK call — no server round-trip, no
/// auth needed — so there's nothing to fail here except a missing/broken
/// Play Services install, which is why every call is try/catch-guarded
/// rather than allowed to crash login or the picker.

/// Broadcast topic every signed-in User is subscribed to, regardless of
/// territory — the target QuickyAdmin's "All users" option sends to.
const kAllUsersTopic = 'all_users';

/// The topic for a given territory's Firestore doc id — must match
/// QuickyAdmin's `createTerritory` (`firestore_territories_provider.dart`),
/// which writes this exact string into `topics/{territoryId}.topic` so its
/// Send Notification picker doesn't need to re-derive this scheme.
String topicForTerritory(String territoryId) => 'territory_$territoryId';

/// Every role's own personal topic — subscribed on login, unsubscribed on
/// logout (see [listenForAccountTopicSync]), and what the order-lifecycle
/// Cloud Function (`onOrderStatusChange`, `QuickyAdmin/functions/index.js`)
/// targets for a specific User/Vendor/Manager/Driver recipient.
String topicForAccount(String accountId) => 'account_$accountId';

/// Every active Driver in [territoryName] — subscribed to by Drivers while
/// active (see [listenForDriverTerritoryTopicSync]), and what
/// `onOrderStatusChange` targets for the "notify every available Driver"
/// fan-out at the `vendorAccepted` step.
///
/// FCM topic names only allow `[a-zA-Z0-9-_.~%]` — `Account.territory` is a
/// free-text display name (e.g. `"Chityal, Nalgonda"`, comma and space
/// included), so it's sanitized first. Must match the same sanitization in
/// `onOrderStatusChange`'s JS, or the two sides never land on the same
/// topic string.
String topicForActiveDrivers(String territoryName) => 'drivers_${sanitizeTopicSegment(territoryName)}';

final _unsafeTopicChars = RegExp(r'[^a-zA-Z0-9\-_.~%]');

String sanitizeTopicSegment(String s) => s.replaceAll(_unsafeTopicChars, '_');

Future<void> subscribeToTopic(String topic) async {
  try {
    await FirebaseMessaging.instance.subscribeToTopic(topic);
  } catch (e, st) {
    debugPrint('fcm_topics: subscribe($topic) failed: $e\n$st');
  }
}

Future<void> unsubscribeFromTopic(String topic) async {
  try {
    await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
  } catch (e, st) {
    debugPrint('fcm_topics: unsubscribe($topic) failed: $e\n$st');
  }
}

/// Moves the device's territory-topic subscription from [previousTerritoryId]
/// to [nextTerritoryId] — called once at login (`previousTerritoryId` null,
/// nothing to unsubscribe) and again whenever the User picks a different
/// territory (`home_screen.dart`). A no-op if both resolve to the same
/// topic, so callers don't need to pre-check for "unchanged" themselves.
Future<void> syncTerritoryTopic({
  required String? previousTerritoryId,
  required String? nextTerritoryId,
}) async {
  final previousTopic = previousTerritoryId == null ? null : topicForTerritory(previousTerritoryId);
  final nextTopic = nextTerritoryId == null ? null : topicForTerritory(nextTerritoryId);
  if (previousTopic == nextTopic) return;
  if (previousTopic != null) await unsubscribeFromTopic(previousTopic);
  if (nextTopic != null) await subscribeToTopic(nextTopic);
}

/// The territory this device's FCM subscription should currently track:
/// null unless a User is actively signed in, in which case it's their
/// explicit pick or the same default `home_screen.dart`/`search_screen.dart`
/// already fall back to — so the subscribed topic always matches what's
/// actually shown as "Deliver to", not a separately-tracked notion of it.
/// Also reused by `firestore_notifications_provider.dart`'s bell-screen
/// feed, so "what territory am I subscribed to" is computed in exactly one
/// place for both purposes.
final currentTopicTerritoryProvider = Provider<Territory?>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session.role != AppRole.user || session.account == null || session.stage != AuthStage.active) return null;
  final territories = ref.watch(firestoreTerritoriesProvider).valueOrNull ?? const [];
  return ref.watch(selectedTerritoryProvider) ?? resolveDefaultTerritory(territories);
});

/// Wired once at the app root (`app.dart`), alongside
/// `listenForBrandThemeChanges`/`hydrateSelectedTerritoryFromCache`. Keeps
/// the device's FCM subscriptions in sync with [currentTopicTerritoryProvider] —
/// covers login (previous null → a territory: subscribes to it plus
/// [kAllUsersTopic]), an explicit territory change (unsubscribes the old
/// one, subscribes the new one), and logout (a territory → null:
/// unsubscribes both) — all from one place, so there's no separate
/// "did we already do this" flag to keep in sync with session/login state.
void listenForTopicSync(WidgetRef ref) {
  ref.listen<Territory?>(currentTopicTerritoryProvider, (previous, next) {
    if (previous?.id == next?.id) return;
    syncTerritoryTopic(previousTerritoryId: previous?.id, nextTerritoryId: next?.id);
    saveCachedTerritoryId(next?.id);
    if (next != null && previous == null) {
      subscribeToTopic(kAllUsersTopic);
    } else if (next == null && previous != null) {
      unsubscribeFromTopic(kAllUsersTopic);
    }
  });
}

/// The signed-in account's own id, for [listenForAccountTopicSync] —
/// role-agnostic (unlike [currentTopicTerritoryProvider], which is
/// User-only): every role gets order-lifecycle notifications
/// (`onOrderStatusChange`), so every role needs its own personal topic.
final currentAccountIdProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session.account == null || session.stage != AuthStage.active) return null;
  return session.account!.id;
});

/// Wired once at the app root, alongside [listenForTopicSync] — subscribes
/// to [topicForAccount] on login, unsubscribes on logout, for every role.
void listenForAccountTopicSync(WidgetRef ref) {
  ref.listen<String?>(currentAccountIdProvider, (previous, next) {
    if (previous == next) return;
    if (previous != null) unsubscribeFromTopic(topicForAccount(previous));
    if (next != null) subscribeToTopic(topicForAccount(next));
  });
}

/// The Driver's own territory while actively signed in as an active Driver
/// — null otherwise, including for every other role. Drilled from the
/// session's own [Account.territory] (denormalized onto the Driver's own
/// record at creation, see `manager_driver_create_screen.dart`) rather than
/// a live Firestore lookup — same login/logout-only granularity as
/// [currentTopicTerritoryProvider], not reactive to a Manager suspending
/// this Driver mid-session (an accepted simplification: that already routes
/// them out of the normal Driver flow via `AuthStage.blocked`, so a
/// lingering topic subscription for the rest of that one session is low
/// stakes, and re-evaluates cleanly on their next login either way).
final currentDriverTerritoryProvider = Provider<String?>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session.role != AppRole.driver || session.account == null || session.stage != AuthStage.active) return null;
  return session.account!.territory;
});

/// Wired once at the app root, alongside the others — keeps a Driver's
/// device subscribed to [topicForActiveDrivers] for their own territory
/// while signed in.
void listenForDriverTerritoryTopicSync(WidgetRef ref) {
  ref.listen<String?>(currentDriverTerritoryProvider, (previous, next) {
    if (previous == next) return;
    if (previous != null) unsubscribeFromTopic(topicForActiveDrivers(previous));
    if (next != null) subscribeToTopic(topicForActiveDrivers(next));
  });
}
