import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/error_messages.dart';
import '../../data/models/user_model.dart';

final authProvider = NotifierProvider<AuthNotifier, AdminAuthState>(AuthNotifier.new);

class AdminAuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final String? errorMessage;
  final bool accessDenied;
  final String? schoolSubscriptionStatus;
  final bool schoolIsActive;

  AdminAuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.errorMessage,
    this.accessDenied = false,
    this.schoolSubscriptionStatus,
    this.schoolIsActive = true,
  });

  AdminAuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    String? errorMessage,
    bool? accessDenied,
    String? schoolSubscriptionStatus,
    bool? schoolIsActive,
  }) {
    return AdminAuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      errorMessage: errorMessage,
      accessDenied: accessDenied ?? this.accessDenied,
      schoolSubscriptionStatus:
          schoolSubscriptionStatus ?? this.schoolSubscriptionStatus,
      schoolIsActive: schoolIsActive ?? this.schoolIsActive,
    );
  }
}

class AuthNotifier extends Notifier<AdminAuthState> {
  @override
  AdminAuthState build() {
    _init();
    return AdminAuthState();
  }

  SupabaseClient get _supabase => Supabase.instance.client;

  void _init() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        _loadUserData();
      } else if (data.event == AuthChangeEvent.signedOut) state = AdminAuthState();
    });
    if (_supabase.auth.currentSession != null) _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    state = state.copyWith(isLoading: true);
    try {
      final resp = await _supabase.from('users').select().eq('id', userId).single();
      final user = UserModel.fromJson(resp);
      if (!['admin', 'staff', 'owner', 'manager', 'super_admin'].contains(user.role)) {
        await _supabase.auth.signOut();
        final message = 'Access denied. This dashboard is for school administrators only.';
        state = AdminAuthState(accessDenied: true, errorMessage: message);
        return;
      }

      // Check master SaaS school subscription & active kill-switch
      String? subStatus = 'active';
      bool schoolIsActive = true;
      if (user.schoolId != null) {
        try {
          final schoolRow = await _supabase
              .from('schools')
              .select('is_active, school_subscriptions(status)')
              .eq('id', user.schoolId!)
              .maybeSingle();
          if (schoolRow != null) {
            schoolIsActive = schoolRow['is_active'] as bool? ?? true;
            final subs = schoolRow['school_subscriptions'] as List?;
            if (subs != null && subs.isNotEmpty) {
              subStatus = (subs.first as Map)['status']?.toString();
            }
          }
        } catch (_) {}
      }

      if (!schoolIsActive || subStatus == 'suspended') {
        await _supabase.auth.signOut();
        state = AdminAuthState(
          accessDenied: true,
          schoolSubscriptionStatus: subStatus ?? 'suspended',
          schoolIsActive: false,
          errorMessage:
              'L\'abonnement de votre établissement est suspendu. Veuillez contacter l\'administrateur de la plateforme.',
        );
        return;
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
        errorMessage: null,
        accessDenied: false,
        schoolSubscriptionStatus: subStatus,
        schoolIsActive: schoolIsActive,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserFriendlyError.format(
          e,
          fallback: 'Unable to load your account right now. Please try again.',
        ),
      );
    }
  }

  Future<String?> completeForcedPasswordChange(String newPassword) async {
    final userId = state.user?.id ?? _supabase.auth.currentUser?.id;
    if (userId == null) return 'Session expirée';
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
      await _supabase.from('users').update({
        'force_password_change': false,
        'initial_password': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
      if (state.user != null) {
        state = state.copyWith(
          user: state.user!.copyWith(
            forcePasswordChange: false,
            initialPassword: null,
          ),
        );
      }
      return null;
    } catch (e) {
      return UserFriendlyError.format(e);
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null, accessDenied: false);
    try {
      await _supabase.auth.signInWithPassword(email: email, password: password);
      await _loadUserData();
      return state.isAuthenticated;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserFriendlyError.format(
          e,
          fallback: 'Unable to sign in. Please check your credentials and try again.',
        ),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserFriendlyError.format(
          e,
          fallback: 'Unable to sign in right now. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    state = AdminAuthState();
  }

  void clearError() { state = state.copyWith(errorMessage: null, accessDenied: false); }
}