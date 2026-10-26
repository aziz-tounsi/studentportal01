import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/user_management_service.dart';

final platformConsoleProvider =
    NotifierProvider<PlatformConsoleNotifier, PlatformConsoleState>(
  PlatformConsoleNotifier.new,
);

class PlatformConsoleState {
  final bool isLoading;
  final String? errorMessage;
  final List<Map<String, dynamic>> schools;
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> pendingPayments;
  final List<Map<String, dynamic>> recentAiLogs;
  final List<Map<String, dynamic>> auditLogs;
  final Map<String, dynamic>? platformSettings;
  final Map<String, dynamic> kpis;

  PlatformConsoleState({
    this.isLoading = false,
    this.errorMessage,
    this.schools = const [],
    this.plans = const [],
    this.invoices = const [],
    this.pendingPayments = const [],
    this.recentAiLogs = const [],
    this.auditLogs = const [],
    this.platformSettings,
    this.kpis = const {},
  });

  PlatformConsoleState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Map<String, dynamic>>? schools,
    List<Map<String, dynamic>>? plans,
    List<Map<String, dynamic>>? invoices,
    List<Map<String, dynamic>>? pendingPayments,
    List<Map<String, dynamic>>? recentAiLogs,
    List<Map<String, dynamic>>? auditLogs,
    Map<String, dynamic>? platformSettings,
    Map<String, dynamic>? kpis,
  }) {
    return PlatformConsoleState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      schools: schools ?? this.schools,
      plans: plans ?? this.plans,
      invoices: invoices ?? this.invoices,
      pendingPayments: pendingPayments ?? this.pendingPayments,
      recentAiLogs: recentAiLogs ?? this.recentAiLogs,
      auditLogs: auditLogs ?? this.auditLogs,
      platformSettings: platformSettings ?? this.platformSettings,
      kpis: kpis ?? this.kpis,
    );
  }
}

class PlatformConsoleNotifier extends Notifier<PlatformConsoleState> {
  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  PlatformConsoleState build() {
    loadAll();
    return PlatformConsoleState(isLoading: true);
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 1. Load Platform Settings
      final settingsResp = await _supabase
          .from('platform_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();

      // 2. Load Plans
      final plansResp = await _supabase
          .from('subscription_plans')
          .select()
          .order('price_tnd_monthly', ascending: true);
      final plansList = List<Map<String, dynamic>>.from(plansResp);

      // 3. Load Schools with subscription & quotas
      final schoolsResp = await _supabase.from('schools').select('''
        id, name, code, email, phone, address, primary_color, secondary_color, is_active, created_at,
        school_subscriptions (
          id, status, billing_cycle, current_period_start, current_period_end,
          plan:subscription_plans(id, code, name, price_tnd_monthly, price_tnd_yearly)
        ),
        ai_school_quotas (
          monthly_budget_usd, spent_current_month_usd, tokens_current_month, is_quota_exceeded, kill_switch_enabled
        )
      ''').order('created_at', ascending: false);
      final schoolsList = List<Map<String, dynamic>>.from(schoolsResp);

      // 4. Load Invoices & Pending Payments
      final invoicesResp = await _supabase
          .from('invoices')
          .select('''
            id, invoice_number, school_id, amount, currency, status, issue_date, due_date, paid_at, notes,
            school:schools(id, name, code)
          ''')
          .order('issue_date', ascending: false);
      final invoicesList = List<Map<String, dynamic>>.from(invoicesResp);

      final paymentsResp = await _supabase
          .from('invoice_payments')
          .select('''
            id, invoice_id, amount, payment_method, transaction_ref, is_verified, receipt_url, notes, created_at,
            invoice:invoices(
              id, invoice_number, amount,
              school:schools(id, name, code)
            )
          ''')
          .eq('is_verified', false)
          .order('created_at', ascending: false);
      final pendingPaymentsList = List<Map<String, dynamic>>.from(paymentsResp);

      // 5. Load Recent AI Logs & Telemetry
      final aiLogsResp = await _supabase
          .from('ai_usage_logs')
          .select('''
            id, school_id, student_id, model, prompt_tokens, completion_tokens, total_tokens, cost_usd, latency_ms, status, created_at,
            school:schools(name)
          ''')
          .order('created_at', ascending: false)
          .limit(100);
      final aiLogsList = List<Map<String, dynamic>>.from(aiLogsResp);

      // 6. Load Audit Logs
      final auditResp = await _supabase
          .from('audit_logs')
          .select('''
            id, school_id, actor_id, actor_role, action, target_table, target_id, created_at,
            school:schools(name)
          ''')
          .order('created_at', ascending: false)
          .limit(100);
      final auditList = List<Map<String, dynamic>>.from(auditResp);

      // 7. Calculate Aggregated Platform KPIs
      int totalSchools = schoolsList.length;
      int activeSchools = schoolsList.where((s) => s['is_active'] == true).length;
      double mrrTnd = 0.0;
      double totalAiSpendUsd = 0.0;

      for (final s in schoolsList) {
        final subs = s['school_subscriptions'] as List?;
        if (subs != null && subs.isNotEmpty) {
          final sub = subs[0];
          final plan = sub['plan'] as Map<String, dynamic>?;
          if (plan != null && (sub['status'] == 'active' || sub['status'] == 'trial')) {
            final monthly = (plan['price_tnd_monthly'] as num?)?.toDouble() ?? 0.0;
            mrrTnd += monthly;
          }
        }

        final quotas = s['ai_school_quotas'] as List?;
        if (quotas != null && quotas.isNotEmpty) {
          final q = quotas[0];
          totalAiSpendUsd += (q['spent_current_month_usd'] as num?)?.toDouble() ?? 0.0;
        }
      }

      state = state.copyWith(
        isLoading: false,
        schools: schoolsList,
        plans: plansList,
        invoices: invoicesList,
        pendingPayments: pendingPaymentsList,
        recentAiLogs: aiLogsList,
        auditLogs: auditList,
        platformSettings: settingsResp,
        kpis: {
          'totalSchools': totalSchools,
          'activeSchools': activeSchools,
          'mrrTnd': mrrTnd,
          'totalAiSpendUsd': totalAiSpendUsd,
          'pendingVerifications': pendingPaymentsList.length,
        },
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Erreur lors du chargement des données de plateforme: $e',
      );
    }
  }

