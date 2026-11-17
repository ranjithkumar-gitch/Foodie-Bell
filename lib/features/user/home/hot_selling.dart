import '../../../data/providers/firestore_products_provider.dart';

/// Home's "Hot selling" row (2026-11-17): the territory's best-selling items
/// that the shops on screen actually have in stock, and picking one shows
/// the shops selling it.
///
/// The best-sellers are the server's (`trending/{territoryId}`: the last 7
/// days of delivered orders, items sold at least 3 times so no single order
/// shows — QuickyAdmin `functions/aggregates.js`). While there aren't enough
/// sales yet the row is topped up with "popular picks": the items stocked by
/// the most shops in view — labelled as such, never as best-sellers.

/// An item name compared loosely: case, spacing and punctuation don't matter.
String normalizeItemName(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9ఀ-౿]+'), ' ').trim();

/// Whether a product called [productName] is the item [term]: the same
/// name, or the name with extras ("Masala Dosa (2 pcs)" for "Masala Dosa").
bool productMatchesItem(String productName, String term) {
  final p = normalizeItemName(productName);
  final t = normalizeItemName(term);
  if (t.isEmpty) return false;
  if (p == t) return true;
  return t.length >= 3 && ' $p '.contains(' $t ');
}

/// The shops in [stocked] selling [term].
Set<String> vendorsSellingItem(Iterable<CatalogEntry> stocked, String term) => {
  for (final e in stocked)
    if (productMatchesItem(e.name, term)) e.vendorId,
};

/// The row's items: best-sellers in stock first ([fromSales] true when there
/// are any), then up to [max] with the most widely stocked items.
({List<String> items, bool fromSales}) hotSellingItems({
  required List<String> bestSellers,
  required List<CatalogEntry> stocked,
  int max = 8,
}) {
  final items = <String>[];
  final seen = <String>{};
  for (final name in bestSellers) {
    final key = normalizeItemName(name);
    if (key.isEmpty || seen.contains(key)) continue;
    if (vendorsSellingItem(stocked, name).isEmpty) continue;
    items.add(name);
    seen.add(key);
    if (items.length == max) return (items: items, fromSales: true);
  }
  final fromSales = items.isNotEmpty;
  if (items.length < max) {
    // Popular picks: items stocked by the most shops, then alphabetical.
    final shops = <String, Set<String>>{};
    final display = <String, String>{};
    for (final e in stocked) {
      final key = normalizeItemName(e.name);
      if (key.isEmpty || seen.contains(key)) continue;
      (shops[key] ??= <String>{}).add(e.vendorId);
      display.putIfAbsent(key, () => e.name.trim());
    }
    final ranked = shops.keys.toList()
      ..sort((a, b) {
        final byShops = shops[b]!.length.compareTo(shops[a]!.length);
        return byShops != 0 ? byShops : a.compareTo(b);
      });
    for (final key in ranked) {
      if (items.length == max) break;
      items.add(display[key]!);
    }
  }
  return (items: items, fromSales: fromSales);
}
