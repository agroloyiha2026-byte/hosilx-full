import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../../models/market_models.dart';
import 'market_providers.dart';
import 'product_card.dart';

class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});
  @override
  ConsumerState<MarketScreen> createState() => _S();
}

class _S extends ConsumerState<MarketScreen> {
  final _scroll = ScrollController();
  late final _search = TextEditingController(text: ref.read(filtersProvider).query);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(productsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _openFilters() {
    final lang = Localizations.localeOf(context).languageCode;
    var f = ref.read(filtersProvider);
    final region = TextEditingController(text: f.region);
    final min = TextEditingController(text: f.minPrice?.toString() ?? '');
    final max = TextEditingController(text: f.maxPrice?.toString() ?? '');
    final cats = ref.read(categoriesProvider).valueOrNull ?? const <Category>[];
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(ctx.tr('filters'), style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: Text(ctx.tr('all')), selected: f.category == null, onSelected: (_) => set(() => f = f.copyWith(category: null))),
            for (final c in cats) ChoiceChip(label: Text(c.name(lang)), selected: f.category == c.slug, onSelected: (_) => set(() => f = f.copyWith(category: c.slug))),
          ]),
          const SizedBox(height: 12),
          AppTextField(controller: region, label: ctx.tr('region')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: AppTextField(controller: min, label: ctx.tr('price_from'), keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: AppTextField(controller: max, label: ctx.tr('price_to'), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 12),
          Text(ctx.tr('currency')),
          SegmentedButton<String>(segments: const [ButtonSegment(value: 'UZS', label: Text('UZS')), ButtonSegment(value: 'USD', label: Text('USD'))],
              selected: {f.currency}, onSelectionChanged: (v) => set(() => f = f.copyWith(currency: v.first))),
          const SizedBox(height: 12),
          Text(ctx.tr('sort')),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'new', label: Text(ctx.tr('sort_new'))),
              ButtonSegment(value: 'price_asc', label: Text(ctx.tr('sort_price_asc'))),
              ButtonSegment(value: 'price_desc', label: Text(ctx.tr('sort_price_desc'))),
            ],
            selected: {f.sort}, onSelectionChanged: (v) => set(() => f = f.copyWith(sort: v.first)),
          ),
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(ctx.tr('price_hint'), style: Theme.of(ctx).textTheme.bodySmall)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: AppButton(label: ctx.tr('reset'), outlined: true, onPressed: () {
              ref.read(filtersProvider.notifier).state = ProductFilters(query: ref.read(filtersProvider).query);
              Navigator.pop(ctx);
            })),
            const SizedBox(width: 8),
            Expanded(child: AppButton(label: ctx.tr('apply'), onPressed: () {
              ref.read(filtersProvider.notifier).state = f.copyWith(
                  region: region.text.trim(), minPrice: double.tryParse(min.text.replaceAll(' ', '')), maxPrice: double.tryParse(max.text.replaceAll(' ', '')));
              Navigator.pop(ctx);
            })),
          ]),
        ])),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(productsProvider);
    final f = ref.watch(filtersProvider);
    final scheme = Theme.of(context).colorScheme;
    Widget body;
    if (st.loading && st.items.isEmpty) {
      body = const LoadingView();
    } else if (st.error != null && st.items.isEmpty) {
      body = ErrorView(error: st.error!, onRetry: () => ref.read(productsProvider.notifier).refresh());
    } else if (st.items.isEmpty) {
      body = EmptyView(message: context.tr('no_products'));
    } else {
      body = GridView.builder(
        controller: _scroll, padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
        itemCount: st.items.length + (st.loading ? 1 : 0),
        itemBuilder: (_, i) => i >= st.items.length ? const Center(child: CircularProgressIndicator()) : ProductCard(st.items[i]),
      );
    }
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _search, textInputAction: TextInputAction.search,
              onSubmitted: (v) => ref.read(filtersProvider.notifier).state = f.copyWith(query: v),
              decoration: InputDecoration(hintText: context.tr('search_hint'), prefixIcon: const Icon(Icons.search), filled: true, fillColor: scheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            )),
            const SizedBox(width: 8),
            Badge(isLabelVisible: f.hasActive, child: IconButton.filledTonal(onPressed: _openFilters, icon: const Icon(Icons.tune))),
          ]),
        ),
        Expanded(child: RefreshIndicator(onRefresh: () => ref.read(productsProvider.notifier).refresh(), child: body)),
      ]),
    );
  }
}
