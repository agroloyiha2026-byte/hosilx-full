import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/app/localization/l10n.dart';
import 'package:hosilx/core/validation/validators.dart';
import 'package:hosilx/features/products/product_repository.dart';

void main() {
  test('imageContentType allows only jpeg/png/webp', () {
    expect(imageContentType('a.JPG'), 'image/jpeg');
    expect(imageContentType('a.webp'), 'image/webp');
    expect(imageContentType('a.gif'), isNull);
    expect(imageContentType('noext'), isNull);
  });

  test('positive validator', () {
    expect(Validators.positive('12 500'), isNull);
    expect(Validators.positive('0'), 'v_positive');
    expect(Validators.positive('-1'), 'v_positive');
    expect(Validators.positive(''), 'v_positive');
  });

  test('status and moderation labels exist in all languages', () {
    for (final l in supportedLangs) {
      for (final k in ['status_active', 'status_hidden', 'status_sold', 'mod_pending', 'mod_approved', 'mod_rejected', 'role_admin']) {
        expect(L10n.all[l]!.containsKey(k), true, reason: '$l/$k');
      }
    }
  });
}
