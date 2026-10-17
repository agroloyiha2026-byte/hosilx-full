import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../auth/auth_widgets.dart';
import 'admin_content_providers.dart';

/// Shikoyatlar va audit jurnali (jurnal faqat o'qiladi; yozish serverdagi triggerlar orqali).
class AdminReportsScreen extends ConsumerWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(title: Text(context.tr('a_reports')), bottom: TabBar(tabs: [Tab(text: context.tr('a_reports')), Tab(text: context.tr('a_audit'))])),
          body: TabBarView(children: [
            AsyncValueView<List<Map<String, dynamic>>>(
              value: ref.watch(adminReportsProvider),
              onRetry: () => ref.invalidate(adminReportsProvider),
              isEmpty: (l) => l.isEmpty,
              data: (l) => ListView.separated(
                padding: const EdgeInsets.all(16), itemCount: l.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final r = l[i];
                  final done = r['resolved'] as bool;
                  final title = (r['products'] as Map?)?['title'] as String?;
                  return Opacity(
                    opacity: done ? 0.55 : 1,
                    child: AppCard(
                      onTap: r['product_id'] == null ? null : () => context.push('/product/${r['product_id']}'),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title ?? '—', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(r['reason'] as String),
                          Text((r['created_at'] as String).substring(0, 16).replaceFirst('T', ' '), style: Theme.of(context).textTheme.bodySmall),
                        ])),
                        if (!done)
                          TextButton(
                            onPressed: () async {
                              try {
                                await ref.read(adminContentRepoProvider).resolveReport(r['id'] as String);
                                ref.invalidate(adminReportsProvider);
                                ref.invalidate(adminAuditProvider);
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(context, e))));
                              }
                            },
                            child: Text(context.tr('resolve')),
                          )
                        else
                          Text(context.tr('resolved')),
                      ]),
                    ),
                  );
                },
              ),
            ),
            AsyncValueView<List<Map<String, dynamic>>>(
              value: ref.watch(adminAuditProvider),
              onRetry: () => ref.invalidate(adminAuditProvider),
              isEmpty: (l) => l.isEmpty,
              data: (l) => ListView.separated(
                padding: const EdgeInsets.all(16), itemCount: l.length, separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final a = l[i];
                  return ListTile(
                    dense: true, contentPadding: EdgeInsets.zero,
                    title: Text('${a['action']} · ${a['entity']}'),
                    subtitle: Text('${(a['created_at'] as String).substring(0, 16).replaceFirst('T', ' ')} · ${(a['actor_id'] as String? ?? '—').substring(0, 8)}'),
                  );
                },
              ),
            ),
          ]),
        ),
      );
}
