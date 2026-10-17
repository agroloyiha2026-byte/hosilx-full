import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import '../market/market_repository.dart' show sanitizeSearch;

class AdminUser {
  final String id, fullName, role;
  final String? region;
  const AdminUser(this.id, this.fullName, this.role, this.region);
}

class PendingProduct {
  final String id, title, region, currency, unit;
  final double price;
  final String? imageUrl;
  const PendingProduct(this.id, this.title, this.region, this.currency, this.unit, this.price, this.imageUrl);
}

/// Hamma amallar serverda tekshiriladi (RLS va admin_* funksiyalari). Bu yerdagi UI cheklovi faqat qulaylik.
class AdminRepository {
  get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  Future<Map<String, dynamic>> stats() async => Map<String, dynamic>.from(await _c.rpc('admin_stats') as Map);

  Future<List<AdminUser>> users(String query) async {
    var q = _c.from('profiles').select('id,full_name,role,region');
    final t = sanitizeSearch(query);
    if (t.isNotEmpty) q = q.ilike('full_name', '%$t%');
    final r = await q.order('created_at', ascending: false).limit(100);
    return (r as List).map((e) => AdminUser(e['id'] as String, (e['full_name'] as String?) ?? '', e['role'] as String, e['region'] as String?)).toList();
  }

  Future<void> setRole(String id, String role) async => _c.rpc('admin_set_role', params: {'target': id, 'new_role': role});

  Future<List<PendingProduct>> pending() async {
    final r = await _c.from('products').select('id,title,region,currency,unit,price,image_url')
        .eq('moderation_status', 'pending').order('created_at').limit(100);
    return (r as List).map((e) => PendingProduct(e['id'] as String, e['title'] as String, e['region'] as String, e['currency'] as String,
        e['unit'] as String, (e['price'] as num).toDouble(), e['image_url'] as String?)).toList();
  }

  Future<void> moderate(String id, String decision, String? note) async =>
      _c.rpc('moderate_product', params: {'p_id': id, 'decision': decision, 'note': (note ?? '').trim().isEmpty ? null : note!.trim()});
}
