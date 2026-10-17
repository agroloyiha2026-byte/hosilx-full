import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/localization/l10n.dart';
import '../../core/format.dart';
import '../../core/widgets/widgets.dart';
import '../../models/stage5_models.dart';
import '../auth/auth_widgets.dart';
import '../auth/session_controller.dart';
import '../stage5_providers.dart';

class InquiriesScreen extends ConsumerWidget {
  const InquiriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(sessionProvider).user?.id;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: Text(context.tr('inquiries')), bottom: TabBar(tabs: [Tab(text: context.tr('sent')), Tab(text: context.tr('received'))])),
        body: AsyncValueView<List<InquiryItem>>(
          value: ref.watch(inquiriesProvider),
          onRetry: () => ref.invalidate(inquiriesProvider),
          data: (all) => TabBarView(children: [
            _List(all.where((i) => i.buyerId == uid).toList(), received: false),
            _List(all.where((i) => i.sellerId == uid).toList(), received: true),
          ]),
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  final List<InquiryItem> items;
  final bool received;
  const _List(this.items, {required this.received});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) return EmptyView(message: context.tr('no_inquiries'), icon: Icons.mail_outline);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(inquiriesProvider),
      child: ListView.separated(
        padding: const EdgeInsets.all(16), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final q = items[i];
          Future<void> set(String st) async {
            try {
              await ref.read(inquiryRepoProvider).setStatus(q.id, st);
              ref.invalidate(inquiriesProvider);
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
            }
          }
          return AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(q.productTitle, style: const TextStyle(fontWeight: FontWeight.w800))),
                Chip(label: Text(context.tr('s_${q.status}'))),
              ]),
              if (q.offeredPrice != null) Text('${fmtNum(q.offeredPrice!)} ${q.currency}'),
              if ((q.message ?? '').isNotEmpty) Text(q.message!),
              Text(q.createdAt.toLocal().toString().substring(0, 16), style: Theme.of(context).textTheme.bodySmall),
              if (received && q.status == 'new') ...[
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: AppButton(label: context.tr('accept'), onPressed: () => set('accepted'))),
                  const SizedBox(width: 8),
                  Expanded(child: AppButton(label: context.tr('reject'), outlined: true, onPressed: () => set('rejected'))),
                ]),
              ],
            ]),
          );
        },
      ),
    );
  }
}
