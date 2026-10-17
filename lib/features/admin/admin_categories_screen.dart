import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import 'admin_content_providers.dart';
import 'admin_widgets.dart';

class AdminCategoriesScreen extends ConsumerWidget {
  const AdminCategoriesScreen({super.key});
  static const _t = 'product_categories';

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() f) async {
    try {
      await f();
      ref.invalidate(adminRowsProvider(_t));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Map<String, dynamic>? c) async {
    final repo = ref.read(adminContentRepoProvider);
    final r = await showFormDialog(context, context.tr(c == null ? 'add' : 'edit'), [
      if (c == null) FieldSpec('slug', context.tr('slug'), required: true, validate: slugKey),
      FieldSpec('name_uz', context.tr('name_uz'), initial: c?['name_uz'] ?? '', required: true),
      FieldSpec('name_ru', context.tr('name_ru'), initial: c?['name_ru'] ?? '', required: true),
      FieldSpec('name_en', context.tr('name_en'), initial: c?['name_en'] ?? '', required: true),
      FieldSpec('icon', context.tr('icon'), initial: c?['icon'] ?? ''),
      FieldSpec('sort_order', context.tr('sort_order'), initial: '${c?['sort_order'] ?? 0}', validate: intKey, keyboard: TextInputType.number),
    ]);
    if (r == null || !context.mounted) return;
    final data = {'name_uz': r['name_uz'], 'name_ru': r['name_ru'], 'name_en': r['name_en'], 'icon': r['icon']!.isEmpty ? null : r['icon'],
      'sort_order': int.tryParse(r['sort_order'] ?? '') ?? 0};
    await _run(context, ref, () => c == null ? repo.insertRow(_t, {...data, 'slug': r['slug']}) : repo.updateRow(_t, 'slug', c['slug'] as String, data));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('a_categories'))),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(context, ref, null), child: const Icon(Icons.add)),
      body: AsyncValueView<List<Map<String, dynamic>>>(
        value: ref.watch(adminRowsProvider(_t)),
        onRetry: () => ref.invalidate(adminRowsProvider(_t)),
        isEmpty: (l) => l.isEmpty,
        data: (l) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 88), itemCount: l.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final c = l[i];
            return AppCard(
              child: Row(children: [
                Text('${c['icon'] ?? '•'}', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c['name_$lang'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${c['slug']} · #${c['sort_order']}', style: Theme.of(context).textTheme.bodySmall),
                ])),
                // O'chirish yo'q: mahsulotlarga bog'langan kategoriya faqat faolsizlantiriladi
                Switch(value: c['active'] as bool, onChanged: (v) => _run(context, ref, () => ref.read(adminContentRepoProvider).updateRow(_t, 'slug', c['slug'] as String, {'active': v}))),
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, ref, c)),
              ]),
            );
          },
        ),
      ),
    );
  }
}
