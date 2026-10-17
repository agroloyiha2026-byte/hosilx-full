import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../market/product_card.dart';
import 'admin_providers.dart';
import 'admin_repository.dart';

class AdminModerationScreen extends ConsumerWidget {
  const AdminModerationScreen({super.key});

  Future<void> _decide(BuildContext context, WidgetRef ref, PendingProduct p, String decision) async {
    String? note;
    if (decision == 'rejected') {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('reject')),
          content: TextField(controller: c, decoration: InputDecoration(labelText: ctx.tr('reject_note')), maxLines: 2),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('reject')))],
        ),
      );
      if (ok != true) return;
      note = c.text;
    }
    try {
      await ref.read(adminRepoProvider).moderate(p.id, decision, note);
      ref.invalidate(pendingProductsProvider);
      ref.invalidate(adminStatsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(context.tr('a_moderation'))),
        body: AsyncValueView<List<PendingProduct>>(
          value: ref.watch(pendingProductsProvider),
          onRetry: () => ref.invalidate(pendingProductsProvider),
          isEmpty: (l) => l.isEmpty,
          data: (l) => ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: l.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final p = l[i];
              return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  SizedBox(width: 64, height: 64, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: ProductImage(p.imageUrl))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${fmtNum(p.price)} ${p.currency}/${p.unit}'),
                    Text('📍 ${p.region}', style: Theme.of(context).textTheme.bodySmall),
                  ])),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: AppButton(label: context.tr('approve'), onPressed: () => _decide(context, ref, p, 'approved'))),
                  const SizedBox(width: 8),
                  Expanded(child: AppButton(label: context.tr('reject'), outlined: true, onPressed: () => _decide(context, ref, p, 'rejected'))),
                ]),
              ]));
            },
          ),
        ),
      );
}
