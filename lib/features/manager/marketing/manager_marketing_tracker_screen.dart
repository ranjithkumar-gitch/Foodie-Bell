import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/empty_state.dart';

class _MarketingEntry {
  const _MarketingEntry({required this.title, required this.date, required this.note});
  final String title;
  final DateTime date;
  final String note;
}

/// Local Marketing Tracker (spec §7.12, lower priority) — a simple mock log
/// list, kept entirely as local widget state (no shared provider needed).
class ManagerMarketingTrackerScreen extends StatefulWidget {
  const ManagerMarketingTrackerScreen({super.key});

  @override
  State<ManagerMarketingTrackerScreen> createState() => _ManagerMarketingTrackerScreenState();
}

class _ManagerMarketingTrackerScreenState extends State<ManagerMarketingTrackerScreen> {
  final List<_MarketingEntry> _entries = [
    _MarketingEntry(title: 'Flyer drop — Kukatpally main road', date: DateTime(2026, 8, 12), note: 'Distributed 500 flyers near vendor cluster.'),
    _MarketingEntry(title: 'Launch offer — 20% off first order', date: DateTime(2026, 8, 10), note: 'Ran territory-wide launch discount for new users.'),
    _MarketingEntry(title: 'Local FM radio spot', date: DateTime(2026, 8, 5), note: 'Booked a week of drive-time radio ads.'),
  ];

  Future<void> _addEntry() async {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log marketing activity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Activity')),
            const SizedBox(height: 12),
            TextField(controller: noteController, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (added != true || titleController.text.trim().isEmpty) return;
    setState(() {
      _entries.insert(0, _MarketingEntry(title: titleController.text.trim(), date: DateTime.now(), note: noteController.text.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Local Marketing Tracker')),
      floatingActionButton: FloatingActionButton(onPressed: _addEntry, child: const Icon(Icons.add_rounded)),
      body: _entries.isEmpty
          ? const EmptyState(icon: Icons.campaign_outlined, title: 'No activity logged yet', subtitle: 'Tap + to log your first marketing activity.')
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _entries.length,
              separatorBuilder: (context, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final e = _entries[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: palette.border)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: palette.primaryLight.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.campaign_rounded, color: palette.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.title, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary)),
                            const SizedBox(height: 3),
                            Text(DateFormat('d MMM yyyy').format(e.date), style: TextStyle(fontSize: 11.5, color: palette.textMuted)),
                            if (e.note.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(e.note, style: TextStyle(fontSize: 12.5, color: palette.textSecondary)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
