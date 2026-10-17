import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../home/site_settings_provider.dart';
import 'admin_content_providers.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});
  @override
  ConsumerState<AdminSettingsScreen> createState() => _S();
}

class _S extends ConsumerState<AdminSettingsScreen> {
  final _ann = TextEditingController(), _mnt = TextEditingController();
  bool _mod = false, _loaded = false, _busy = false;
  String? _msg;
  bool _isErr = false;

  @override
  void dispose() {
    _ann.dispose();
    _mnt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _busy = true; _msg = null; });
    try {
      final repo = ref.read(adminContentRepoProvider);
      await repo.saveSetting('announcement', _ann.text.trim());
      await repo.saveSetting('maintenance_notice', _mnt.text.trim());
      await repo.saveSetting('require_moderation', _mod ? 'true' : 'false');
      ref.invalidate(siteSettingsProvider);
      if (mounted) { _msg = context.tr('saved_ok'); _isErr = false; }
    } catch (e) {
      if (mounted) { _msg = errText(context, e); _isErr = true; }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('a_settings'))),
      body: AsyncValueView<Map<String, String>>(
        value: async,
        onRetry: () => ref.invalidate(adminSettingsProvider),
        data: (s) {
          if (!_loaded) { _ann.text = s['announcement'] ?? ''; _mnt.text = s['maintenance_notice'] ?? ''; _mod = s['require_moderation'] == 'true'; _loaded = true; }
          return ListView(padding: const EdgeInsets.all(16), children: [
            AppTextField(controller: _ann, label: context.tr('announcement'), maxLines: 2),
            const SizedBox(height: 14),
            AppTextField(controller: _mnt, label: context.tr('maintenance'), maxLines: 2),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(context.tr('require_moderation')), value: _mod, onChanged: (v) => setState(() => _mod = v)),
            if (_msg != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_msg!, style: TextStyle(color: _isErr ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary))),
            AppButton(label: context.tr('save'), onPressed: _save, loading: _busy),
          ]);
        },
      ),
    );
  }
}
