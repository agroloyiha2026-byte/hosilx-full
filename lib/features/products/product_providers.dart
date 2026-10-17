import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/session_controller.dart';
import 'product_repository.dart';

final productRepoProvider = Provider((ref) => ProductRepository());

final myProductsProvider = FutureProvider.autoDispose<List<MyProduct>>((ref) {
  final uid = ref.watch(sessionProvider.select((s) => s.user?.id));
  return uid == null ? Future.value(const <MyProduct>[]) : ref.read(productRepoProvider).mine(uid);
});
