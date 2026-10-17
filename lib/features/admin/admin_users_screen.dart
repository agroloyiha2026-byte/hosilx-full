import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import 'admin_providers.dart';
import 'admin_repository.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});
  static const _roles = ['farmer', 'buyer', 'warehouse_owner', 'admin'];

  Future<void> _change(BuildContext context, WidgetRef ref, AdminUser u, String role) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('confirm_role')),
        content: Text('${u.fullName.isEmpty ? u.id.substring(0, 8) : u.fullName}: ${ctx.tr('role_${u.role}')} → ${ctx.tr('role_$role')}'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('confirm')))],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminRepoProvider).setRole(u.id, role); // server: faqat admin, o'zini pasaytirib bo'lmaydi, audit jurnaliga yoziladi
      ref.invalidate(adminUsersProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(context.tr('a_users'))),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => ref.read(adminUserQueryProvider.notifier).state = v,
              decoration: InputDecoration(hintText: context.tr('search_users'), prefixIcon: const Icon(Icons.search), filled: true,
                  fillColor: Theme.of(context).colorScheme.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<AdminUser>>(
              value: ref.watch(adminUsersProvider),
              onRetry: () => ref.invalidate(adminUsersProvider),
              isEmpty: (l) => l.isEmpty,
              data: (l) => ListView.separated(
                padding: const EdgeInsets.all(16), itemCount: l.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final u = l[i];
                  return AppCard(
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u.fullName.isEmpty ? u.id.substring(0, 8) : u.fullName, style: const TextStyle(fontWeight: FontWeight.w800)),
                        if (u.region != null) Text('📍 ${u.region}', style: Theme.of(context).textTheme.bodySmall),
                      ])),
                      DropdownButton<String>(
                        value: u.role, underline: const SizedBox.shrink(),
                        items: [for (final r in _roles) DropdownMenuItem(value: r, child: Text(context.tr('role_$r')))],
                        onChanged: (v) { if (v != null && v != u.role) _change(context, ref, u, v); },
                      ),
                    ]),
                  );
                },
              ),
            ),
          ),
        ]),
      );
}
