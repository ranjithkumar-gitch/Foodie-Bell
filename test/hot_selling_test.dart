// Home's "Hot selling" row (2026-11-17): real best-sellers in stock, topped
// up with widely stocked items while sales are few; picking one finds the
// shops selling it, with a forgiving name match.
import 'package:flutter_test/flutter_test.dart';
import 'package:foodiebell/data/providers/firestore_products_provider.dart';
import 'package:foodiebell/features/user/home/hot_selling.dart';

CatalogEntry _e(String vendor, String name, {bool inStock = true}) =>
    CatalogEntry(productId: '$vendor-$name', vendorId: vendor, name: name, price: 50, isVeg: true, inStock: inStock);

void main() {
  final stocked = [
    _e('v1', 'Masala Dosa (2 pcs)'),
    _e('v2', 'masala  dosa'),
    _e('v1', 'Idli'),
    _e('v2', 'Idli'),
    _e('v3', 'Idli'),
    _e('v3', 'Tea'),
  ];

  test('forgiving match: case, spacing and extras', () {
    expect(productMatchesItem('Masala Dosa (2 pcs)', 'masala dosa'), isTrue);
    expect(productMatchesItem('MASALA  DOSA', 'Masala Dosa'), isTrue);
    expect(productMatchesItem('Dosa Batter', 'Masala Dosa'), isFalse);
    expect(productMatchesItem('Teacake', 'Tea'), isFalse);
    expect(vendorsSellingItem(stocked, 'Masala Dosa'), {'v1', 'v2'});
  });

  test('best-sellers in stock come first and say so; unsold ones are skipped', () {
    final r = hotSellingItems(bestSellers: ['Masala Dosa', 'Biryani'], stocked: stocked);
    expect(r.fromSales, isTrue);
    expect(r.items.first, 'Masala Dosa');
    expect(r.items, isNot(contains('Biryani')));
  });

  test('no sales yet: popular picks by how many shops stock them — never made-up items', () {
    final r = hotSellingItems(bestSellers: const [], stocked: stocked);
    expect(r.fromSales, isFalse);
    expect(r.items.first, 'Idli'); // 3 shops
    expect(r.items, isNot(contains('Biryani')));
    expect(hotSellingItems(bestSellers: const ['Biryani'], stocked: const []).items, isEmpty);
  });
}
