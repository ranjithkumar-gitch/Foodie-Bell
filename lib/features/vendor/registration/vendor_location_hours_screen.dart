import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/vendor.dart';
import '../../../shared/widgets/mock_map_view.dart';
import 'vendor_registration_scaffold.dart';
import 'vendor_registration_state.dart';

const _kDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Registration step 4 — Location & Hours (spec §5.4): a fake map pin for
/// the shop location plus per-day operating hours. Vegetables & Fruits
/// vendors have a platform-enforced 10 AM - 6 PM ordering window
/// (`VendorCategory.hasOrderingWindow`) shown as a read-only notice instead
/// of an editable field.
class VendorLocationHoursScreen extends ConsumerStatefulWidget {
  const VendorLocationHoursScreen({super.key});

  @override
  ConsumerState<VendorLocationHoursScreen> createState() => _VendorLocationHoursScreenState();
}

class _VendorLocationHoursScreenState extends ConsumerState<VendorLocationHoursScreen> {
  bool _pinConfirmed = false;
  final Map<String, bool> _openDays = {for (final d in _kDays) d: true};
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 22, minute: 0);

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? _start : _end);
    if (picked == null) return;
    setState(() => isStart ? _start = picked : _end = picked);
  }

  void _continue() {
    final category = ref.read(vendorRegistrationProvider).category;
    final hoursSummary = category.hasOrderingWindow
        ? '10:00 AM - 6:00 PM, all days (platform-enforced)'
        : '${_start.format(context)} - ${_end.format(context)}, '
            '${_openDays.values.every((v) => v) ? 'all days' : _openDays.entries.where((e) => e.value).map((e) => e.key).join(', ')}';
    ref.read(vendorRegistrationProvider.notifier).update((d) => d.copyWith(operatingHours: hoursSummary));
    context.push('/vendor/register/rebate-terms');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final category = ref.watch(vendorRegistrationProvider).category;
    return VendorRegistrationScaffold(
      step: 4,
      totalSteps: 5,
      title: 'Location & operating hours',
      subtitle: 'Drop a pin at your shop and let customers know when you\'re open.',
      onContinue: _continue,
      children: [
        Text('Shop location', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: palette.textPrimary)),
        const SizedBox(height: 8),
        MockMapView(height: 180, borderRadius: BorderRadius.circular(16)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => setState(() => _pinConfirmed = true),
          icon: Icon(_pinConfirmed ? Icons.check_rounded : Icons.place_outlined),
          label: Text(_pinConfirmed ? 'Location pinned' : 'Confirm this pin as shop location'),
        ),
        const SizedBox(height: 24),
        Text('Operating hours', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: palette.textPrimary)),
        const SizedBox(height: 8),
        if (category.hasOrderingWindow)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: palette.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded, color: palette.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vegetables & Fruits vendors follow a platform-enforced ordering '
                    'window of 10:00 AM - 6:00 PM, every day.',
                    style: TextStyle(color: palette.warning, fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: () => _pickTime(isStart: true), child: Text('Opens ${_start.format(context)}')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(onPressed: () => _pickTime(isStart: false), child: Text('Closes ${_end.format(context)}')),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final day in _kDays)
                FilterChip(
                  label: Text(day),
                  selected: _openDays[day]!,
                  onSelected: (v) => setState(() => _openDays[day] = v),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
