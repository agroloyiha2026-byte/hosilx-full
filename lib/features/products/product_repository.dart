import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import '../../models/market_models.dart';

const _cols = 'id,title,category,product_type,price,currency,unit,quantity,region,description,image_url,seller_id,created_at,status,moderation_status';
const _types = {'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp'};
const maxImageBytes = 5 * 1024 * 1024;

class MyProduct {
  final Product product;
  final String status, moderation;
  const MyProduct(this.product, this.status, this.moderation);
}

/// Fayl kengaytmasi bo'yicha content-type (ruxsat etilmagan bo'lsa null). Server ham buni tekshiradi.
String? imageContentType(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot < 0 ? null : _types[fileName.substring(dot + 1).toLowerCase()];
}

class ProductRepository {
  get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  Future<List<MyProduct>> mine(String uid) async {
    final r = await _c.from('products').select(_cols).eq('seller_id', uid).order('created_at', ascending: false);
    return (r as List).map((e) {
      final m = e as Map<String, dynamic>;
      return MyProduct(Product.fromMap(m), m['status'] as String, (m['moderation_status'] as String?) ?? 'approved');
    }).toList();
  }

  Future<String> create(Map<String, dynamic> data) async {
    final r = await _c.from('products').insert(data).select('id').single();
    return (r as Map<String, dynamic>)['id'] as String;
  }

  Future<void> update(String id, Map<String, dynamic> data) async => _c.from('products').update(data).eq('id', id);
  Future<void> setStatus(String id, String status) async => _c.from('products').update({'status': status}).eq('id', id);

  Future<String> uploadImage(XFile f, String uid) async {
    final ct = imageContentType(f.name);
    final bytes = await f.readAsBytes();
    if (ct == null || bytes.length > maxImageBytes) throw const AppError('bad_image');
    final ext = f.name.split('.').last.toLowerCase();
    final path = '$uid/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await _c.storage.from('images').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: ct));
    return _c.storage.from('images').getPublicUrl(path) as String;
  }

  /// Birinchi rasm asosiy bo'ladi (agar hali yo'q bo'lsa), qolganlari galereyaga yoziladi.
  Future<void> attachImages(String productId, List<String> urls, {required bool setMain}) async {
    if (urls.isEmpty) return;
    final rest = setMain ? urls.sublist(1) : urls;
    if (setMain) await _c.from('products').update({'image_url': urls.first}).eq('id', productId);
    if (rest.isNotEmpty) {
      await _c.from('product_images').insert([for (var i = 0; i < rest.length; i++) {'product_id': productId, 'url': rest[i], 'sort_order': i + 1}]);
    }
  }
}
