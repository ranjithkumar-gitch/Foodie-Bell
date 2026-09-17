import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/fcm_topics.dart';
import '../../../data/providers/firestore_personal_notifications_provider.dart';
import '../../../shared/widgets/notification_count_badge.dart';
import '../../../shared/widgets/notification_wall.dart';

/// Notifications Feed (spec §7.16) — order-lifecycle notifications this
/// Manager received (`onOrderStatusChange`, `QuickyAdmin/functions/index.js`),
/// all deletable. Real data now: this used to be a static mock list.
///
/// [ConsumerStatefulWidget], not [ConsumerWidget] — needs an `initState` to
/// call [markNotificationsSeen] exactly once when the screen opens, not on
/// every rebuild a live Firestore stream update would otherwise trigger.
class ManagerNotificationsScreen extends ConsumerStatefulWidget {
  const ManagerNotificationsScreen({super.key});

  @override
  ConsumerState<ManagerNotificationsScreen> createState() =>
      _ManagerNotificationsScreenState();
}

class _ManagerNotificationsScreenState
    extends ConsumerState<ManagerNotificationsScreen> {
  @override
  void initState() {
    super.initState();
    final accountId = ref.read(currentAccountIdProvider);
    if (accountId != null) markNotificationsSeen(ref, accountId);
  }

  @override
  Widget build(BuildContext context) {
    final accountId = ref.watch(currentAccountIdProvider);
    final async = accountId == null
        ? const AsyncValue.data(<Never>[])
        : ref.watch(firestorePersonalNotificationsProvider(accountId));

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: async.when(
        data: (items) => NotificationWall(
          items: [
            for (final p in items)
              WallItem(
                id: p.id,
                title: p.title,
                body: p.body,
                createdAt: p.createdAt,
                deletable: true,
                icon: Icons.receipt_long_rounded,
              ),
          ],
          emptySubtitle: 'Order updates from your territory will show up here.',
          onDelete: (item) => deletePersonalNotification(item.id),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text("Couldn't load notifications.")),
      ),
    );
  }
}
