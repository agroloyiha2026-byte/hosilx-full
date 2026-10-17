import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import 'admin_providers.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  static const _metrics = [
    ('users', 'stat_users', Icons.people_outline), ('products', 'stat_products', Icons.inventory_2_outlined),
    ('pending_products', 'stat_pending', Icons.pending_actions), ('active_banners', 'stat_banners', Icons.view_carousel_outlined),
    ('active_ads', 'stat_ads', Icons.campaign_outlined), ('open_reports', 'stat_reports', Icons.flag_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(context.tr('admin'))),
        body: AsyncValueView<Map<String, dynamic>>(
          value: ref.watch(adminStatsProvider), // xato bo'lsa statistika uydirilmaydi: xato holati ko'rsatiladi
          onRetry: () => ref.invalidate(adminStatsProvider),
          data: (s) => ListView(padding: const EdgeInsets.all(16), children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final m in _metrics)
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 44) / 2,
                  child: AppCard(child: Row(children: [
                    Icon(m.$3, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${s[m.$1] ?? '—'}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      Text(context.tr(m.$2), style: Theme.of(context).textTheme.bodySmall),
                    ])),
                  ])),
                ),
            ]),
            const SizedBox(height: 16),
            AppButton(label: context.tr('a_moderation'), icon: Icons.fact_check_outlined, onPressed: () => context.push('/admin/moderation')),
            const SizedBox(height: 10),
            AppButton(label: context.tr('a_users'), icon: Icons.manage_accounts_outlined, outlined: true, onPressed: () => context.push('/admin/users')),
            for (final t in const [
              ('/admin/categories', 'a_categories', Icons.category_outlined), ('/admin/banners', 'a_banners', Icons.view_carousel_outlined),
              ('/admin/ads', 'a_ads', Icons.campaign_outlined), ('/admin/reports', 'a_reports', Icons.flag_outlined),
              ('/admin/settings', 'a_settings', Icons.tune),
            ]) ...[
              const SizedBox(height: 10),
              AppButton(label: context.tr(t.$2), icon: t.$3, outlined: true, onPressed: () => context.push(t.$1)),
            ],
          ]),
        ),
      );
}
