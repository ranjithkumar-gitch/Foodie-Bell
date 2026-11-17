import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/store_hours.dart';
import '../../../data/models/vendor.dart';
import '../../../data/providers/firestore_vendors_provider.dart';
import '../../../shared/error_reporting.dart';
import '../vendor_session.dart';

/// Store Hours editor (spec §5.17): opening/closing time and the days the
/// shop is open. Loads the saved hours (`vendors/{id}.storeHours`) and
/// writes them back on Save ([setVendorStoreHours]); customers see them on
/// the storefront. The Open/Closed switch on the Dashboard still decides
/// whether orders are taken right now.
class VendorStoreHoursScreen extends ConsumerStatefulWidget {
  const VendorStoreHoursScreen({super.key});

  @override
  ConsumerState<VendorStoreHoursScreen> createState() => _VendorStoreHoursScreenState();
}

class _VendorStoreHoursScreenState extends ConsumerState<VendorStoreHoursScreen> {
  /// Null until the saved hours have been loaded into the form (or found
  /// missing), so a late-arriving record never overwrites the Vendor's edits.
  StoreHours? _hours;
  bool _saving = false;

  Future<void> _pickTime({required bool isStart}) async {
    final hours = _hours!;
    final picked = await showTimePicker(context: context, initialTime: isStart ? hours.opens : hours.closes);
    if (picked == null) return;
    setState(() => _hours = StoreHours(
      opens: isStart ? picked : hours.opens,
      closes: isStart ? hours.closes : picked,
      days: hours.days,
    ));
  }

  void _toggleDay(int day, bool open) {
    final hours = _hours!;
    setState(() => _hours = StoreHours(
      opens: hours.opens,
      closes: hours.closes,
      days: {...hours.days}..removeWhere((d) => d == day)..addAll(open ? [day] : const []),
    ));
  }

  Future<void> _save(String vendorId) async {
    final hours = _hours;
    if (hours == null) return;
    final opensMin = hours.opens.hour * 60 + hours.opens.minute;
    final closesMin = hours.closes.hour * 60 + hours.closes.minute;
    if (opensMin == closesMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening and closing time can’t be the same.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await setVendorStoreHours(vendorId, hours);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store hours saved.')));
      Navigator.of(context).maybePop();
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e, action: 'Saving store hours', stackTrace: st))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final vendorId = ref.watch(currentVendorIdProvider);
    final category = ref.watch(currentVendorCategoryProvider);
    final enforcedWindow = category.hasOrderingWindow;
    final account = ref.watch(liveVendorAccountProvider(vendorId));
    if (_hours == null && account != null) {
      _hours = account.storeHours ?? StoreHours.fallback;
    }
    final hours = _hours;

    return Scaffold(
      appBar: AppBar(title: const Text('Store Hours')),
      body: hours == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (enforcedWindow) ...[
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
                            '${category.label} vendors follow a platform-enforced 10:00 AM - 6:00 PM ordering window, every day.',
                            style: TextStyle(color: palette.warning, fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Text(
                    'Customers see these hours on your shop page. Use the Open/Closed switch on your Dashboard to stop orders right away.',
                    style: TextStyle(color: palette.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => _pickTime(isStart: true),
                          child: Text('Opens ${hours.opens.format(context)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving ? null : () => _pickTime(isStart: false),
                          child: Text('Closes ${hours.closes.format(context)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('Days open', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  for (var day = 1; day <= 7; day++)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(StoreHours.dayNames[day - 1]),
                      value: hours.days.contains(day),
                      onChanged: _saving ? null : (v) => _toggleDay(day, v),
                    ),
                ],
              ],
            ),
      bottomNavigationBar: enforcedWindow || hours == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _save(vendorId),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                        )
                      : const Text('Save hours'),
                ),
              ),
            ),
    );
  }
}
