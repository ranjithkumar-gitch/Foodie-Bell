import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/fcm_topics.dart';
import '../../../data/models/personal_notification.dart';
import '../../../data/providers/firestore_notifications_provider.dart';
import '../../../data/providers/firestore_personal_notifications_provider.dart';
import '../../../l10n/app_localizations_context.dart';
import '../../../shared/widgets/notification_count_badge.dart';
import '../../../shared/widgets/notification_wall.dart';

/// Notifications Feed (spec §4.16) — merges two sources: Admin's shared
/// broadcasts (`firestore_notifications_provider.dart`, filtered to topics
/// this device is subscribed to — not deletable here, see
/// [WallItem.deletable]'s doc comment) and this User's own order-lifecycle
/// notifications (`firestore_personal_notifications_provider.dart`,
/// deletable). Real data now: this used to be a static mock list before the
/// FCM push notification feature shipped.
///
/// [ConsumerStatefulWidget], not [ConsumerWidget] — needs an `initState` to
/// call [markNotificationsSeen] exactly once when the screen opens, not on
/// every rebuild a live Firestore stream update would otherwise trigger.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    final accountId = ref.read(currentAccountIdProvider);
    if (accountId != null) markNotificationsSeen(ref, accountId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accountId = ref.watch(currentAccountIdProvider);
    final broadcastsAsync = ref.watch(firestoreNotificationsProvider);
    final personalAsync = accountId == null
        ? const AsyncValue<List<PersonalNotification>>.data(
            <PersonalNotification>[],
          )
        : ref.watch(firestorePersonalNotificationsProvider(accountId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsTitle)),
      body: broadcastsAsync.when(
        data: (broadcasts) {
          final personal = personalAsync.valueOrNull ?? const [];
          // personalAsync errors (e.g. a missing Firestore index) used to
          // be swallowed entirely by the valueOrNull fallback above — the
          // wall would just silently render as if this User had no
          // personal notifications at all, with nothing to tell them
          // (or a developer) that something had actually failed. Surface
          // it instead, without losing the broadcasts that did load fine.
          if (personalAsync.hasError) {
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "Couldn't load your order notifications right now.",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Expanded(
                  child: NotificationWall(
                    items:
                        [
                          for (final b in broadcasts)
                            WallItem(
                              id: b.id,
                              title: b.title,
                              body: b.body,
                              createdAt: b.sentAt,
                              deletable: false,
                            ),
                        ]..sort(
                          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                            a.createdAt ?? DateTime(0),
                          ),
                        ),
                    emptySubtitle:
                        'Offers, announcements, and order updates will show up here.',
                    onDelete: (item) => deletePersonalNotification(item.id),
                  ),
                ),
              ],
            );
          }
          final items =
              <WallItem>[
                for (final b in broadcasts)
                  WallItem(
                    id: b.id,
                    title: b.title,
                    body: b.body,
                    createdAt: b.sentAt,
                    deletable: false,
                  ),
                for (final p in personal)
                  WallItem(
                    id: p.id,
                    title: p.title,
                    body: p.body,
                    createdAt: p.createdAt,
                    deletable: true,
                    icon: Icons.receipt_long_rounded,
                  ),
              ]..sort(
                (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                  a.createdAt ?? DateTime(0),
                ),
              );

          return NotificationWall(
            items: items,
            emptySubtitle:
                'Offers, announcements, and order updates will show up here.',
            onDelete: (item) => deletePersonalNotification(item.id),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text("Couldn't load notifications.")),
      ),
    );
  }
}
