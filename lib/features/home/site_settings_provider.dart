import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/supabase_service.dart';

/// Ochiq sozlamalar (e'lon matni, texnik ishlar xabari). Admin o'zgartirsa yangi build kerak emas.
final siteSettingsProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  if (!SupabaseService.ready) return const {};
  final r = await SupabaseService.client.from('site_settings').select('key,value');
  return {for (final e in r as List) e['key'] as String: (e['value'] as String?) ?? ''};
});
