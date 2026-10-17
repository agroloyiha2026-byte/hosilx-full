import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/widgets/widgets.dart';
import '../../models/stage5_models.dart';
import '../market/product_card.dart';
import '../stage5_providers.dart';

class WarehousesScreen extends ConsumerWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(context.tr('warehouses'))),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => ref.read(warehouseQueryProvider.notifier).state = v,
              decoration: InputDecoration(hintText: context.tr('wh_search'), prefixIcon: const Icon(Icons.search), filled: true,
                  fillColor: Theme.of(context).colorScheme.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Warehouse>>(
              value: ref.watch(warehousesProvider),
              onRetry: () => ref.invalidate(warehousesProvider),
              isEmpty: (l) => l.isEmpty,
              data: (l) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(warehousesProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16), itemCount: l.length, separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _WarehouseCard(l[i]),
                ),
              ),
            ),
          ),
        ]),
      );
}

class _WarehouseCard extends StatelessWidget {
  final Warehouse w;
  const _WarehouseCard(this.w);

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final ratio = w.capacityTons <= 0 ? 0.0 : (w.freeTons / w.capacityTons).clamp(0.0, 1.0);
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/warehouse/${w.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(aspectRatio: 16 / 7, child: ProductImage(w.imageUrl)),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(w.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            Text('📍 ${w.region} · ${context.tr('st_${w.storageType}')}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: ratio, minHeight: 8, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 6),
            Text('${context.tr('free_space')}: ${fmtNum(w.freeTons)} / ${fmtNum(w.capacityTons)} ${context.tr('tons')}'),
            const SizedBox(height: 4),
            Text(w.pricePerTonMonth == null ? context.tr('price_na') : '${fmtNum(w.pricePerTonMonth!)} ${w.currency} ${context.tr('price_month')}',
                style: TextStyle(color: s.primary, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }
}
