import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_repository.dart';

final adminRepoProvider = Provider((ref) => AdminRepository());
final adminStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) => ref.read(adminRepoProvider).stats());
final adminUserQueryProvider = StateProvider<String>((ref) => '');
final adminUsersProvider = FutureProvider.autoDispose<List<AdminUser>>(
    (ref) => ref.read(adminRepoProvider).users(ref.watch(adminUserQueryProvider)));
final pendingProductsProvider = FutureProvider.autoDispose<List<PendingProduct>>((ref) => ref.read(adminRepoProvider).pending());
