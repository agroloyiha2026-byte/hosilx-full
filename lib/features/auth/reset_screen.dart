import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/widgets.dart';
import 'auth_widgets.dart';
import 'session_controller.dart';

class ResetScreen extends ConsumerStatefulWidget {
  const ResetScreen({super.key});
  @override
  ConsumerState<ResetScreen> createState() => _S();
}

class _S extends ConsumerState<ResetScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _busy = false;
  String? _err, _info;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _err = null; _info = null; });
    try {
      await ref.read(authRepositoryProvider).resetPassword(_email.text);
      if (mounted) _info = context.tr('reset_sent'); // email mavjudligini oshkor qilmaydi
    } catch (e) {
      if (mounted) _err = errText(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(title: context.tr('forgot_password'), children: [
        Form(key: _form, child: AppTextField(controller: _email, label: context.tr('email'), keyboardType: TextInputType.emailAddress, validator: tv(context, Validators.email))),
        const SizedBox(height: 16),
        ErrorText(_err),
        if (_info != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_info!)),
        AppButton(label: context.tr('send_reset'), onPressed: _submit, loading: _busy),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.go('/login'), child: Text(context.tr('back_login'))),
      ]);
}
