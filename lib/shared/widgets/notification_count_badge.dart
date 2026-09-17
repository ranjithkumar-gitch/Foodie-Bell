import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/fcm_topics.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers/firestore_notifications_provider.dart';
import '../../data/providers/firestore_personal_notifications_provider.dart';
import '../../data/providers/notification_seen_cache.dart';

/// In-memory "opened the wall this session" timestamp, per account — set
/// immediately (no async wait) by [markNotificationsSeen] so the badge
/// clears the instant the screen opens, not only after the persisted write
/// below finishes. Defaults to null (nothing seen yet this session).
final _sessionLastSeenProvider = StateProvider.family<DateTime?, String>(
  (ref, accountId) => null,
);

/// The persisted last-seen timestamp from a previous session
/// (`notification_seen_cache.dart`) — loaded once per account the first
/// time anything asks for it.
final _persistedLastSeenProvider = FutureProvider.family<DateTime?, String>(
  (ref, accountId) => loadNotificationsLastSeen(accountId),
);

/// Marks "now" as this account's last-seen point — call once when a
/// Notifications screen opens (its `initState`), not on every rebuild:
/// updates the in-memory value (after this frame, see below) for the
/// badge, and persists it in the background so it survives an app restart
/// too.
void markNotificationsSeen(WidgetRef ref, String accountId) {
  final now = DateTime.now();
  // Deferred with Future.microtask, not written synchronously — a
  // Notifications screen's initState runs while the tree is still
  // building this same frame (GoRouter's push transition keeps the Home
  // screen, whose own bell badge watches this same provider, mounted
  // underneath), so a synchronous write here trips Riverpod's "tried to
  // modify a provider while the widget tree was building" guard. Deferring
  // to right after the frame finishes avoids that without any delay a
  // user would notice.
  Future.microtask(() {
    ref.read(_sessionLastSeenProvider(accountId).notifier).state = now;
  });
  saveNotificationsLastSeen(accountId, now);
}

/// Total item count for the signed-in account's notification wall,
/// *excluding* anything already seen — the newest one is what
/// [NotificationWall] (`notification_wall.dart`) renders in full (seen or
/// not; the wall itself doesn't hide read items, only the badge does):
/// every personal notification created after the account's last-seen point,
/// plus (only when [includeBroadcasts]) every Admin broadcast sent after
/// it. User is the only role with a live broadcast topic subscription
/// (`firestore_notifications_provider.dart`'s doc comment — Vendor/Driver/
/// Manager have no territory/all-users topic of their own), so those three
/// only ever pass `false` here.
final notificationWallCountProvider = Provider.family<int, bool>((
  ref,
  includeBroadcasts,
) {
  final accountId = ref.watch(currentAccountIdProvider);
  if (accountId == null) return 0;

  final sessionSeen = ref.watch(_sessionLastSeenProvider(accountId));
  final persistedSeen = ref
      .watch(_persistedLastSeenProvider(accountId))
      .valueOrNull;
  final lastSeen = _laterOf(sessionSeen, persistedSeen);

  final personal =
      ref
          .watch(firestorePersonalNotificationsProvider(accountId))
          .valueOrNull ??
      const [];
  final personalCount = personal
      .where(
        (p) =>
            p.createdAt == null ||
            lastSeen == null ||
            p.createdAt!.isAfter(lastSeen),
      )
      .length;

  var broadcastCount = 0;
  if (includeBroadcasts) {
    final broadcasts =
        ref.watch(firestoreNotificationsProvider).valueOrNull ?? const [];
    broadcastCount = broadcasts
        .where(
          (b) =>
              b.sentAt == null ||
              lastSeen == null ||
              b.sentAt!.isAfter(lastSeen),
        )
        .length;
  }

  return personalCount + broadcastCount;
});

DateTime? _laterOf(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

/// Red count dot for a notification bell icon — the caller wraps its own
/// bell in `Stack(clipBehavior: Clip.none, children: [bell, const
/// NotificationBellDot(...)])` so each screen keeps its own bell styling
/// (User's rounded tile, Vendor/Driver's plain AppBar `IconButton`) and only
/// borrows the badge itself. Same red-circle look as
/// `bottom_nav_shell.dart`'s cart badge, capped at "9+" past 9.
class NotificationBellDot extends ConsumerWidget {
  const NotificationBellDot({super.key, this.includeBroadcasts = false});

  final bool includeBroadcasts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(notificationWallCountProvider(includeBroadcasts));
    if (count <= 0) return const SizedBox.shrink();
    final palette = context.colors;
    return Positioned(
      right: -2,
      top: -2,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.all(3),
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          decoration: BoxDecoration(
            color: palette.error,
            shape: BoxShape.circle,
            border: Border.all(color: palette.surface, width: 1.5),
          ),
          child: Text(
            count > 9 ? '9+' : '$count',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small inline count pill for a menu-tile row — Manager reaches
/// Notifications from a Profile menu tile rather than an AppBar bell icon,
/// so there's no icon to overlay [NotificationBellDot] on; same red, just
/// laid out inline instead of [Positioned].
class NotificationCountPill extends ConsumerWidget {
  const NotificationCountPill({super.key, this.includeBroadcasts = false});

  final bool includeBroadcasts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(notificationWallCountProvider(includeBroadcasts));
    if (count <= 0) return const SizedBox.shrink();
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: palette.error,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
