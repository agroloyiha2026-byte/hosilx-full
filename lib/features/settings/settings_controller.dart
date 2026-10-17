import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/localization/l10n.dart';

class AppSettings {
  final Locale locale;
  final ThemeMode themeMode;
  const AppSettings(this.locale, this.themeMode);
  AppSettings copyWith({Locale? locale, ThemeMode? themeMode}) =>
      AppSettings(locale ?? this.locale, themeMode ?? this.themeMode);
}

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController() : super(const AppSettings(Locale('uz'), ThemeMode.system)) {
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final lang = p.getString('lang');
      final theme = p.getString('theme');
      state = AppSettings(
        Locale(supportedLangs.contains(lang) ? lang! : 'uz'),
        ThemeMode.values.firstWhere((m) => m.name == theme, orElse: () => ThemeMode.system),
      );
    } catch (_) {/* saqlangan sozlama o'qilmasa standart qoladi */}
  }

  Future<void> setLocale(String lang) async {
    if (!supportedLangs.contains(lang)) return;
    state = state.copyWith(locale: Locale(lang));
    try { (await SharedPreferences.getInstance()).setString('lang', lang); } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode m) async {
    state = state.copyWith(themeMode: m);
    try { (await SharedPreferences.getInstance()).setString('theme', m.name); } catch (_) {}
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, AppSettings>((ref) => SettingsController());
