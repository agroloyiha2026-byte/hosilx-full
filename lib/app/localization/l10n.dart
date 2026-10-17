import 'package:flutter/widgets.dart';
import 'strings/auth_strings.dart';
import 'strings/core_strings.dart';
import 'strings/market_strings.dart';
import 'strings/stage5_strings.dart';
import 'strings/stage6_strings.dart';
import 'strings/stage7_strings.dart';

const supportedLangs = ['uz', 'ru', 'en'];

class L10n {
  /// Har bir keyingi bosqich o'z matn faylini shu ro'yxatga qo'shadi.
  static final List<Map<String, Map<String, String>>> _sources = [coreStrings, authStrings, marketStrings, stage5Strings, stage6Strings, stage7Strings];

  static final Map<String, Map<String, String>> all = _merge();

  static Map<String, Map<String, String>> _merge() {
    final out = <String, Map<String, String>>{for (final l in supportedLangs) l: {}};
    for (final src in _sources) {
      for (final l in supportedLangs) {
        out[l]!.addAll(src[l] ?? const {});
      }
    }
    return out;
  }

  static String tr(String lang, String key) => all[lang]?[key] ?? all['uz']?[key] ?? key;
}

extension TrX on BuildContext {
  String tr(String key) => L10n.tr(Localizations.localeOf(this).languageCode, key);
}
