import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Availability / Shift Preferences (spec §6 item 16, lower priority) — a
/// simple day/time-slot toggle list, local-only state since there's no
/// scheduling backend behind it.
class DriverAvailabilityScreen extends StatefulWidget {
  const DriverAvailabilityScreen({super.key});

  @override
  State<DriverAvailabilityScreen> createState() => _DriverAvailabilityScreenState();
}

class _DriverAvailabilityScreenState extends State<DriverAvailabilityScreen> {
  final Map<String, bool> _days = {
    'Monday': true,
    'Tuesday': true,
    'Wednesday': true,
    'Thursday': true,
    'Friday': true,
    'Saturday': false,
    'Sunday': false,
  };

  String _shift = 'Morning (8 AM – 2 PM)';
  static const _shifts = ['Morning (8 AM – 2 PM)', 'Afternoon (2 PM – 8 PM)', 'Evening (6 PM – 12 AM)', 'Full day'];

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Availability & Shift')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text('Days available', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
            child: Column(
              children: [
                for (final day in _days.keys) ...[
                  if (day != _days.keys.first) Divider(height: 1, color: palette.divider),
                  SwitchListTile(
                    title: Text(day, style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary)),
                    value: _days[day]!,
                    onChanged: (v) => setState(() => _days[day] = v),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Preferred shift', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: palette.border)),
            child: RadioGroup<String>(
              groupValue: _shift,
              onChanged: (v) => setState(() => _shift = v!),
              child: Column(
                children: [
                  for (final shift in _shifts) ...[
                    if (shift != _shifts.first) Divider(height: 1, color: palette.divider),
                    RadioListTile<String>(
                      title: Text(shift, style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary)),
                      value: shift,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ElevatedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Availability preferences saved'))),
            child: const Text('Save preferences'),
          ),
        ),
      ),
    );
  }
}
