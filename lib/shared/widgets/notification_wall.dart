import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';

final _timeFmt = DateFormat('h:mm a');

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
}

/// The rendering every role's Notifications screen shares: grouped
/// Today/Earlier, a delete button only on [WallItem.deletable] rows, and a
/// consistent empty state. [items] should already be merged (if this role
/// has more than one source) and sorted newest-first by the caller.
class NotificationWall extends StatelessWidget {
  const NotificationWall({
    super.key,
    required this.items,
    required this.onDelete,
    this.emptySubtitle = 'Nothing here yet.',
  });

  final List<WallItem> items;
  final ValueChanged<WallItem> onDelete;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;

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
                  const SizedBox(height: 6),
                  Text(
                    item.createdAt == null
                        ? ''
                        : _timeFmt.format(item.createdAt!),
                    style: TextStyle(color: palette.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (item.deletable)
              IconButton(
                onPressed: () => onDelete(item),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: palette.textMuted,
                ),
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
