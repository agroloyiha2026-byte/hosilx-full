import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import 'market_providers.dart';
import 'product_card.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String id;
  const ProductDetailScreen({super.key, required this.id});

  void _inquiry(BuildContext context, WidgetRef ref, String productId) {
    final uid = ref.read(sessionProvider).user?.id;
    if (uid == null) return;
    final msg = TextEditingController();
    final offer = TextEditingController();
    var busy = false;
    String? err;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ctx.tr('send_inquiry'), style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          AppTextField(controller: offer, label: ctx.tr('offer_price'), keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          AppTextField(controller: msg, label: ctx.tr('message'), maxLines: 3),
          const SizedBox(height: 12),
          ErrorText(err),
          AppButton(label: ctx.tr('send'), loading: busy, onPressed: () async {
            set(() { busy = true; err = null; });
            try {
              await ref.read(marketRepositoryProvider).sendInquiry(
                  productId: productId, buyerId: uid, message: msg.text, offer: double.tryParse(offer.text.replaceAll(' ', '')));
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('inquiry_sent'))));
            } catch (e) {
              if (ctx.mounted) set(() { busy = false; err = errText(ctx, e); });
            }
          }),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(productDetailProvider(id));
    final uid = ref.watch(sessionProvider).user?.id;
    final lang = Localizations.localeOf(context).languageCode;
    final favs = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(
          icon: Icon(favs.contains(id) ? Icons.favorite : Icons.favorite_border),
          onPressed: () async {
            try { await ref.read(favoritesProvider.notifier).toggle(id); }
            catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e)))); }
          },
        ),
      ]),
      body: AsyncValueView(
        value: async,
        onRetry: () => ref.invalidate(productDetailProvider(id)),
        data: (d) {
          if (d == null) return EmptyView(message: context.tr('product_missing'), icon: Icons.search_off);
          final p = d.product;
          final cat = ref.watch(categoriesProvider).valueOrNull?.where((c) => c.slug == p.category).firstOrNull;
          final scheme = Theme.of(context).colorScheme;
          return ListView(padding: const EdgeInsets.all(16), children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(height: 260, child: p.images.isEmpty
                  ? const ProductImage(null)
                  : PageView(children: [for (final u in p.images) ProductImage(u)])),
            ),
            const SizedBox(height: 16),
            Text(p.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${fmtNum(p.price)} ${p.currency}/${p.unit}', style: TextStyle(color: scheme.primary, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Chip(label: Text('${context.tr('available')}: ${fmtNum(p.quantity)} ${p.unit}')),
              Chip(label: Text('📍 ${p.region}')),
              if (cat != null) Chip(label: Text('${cat.icon ?? ''} ${cat.name(lang)}'.trim())),
            ]),
            if ((p.description ?? '').isNotEmpty) ...[const SizedBox(height: 12), Text(p.description!)],
            const SizedBox(height: 16),
            AppCard(child: Row(children: [
              CircleAvatar(backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary,
                  child: Text(((d.sellerName ?? '').isEmpty ? '?' : d.sellerName![0]).toUpperCase())),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('seller'), style: Theme.of(context).textTheme.bodySmall),
                Text((d.sellerName ?? '').isEmpty ? '—' : d.sellerName!, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (d.sellerRegion != null) Text('📍 ${d.sellerRegion}', style: Theme.of(context).textTheme.bodySmall),
              ])),
            ])),
            const SizedBox(height: 16),
            if (uid == p.sellerId) Text(context.tr('own_product'), textAlign: TextAlign.center)
            else AppButton(label: context.tr('send_inquiry'), icon: Icons.mail_outline, onPressed: () => _inquiry(context, ref, p.id)),
          ]);
        },
      ),
    );
  }
}
