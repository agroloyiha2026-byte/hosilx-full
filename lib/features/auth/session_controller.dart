import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../models/profile.dart';
import 'auth_repository.dart';

class SessionState {
  final bool loading;
  final User? user;
  final Profile? profile;
  const SessionState({this.loading = false, this.user, this.profile});
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class SessionController extends StateNotifier<SessionState> {
  final AuthRepository _repo;
  StreamSubscription<AuthState>? _sub;

  SessionController(this._repo) : super(const SessionState(loading: true)) {
    _init();
  }

  void _init() {
    if (!SupabaseService.ready) {
      state = const SessionState();
      return;
    }
    _sub = SupabaseService.client.auth.onAuthStateChange.listen((e) => _sync(e.session?.user));
    _sync(SupabaseService.client.auth.currentUser);
  }

  Future<void> _sync(User? u) async {
    if (u == null) {
      state = const SessionState();
      return;
    }
    try {
      state = SessionState(user: u, profile: await _repo.fetchProfile(u.id));
    } catch (_) {
      state = SessionState(user: u); // profil o'qilmasa ham sessiya saqlanadi
    }
  }

  Future<void> refreshProfile() => _sync(SupabaseService.client.auth.currentUser);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final sessionProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) => SessionController(ref.read(authRepositoryProvider)));
