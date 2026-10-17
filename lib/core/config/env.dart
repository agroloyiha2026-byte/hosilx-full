/// Supabase sozlamalari. FlutLab'da --dart-define ishlatish qiyin, shuning uchun
/// quyidagi ikki qiymatni to'g'ridan-to'g'ri o'zgartiring (Supabase > Project Settings > API).
/// Faqat Project URL va anon/publishable kalit. service_role / secret kalitni BU YERGA YOZMANG.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'PASTE_SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'PASTE_ANON_KEY');
  static const webUrl = String.fromEnvironment('WEB_URL', defaultValue: 'PASTE_WEB_URL');

  static bool get isConfigured =>
      supabaseUrl.startsWith('https://') && !supabaseAnonKey.startsWith('PASTE');
}
