import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/widgets.dart';
import '../settings/settings_controller.dart';
import 'auth_widgets.dart';
import 'session_controller.dart';

/// Birinchi kirishdan keyingi majburiy bosqich (router shu ekranga yo'naltiradi).
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});
  @override
  ConsumerState<ProfileSetupScreen> createState() => _S();
}

class _S extends ConsumerState<ProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: ref.read(sessionProvider).profile?.fullName ?? '');
  final _region = TextEditingController();
  late String _role = (ref.read(sessionProvider).profile?.role == 'buyer' || ref.read(sessionProvider).profile?.role == 'warehouse_owner')
      ? ref.read(sessionProvider).profile!.role : 'farmer';
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _name.dispose();
    _region.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final p = ref.read(sessionProvider).profile;
    if (p == null || !_form.currentState!.validate()) return;
    setState(() { _busy = true; _err = null; });
    try {
      await ref.read(authRepositoryProvider).completeOnboarding(
          current: p, role: _role, fullName: _name.text, region: _region.text,
          language: ref.read(settingsProvider).locale.languageCode);
      await ref.read(sessionProvider.notifier).refreshProfile(); // router '/' ga o'tkazadi
    } catch (e) {
      if (mounted) _err = errText(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(sessionProvider).profile?.isAdmin ?? false;
    return AuthScaffold(title: context.tr('setup_title'), children: [
      Form(
        key: _form,
        child: Column(children: [
          AppTextField(controller: _name, label: context.tr('full_name'), validator: tv(context, Validators.required)),
          const SizedBox(height: 14),
          AppTextField(controller: _region, label: context.tr('region')),
          if (!isAdmin) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: InputDecoration(labelText: context.tr('role'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              items: [for (final r in const ['farmer', 'buyer', 'warehouse_owner']) DropdownMenuItem(value: r, child: Text(context.tr('role_$r')))],
              onChanged: (v) => setState(() => _role = v ?? 'farmer'),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 16),
      ErrorText(_err),
      AppButton(label: context.tr('continue'), onPressed: _submit, loading: _busy),
    ]);
  }
}
