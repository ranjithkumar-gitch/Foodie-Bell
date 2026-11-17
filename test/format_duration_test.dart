// Times read as people say them (2026-11-17): "45 min", "2 hr 3 min",
// "2 hr" — never "123 min".
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/l10n/generated/app_localizations.dart';
import 'package:foodiebell/shared/format_duration.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final te = lookupAppLocalizations(const Locale('te'));

  test('minutes under an hour; hours and minutes after', () {
    expect(formatDurationWith(en, 0), '0 min');
    expect(formatDurationWith(en, 45), '45 min');
    expect(formatDurationWith(en, 60), '1 hr');
    expect(formatDurationWith(en, 123), '2 hr 3 min');
    expect(formatDurationWith(en, 180), '3 hr');
    expect(formatDurationWith(te, 123), '2 గం. 3 ని.');
  });

  test('tracking reads "Arriving in 1 hr 5 min"', () {
    expect(en.trackArrivingIn(formatDurationWith(en, 65)), 'Arriving in 1 hr 5 min');
  });
}
