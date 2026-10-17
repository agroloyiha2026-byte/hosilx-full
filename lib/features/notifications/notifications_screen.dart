import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/localization/l10n.dart';
import '../../core/widgets/widgets.dart';
import '../../models/stage5_models.dart';
import '../stage5_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _S();
}

class _S extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Ro'yxat yuklangach o'qilgan deb belgilanadi (belgilar bu sessiyada ko'rinib turadi).
    ref.read(notificationsProvider.future).then((_) async {
      try { await ref.read(notificationRepoProvider).markAllRead(); } catch (_) {}
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('notifications'))),
        body: AsyncValueView<List<NotificationItem>>(
          value: ref.watch(notificationsProvider),
          onRetry: () => ref.invalidate(notificationsProvider),
          isEmpty: (l) => l.isEmpty,
          data: (l) => ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: l.length, separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final n = l[i];
              return AppCard(
                onTap: n.productId == null ? null : () => context.push('/product/${n.productId}'),
                child: Row(children: [
                  Icon(n.read ? Icons.notifications_none : Icons.notifications_active, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.tr('notif_${n.titleKey}'), style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800)),
                    if ((n.body ?? '').isNotEmpty) Text(n.body!),
                    Text(n.createdAt.toLocal().toString().substring(0, 16), style: Theme.of(context).textTheme.bodySmall),
                  ])),
                ]),
              );
            },
          ),
        ),
      );
}
