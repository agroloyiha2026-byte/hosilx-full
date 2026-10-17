import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';

const _tables = {'banners', 'ads', 'product_categories'};

/// Ochiq URL dan Storage yo'lini ajratadi (bucket: images). Topilmasa null.
String? storagePathFromUrl(String url) {
  const m = '/object/public/images/';
  final i = url.indexOf(m);
  return i < 0 ? null : Uri.decodeComponent(url.substring(i + m.length).split('?').first);
}

/// Hamma yozuvlar RLS bo'yicha faqat adminga ruxsat etilgan; o'zgarishlar audit triggeri orqali jurnalga tushadi.
class AdminContentRepository {
  get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  void _check(String t) => assert(_tables.contains(t));

  Future<List<Map<String, dynamic>>> rows(String table) async {
    _check(table);
    final r = await _c.from(table).select().order(table == 'product_categories' ? 'sort_order' : 'created_at', ascending: table == 'product_categories');
    return (r as List).cast<Map<String, dynamic>>();
  }

  Future<void> insertRow(String table, Map<String, dynamic> data) async {
    _check(table);
    await _c.from(table).insert(data);
  }

  Future<void> updateRow(String table, String idColumn, String id, Map<String, dynamic> data) async {
    _check(table);
    await _c.from(table).update(data).eq(idColumn, id);
  }

  Future<void> deleteRow(String table, String id, {String? imageUrl}) async {
    _check(table);
    await _c.from(table).delete().eq('id', id);
    final path = imageUrl == null ? null : storagePathFromUrl(imageUrl);
    if (path != null) {
      try { await _c.storage.from('images').remove([path]); } catch (_) {/* faqat o'z papkangizdagi fayl o'chadi; xato e'tiborga olinmaydi */}
    }
  }

  Future<Map<String, String>> settings() async {
    final r = await _c.from('site_settings').select('key,value');
    return {for (final e in r as List) e['key'] as String: (e['value'] as String?) ?? ''};
  }

  Future<void> saveSetting(String key, String value) async => _c.from('site_settings').upsert({'key': key, 'value': value});

  Future<List<Map<String, dynamic>>> reports() async {
    final r = await _c.from('reports').select('id,reason,resolved,product_id,created_at,products(title)').order('resolved').order('created_at', ascending: false).limit(100);
    return (r as List).cast<Map<String, dynamic>>();
  }

  Future<void> resolveReport(String id) async => _c.from('reports').update({'resolved': true}).eq('id', id);

  Future<List<Map<String, dynamic>>> audit() async {
    final r = await _c.from('audit_logs').select('id,actor_id,action,entity,entity_id,created_at').order('created_at', ascending: false).limit(100);
    return (r as List).cast<Map<String, dynamic>>();
  }
}
