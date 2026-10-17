import 'package:flutter/material.dart';
import '../../app/localization/l10n.dart';
import '../../core/errors/app_error.dart';

/// Validator (kalit qaytaradi) ni tarjima qiluvchi validatorga aylantiradi.
FormFieldValidator<String> tv(BuildContext c, String? Function(String?) f) => (v) {
      final k = f(v);
      return k == null ? null : c.tr(k);
    };

String errText(BuildContext c, Object e) => c.tr(AppError.from(e).key);

class AuthScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const AuthScaffold({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('🌾 Hosil X', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 24),
                  ...children,
                ]),
              ),
            ),
          ),
        ),
      );
}

class ErrorText extends StatelessWidget {
  final String? text;
  const ErrorText(this.text, {super.key});
  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(text!, style: TextStyle(color: Theme.of(context).colorScheme.error)));
}
