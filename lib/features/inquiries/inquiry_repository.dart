import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import '../../models/stage5_models.dart';

class InquiryRepository {
  get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  /// RLS faqat o'zingiz yuborgan yoki o'zingizning mahsulotlaringizga kelgan so'rovlarni qaytaradi.
  Future<List<InquiryItem>> list() async {
    final r = await _c.from('inquiries')
        .select('id,status,buyer_id,offered_price,message,created_at,products(title,seller_id,currency)')
        .order('created_at', ascending: false).limit(100);
    return (r as List).map((e) => InquiryItem.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> setStatus(String id, String status) async {
    await _c.from('inquiries').update({'status': status}).eq('id', id);
  }
}
