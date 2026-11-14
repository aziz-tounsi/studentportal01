import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final hasSession = _supabase.auth.currentSession != null;
    _currentState = ConsoleAuthState(
      isLoading: hasSession,
      isInitialized: false,
      isAuthenticated: false,
    );
    Future.microtask(_init);
    return _currentState;
  }

  void _init() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _loadUserData();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _setState(ConsoleAuthState(isInitialized: true, isAuthenticated: false));
      }
    });

    if (_supabase.auth.currentSession != null) {
      _loadUserData();
    } else {
      _setState(ConsoleAuthState(isInitialized: true, isAuthenticated: false));
    }
  }

  Future<void> _loadUserData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      _setState(ConsoleAuthState(isInitialized: true, isAuthenticated: false));
      return;
    }
    _setState(_currentState.copyWith(isLoading: true));
    try {
      final resp = await _supabase
          .from('users')
          .select('id, full_name, email, role')
          .eq('id', userId)
          .single();

      final role = resp['role'] as String?;
      if (role != 'super_admin') {
        await _supabase.auth.signOut();
        _setState(ConsoleAuthState(
          isInitialized: true,
          isAuthenticated: false,
          errorMessage:
              'Accès refusé. Cette console est strictement réservée au super_admin de la plateforme.',
        ));
        return;
      }

      _setState(_currentState.copyWith(
        isLoading: false,
        isInitialized: true,
        isAuthenticated: true,
        user: resp,
        errorMessage: null,
      ));
    } catch (e) {
      _setState(_currentState.copyWith(
        isLoading: false,
        isInitialized: true,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<bool> signIn(String email, String password) async {
    _setState(_currentState.copyWith(isLoading: true, errorMessage: null));
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      await _loadUserData();
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
