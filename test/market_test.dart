import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/core/format.dart';
import 'package:hosilx/features/market/market_repository.dart';
import 'package:hosilx/models/market_models.dart';

void main() {
  test('fmtNum groups thousands', () {
    expect(fmtNum(1234567), '1 234 567');
    expect(fmtNum(7500), '7 500');
    expect(fmtNum(0.65), '0.65');
  });

  test('sanitizeSearch removes filter-breaking characters', () {
    expect(sanitizeSearch('a,b(c)%d'), 'a b c  d');
    expect(sanitizeSearch('  pomidor '), 'pomidor');
  });

  test('ProductFilters.copyWith can clear nullable fields', () {
    const f = ProductFilters(category: 'fruit', minPrice: 5);
    expect(f.hasActive, true);
    final g = f.copyWith(category: null, minPrice: null);
    expect(g.category, isNull);
    expect(g.minPrice, isNull);
    expect(g.hasActive, false);
  });

  test('Product.fromMap merges main image and gallery without duplicates', () {
    final p = Product.fromMap({
      'id': '1', 'title': 'T', 'category': 'fruit', 'product_type': 'olma', 'price': 10, 'currency': 'UZS', 'unit': 'kg',
      'quantity': 5, 'region': 'R', 'seller_id': 's', 'created_at': '2026-01-01T00:00:00Z', 'image_url': 'a',
      'product_images': [{'url': 'b', 'sort_order': 2}, {'url': 'a', 'sort_order': 1}],
    });
    expect(p.images, ['a', 'b']);
  });
}
