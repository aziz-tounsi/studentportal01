import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/error_messages.dart';
import 'auth_provider.dart';

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(SubscriptionNotifier.new);

class SubscriptionState {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? subscriptionData;
  final List<Map<String, dynamic>> invoices;
  final Map<String, dynamic>? aiQuota;
  final List<Map<String, dynamic>> availablePlans;

  SubscriptionState({
    this.isLoading = false,
    this.errorMessage,
    this.subscriptionData,
    this.invoices = const [],
    this.aiQuota,
    this.availablePlans = const [],
  });

  SubscriptionState copyWith({
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? subscriptionData,
    List<Map<String, dynamic>>? invoices,
    Map<String, dynamic>? aiQuota,
    List<Map<String, dynamic>>? availablePlans,
  }) {
    return SubscriptionState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      subscriptionData: subscriptionData ?? this.subscriptionData,
      invoices: invoices ?? this.invoices,
      aiQuota: aiQuota ?? this.aiQuota,
      availablePlans: availablePlans ?? this.availablePlans,
    );
  }
}

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  SubscriptionState build() {
    loadSubscription();
    return SubscriptionState(isLoading: true);
  }

  Future<void> loadSubscription() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = ref.read(authProvider).user;
      final schoolId = user?.schoolId;

      if (schoolId == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Unable to identify your school account. Please sign in again.',
        );
        return;
      }

      // 1. Fetch school subscription & plan
      final subResp = await _supabase
          .from('school_subscriptions')
          .select('*, plan:subscription_plans(*)')
          .eq('school_id', schoolId)
          .maybeSingle();

      // 2. Fetch invoices
      final invoicesResp = await _supabase
          .from('invoices')
          .select('*, invoice_payments(*)')
          .eq('school_id', schoolId)
          .order('issue_date', ascending: false);

      // 3. Fetch AI quota
      final quotaResp = await _supabase
          .from('ai_school_quotas')
          .select()
          .eq('school_id', schoolId)
          .maybeSingle();

      // 4. Fetch all available plans
      final plansResp = await _supabase
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('price_tnd_monthly', ascending: true);

      state = state.copyWith(
        isLoading: false,
        subscriptionData: subResp,
        invoices: List<Map<String, dynamic>>.from(invoicesResp),
        aiQuota: quotaResp,
        availablePlans: List<Map<String, dynamic>>.from(plansResp),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserFriendlyError.format(
          e,
          fallback: 'Unable to load your subscription details right now. Please try again.',
        ),
      );
    }
  }

  Future<bool> submitPaymentProof({
    required String invoiceId,
    required double amount,
    required String paymentMethod,
    required String transactionRef,
    String? notes,
  }) async {
    try {
      await _supabase.from('invoice_payments').insert({
        'invoice_id': invoiceId,
        'amount': amount,
        'payment_method': paymentMethod,
        'transaction_ref': transactionRef,
        'notes': notes,
        'is_verified': false,
      });
      await loadSubscription();
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: UserFriendlyError.format(
          e,
          fallback: 'Unable to submit payment proof right now. Please try again.',
        ),
      );
      return false;
    }
  }
}
