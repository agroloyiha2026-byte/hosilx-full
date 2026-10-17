import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stage5_models.dart';
import 'inquiries/inquiry_repository.dart';
import 'notifications/notification_repository.dart';
import 'warehouses/warehouse_repository.dart';

final warehouseRepoProvider = Provider((ref) => WarehouseRepository());
final inquiryRepoProvider = Provider((ref) => InquiryRepository());
final notificationRepoProvider = Provider((ref) => NotificationRepository());

final warehouseQueryProvider = StateProvider<String>((ref) => '');
final warehousesProvider = FutureProvider.autoDispose<List<Warehouse>>(
    (ref) => ref.read(warehouseRepoProvider).list(ref.watch(warehouseQueryProvider)));
final warehouseProvider =
    FutureProvider.autoDispose.family<Warehouse?, String>((ref, id) => ref.read(warehouseRepoProvider).get(id));

final inquiriesProvider = FutureProvider.autoDispose<List<InquiryItem>>((ref) => ref.read(inquiryRepoProvider).list());
final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationItem>>((ref) => ref.read(notificationRepoProvider).list());
