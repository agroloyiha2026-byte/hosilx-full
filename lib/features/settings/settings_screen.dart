import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/config/env.dart';
import '../../core/widgets/widgets.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('🌾 ${context.tr('settings')}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Row(children: [
            Icon(Env.isConfigured ? Icons.check_circle : Icons.warning_amber_rounded,
                color: Env.isConfigured ? s.primary : s.error),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr(Env.isConfigured ? 'config_ok' : 'config_missing'))),
          ]),
        ),
        const SizedBox(height: 16),
        Text(context.tr('language'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'uz', label: Text('UZ')),
            ButtonSegment(value: 'ru', label: Text('RU')),
            ButtonSegment(value: 'en', label: Text('EN')),
          ],
          selected: {settings.locale.languageCode},
          onSelectionChanged: (v) => ctrl.setLocale(v.first),
        ),
        const SizedBox(height: 20),
        Text(context.tr('theme'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(value: ThemeMode.light, label: Text(context.tr('theme_light')), icon: const Icon(Icons.light_mode_outlined)),
            ButtonSegment(value: ThemeMode.dark, label: Text(context.tr('theme_dark')), icon: const Icon(Icons.dark_mode_outlined)),
            ButtonSegment(value: ThemeMode.system, label: Text(context.tr('theme_system')), icon: const Icon(Icons.brightness_auto_outlined)),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (v) => ctrl.setThemeMode(v.first),
        ),
      ]),
    );
  }
}
