import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/services/user_management_service.dart';

final platformProvider =
    NotifierProvider<PlatformNotifier, PlatformState>(PlatformNotifier.new);

class PlatformState {
  final bool isLoading;
  final String? errorMessage;
  final List<Map<String, dynamic>> schools;
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> pendingPayments;
  final List<Map<String, dynamic>> recentAiLogs;
  final List<Map<String, dynamic>> auditLogs;
  final List<Map<String, dynamic>> bugReports;
  final Map<String, dynamic>? platformSettings;
  final Map<String, dynamic> kpis;

  PlatformState({
    this.isLoading = false,
    this.errorMessage,
    this.schools = const [],
    this.plans = const [],
    this.invoices = const [],
    this.pendingPayments = const [],
    this.recentAiLogs = const [],
    this.auditLogs = const [],
    this.bugReports = const [],
    this.platformSettings,
    this.kpis = const {},
  });

  PlatformState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Map<String, dynamic>>? schools,
    List<Map<String, dynamic>>? plans,
    List<Map<String, dynamic>>? invoices,
    List<Map<String, dynamic>>? pendingPayments,
    List<Map<String, dynamic>>? recentAiLogs,
    List<Map<String, dynamic>>? auditLogs,
    List<Map<String, dynamic>>? bugReports,
    Map<String, dynamic>? platformSettings,
    Map<String, dynamic>? kpis,
  }) {
    return PlatformState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      schools: schools ?? this.schools,
      plans: plans ?? this.plans,
      invoices: invoices ?? this.invoices,
      pendingPayments: pendingPayments ?? this.pendingPayments,
      recentAiLogs: recentAiLogs ?? this.recentAiLogs,
      auditLogs: auditLogs ?? this.auditLogs,
      bugReports: bugReports ?? this.bugReports,
      platformSettings: platformSettings ?? this.platformSettings,
      kpis: kpis ?? this.kpis,
    );
  }
}

Map<String, dynamic>? _extractMap(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List && value.isNotEmpty) {
    final first = value.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) return Map<String, dynamic>.from(first);
  }
  return null;
}

class PlatformNotifier extends Notifier<PlatformState> {
  SupabaseClient get _supabase => Supabase.instance.client;
  PlatformState _currentState = PlatformState();

  @override
  PlatformState build() {
    _currentState = PlatformState(isLoading: true);
    Future.microtask(() => loadAll());
    return _currentState;
  }

