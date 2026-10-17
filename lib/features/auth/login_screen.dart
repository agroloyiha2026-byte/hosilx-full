import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/widgets.dart';
import 'auth_widgets.dart';
import 'session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _S();
}

class _S extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _err;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _err = null; });
    try {
      await ref.read(authRepositoryProvider).signIn(_email.text, _pass.text);
      // Navigatsiyani router o'zi bajaradi (sessiya o'zgarganda).
    } catch (e) {
      if (mounted) _err = errText(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(title: context.tr('login'), children: [
        Form(
          key: _form,
          child: Column(children: [
            AppTextField(controller: _email, label: context.tr('email'), keyboardType: TextInputType.emailAddress,
                validator: tv(context, Validators.email), textInputAction: TextInputAction.next),
            const SizedBox(height: 14),
            AppTextField(controller: _pass, label: context.tr('password'), obscure: true, validator: tv(context, Validators.required)),
          ]),
        ),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.push('/reset'), child: Text(context.tr('forgot_password')))),
        ErrorText(_err),
        AppButton(label: context.tr('login'), onPressed: _submit, loading: _busy),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.go('/register'), child: Text(context.tr('no_account'))),
      ]);
}
