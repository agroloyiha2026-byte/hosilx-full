import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/app/localization/l10n.dart';

void main() {
  test('uz, ru, en have exactly the same keys', () {
    final uz = L10n.all['uz']!.keys.toSet();
    expect(L10n.all['ru']!.keys.toSet(), uz);
    expect(L10n.all['en']!.keys.toSet(), uz);
  });

  test('no empty translations', () {
    for (final lang in supportedLangs) {
      L10n.all[lang]!.forEach((k, v) => expect(v.trim().isNotEmpty, true, reason: '$lang/$k'));
    }
  });

  test('unknown key falls back to the key itself', () {
    expect(L10n.tr('en', 'does_not_exist'), 'does_not_exist');
  });
}