  Future<void> loadAll() async {
    _currentState = _currentState.copyWith(isLoading: true, errorMessage: null);
    try {
      state = _currentState;
    } catch (_) {}

    try {
      // 1. Settings
      Map<String, dynamic>? settings;
      try {
        settings = await _supabase
            .from('platform_settings')
            .select()
            .eq('id', 1)
            .maybeSingle();
      } catch (_) {}

      // 2. Plans
      List<Map<String, dynamic>> plans = [];
      try {
        final plansResp = await _supabase
            .from('subscription_plans')
            .select()
            .order('price_tnd_monthly');
        plans = List<Map<String, dynamic>>.from(plansResp);
      } catch (_) {}

      // 3. Schools
      List<Map<String, dynamic>> schools = [];
      try {
        final schoolsResp = await _supabase.from('schools').select('''
          id, name, code, logo_url, email, phone, address, is_active, created_at,
          school_subscriptions (
            id, status, billing_cycle, current_period_start, current_period_end,
            plan:subscription_plans(id, code, name, price_tnd_monthly, price_tnd_yearly)
          ),
          ai_school_quotas (
            monthly_budget_usd, spent_current_month_usd, tokens_current_month, is_quota_exceeded, kill_switch_enabled
          )
        ''').order('created_at', ascending: false);
        schools = List<Map<String, dynamic>>.from(schoolsResp);
      } catch (_) {
        try {
          final fallbackSchools = await _supabase
              .from('schools')
              .select('id, name, code, logo_url, email, phone, address, is_active, created_at')
              .order('created_at', ascending: false);
          schools = List<Map<String, dynamic>>.from(fallbackSchools);
        } catch (_) {
          schools = [];
        }
      }

      // 4. Invoices & Payments
      List<Map<String, dynamic>> invoices = [];
      try {
        final invoicesResp = await _supabase.from('invoices').select('''
          id, invoice_number, school_id, amount, currency, status, issue_date, due_date, notes,
          school:schools(id, name, code)
        ''').order('issue_date', ascending: false);
        invoices = List<Map<String, dynamic>>.from(invoicesResp);
      } catch (_) {}

      List<Map<String, dynamic>> pendingPayments = [];
      try {
        final paymentsResp = await _supabase.from('invoice_payments').select('''
          id, invoice_id, amount, payment_method, transaction_ref, is_verified, receipt_url, notes, created_at,
          invoice:invoices(id, invoice_number, amount, school:schools(id, name, code))
        ''').eq('is_verified', false).order('created_at', ascending: false);
        pendingPayments = List<Map<String, dynamic>>.from(paymentsResp);
      } catch (_) {}

      // 5. AI Telemetry Logs
      List<Map<String, dynamic>> aiLogs = [];
      try {
        final aiLogsResp = await _supabase.from('ai_usage_logs').select('''
          id, school_id, student_id, model, prompt_tokens, completion_tokens, total_tokens, cost_usd, latency_ms, status, created_at,
          school:schools(name)
        ''').order('created_at', ascending: false).limit(100);
        aiLogs = List<Map<String, dynamic>>.from(aiLogsResp);
      } catch (_) {}

      // 6. Audit Logs
      List<Map<String, dynamic>> auditLogs = [];
      try {
        final auditResp = await _supabase.from('audit_logs').select('''
          id, school_id, actor_id, actor_role, action, target_table, target_id, created_at,
          school:schools(name)
        ''').order('created_at', ascending: false).limit(100);
        auditLogs = List<Map<String, dynamic>>.from(auditResp);
      } catch (_) {}

      // 7. Bug Reports
      List<Map<String, dynamic>> bugReports = [];
      try {
        final brResp = await _supabase
            .from('bug_reports')
            .select('*')
            .order('created_at', ascending: false);
        bugReports = List<Map<String, dynamic>>.from(brResp);
      } catch (_) {
        try {
          final brFallback = await _supabase
              .from('suggestions')
              .select('id, student_id, subject, message, status, created_at')
              .order('created_at', ascending: false)
              .limit(50);

          bugReports = List<Map<String, dynamic>>.from(brFallback).map((s) {
            return {
              'id': s['id'],
              'user_id': s['student_id'],
              'school_id': null,
              'student_name': 'Élève',
              'student_code': null,
              'title': s['subject'] ?? 'Signalement',
              'description': s['message'] ?? '',
              'category': 'App',
              'attachment_urls': <String>[],
              'status': s['status'] ?? 'open',
              'created_at': s['created_at'],
              'schools': null,
              '_source': 'suggestions',
            };
          }).toList();
        } catch (_) {
          bugReports = [];
        }
      }

      // 8. KPIs (using safe _extractMap helper)
      double mrr = 0.0;
      double aiSpend = 0.0;
      for (final s in schools) {
        final sub = _extractMap(s['school_subscriptions']);
        if (sub != null) {
          final plan = _extractMap(sub['plan']);
          if (plan != null &&
              (sub['status'] == 'active' || sub['status'] == 'trial')) {
            mrr += (plan['price_tnd_monthly'] as num?)?.toDouble() ?? 0.0;
          }
        }
        final quota = _extractMap(s['ai_school_quotas']);
        if (quota != null) {
          aiSpend +=
              (quota['spent_current_month_usd'] as num?)?.toDouble() ?? 0.0;
        }
      }

      _currentState = _currentState.copyWith(
        isLoading: false,
        errorMessage: null,
        schools: schools,
        plans: plans,
        invoices: invoices,
        pendingPayments: pendingPayments,
        recentAiLogs: aiLogs,
        auditLogs: auditLogs,
        bugReports: bugReports,
        platformSettings: settings,
        kpis: {
          'totalSchools': schools.length,
          'activeSchools':
              schools.where((s) => s['is_active'] == true).length,
          'mrrTnd': mrr,
          'aiSpendUsd': aiSpend,
          'pendingCount': pendingPayments.length,
          'bugReportsCount': bugReports.length,
          'openBugsCount': bugReports
              .where((b) =>
                  b['status'] != 'resolved' && b['status'] != 'closed')
              .length,
        },
      );
      try {
        state = _currentState;
      } catch (_) {}
    } catch (_) {
      _currentState = _currentState.copyWith(
        isLoading: false,
        errorMessage: null,
      );
      try {
        state = _currentState;
      } catch (_) {}
    }
  }

  Future<void> updateBugReportStatus(String id, String newStatus, {bool isFallback = false}) async {
    try {
      if (isFallback) {
        await _supabase.from('suggestions').update({'status': newStatus}).eq('id', id);
      } else {
        await _supabase.from('bug_reports').update({'status': newStatus}).eq('id', id);
      }
      final updated = state.bugReports.map((br) {
        if (br['id'] == id) {
          return {...br, 'status': newStatus};
        }
        return br;
      }).toList();
      state = state.copyWith(bugReports: updated);
    } catch (e) {
      // If table doesn't exist, try fallback table
      try {
        await _supabase.from('suggestions').update({'status': newStatus}).eq('id', id);
        final updated = state.bugReports.map((br) {
          if (br['id'] == id) {
            return {...br, 'status': newStatus};
          }
          return br;
        }).toList();
        state = state.copyWith(bugReports: updated);
      } catch (_) {}
    }
  }

