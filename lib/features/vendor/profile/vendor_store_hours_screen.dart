import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/vendor.dart';
import '../vendor_session.dart';

const _kDays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Store Hours editor (part of spec §5.17). Per-day open/closed + start/end
/// time, same "doesn't need real persistence" affordance used during
/// registration's Location & Hours step — local state, a "Save" button that
/// just confirms with a toast.
class VendorStoreHoursScreen extends ConsumerStatefulWidget {
  const VendorStoreHoursScreen({super.key});

  @override
  ConsumerState<VendorStoreHoursScreen> createState() =>
      _VendorStoreHoursScreenState();
}

class _VendorStoreHoursScreenState
    extends ConsumerState<VendorStoreHoursScreen> {
  final Map<String, bool> _openDays = {for (final d in _kDays) d: true};
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 22, minute: 0);

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final vendor = ref.watch(currentVendorProvider);
    final enforcedWindow = vendor.category.hasOrderingWindow;

    return Scaffold(
      appBar: AppBar(title: const Text('Store Hours')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (enforcedWindow)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, color: palette.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${vendor.category.label} vendors follow a platform-enforced 10:00 AM - 6:00 PM ordering window, every day.',
                      style: TextStyle(
                        color: palette.warning,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(isStart: true),
                    child: Text('Opens ${_start.format(context)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickTime(isStart: false),
                    child: Text('Closes ${_end.format(context)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Days open', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final day in _kDays)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(day),
                value: _openDays[day]!,
                onChanged: (v) => setState(() => _openDays[day] = v),
              ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Store hours updated.')),
            ),
            child: const Text('Save hours'),
          ),
        ),
      ),
    );
  }
}
