import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../../models/market_models.dart';
import '../market/market_providers.dart';
import '../market/product_card.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(context.tr('nav_favorites'))),
        body: AsyncValueView<List<Product>>(
          value: ref.watch(favoriteProductsProvider),
          onRetry: () => ref.invalidate(favoriteProductsProvider),
          isEmpty: (l) => l.isEmpty,
          data: (l) => GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
            itemCount: l.length,
            itemBuilder: (_, i) => ProductCard(l[i]),
          ),
        ),
      );
}