  Future<String?> pickAndUploadSchoolLogo({String? schoolId}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (image == null) return null;

    final bytes = await image.readAsBytes();
    final name = image.name;
    var ext = 'png';
    if (name.contains('.')) {
      final candidate = name.split('.').last.toLowerCase();
      if (candidate.isNotEmpty && !candidate.contains('/')) ext = candidate;
    } else if (image.mimeType != null && image.mimeType!.contains('/')) {
      final sub = image.mimeType!.split('/').last.toLowerCase();
      ext = sub == 'jpeg' ? 'jpg' : sub;
    }

    final mimeType = image.mimeType ??
        switch (ext) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'webp' => 'image/webp',
          'gif' => 'image/gif',
          _ => 'image/png',
        };

    final sanitizedId =
        (schoolId ?? 'new').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final storagePath =
        'logos/${sanitizedId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _supabase.storage.from('profiles').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType),
        );

    return _supabase.storage.from('profiles').getPublicUrl(storagePath);
  }

  Future<bool> updateSchoolBranding({
    required String schoolId,
    String? logoUrl,
    bool clearLogo = false,
  }) async {
    try {
      await _supabase.from('schools').update({
        'logo_url': clearLogo ? null : logoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', schoolId);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur mise à jour logo: $e');
      return false;
    }
  }

  Future<bool> createSchool({
    required String name,
    required String code,
    required String email,
    String? logoUrl,
    required String directorName,
    required String directorEmail,
    required String directorPassword,
    required String planId,
  }) async {
    try {
      final school = await _supabase.from('schools').insert({
        'name': name,
        'code': code.toLowerCase().trim(),
        'email': email,
        if (logoUrl != null && logoUrl.isNotEmpty) 'logo_url': logoUrl,
        'is_active': true,
      }).select().single();

      final schoolId = school['id'] as String;

      await _supabase.from('ai_school_quotas').upsert({
        'school_id': schoolId,
        'monthly_budget_usd': 25.00,
        'spent_current_month_usd': 0.0,
        'tokens_current_month': 0,
        'is_quota_exceeded': false,
        'kill_switch_enabled': false,
      });

      await _supabase.from('school_subscriptions').upsert({
        'school_id': schoolId,
        'plan_id': planId,
        'status': 'active',
        'billing_cycle': 'monthly',
        'current_period_start': DateTime.now().toIso8601String(),
        'current_period_end': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      });

      final userResult = await UserManagementService.createUser(
        email: directorEmail,
        password: directorPassword,
        fullName: directorName,
        role: 'owner',
        schoolId: schoolId,
        forcePasswordChange: true,
      );

      if (userResult['success'] != true) {
        throw Exception(userResult['error'] ?? 'Échec création directeur');
      }

      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Échec création école: $e');
      return false;
    }
  }

  Future<bool> toggleSchoolStatus(String schoolId, bool isActive) async {
    return updateSchoolSubscriptionStatus(
      schoolId,
      isActive ? 'active' : 'suspended',
    );
  }

  Future<bool> updateSchoolSubscriptionStatus(
    String schoolId,
    String subscriptionStatus,
  ) async {
    try {
      final isSuspended = subscriptionStatus == 'suspended';
      await _supabase.from('schools').update({
        'is_active': !isSuspended,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', schoolId);

      await _supabase.from('school_subscriptions').update({
        'status': subscriptionStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('school_id', schoolId);

      await _supabase.from('ai_school_quotas').update({
        'kill_switch_enabled': isSuspended,
      }).eq('school_id', schoolId);

      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur statut abonnement: $e');
      return false;
    }
  }

  Future<bool> verifyPayment(String paymentId) async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      final res = await _supabase.rpc('verify_invoice_payment', params: {
        'p_payment_id': paymentId,
        'p_verifier_id': uid,
      });
      if (res != null && res['success'] == true) {
        await loadAll();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur validation: $e');
      return false;
    }
  }

  Future<bool> toggleAiKillSwitch(bool enabled) async {
    try {
      await _supabase.from('platform_settings').update({
        'global_ai_kill_switch': enabled,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', 1);
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur kill-switch: $e');
      return false;
    }
  }

  Future<bool> updatePlatformSettings({
    required String defaultAiModel,
    required String fallbackAiModel,
    required String supportEmail,
    required String platformFeeCurrency,
  }) async {
    try {
      await _supabase.from('platform_settings').update({
        'default_ai_model': defaultAiModel,
        'fallback_ai_model': fallbackAiModel,
        'support_email': supportEmail,
        'platform_fee_currency': platformFeeCurrency,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', 1);
      await loadAll();
      return true;
    } catch (e) {
      _currentState = _currentState.copyWith(errorMessage: 'Settings update error: $e');
      try {
        state = _currentState;
      } catch (_) {}
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
        'notes': notes ?? 'Facturation manuelle console plateforme',
      });
      await loadAll();
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Erreur: $e');
      return false;
    }
  }
}
