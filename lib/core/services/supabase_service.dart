import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env.dart';

class SupabaseService {
  static bool ready = false;

  static Future<void> init() async {
    if (!Env.isConfigured) return;
    await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
    ready = true;
  }

  /// Faqat init() muvaffaqiyatli bo'lgandan keyin chaqiring.
  static SupabaseClient get client => Supabase.instance.client;
}
