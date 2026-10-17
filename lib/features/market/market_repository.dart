import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import '../../models/market_models.dart';

const _cols = 'id,title,category,product_type,price,currency,unit,quantity,region,description,image_url,seller_id,created_at';

/// Qidiruv so'rovidagi filtr sintaksisini buzadigan belgilarni olib tashlaydi.
String sanitizeSearch(String s) => s.replaceAll(RegExp(r'[%,()*\\]'), ' ').trim();

class MarketRepository {
  SupabaseClient get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  Future<List<Category>> categories() async {
    final r = await _c.from('product_categories').select().eq('active', true).order('sort_order');
    return (r as List).map((e) => Category.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<List<BannerItem>> banners() async {
    final r = await _c.from('banners').select().eq('active', true).order('sort_order'); // sanalarni RLS filtrlaydi
    return (r as List).map((e) => BannerItem.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Faol va (moderatsiya yoqilgan bo'lsa) tasdiqlangan e'lonlar; ko'rinishni RLS ta'minlaydi.
  Future<List<Product>> products(ProductFilters f, int page, int size) async {
    var q = _c.from('products').select(_cols).eq('status', 'active');
    if (f.category != null) q = q.eq('category', f.category!);
    final t = sanitizeSearch(f.query);
    if (t.isNotEmpty) q = q.or('title.ilike.%$t%,product_type.ilike.%$t%');
    final rg = sanitizeSearch(f.region);
    if (rg.isNotEmpty) q = q.ilike('region', '%$rg%');
    // Valyutalar aralashtirilmaydi: narx bo'yicha filtr/saralashda bitta valyuta tanlanadi.
    if (f.minPrice != null || f.maxPrice != null || f.sort != 'new') q = q.eq('currency', f.currency);
    if (f.minPrice != null) q = q.gte('price', f.minPrice!);
    if (f.maxPrice != null) q = q.lte('price', f.maxPrice!);
    final col = f.sort == 'new' ? 'created_at' : 'price';
    final from = page * size;
    final r = await q.order(col, ascending: f.sort == 'price_asc').range(from, from + size - 1);
    return (r as List).map((e) => Product.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Product?> product(String id) async {
    final r = await _c.from('products').select('$_cols,product_images(url,sort_order)').eq('id', id).maybeSingle();
    return r == null ? null : Product.fromMap(r);
  }

  Future<({String? name, String? region})> seller(String id) async {
    final r = await _c.rpc('seller_public', params: {'p_seller': id});
    if (r is List && r.isNotEmpty) return (name: r[0]['full_name'] as String?, region: r[0]['region'] as String?);
    return (name: null, region: null);
  }

  Future<Set<String>> favoriteIds(String uid) async {
    final r = await _c.from('saved_products').select('product_id').eq('user_id', uid);
    return (r as List).map((e) => e['product_id'] as String).toSet();
  }

  Future<void> setFavorite(String uid, String pid, bool on) async {
    if (on) {
      await _c.from('saved_products').upsert({'user_id': uid, 'product_id': pid});
    } else {
      await _c.from('saved_products').delete().eq('user_id', uid).eq('product_id', pid);
    }
  }

  Future<List<Product>> favorites() async {
    final r = await _c.from('saved_products').select('products($_cols)');
    return (r as List).map((e) => e['products']).whereType<Map<String, dynamic>>().map(Product.fromMap).toList();
  }

  Future<void> sendInquiry({required String productId, required String buyerId, String? message, double? offer}) async {
    await _c.from('inquiries').insert({
      'product_id': productId, 'buyer_id': buyerId,
      'message': (message ?? '').trim().isEmpty ? null : message!.trim(), 'offered_price': offer,
    });
  }
}
