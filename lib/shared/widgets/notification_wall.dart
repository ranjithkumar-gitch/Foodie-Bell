import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/fcm_topics.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/chat_message.dart';
import '../../data/providers/firestore_personal_notifications_provider.dart';
import '../../data/providers/notification_seen_cache.dart';
import '../time_ago.dart';
import 'busy_overlay.dart';

/// When this account last tapped "Delete all" (persisted per account), or
/// null. Items the wall can't delete (Admin broadcasts, chat messages)
/// from before then are hidden on this device.
class NotificationsClearedAt extends StateNotifier<DateTime?> {
  NotificationsClearedAt(this.accountId) : super(null) {
    loadNotificationsClearedAt(accountId).then((v) {
      if (mounted && v != null && (state == null || v.isAfter(state!))) state = v;
    }).catchError((_) {});
  }
  final String accountId;

  void clear(DateTime at) {
    state = at;
    saveNotificationsClearedAt(accountId, at).catchError((_) {});
  }
}

final notificationsClearedAtProvider = StateNotifierProvider.family<NotificationsClearedAt, DateTime?, String>(
  (ref, accountId) => NotificationsClearedAt(accountId),
);

/// The rows still shown after "Delete all" at [clearedAt]: every deletable
/// row (deleted ones are gone from the server anyway) and anything newer.
List<WallItem> visibleWallItems(List<WallItem> items, DateTime? clearedAt) => [
  for (final i in items)
    if (clearedAt == null || i.deletable || (i.createdAt != null && i.createdAt!.isAfter(clearedAt))) i,
];

/// One row on a Notifications screen — a common shape every role's wall
/// (`notifications_screen.dart` for User, and the Vendor/Manager/Driver
/// equivalents) maps its own data into before merging and sorting, so the
/// rendering below (`NotificationWall`) only has to exist once.
class WallItem {
  const WallItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.deletable,
    this.icon = Icons.campaign_rounded,
    this.onTap,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? createdAt;

  /// False for an Admin broadcast (`NotificationBroadcast`) — no delete
  /// button shown at all for those; only Admin can remove one (from
  /// QuickyAdmin's own Push Notifications screen), which then disappears
  /// from every wall at once since they're all reading the same shared doc
  /// live, not a per-recipient copy.
  final bool deletable;

  final IconData icon;

  /// Where tapping the row leads (a chat message opens its chat); null for
  /// a row that only informs.
  final VoidCallback? onTap;
}

/// The other side's order-chat messages ([incomingChatProvider]) as wall
/// rows; tapping one opens that order's chat via [openChat].
List<WallItem> chatWallItems(Map<String, List<ChatMessage>> chats, void Function(String orderId) openChat) => [
  for (final messages in chats.values)
    for (final m in messages)
      WallItem(
        id: m.id,
        title: 'Message from ${m.senderName}',
        body: m.text,
        createdAt: m.sentAt,
        deletable: false,
        icon: Icons.chat_bubble_rounded,
        onTap: () => openChat(m.orderId),
      ),
];

/// The rendering every role's Notifications screen shares: grouped
/// Today/Earlier, a delete button only on [WallItem.deletable] rows, and a
/// consistent empty state. [items] should already be merged (if this role
/// has more than one source) and sorted newest-first by the caller.
class NotificationWall extends ConsumerWidget {
  const NotificationWall({
    super.key,
    required this.items,
    required this.onDelete,
    this.emptySubtitle = 'Nothing here yet.',
  });

  final List<WallItem> items;
  final ValueChanged<WallItem> onDelete;
  final String emptySubtitle;

  /// "Delete all": asks first, then deletes every personal notification of
  /// the account on the server and clears the rest off this wall.
  Future<void> _deleteAll(BuildContext context, WidgetRef ref, String accountId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        key: const Key('deleteAllNotificationsDialog'),
        title: const Text('Delete all notifications?'),
        content: const Text('This removes every notification from this list. It can’t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          ElevatedButton(key: const Key('confirmDeleteAllNotifications'), onPressed: () => Navigator.pop(d, true), child: const Text('Delete all')),
        ],
      ),
    );
    if (ok != true) return;
    final at = DateTime.now();
    try {
      await runBusy(() => deleteAllPersonalNotifications(accountId));
      ref.read(notificationsClearedAtProvider(accountId).notifier).clear(at);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All notifications deleted.')));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Couldn’t delete all notifications. Check your connection and try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.colors;
    final accountId = ref.watch(currentAccountIdProvider);
    final clearedAt = accountId == null ? null : ref.watch(notificationsClearedAtProvider(accountId));
    final items = visibleWallItems(this.items, clearedAt);

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: palette.textMuted,
              ),
              const SizedBox(height: 10),
              Text(
                'Nothing here yet',
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                emptySubtitle,
                style: TextStyle(color: palette.textMuted, fontSize: 12.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final now = DateTime.now();
    bool isToday(DateTime? d) =>
        d != null &&
        d.year == now.year &&
        d.month == now.month &&
        d.day == now.day;
    final today = items.where((n) => isToday(n.createdAt)).toList();
    final earlier = items.where((n) => !isToday(n.createdAt)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        if (accountId != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('deleteAllNotifications'),
              onPressed: () => _deleteAll(context, ref, accountId),
              icon: Icon(Icons.delete_sweep_rounded, color: palette.error),
              label: Text('Delete all', style: TextStyle(color: palette.error, fontWeight: FontWeight.w700)),
            ),
          ),
        if (today.isNotEmpty) ...[
          Text('Today', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final n in today) _WallTile(item: n, onDelete: onDelete),
          const SizedBox(height: 20),
        ],
        if (earlier.isNotEmpty) ...[
          Text('Earlier', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final n in earlier) _WallTile(item: n, onDelete: onDelete),
        ],
      ],
    );
  }
}

class _WallTile extends StatelessWidget {
  const _WallTile({required this.item, required this.onDelete});
  final WallItem item;
  final ValueChanged<WallItem> onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: item.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: palette.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  if (item.createdAt != null) ...[
                    const SizedBox(height: 6),
                    TimeAgoText(
                      item.createdAt!,
                      style: TextStyle(color: palette.textMuted, fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            if (item.deletable)
              IconButton(
                onPressed: () => onDelete(item),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: palette.textMuted,
                ),
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
              ),
            if (item.onTap != null)
              Icon(Icons.chevron_right_rounded, color: palette.textMuted),
          ],
        ),
      ),
      ),
    );
  }
}
