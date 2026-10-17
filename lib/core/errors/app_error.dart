import 'package:supabase_flutter/supabase_flutter.dart';

/// Istisnoni foydalanuvchiga tarjima qilib ko'rsatiladigan kalitga aylantiradi.
class AppError implements Exception {
  final String key; // l10n kaliti
  final Object? cause;
  const AppError(this.key, [this.cause]);

  factory AppError.from(Object e) {
    if (e is AppError) return e;
    if (e is AuthException) return AppError('error_auth', e);
    if (e is PostgrestException) {
      if (e.code == '42501') return AppError('error_permission', e);
      return AppError('error_generic', e);
    }
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('ClientException') || s.contains('Failed host lookup')) {
      return AppError('error_network', e);
    }
    return AppError('error_generic', e);
  }

  @override
  String toString() => 'AppError($key, $cause)';
}
