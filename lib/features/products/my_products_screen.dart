import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../market/market_providers.dart';
import '../market/product_card.dart';
import 'product_providers.dart';
import 'product_repository.dart';

class MyProductsScreen extends ConsumerWidget {
  const MyProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(context.tr('my_products'))),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await context.push('/my-products/new');
            ref.invalidate(myProductsProvider);
            ref.invalidate(recentProductsProvider);
          },
          icon: const Icon(Icons.add), label: Text(context.tr('add_product')),
        ),
        body: AsyncValueView<List<MyProduct>>(
          value: ref.watch(myProductsProvider),
          onRetry: () => ref.invalidate(myProductsProvider),
          isEmpty: (l) => l.isEmpty,
          data: (l) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96), itemCount: l.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final m = l[i];
              final p = m.product;
              return AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    SizedBox(width: 64, height: 64, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: ProductImage(p.imageUrl))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('${fmtNum(p.price)} ${p.currency}/${p.unit} · ${fmtNum(p.quantity)} ${p.unit}'),
                      Wrap(spacing: 6, children: [
                        Chip(label: Text(context.tr('status_${m.status}')), visualDensity: VisualDensity.compact),
                        if (m.moderation != 'approved') Chip(label: Text(context.tr('mod_${m.moderation}')), visualDensity: VisualDensity.compact),
                      ]),
                    ])),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: AppButton(label: context.tr('edit'), outlined: true, onPressed: () async {
                      await context.push('/my-products/edit/${p.id}');
                      ref.invalidate(myProductsProvider);
                    })),
                    const SizedBox(width: 8),
                    Expanded(child: AppButton(label: context.tr(m.status == 'active' ? 'hide' : 'activate'), outlined: true, onPressed: () async {
                      try {
                        await ref.read(productRepoProvider).setStatus(p.id, m.status == 'active' ? 'hidden' : 'active');
                        ref.invalidate(myProductsProvider);
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
                      }
                    })),
                  ]),
                ]),
              );
            },
          ),
        ),
      );
}
