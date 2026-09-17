import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/fcm_topics.dart';
import '../../../data/providers/firestore_personal_notifications_provider.dart';
import '../../../shared/widgets/notification_count_badge.dart';
import '../../../shared/widgets/notification_wall.dart';

/// Notifications Feed (spec §6 item 17) — order-lifecycle notifications this
/// Driver received (`onOrderStatusChange`, `QuickyAdmin/functions/index.js`),
/// including new-delivery alerts for their whole territory, all deletable.
/// Real data now: this used to be a static mock list.
///
/// [ConsumerStatefulWidget], not [ConsumerWidget] — needs an `initState` to
/// call [markNotificationsSeen] exactly once when the screen opens, not on
/// every rebuild a live Firestore stream update would otherwise trigger.
class DriverNotificationsScreen extends ConsumerStatefulWidget {
  const DriverNotificationsScreen({super.key});

  @override
  ConsumerState<DriverNotificationsScreen> createState() =>
      _DriverNotificationsScreenState();
}

class _DriverNotificationsScreenState
    extends ConsumerState<DriverNotificationsScreen> {
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
                icon: Icons.local_shipping_rounded,
              ),
          ],
          emptySubtitle: 'New deliveries and order updates will show up here.',
          onDelete: (item) => deletePersonalNotification(item.id),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text("Couldn't load notifications.")),
      ),
    );
  }
}
