import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../../models/market_models.dart';
import '../auth/session_controller.dart';
import '../market/market_providers.dart';
import '../market/product_card.dart';
import 'site_settings_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  void _banner(BuildContext c, WidgetRef ref, BannerItem b) {
    if (b.linkType == 'product' && b.linkValue != null) {
      c.push('/product/${b.linkValue}');
    } else if (b.linkType == 'category' && b.linkValue != null) {
      ref.read(filtersProvider.notifier).state = ProductFilters(category: b.linkValue);
      c.go('/market');
    } // 'url' turi uchun url_launcher paketi kerak: keyingi bosqichda qo'shiladi
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = Localizations.localeOf(context).languageCode;
    final name = ref.watch(sessionProvider).profile?.fullName ?? '';
    final search = TextEditingController();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bannersProvider);
          ref.invalidate(categoriesProvider);
          ref.invalidate(recentProductsProvider);
        },
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text('🌾 Hosil X${name.isEmpty ? '' : ' · $name'}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Builder(builder: (_) {
            final s = ref.watch(siteSettingsProvider).valueOrNull ?? const <String, String>{};
            final notes = [s['maintenance_notice'], s['announcement']].where((e) => (e ?? '').isNotEmpty).toList();
            if (notes.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: AppCard(child: Row(children: [const Icon(Icons.campaign_outlined), const SizedBox(width: 10), Expanded(child: Text(notes.join('\n')))])),
            );
          }),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) {
              ref.read(filtersProvider.notifier).state = ProductFilters(query: v);
              context.go('/market');
            },
            decoration: InputDecoration(
              hintText: context.tr('search_hint'), prefixIcon: const Icon(Icons.search), filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, children: [
            ActionChip(avatar: const Icon(Icons.warehouse_outlined, size: 18), label: Text(context.tr('warehouses')), onPressed: () => context.push('/warehouses')),
            ActionChip(avatar: const Icon(Icons.smart_toy_outlined, size: 18), label: Text(context.tr('assistant')), onPressed: () => context.push('/assistant')),
            ActionChip(avatar: const Icon(Icons.notifications_none, size: 18), label: Text(context.tr('notifications')), onPressed: () => context.push('/notifications')),
          ]),
          const SizedBox(height: 16),
          ref.watch(bannersProvider).when(
                loading: () => const SizedBox(height: 140, child: LoadingView()),
                error: (_, __) => const SizedBox.shrink(), // bannerlar bo'lmasa bosh sahifa baribir ishlaydi
                data: (list) => list.isEmpty ? const SizedBox.shrink() : _Banners(list, (b) => _banner(context, ref, b)),
              ),
          const SizedBox(height: 16),
          Text(context.tr('categories'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ref.watch(categoriesProvider).when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (cats) => ListView(scrollDirection: Axis.horizontal, children: [
                    for (final c in cats)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text('${c.icon ?? ''} ${c.name(lang)}'.trim()),
                          onPressed: () {
                            ref.read(filtersProvider.notifier).state = ProductFilters(category: c.slug);
                            context.go('/market');
                          },
                        ),
                      ),
                  ]),
                ),
          ),
          const SizedBox(height: 20),
          Text(context.tr('recent'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 230,
            child: AsyncValueView<List<Product>>(
              value: ref.watch(recentProductsProvider),
              onRetry: () => ref.invalidate(recentProductsProvider),
              isEmpty: (l) => l.isEmpty,
              data: (l) => ListView(scrollDirection: Axis.horizontal, children: [
                for (final p in l) SizedBox(width: 170, child: Padding(padding: const EdgeInsets.only(right: 12), child: ProductCard(p))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Banners extends StatefulWidget {
  final List<BannerItem> list;
  final void Function(BannerItem) onTap;
  const _Banners(this.list, this.onTap);
  @override
  State<_Banners> createState() => _BannersState();
}

class _BannersState extends State<_Banners> {
  int _i = 0;
  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          height: 150,
          child: PageView(
            onPageChanged: (v) => setState(() => _i = v),
            children: [
              for (final b in widget.list)
                GestureDetector(
                  onTap: () => widget.onTap(b),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(fit: StackFit.expand, children: [
                      ProductImage(b.imageUrl),
                      Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center, colors: [Color(0xCC000000), Colors.transparent]))),
                      Positioned(left: 14, right: 14, bottom: 12, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(b.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                        if (b.subtitle != null) Text(b.subtitle!, style: const TextStyle(color: Colors.white70)),
                      ])),
                    ]),
                  ),
                ),
            ],
          ),
        ),
        if (widget.list.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var k = 0; k < widget.list.length; k++)
                Container(margin: const EdgeInsets.all(3), width: k == _i ? 18 : 7, height: 7,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: Theme.of(context).colorScheme.primary.withOpacity(k == _i ? 1 : 0.25))),
            ]),
          ),
      ]);
}
