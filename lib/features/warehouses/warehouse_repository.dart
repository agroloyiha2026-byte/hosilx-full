import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import '../../models/stage5_models.dart';
import '../market/market_repository.dart' show sanitizeSearch;

const _wcols = 'id,name,region,storage_type,currency,owner_id,capacity_tons,free_tons,price_per_ton_month,address,conditions,contact_phone,image_url,accepted_products';

class WarehouseRepository {
  get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  Future<List<Warehouse>> list(String query) async {
    var q = _c.from('warehouses').select(_wcols).eq('status', 'active');
    final t = sanitizeSearch(query);
    if (t.isNotEmpty) q = q.or('name.ilike.%$t%,region.ilike.%$t%');
    final r = await q.order('created_at', ascending: false).limit(100);
    return (r as List).map((e) => Warehouse.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<Warehouse?> get(String id) async {
    final r = await _c.from('warehouses').select(_wcols).eq('id', id).maybeSingle();
    return r == null ? null : Warehouse.fromMap(r as Map<String, dynamic>);
  }

  Future<void> requestStorage({required String warehouseId, required String farmerId, required String productType,
      required double tons, String? message}) async {
    await _c.from('storage_requests').insert({
      'warehouse_id': warehouseId, 'farmer_id': farmerId, 'product_type': productType.trim().toLowerCase(),
      'quantity_tons': tons, 'message': (message ?? '').trim().isEmpty ? null : message!.trim(),
    });
  }
}
