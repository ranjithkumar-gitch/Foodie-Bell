import 'package:flutter/material.dart';

/// A shop's weekly opening hours, set by the Vendor (`vendor_store_hours_screen.dart`)
/// and stored on `vendors/{id}.storeHours` as
/// `{opens: "09:00", closes: "22:00", days: [1, 2, ..., 7]}` (1 = Monday,
/// as [DateTime.weekday]). Copied to `vendor_directory` so customers see
/// it on the storefront. Informational: the Vendor's own Open/Closed
/// switch ([Account.isOpen]) still decides whether orders are taken.
class StoreHours {
  const StoreHours({required this.opens, required this.closes, required this.days});

  static const fallback = StoreHours(
    opens: TimeOfDay(hour: 9, minute: 0),
    closes: TimeOfDay(hour: 22, minute: 0),
    days: {1, 2, 3, 4, 5, 6, 7},
  );

  final TimeOfDay opens;
  final TimeOfDay closes;

  /// Days open, 1 (Monday) to 7 (Sunday).
  final Set<int> days;

  static const dayShortNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  static TimeOfDay? _parse(Object? raw) {
    if (raw is! String) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Null when [raw] isn't a valid stored value (never set yet).
  static StoreHours? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final opens = _parse(raw['opens']);
    final closes = _parse(raw['closes']);
    if (opens == null || closes == null) return null;
    final days = <int>{
      for (final d in (raw['days'] as List<dynamic>? ?? const []))
        if (d is num && d >= 1 && d <= 7) d.toInt(),
    };
    return StoreHours(opens: opens, closes: closes, days: days);
  }

  Map<String, dynamic> toMap() => {
    'opens': _format(opens),
    'closes': _format(closes),
    'days': (days.toList()..sort()),
  };

  /// "Mon–Sat" / "Every day" / "Mon, Wed, Fri" / "Closed all week".
  String get daysLabel {
    if (days.isEmpty) return 'Closed all week';
    if (days.length == 7) return 'Every day';
    final sorted = days.toList()..sort();
    final consecutive = sorted.last - sorted.first == sorted.length - 1;
    if (consecutive && sorted.length > 2) {
      return '${dayShortNames[sorted.first - 1]}–${dayShortNames[sorted.last - 1]}';
    }
    return sorted.map((d) => dayShortNames[d - 1]).join(', ');
  }

  /// "9:00 AM – 10:00 PM" in the device's 12/24-hour style.
  String timesLabel(BuildContext context) => '${opens.format(context)} – ${closes.format(context)}';
}
