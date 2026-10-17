import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/widgets.dart';
import 'auth_widgets.dart';
import 'session_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _S();
}

class _S extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  String _role = 'farmer';
  bool _busy = false;
  String? _err, _info;

  @override
  void dispose() {
    for (final c in [_name, _email, _pass, _pass2]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _err = null; _info = null; });
    try {
      final needsConfirm = await ref.read(authRepositoryProvider)
          .signUp(email: _email.text, password: _pass.text, fullName: _name.text, role: _role);
      if (mounted && needsConfirm) _info = context.tr('check_email');
    } catch (e) {
      if (mounted) _err = errText(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(title: context.tr('register'), children: [
        Form(
          key: _form,
          child: Column(children: [
            AppTextField(controller: _name, label: context.tr('full_name'), validator: tv(context, Validators.required), textInputAction: TextInputAction.next),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _role,
              decoration: InputDecoration(labelText: context.tr('role'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
              items: [for (final r in const ['farmer', 'buyer', 'warehouse_owner']) DropdownMenuItem(value: r, child: Text(context.tr('role_$r')))],
              onChanged: (v) => setState(() => _role = v ?? 'farmer'),
            ),
            const SizedBox(height: 14),
            AppTextField(controller: _email, label: context.tr('email'), keyboardType: TextInputType.emailAddress,
                validator: tv(context, Validators.email), textInputAction: TextInputAction.next),
            const SizedBox(height: 14),
            AppTextField(controller: _pass, label: context.tr('password'), obscure: true, validator: tv(context, Validators.password)),
            const SizedBox(height: 14),
            AppTextField(controller: _pass2, label: context.tr('confirm_password'), obscure: true,
                validator: (v) => v == _pass.text ? null : context.tr('v_confirm')),
          ]),
        ),
        const SizedBox(height: 16),
        ErrorText(_err),
        if (_info != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_info!, style: TextStyle(color: Theme.of(context).colorScheme.primary))),
        AppButton(label: context.tr('register'), onPressed: _submit, loading: _busy),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.go('/login'), child: Text(context.tr('have_account'))),
      ]);
}
