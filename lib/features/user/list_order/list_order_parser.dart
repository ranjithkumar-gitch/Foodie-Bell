/// One OCR-guessed item/quantity pair — always editable afterward
/// (`list_order_capture_screen.dart`), since this is a best-effort split of
/// a raw text line, not a reliable extraction.
class ParsedListItem {
  ParsedListItem({required this.name, required this.quantity});

  String name;
  String quantity;
}

final _bulletPrefix = RegExp(r'^[\-\*•]\s*');
final _numberedPrefix = RegExp(r'^\d+[\.\)]\s*');

/// Matches a quantity token: a number, optionally followed by a common unit
/// word (kg/g/l/ml/pcs/pack/dozen/box/bottle, singular or plural). Used to
/// split "Rice 5kg" / "5kg Rice" / "Tomato x3" into a name + quantity guess.
final _quantityToken = RegExp(
  r'(\d+(?:\.\d+)?)\s*(kg|g|gm|grams?|l|ltr|litres?|liters?|ml|pcs?|pieces?|packs?|packets?|doz(?:en)?|box(?:es)?|bottles?|btl)?',
  caseSensitive: false,
);

final _joinerTrim = RegExp(r'^[\s\-xX×:]+|[\s\-xX×:]+$');

/// Turns raw OCR'd lines into editable (name, quantity) guesses — one line
/// per shopping-list entry. No unit conversion or catalogue matching: just
/// pulls the first quantity-looking token out of the line and leaves the
/// rest as the item name, defaulting quantity to "1" when nothing numeric
/// is found. Deliberately permissive since every row gets a human edit pass
/// before submit.
List<ParsedListItem> parseListLines(List<String> lines) {
  final items = <ParsedListItem>[];
  for (final raw in lines) {
    var line = raw
        .trim()
        .replaceFirst(_bulletPrefix, '')
        .replaceFirst(_numberedPrefix, '')
        .trim();
    if (line.isEmpty) continue;

    final matches = _quantityToken
        .allMatches(line)
        .where((m) => m.group(0)!.trim().isNotEmpty)
        .toList();
    if (matches.isEmpty) {
      items.add(ParsedListItem(name: line, quantity: '1'));
      continue;
    }

    // Prefer a match with a recognized unit (e.g. "5kg") over a bare number
    // that might just be part of the product name (e.g. a brand/pack code).
    final withUnit = matches.where((m) => m.group(2) != null).toList();
    final match = withUnit.isNotEmpty ? withUnit.first : matches.first;
    final quantity = match.group(0)!.trim();
    var name = (line.substring(0, match.start) + line.substring(match.end))
        .replaceAll(_joinerTrim, '')
        .trim();
    if (name.isEmpty) name = line;

    items.add(ParsedListItem(name: name, quantity: quantity));
  }
  return items;
}