  Future<bool> createSchoolWithDirector({
    required String schoolName,
    required String schoolCode,
    required String contactEmail,
    String? phone,
    String? address,
    required String directorName,
    required String directorEmail,
    required String directorPassword,
    required String planId,
    String primaryColor = '#0052CC',
  }) async {
    try {
      // 1. Create School row
      final schoolResp = await _supabase.from('schools').insert({
        'name': schoolName,
        'code': schoolCode.toLowerCase().trim(),
        'email': contactEmail,
        'phone': phone,
        'address': address,
        'primary_color': primaryColor,
        'is_active': true,
      }).select().single();

      final schoolId = schoolResp['id'] as String;

      // 2. Attach Quota
      await _supabase.from('ai_school_quotas').upsert({
        'school_id': schoolId,
        'monthly_budget_usd': 25.00,
        'spent_current_month_usd': 0.0,
        'tokens_current_month': 0,
        'is_quota_exceeded': false,
        'kill_switch_enabled': false,
      });

      // 3. Attach Subscription Plan
      await _supabase.from('school_subscriptions').upsert({
        'school_id': schoolId,
        'plan_id': planId,
        'status': 'active',
        'billing_cycle': 'monthly',
        'current_period_start': DateTime.now().toIso8601String(),
        'current_period_end': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });

      // 4. Create Director User via UserManagementService
      final createResult = await UserManagementService.createUser(
        email: directorEmail,
        password: directorPassword,
        role: 'owner',
        fullName: directorName,
        schoolId: schoolId,
      );

      if (createResult['success'] != true) {
        throw Exception(createResult['error'] ?? 'Échec de création du directeur');
      }

      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Échec de la création de l\'établissement: $e');
      return false;
    }
  }

  Future<bool> toggleSchoolStatus(String schoolId, bool isActive) async {
    try {
      await _supabase.from('schools').update({'is_active': isActive}).eq('id', schoolId);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur lors du changement de statut: $e');
      return false;
    }
  }

  Future<bool> verifyPayment(String paymentId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final res = await _supabase.rpc('verify_invoice_payment', params: {
        'p_payment_id': paymentId,
        'p_verifier_id': currentUserId,
      });

      if (res != null && res['success'] == true) {
        await loadAll();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur validation paiement: $e');
      return false;
    }
  }

  Future<bool> toggleGlobalAiKillSwitch(bool enabled) async {
    try {
      await _supabase.from('platform_settings').update({
        'global_ai_kill_switch': enabled,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', 1);

      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur kill-switch IA: $e');
      return false;
    }
  }

  Future<bool> updatePlatformAiModels(String defaultModel, String fallbackModel) async {
    try {
      await _supabase.from('platform_settings').update({
        'default_ai_model': defaultModel,
        'fallback_ai_model': fallbackModel,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', 1);

      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur mise à jour modèles IA: $e');
      return false;
    }
  }

  Future<bool> issueManualInvoice({
    required String schoolId,
    required double amount,
    required String dueDate,
    String? notes,
  }) async {
    try {
      final invNumResp = await _supabase.rpc('generate_invoice_number');
      final invNum = (invNumResp as String?) ?? 'INV-${DateTime.now().year}-MANUAL';

      await _supabase.from('invoices').insert({
        'invoice_number': invNum,
        'school_id': schoolId,
        'amount': amount,
        'currency': 'TND',
        'status': 'issued',
        'issue_date': DateTime.now().toIso8601String().split('T')[0],
        'due_date': dueDate,
        'notes': notes ?? 'Facturation manuelle émise par la console plateforme',
      });

      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur émission facture: $e');
      return false;
    }
  }
}
