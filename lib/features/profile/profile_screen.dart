import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../settings/settings_controller.dart';

/// Stage 3 da asosiy ekran. Stage 4 da bosh sahifa va pastki navigatsiya qo'shilganda
/// bu ekran "Profil" yorlig'iga ko'chadi.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _S();
}

class _S extends ConsumerState<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: ref.read(sessionProvider).profile?.fullName ?? '');
  late final _region = TextEditingController(text: ref.read(sessionProvider).profile?.region ?? '');
  bool _busy = false;
  String? _msg;
  bool _isErr = false;

  @override
  void dispose() {
    _name.dispose();
    _region.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = ref.read(sessionProvider).profile;
    if (p == null || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _msg = null; });
    try {
      await ref.read(authRepositoryProvider).updateProfile(p.id, fullName: _name.text, region: _region.text,
          language: ref.read(settingsProvider).locale.languageCode);
      await ref.read(sessionProvider.notifier).refreshProfile();
      if (mounted) { _msg = context.tr('saved_ok'); _isErr = false; }
    } catch (e) {
      if (mounted) { _msg = errText(context, e); _isErr = true; }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final p = s.profile;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile')), actions: [
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(child: Row(children: [
          CircleAvatar(radius: 28, backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary,
              child: Text(((p?.fullName.isNotEmpty ?? false) ? p!.fullName[0] : (s.user?.email ?? '?')[0]).toUpperCase(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p?.fullName.isEmpty ?? true ? '—' : p!.fullName, style: Theme.of(context).textTheme.titleMedium),
            Text(s.user?.email ?? '', style: Theme.of(context).textTheme.bodySmall),
            if (p != null) Text(context.tr('role_${p.role}'), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700)),
          ])),
        ])),
        const SizedBox(height: 12),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            if (p != null && (p.role == 'farmer' || p.isAdmin))
              ListTile(leading: const Icon(Icons.inventory_2_outlined), title: Text(context.tr('my_products')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/my-products')),
            if (p?.isAdmin == true)
              ListTile(leading: const Icon(Icons.admin_panel_settings_outlined), title: Text(context.tr('admin')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/admin')),
            ListTile(leading: const Icon(Icons.mail_outline), title: Text(context.tr('inquiries')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/inquiries')),
            ListTile(leading: const Icon(Icons.notifications_none), title: Text(context.tr('notifications')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/notifications')),
            ListTile(leading: const Icon(Icons.smart_toy_outlined), title: Text(context.tr('assistant')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/assistant')),
            ListTile(leading: const Icon(Icons.warehouse_outlined), title: Text(context.tr('warehouses')), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/warehouses')),
          ]),
        ),
        const SizedBox(height: 20),
        Text(context.tr('edit_profile'), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Form(
          key: _form,
          child: Column(children: [
            AppTextField(controller: _name, label: context.tr('full_name'), validator: tv(context, Validators.required)),
            const SizedBox(height: 14),
            AppTextField(controller: _region, label: context.tr('region')),
          ]),
        ),
        const SizedBox(height: 16),
        if (_msg != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_msg!, style: TextStyle(color: _isErr ? scheme.error : scheme.primary))),
        AppButton(label: context.tr('save'), onPressed: p == null ? null : _save, loading: _busy),
        const SizedBox(height: 12),
        AppButton(label: context.tr('sign_out'), outlined: true, icon: Icons.logout, onPressed: () => ref.read(authRepositoryProvider).signOut()),
      ]),
    );
  }
}
