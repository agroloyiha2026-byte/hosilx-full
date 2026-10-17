import 'package:flutter_test/flutter_test.dart';
import 'package:hosilx/app/localization/l10n.dart';
import 'package:hosilx/core/validation/validators.dart';
import 'package:hosilx/models/stage5_models.dart';

void main() {
  test('storage tons validator', () {
    expect(Validators.tons('5', 10), isNull);
    expect(Validators.tons('10', 10), isNull);
    expect(Validators.tons('11', 10), 'v_tons');
    expect(Validators.tons('0', 10), 'v_tons');
    expect(Validators.tons('abc', 10), 'v_tons');
  });

  test('notification title keys exist in every language', () {
    for (final l in supportedLangs) {
      for (final k in ['notif_new_inquiry', 'notif_product_approved', 'notif_product_rejected']) {
        expect(L10n.all[l]!.containsKey(k), true, reason: '$l/$k');
      }
    }
  });

  test('Warehouse.fromMap parses nullable fields', () {
    final w = Warehouse.fromMap({'id': '1', 'name': 'N', 'region': 'R', 'storage_type': 'cold', 'owner_id': 'o',
      'capacity_tons': 100, 'free_tons': 40, 'accepted_products': ['olma']});
    expect(w.pricePerTonMonth, isNull);
    expect(w.accepted, ['olma']);
    expect(w.currency, 'UZS');
  });
}
