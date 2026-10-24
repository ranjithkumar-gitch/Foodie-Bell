import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// A country the phone login/registration fields can dial into.
class PhoneCountry {
  const PhoneCountry({
    required this.name,
    required this.isoCode,
    required this.dialCode,
    required this.flag,
    required this.phoneLength,
  });

  final String name;
  final String isoCode;

  /// With the leading `+`, e.g. `+91` — what's prepended to the typed
  /// digits for Firebase phone auth (`'${country.dialCode}$digits'`).
  final String dialCode;
  final String flag;

  /// How many digits a local mobile number has here — the phone field's
  /// `maxLength` and the "valid number" check.
  final int phoneLength;
}

const kIndia = PhoneCountry(name: 'India', isoCode: 'IN', dialCode: '+91', flag: '🇮🇳', phoneLength: 10);

/// Every country the picker offers. India only for now — Quicky launches
/// in India and every account lookup (`firestore_*_provider.dart`'s
/// `+91`-stripping phone normalizers) assumes it. Adding a country later is
/// just another entry here (plus making those lookups country-aware); the
/// picker, its sheet, and every phone field pick it up with no other change.
const kSupportedPhoneCountries = [kIndia];

const kDefaultPhoneCountry = kIndia;

/// Swiggy/Zomato-style "🇮🇳 +91 ▾" prefix for a phone number field — sits
/// inside the field, before the typed digits, with a divider after it.
/// Tapping opens [showPhoneCountrySheet] — only once there's more than one
/// supported country; until then it's a fixed, non-tappable label.
class CountryCodePrefix extends StatelessWidget {
  const CountryCodePrefix({
    super.key,
    this.country = kDefaultPhoneCountry,
    this.onChanged,
    this.enabled = true,
  });

  final PhoneCountry country;
  final ValueChanged<PhoneCountry>? onChanged;
  final bool enabled;

  /// With a single supported country there's nothing to choose, so the
  /// prefix is plain display — no tap, no sheet, no ▾ arrow.
  bool get _selectable => kSupportedPhoneCountries.length > 1;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: !enabled || !_selectable
          ? null
          : () async {
              final picked = await showPhoneCountrySheet(context, selected: country);
              if (picked != null && picked != country) onChanged?.call(picked);
            },
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text(
              country.dialCode,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black),
            ),
            if (_selectable) Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: palette.textMuted),
            const SizedBox(width: 8),
            Container(width: 1, height: 24, color: palette.border),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing [kSupportedPhoneCountries], [selected] ticked.
/// Returns the tapped country, or null when dismissed.
Future<PhoneCountry?> showPhoneCountrySheet(BuildContext context, {required PhoneCountry selected}) {
  return showModalBottomSheet<PhoneCountry>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final palette = context.colors;
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: palette.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text('Select country', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              for (final country in kSupportedPhoneCountries)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Text(country.flag, style: const TextStyle(fontSize: 26)),
                  title: Text(country.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(country.dialCode, style: TextStyle(fontWeight: FontWeight.w700, color: palette.textSecondary)),
                      if (country == selected) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.check_circle_rounded, color: palette.primary),
                      ],
                    ],
                  ),
                  onTap: () => Navigator.pop(context, country),
                ),
            ],
          ),
        ),
      );
    },
  );
}
