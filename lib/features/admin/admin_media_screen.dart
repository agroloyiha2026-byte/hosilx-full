import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../market/product_card.dart';
import '../products/product_repository.dart';
import 'admin_content_providers.dart';
import 'admin_widgets.dart';

/// Bannerlar (kind: 'banners') va reklamalar (kind: 'ads') boshqaruvi: rasm yuklash, tahrirlash, faol/nofaol, o'chirish.
class AdminMediaScreen extends ConsumerWidget {
  final String kind;
  const AdminMediaScreen({super.key, required this.kind});
  bool get _banners => kind == 'banners';

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() f) async {
    try {
      await f();
      ref.invalidate(adminRowsProvider(kind));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Map<String, dynamic>? row) async {
    final uid = ref.read(sessionProvider).user?.id;
    if (uid == null) return;
    XFile? picked;
    if (row == null) {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      if (picked == null || !context.mounted) return;
    }
    final fields = _banners
        ? [
            FieldSpec('title', context.tr('f_title'), initial: row?['title'] ?? '', required: true),
            FieldSpec('subtitle', context.tr('f_subtitle'), initial: row?['subtitle'] ?? ''),
            FieldSpec('link_type', context.tr('link_type'), initial: row?['link_type'] ?? 'none', options: const ['none', 'product', 'category', 'url']),
            FieldSpec('link_value', context.tr('link_value'), initial: row?['link_value'] ?? ''),
            FieldSpec('sort_order', context.tr('sort_order'), initial: '${row?['sort_order'] ?? 0}', validate: intKey, keyboard: TextInputType.number),
            FieldSpec('starts_at', context.tr('starts_at'), initial: (row?['starts_at'] as String?)?.substring(0, 10) ?? '', validate: dateKey),
            FieldSpec('ends_at', context.tr('ends_at'), initial: (row?['ends_at'] as String?)?.substring(0, 10) ?? '', validate: dateKey),
          ]
        : [
            FieldSpec('title', context.tr('f_title'), initial: row?['title'] ?? '', required: true),
            FieldSpec('link_url', context.tr('link_url'), initial: row?['link_url'] ?? '', validate: httpsKey),
            FieldSpec('placement', context.tr('placement'), initial: row?['placement'] ?? 'home_top', options: const ['home_top', 'home_middle', 'market_top']),
            FieldSpec('ends_at', context.tr('ends_at'), initial: (row?['ends_at'] as String?)?.substring(0, 10) ?? '', validate: dateKey),
          ];
    final r = await showFormDialog(context, context.tr(row == null ? 'add' : 'edit'), fields);
    if (r == null || !context.mounted) return;
    final repo = ref.read(adminContentRepoProvider);
    final data = <String, dynamic>{
      'title': r['title'],
      if (_banners) ...{
        'subtitle': r['subtitle']!.isEmpty ? null : r['subtitle'], 'link_type': r['link_type'], 'link_value': r['link_value']!.isEmpty ? null : r['link_value'],
        'sort_order': int.tryParse(r['sort_order'] ?? '') ?? 0, 'starts_at': isoOrNull(r['starts_at'] ?? ''), 'ends_at': isoOrNull(r['ends_at'] ?? '', endOfDay: true),
      } else ...{
        'link_url': r['link_url']!.isEmpty ? null : r['link_url'], 'placement': r['placement'], 'ends_at': isoOrNull(r['ends_at'] ?? '', endOfDay: true),
      },
    };
    await _run(context, ref, () async {
      if (row == null) {
        final url = await ProductRepository().uploadImage(picked!, uid);
        await repo.insertRow(kind, {...data, 'image_url': url});
      } else {
        await repo.updateRow(kind, 'id', row['id'] as String, data);
      }
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(adminContentRepoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(_banners ? 'a_banners' : 'a_ads'))),
      floatingActionButton: FloatingActionButton(onPressed: () => _edit(context, ref, null), child: const Icon(Icons.add_photo_alternate_outlined)),
      body: Column(children: [
        if (!_banners) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(context.tr('ads_web_note'), style: Theme.of(context).textTheme.bodySmall)),
        Expanded(
          child: AsyncValueView<List<Map<String, dynamic>>>(
            value: ref.watch(adminRowsProvider(kind)),
            onRetry: () => ref.invalidate(adminRowsProvider(kind)),
            isEmpty: (l) => l.isEmpty,
            data: (l) => ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 88), itemCount: l.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final b = l[i];
                return AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    AspectRatio(aspectRatio: 16 / 6, child: ProductImage(b['image_url'] as String?)),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        Expanded(child: Text('${b['title']}${_banners ? '' : ' · ${b['placement']}'}', style: const TextStyle(fontWeight: FontWeight.w700))),
                        Switch(value: b['active'] as bool, onChanged: (v) => _run(context, ref, () => repo.updateRow(kind, 'id', b['id'] as String, {'active': v}))),
                        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(context, ref, b)),
                        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
                          if (await confirmDelete(context) && context.mounted) {
                            await _run(context, ref, () => repo.deleteRow(kind, b['id'] as String, imageUrl: b['image_url'] as String?));
                          }
                        }),
                      ]),
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
}
