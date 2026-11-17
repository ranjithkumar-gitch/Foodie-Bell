import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';

/// A trip or wait time as people read it: "45 min" under an hour, then
/// "2 hr 3 min" (or "2 hr" on the hour) — never "123 min" (2026-11-17).
String formatDuration(BuildContext context, int minutes) => formatDurationWith(AppLocalizations.of(context)!, minutes);

String formatDurationWith(AppLocalizations l10n, int minutes) {
  final m = minutes < 0 ? 0 : minutes;
  if (m < 60) return l10n.durationMinutes(m);
  final hours = m ~/ 60;
  final rest = m % 60;
  return rest == 0 ? l10n.durationHours(hours) : l10n.durationHoursMinutes(hours, rest);
}
