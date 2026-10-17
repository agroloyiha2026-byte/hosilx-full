import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/app/localization/l10n.dart';
import 'package:hosilx/core/validation/validators.dart';

void main() {
  test('email validator', () {
    expect(Validators.email('a@b.uz'), isNull);
    expect(Validators.email('abc'), 'v_email');
    expect(Validators.email(''), 'v_required');
  });

  test('password validator', () {
    expect(Validators.password('12345678'), isNull);
    expect(Validators.password('1234567'), 'v_password');
    expect(Validators.password(null), 'v_required');
  });

  test('every validator key exists in all languages', () {
    for (final lang in supportedLangs) {
      for (final k in ['v_required', 'v_email', 'v_password', 'v_confirm']) {
        expect(L10n.all[lang]!.containsKey(k), true, reason: '$lang/$k');
      }
    }
  });
}
