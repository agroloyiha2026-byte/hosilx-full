import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_content_repository.dart';

final adminContentRepoProvider = Provider((ref) => AdminContentRepository());
final adminRowsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, t) => ref.read(adminContentRepoProvider).rows(t));
final adminSettingsProvider = FutureProvider.autoDispose<Map<String, String>>((ref) => ref.read(adminContentRepoProvider).settings());
final adminReportsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ref.read(adminContentRepoProvider).reports());
final adminAuditProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) => ref.read(adminContentRepoProvider).audit());
