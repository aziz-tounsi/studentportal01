import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'platform_provider.dart';

final consoleAuthProvider =
    NotifierProvider<ConsoleAuthNotifier, ConsoleAuthState>(ConsoleAuthNotifier.new);

class ConsoleAuthState {
  final bool isLoading;
  final bool isInitialized;
  final bool isAuthenticated;
  final Map<String, dynamic>? user;
  final String? errorMessage;

  ConsoleAuthState({
    this.isLoading = false,
    this.isInitialized = false,
    this.isAuthenticated = false,
    this.user,
    this.errorMessage,
  });

  ConsoleAuthState copyWith({
    bool? isLoading,
    bool? isInitialized,
    bool? isAuthenticated,
    Map<String, dynamic>? user,
    String? errorMessage,
  }) {
    return ConsoleAuthState(
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class ConsoleAuthNotifier extends Notifier<ConsoleAuthState> {
  SupabaseClient get _supabase => Supabase.instance.client;
  ConsoleAuthState _currentState = ConsoleAuthState();

  void _setState(ConsoleAuthState newState) {
    _currentState = newState;
    try {
      state = newState;
    } catch (_) {}
  }

  @override
  ConsoleAuthState build() {
    final user = _supabase.auth.currentUser;
    _currentState = ConsoleAuthState(
      isLoading: false,
      isInitialized: true,
      isAuthenticated: user != null,
      user: user != null
          ? {
              'id': user.id,
              'email': user.email,
              'full_name': user.userMetadata?['full_name'] ?? 'Super Admin',
              'role': 'super_admin',
            }
          : null,
    );
    _init();
    return _currentState;
  }

  void _init() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession) {
        _loadUserData();
        ref.read(platformProvider.notifier).loadAll();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _setState(ConsoleAuthState(isInitialized: true, isAuthenticated: false));
      }
    });

    if (_supabase.auth.currentSession != null) {
      _loadUserData();
      ref.read(platformProvider.notifier).loadAll();
    }
  }

  Future<void> _loadUserData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _setState(ConsoleAuthState(isInitialized: true, isAuthenticated: false));
      return;
    }
    try {
      final resp = await _supabase
          .from('users')
          .select('id, full_name, email, role')
          .eq('id', user.id)
          .maybeSingle();

      _setState(_currentState.copyWith(
        isLoading: false,
        isInitialized: true,
        isAuthenticated: true,
        user: resp ?? {
          'id': user.id,
          'email': user.email,
          'full_name': user.userMetadata?['full_name'] ?? 'Super Admin',
          'role': 'super_admin',
        },
        errorMessage: null,
      ));
    } catch (e) {
      _setState(_currentState.copyWith(
        isLoading: false,
        isInitialized: true,
        isAuthenticated: true,
        user: {
          'id': user.id,
          'email': user.email,
          'full_name': user.userMetadata?['full_name'] ?? 'Super Admin',
          'role': 'super_admin',
        },
      ));
    }
  }

  Future<bool> signIn(String email, String password) async {
    _setState(_currentState.copyWith(isLoading: true, errorMessage: null));
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      await _loadUserData();
      if (_currentState.isAuthenticated) {
        ref.read(platformProvider.notifier).loadAll();
      }
      return _currentState.isAuthenticated;
    } on AuthException catch (e) {
      _setState(
          _currentState.copyWith(isLoading: false, isInitialized: true, errorMessage: e.message));
      return false;
    } catch (e) {
      _setState(_currentState.copyWith(
          isLoading: false, isInitialized: true, errorMessage: e.toString()));
      return false;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _setState(ConsoleAuthState(isInitialized: true, isAuthenticated: false));
  }
}
