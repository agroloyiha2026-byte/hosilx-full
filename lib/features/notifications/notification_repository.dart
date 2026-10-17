import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import '../../models/stage5_models.dart';

class NotificationRepository {
  get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  Future<List<NotificationItem>> list() async {
    final r = await _c.from('notifications').select('id,type,title,body,data,read,created_at')
        .order('created_at', ascending: false).limit(50);
    return (r as List).map((e) => NotificationItem.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> markAllRead() async => _c.rpc('mark_notifications_read');
}
