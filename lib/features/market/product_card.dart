import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/format.dart';
import '../../core/widgets/widgets.dart';
import '../../models/market_models.dart';

class ProductImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  const ProductImage(this.url, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.primaryContainer;
    final placeholder = Container(color: bg, alignment: Alignment.center, child: const Text('🌿', style: TextStyle(fontSize: 40)));
    if (url == null) return placeholder;
    return Image.network(url!, fit: fit, errorBuilder: (_, __, ___) => placeholder,
        loadingBuilder: (c, child, p) => p == null ? child : Container(color: bg));
  }
}

class ProductCard extends StatelessWidget {
  final Product p;
  const ProductCard(this.p, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/product/${p.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(aspectRatio: 4 / 3, child: ProductImage(p.imageUrl)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${fmtNum(p.price)} ${p.currency}/${p.unit}', style: TextStyle(color: s.primary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('📍 ${p.region}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ]),
    );
  }
}
