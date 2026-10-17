import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/app/localization/l10n.dart';
import 'package:hosilx/features/admin/admin_content_repository.dart';
import 'package:hosilx/features/admin/admin_widgets.dart';

void main() {
  test('storagePathFromUrl extracts the object path', () {
    expect(storagePathFromUrl('https://x.supabase.co/storage/v1/object/public/images/u1/a%20b.jpg?t=1'), 'u1/a b.jpg');
    expect(storagePathFromUrl('https://other.com/pic.jpg'), isNull);
  });

  test('field validators', () {
    expect(dateKey('2026-12-31'), isNull);
    expect(dateKey(''), isNull);
    expect(dateKey('31.12.2026'), 'v_date');
    expect(httpsKey('https://a.uz'), isNull);
    expect(httpsKey('http://a.uz'), 'v_https');
    expect(httpsKey('javascript:alert(1)'), 'v_https');
    expect(intKey('12'), isNull);
    expect(intKey('1.5'), 'v_int');
    expect(slugKey('fruit_2'), isNull);
    expect(slugKey('Fruit'), 'v_slug');
  });

  test('isoOrNull handles empty and end of day', () {
    expect(isoOrNull(''), isNull);
    expect(isoOrNull('2026-01-01', endOfDay: true), isNotNull);
  });

  test('every validator key exists in all languages', () {
    for (final l in supportedLangs) {
      for (final k in ['v_date', 'v_https', 'v_int', 'v_slug', 'delete_confirm', 'ads_web_note']) {
        expect(L10n.all[l]!.containsKey(k), true, reason: '$l/$k');
      }
    }
  });
}
