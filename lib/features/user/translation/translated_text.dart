import 'package:flutter/material.dart';

import 'english_to_telugu_transliterator.dart';

/// A [Text] for catalogue *content* (category names, sub-categories,
/// product name/description/unit) that renders itself phonetically in
/// Telugu script when the User's chosen language is Telugu — see
/// `english_to_telugu_transliterator.dart` for why this is transliteration
/// ("Milk" → "మిల్క్"), not translation ("Milk" → "పాలు"), and why that's
/// deliberately separate from the app's own hand-translated UI copy
/// (`AppLocalizations`). Purely synchronous — the transliterator is a local
/// rule-based function, not a network/model call — so this just picks
/// which string to render, live, off the current [Locale].
class TranslatedText extends StatelessWidget {
  const TranslatedText(this.text, {super.key, this.style, this.maxLines, this.overflow, this.textAlign});

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final isTelugu = Localizations.localeOf(context).languageCode == 'te';
    final display = isTelugu ? transliterateText(text) : text;
    return Text(display, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign);
  }
}
