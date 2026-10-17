import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/supabase_service.dart';
import '../../models/profile.dart';

class AuthRepository {
  SupabaseClient get _c {
    if (!SupabaseService.ready) throw const AppError('config_missing');
    return SupabaseService.client;
  }

  Future<void> signIn(String email, String password) async {
    await _c.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// true qaytarsa: email tasdiqlash kerak (sessiya hali yo'q).
  Future<bool> signUp({required String email, required String password, required String fullName, required String role}) async {
    final res = await _c.auth.signUp(
      email: email.trim(), password: password, data: {'full_name': fullName.trim(), 'role': role});
    return res.session == null;
  }

  Future<void> resetPassword(String email) => _c.auth.resetPasswordForEmail(email.trim());

  Future<void> signOut() => _c.auth.signOut();

  Future<Profile> fetchProfile(String id) async {
    final m = await _c.from('profiles')
        .select('id,full_name,role,language,region,onboarded').eq('id', id).single();
    return Profile.fromMap(m);
  }

  Future<void> updateProfile(String id, {required String fullName, String? region, required String language}) async {
    await _c.from('profiles').update({
      'full_name': fullName.trim(), 'region': (region ?? '').trim().isEmpty ? null : region!.trim(), 'language': language,
    }).eq('id', id);
  }

  /// Birinchi kirishda: rolni (admin bo'lmasa) belgilaydi va profilni to'ldiradi.
  /// Talab: migration4.sql dagi set_my_role funksiyasi. Xavfsizlik server tomonda.
  Future<void> completeOnboarding({required Profile current, required String role, required String fullName,
      String? region, required String language}) async {
    if (!current.isAdmin && role != current.role) {
      await _c.rpc('set_my_role', params: {'new_role': role});
    }
    await _c.from('profiles').update({
      'full_name': fullName.trim(), 'region': (region ?? '').trim().isEmpty ? null : region!.trim(),
      'language': language, 'onboarded': true,
    }).eq('id', current.id);
  }
}
