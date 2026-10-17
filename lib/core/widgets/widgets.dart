import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../errors/app_error.dart';

/// Yumshoq burchakli karta (mavzuga qarab rang oladi).
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Material(
      color: s.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: s.onSurface.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Asosiy tugma: yuklanayotganda bosilmaydi va aylana ko'rsatadi.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool outlined;
  final IconData? icon;
  const AppButton({super.key, required this.label, this.onPressed, this.loading = false, this.outlined = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ]);
    final cb = loading ? null : onPressed;
    return SizedBox(
      width: double.infinity,
      child: outlined ? OutlinedButton(onPressed: cb, child: child) : FilledButton(onPressed: cb, child: child),
    );
  }
}

/// Forma maydoni: label, validator va parol ko'rsatish tugmasi bilan.
class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextInputAction? textInputAction;
  const AppTextField({super.key, required this.controller, required this.label, this.validator,
    this.obscure = false, this.keyboardType, this.maxLines = 1, this.textInputAction});

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: s.onSurface.withOpacity(0.15)));
    return TextFormField(
      controller: widget.controller,
      validator: widget.validator,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      textInputAction: widget.textInputAction,
      decoration: InputDecoration(
        labelText: widget.label,
        filled: true,
        fillColor: s.surface,
        border: border,
        enabledBorder: border,
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: s.primary, width: 2)),
        suffixIcon: widget.obscure
            ? IconButton(icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hidden = !_hidden))
            : null,
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(context.tr('loading')),
        ]),
      );
}

class EmptyView extends StatelessWidget {
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyView({super.key, this.message, this.icon = Icons.eco_outlined, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(message ?? context.tr('empty_default'), textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              SizedBox(width: 220, child: AppButton(label: actionLabel!, onPressed: onAction)),
            ],
          ]),
        ),
      );
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_outlined, size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(context.tr(AppError.from(error).key), textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              SizedBox(width: 220, child: AppButton(label: context.tr('retry'), onPressed: onRetry, outlined: true)),
            ],
          ]),
        ),
      );
}

/// Riverpod AsyncValue uchun tayyor yuklanish/xato/bo'sh holatlari.
class AsyncValueView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  const AsyncValueView({super.key, required this.value, required this.data, this.onRetry, this.isEmpty});

  @override
  Widget build(BuildContext context) => value.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: onRetry),
        data: (d) => (isEmpty?.call(d) ?? false) ? const EmptyView() : data(d),
      );
}
