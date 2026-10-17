import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/widgets.dart';
import '../../models/stage5_models.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../market/product_card.dart';
import '../stage5_providers.dart';

class WarehouseDetailScreen extends ConsumerWidget {
  final String id;
  const WarehouseDetailScreen({super.key, required this.id});

  void _request(BuildContext context, WidgetRef ref, Warehouse w) {
    final uid = ref.read(sessionProvider).user?.id;
    if (uid == null) return;
    final form = GlobalKey<FormState>();
    final type = TextEditingController();
    final tons = TextEditingController();
    final msg = TextEditingController();
    var busy = false;
    String? err;
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ctx.tr('request_storage'), style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          AppTextField(controller: type, label: ctx.tr('product_type'), validator: tv(ctx, Validators.required)),
          const SizedBox(height: 12),
          AppTextField(controller: tons, label: ctx.tr('tons'), keyboardType: TextInputType.number, validator: tv(ctx, (v) => Validators.tons(v, w.freeTons))),
          const SizedBox(height: 12),
          AppTextField(controller: msg, label: ctx.tr('message'), maxLines: 2),
          const SizedBox(height: 12),
          ErrorText(err),
          AppButton(label: ctx.tr('send'), loading: busy, onPressed: () async {
            if (!form.currentState!.validate()) return;
            set(() { busy = true; err = null; });
            try {
              await ref.read(warehouseRepoProvider).requestStorage(warehouseId: w.id, farmerId: uid, productType: type.text,
                  tons: double.parse(tons.text.replaceAll(' ', '').replaceAll(',', '.')), message: msg.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('storage_sent'))));
            } catch (e) {
              if (ctx.mounted) set(() { busy = false; err = errText(ctx, e); });
            }
          }),
        ])),
      )),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(sessionProvider).user?.id;
    return Scaffold(
      appBar: AppBar(),
      body: AsyncValueView<Warehouse?>(
        value: ref.watch(warehouseProvider(id)),
        onRetry: () => ref.invalidate(warehouseProvider(id)),
        data: (w) {
          if (w == null) return EmptyView(message: context.tr('no_warehouses'), icon: Icons.search_off);
          final s = Theme.of(context).colorScheme;
          final ratio = w.capacityTons <= 0 ? 0.0 : (w.freeTons / w.capacityTons).clamp(0.0, 1.0);
          return ListView(padding: const EdgeInsets.all(16), children: [
            ClipRRect(borderRadius: BorderRadius.circular(18), child: AspectRatio(aspectRatio: 16 / 9, child: ProductImage(w.imageUrl))),
            const SizedBox(height: 16),
            Text(w.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            Text('📍 ${w.region}${w.address == null ? '' : ' · ${w.address}'}'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [Chip(label: Text(context.tr('st_${w.storageType}'))), Chip(label: Text('${context.tr('capacity')}: ${fmtNum(w.capacityTons)} ${context.tr('tons')}'))]),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: ratio, minHeight: 10, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 6),
            Text('${context.tr('free_space')}: ${fmtNum(w.freeTons)} ${context.tr('tons')}'),
            const SizedBox(height: 6),
            Text(w.pricePerTonMonth == null ? context.tr('price_na') : '${fmtNum(w.pricePerTonMonth!)} ${w.currency} ${context.tr('price_month')}',
                style: TextStyle(color: s.primary, fontWeight: FontWeight.w800, fontSize: 18)),
            if (w.accepted.isNotEmpty) ...[
              const SizedBox(height: 16), Text(context.tr('accepted'), style: Theme.of(context).textTheme.titleSmall),
              Wrap(spacing: 8, children: [for (final a in w.accepted) Chip(label: Text(a))]),
            ],
            if ((w.conditions ?? '').isNotEmpty) ...[const SizedBox(height: 12), Text(context.tr('conditions'), style: Theme.of(context).textTheme.titleSmall), Text(w.conditions!)],
            if ((w.contactPhone ?? '').isNotEmpty) ...[const SizedBox(height: 12), SelectableText('${context.tr('contact')}: ${w.contactPhone}')],
            const SizedBox(height: 20),
            if (uid != w.ownerId && w.freeTons > 0) AppButton(label: context.tr('request_storage'), icon: Icons.warehouse_outlined, onPressed: () => _request(context, ref, w)),
          ]);
        },
      ),
    );
  }
}
