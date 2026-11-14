import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/console_theme.dart';
import '../providers/platform_provider.dart';
import '../widgets/console_sidebar.dart';
import '../widgets/console_skeleton_loader.dart';

// ═══════════════════════════════════════════════════════════════════
// DATA MODEL FOR SCHOOL PROFILE
// ═══════════════════════════════════════════════════════════════════

class SchoolProfileData {
  final Map<String, dynamic> school;
  final Map<String, dynamic>? subscription;
  final Map<String, dynamic>? plan;
  final Map<String, dynamic>? aiQuota;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> invoices;
  final List<Map<String, dynamic>> aiLogs;
  final List<Map<String, dynamic>> auditLogs;

  final int studentCount;
  final int teacherCount;
  final int staffCount;
  final int maxCapacity;

  final double mrrTnd;
  final double aiSpentUsd;
  final double aiBudgetUsd;
  final int aiTokensMonth;

  final double totalInvoicedTnd;
  final double totalPaidTnd;
  final int pendingInvoicesCount;
  final double pendingAmountTnd;

  SchoolProfileData({
    required this.school,
    this.subscription,
    this.plan,
    this.aiQuota,
    this.users = const [],
    this.invoices = const [],
    this.aiLogs = const [],
    this.auditLogs = const [],
    this.studentCount = 0,
    this.teacherCount = 0,
    this.staffCount = 0,
    this.maxCapacity = 200,
    this.mrrTnd = 0.0,
    this.aiSpentUsd = 0.0,
    this.aiBudgetUsd = 25.0,
    this.aiTokensMonth = 0,
    this.totalInvoicedTnd = 0.0,
    this.totalPaidTnd = 0.0,
    this.pendingInvoicesCount = 0,
    this.pendingAmountTnd = 0.0,
  });
}

// ═══════════════════════════════════════════════════════════════════
// SCHOOL PROFILE PROVIDER
// ═══════════════════════════════════════════════════════════════════

final schoolProfileDataProvider =
    FutureProvider.autoDispose.family<SchoolProfileData?, String>((ref, schoolId) async {
  final supabase = Supabase.instance.client;

  try {
    // 1. School data with subscription and plan
    Map<String, dynamic>? school;
    try {
      final schoolResp = await supabase
          .from('schools')
          .select('''
            id, name, code, logo_url, email, phone, address, is_active, created_at,
            school_subscriptions (
              id, status, billing_cycle, current_period_start, current_period_end, notes,
              plan:subscription_plans(id, code, name, price_tnd_monthly, price_tnd_yearly, max_students, ai_budget_included_usd, features)
            ),
            ai_school_quotas (
              monthly_budget_usd, spent_current_month_usd, tokens_current_month, is_quota_exceeded, kill_switch_enabled
            )
          ''')
          .eq('id', schoolId)
          .maybeSingle();

      if (schoolResp != null) {
        school = Map<String, dynamic>.from(schoolResp);
      }
    } catch (e) {
      debugPrint('SchoolProfile: primary school query error: $e');
    }

    // Fallback: check cached schools in platformProvider
    if (school == null) {
      final cachedSchools = ref.read(platformProvider).schools;
      final match = cachedSchools.where((s) => s['id']?.toString() == schoolId).toList();
      if (match.isNotEmpty) {
        school = Map<String, dynamic>.from(match.first);
      }
    }

    // Fallback 2: simple school query without joins
    if (school == null) {
      try {
        final simpleResp = await supabase
            .from('schools')
            .select('id, name, code, logo_url, email, phone, address, is_active, created_at')
            .eq('id', schoolId)
            .maybeSingle();
        if (simpleResp != null) {
          school = Map<String, dynamic>.from(simpleResp);
        }
      } catch (e) {
        debugPrint('SchoolProfile: fallback school query error: $e');
      }
    }

    if (school == null) return null;


    Map<String, dynamic>? sub;
    final rawSub = school['school_subscriptions'];
    if (rawSub is Map<String, dynamic>) {
      sub = rawSub;
    } else if (rawSub is List && rawSub.isNotEmpty) {
      sub = Map<String, dynamic>.from(rawSub.first);
    }

    Map<String, dynamic>? plan;
    if (sub != null && sub['plan'] != null) {
      final rawPlan = sub['plan'];
      if (rawPlan is Map<String, dynamic>) {
        plan = rawPlan;
      } else if (rawPlan is List && rawPlan.isNotEmpty) {
        plan = Map<String, dynamic>.from(rawPlan.first);
      }
    }

    Map<String, dynamic>? quota;
    final rawQuota = school['ai_school_quotas'];
    if (rawQuota is Map<String, dynamic>) {
      quota = rawQuota;
    } else if (rawQuota is List && rawQuota.isNotEmpty) {
      quota = Map<String, dynamic>.from(rawQuota.first);
    }

    // 2. Users for this school
    List<Map<String, dynamic>> users = [];
    int studentCount = 0;
    int teacherCount = 0;
    int staffCount = 0;
    try {
      final usersResp = await supabase
          .from('users')
          .select('id, full_name, email, role, phone, is_active, created_at')
          .eq('school_id', schoolId)
          .order('created_at', ascending: false)
          .limit(100);
      users = List<Map<String, dynamic>>.from(usersResp);
      for (final u in users) {
        final role = (u['role'] as String? ?? '').toLowerCase();
        if (role == 'student') {
          studentCount++;
        } else if (role == 'teacher') {
          teacherCount++;
        } else {
          staffCount++;
        }
      }
    } catch (e) {
      debugPrint('SchoolProfile: users error: $e');
    }

    // 3. Invoices for this school
    List<Map<String, dynamic>> invoices = [];
    double totalInvoiced = 0.0;
    double totalPaid = 0.0;
    int pendingCount = 0;
    double pendingAmount = 0.0;
    try {
      final invResp = await supabase
          .from('invoices')
          .select('*, invoice_payments(*)')
          .eq('school_id', schoolId)
          .order('created_at', ascending: false)
          .limit(50);
      invoices = List<Map<String, dynamic>>.from(invResp);
      for (final inv in invoices) {
        final amt = (inv['amount'] as num?)?.toDouble() ?? 0.0;
        final status = (inv['status'] as String? ?? '').toLowerCase();
        totalInvoiced += amt;
        if (status == 'paid') {
          totalPaid += amt;
        } else {
          pendingCount++;
          pendingAmount += amt;
        }
      }
    } catch (e) {
      debugPrint('SchoolProfile: invoices error: $e');
    }

    // 4. AI usage logs
    List<Map<String, dynamic>> aiLogs = [];
    try {
      final aiResp = await supabase
          .from('ai_usage_logs')
          .select('*')
          .eq('school_id', schoolId)
          .order('created_at', ascending: false)
          .limit(50);
      aiLogs = List<Map<String, dynamic>>.from(aiResp);
    } catch (e) {
      debugPrint('SchoolProfile: aiLogs error: $e');
    }

    // 5. Audit logs
    List<Map<String, dynamic>> auditLogs = [];
    try {
      final auditResp = await supabase
          .from('audit_logs')
          .select('*')
          .eq('school_id', schoolId)
          .order('created_at', ascending: false)
          .limit(40);
      auditLogs = List<Map<String, dynamic>>.from(auditResp);
    } catch (e) {
      debugPrint('SchoolProfile: auditLogs error: $e');
    }

    // MRR & AI spend
    final mrr = (plan?['price_tnd_monthly'] as num?)?.toDouble() ?? 850.0;
    final aiSpent = (quota?['spent_current_month_usd'] as num?)?.toDouble() ?? 0.0;
    final aiBudget = (quota?['monthly_budget_usd'] as num?)?.toDouble() ?? 25.0;
    final aiTokens = (quota?['tokens_current_month'] as num?)?.toInt() ?? 0;

    int maxCap = 200;
    if (plan?['max_students'] != null) {
      maxCap = (plan!['max_students'] as num).toInt();
    } else if (sub?['notes'] != null) {
      try {
        final notes = jsonDecode(sub!['notes'].toString());
        if (notes['max_students'] != null) {
          maxCap = int.parse(notes['max_students'].toString());
        }
      } catch (_) {}
    }

    return SchoolProfileData(
      school: school,
      subscription: sub,
      plan: plan,
      aiQuota: quota,
      users: users,
      invoices: invoices,
      aiLogs: aiLogs,
      auditLogs: auditLogs,
      studentCount: studentCount,
      teacherCount: teacherCount,
      staffCount: staffCount,
      maxCapacity: maxCap,
      mrrTnd: mrr,
      aiSpentUsd: aiSpent,
      aiBudgetUsd: aiBudget,
      aiTokensMonth: aiTokens,
      totalInvoicedTnd: totalInvoiced,
      totalPaidTnd: totalPaid,
      pendingInvoicesCount: pendingCount,
      pendingAmountTnd: pendingAmount,
    );
  } catch (e) {
    debugPrint('SchoolProfile: fetch error: $e');
    return null;
  }
});

// ═══════════════════════════════════════════════════════════════════
// SCHOOL PROFILE SCREEN (CLONED EXACTLY FROM USER PROFILE SCREEN)
// ═══════════════════════════════════════════════════════════════════

class SchoolProfileScreen extends ConsumerStatefulWidget {
  final String schoolId;
  const SchoolProfileScreen({super.key, required this.schoolId});

  @override
  ConsumerState<SchoolProfileScreen> createState() => _SchoolProfileScreenState();
}

class _SchoolProfileScreenState extends ConsumerState<SchoolProfileScreen> {
  int _activeTabIndex = 0; // 0: Facturation, 1: Consommation IA, 2: Utilisateurs, 3: Journal
  bool _isUploadingLogo = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(schoolProfileDataProvider(widget.schoolId));

    return Scaffold(
      backgroundColor: ConsoleColors.background,
      body: Row(
        children: [
          const ConsoleSidebar(currentRoute: '/schools'),
          Expanded(
            child: profileAsync.when(
              loading: () => const SchoolProfileSkeleton(),
              error: (err, _) => _buildErrorView(err),
              data: (data) {
                if (data == null) return _buildNotFoundView();
                return _buildProfileBody(context, data);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // MAIN BODY (GOLDEN RATIO 2-COLUMN LAYOUT)
  // ═══════════════════════════════════════════════════
  Widget _buildProfileBody(BuildContext context, SchoolProfileData data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── TOP HEADER ──
          _buildHeader(data),
          const SizedBox(height: 28),

          // ── 2-COLUMN GRID (LEFT: 360px, RIGHT: EXPANDED) ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT COLUMN
              SizedBox(
                width: 360,
                child: Column(
                  children: [
                    _buildSchoolIdentityCard(data),
                    const SizedBox(height: 24),
                    _buildSubscriptionCard(data),
                  ],
                ),
              ),
              const SizedBox(width: 28),

              // RIGHT COLUMN
              Expanded(
                child: Column(
                  children: [
                    // 4 Golden Ratio KPI cards
                    _buildStatsGrid(data),
                    const SizedBox(height: 28),

                    // Tab bar + Tab content
                    _buildTabbedSection(data),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // TOP HEADER
  // ═══════════════════════════════════════════════════
  Widget _buildHeader(SchoolProfileData data) {
    final school = data.school;
    final name = (school['name'] as String?) ?? 'Établissement';
    final isActive = school['is_active'] == true;
    final rawCode = (school['code'] ?? '—').toString().toUpperCase();
    final shortCode = rawCode.length > 6 ? rawCode.substring(0, 6) : rawCode;

    String formattedCreated = '—';
    if (school['created_at'] != null) {
      try {
        final dt = DateTime.parse(school['created_at'].toString());
        formattedCreated = DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Back button
          _buildIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Retour aux établissements',
            onTap: () => context.go('/schools'),
          ),
          const SizedBox(width: 16),

          // Avatar
          _buildSchoolAvatar(school, size: 48),
          const SizedBox(width: 16),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isActive ? 'Actif' : 'Suspendu',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Code Pill
                    Tooltip(
                      message: rawCode,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          shortCode,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Établissement SaaS • Inscrit le $formattedCreated',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Actions
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildOutlineButton(
                icon: Icons.refresh_rounded,
                label: 'Actualiser',
                onTap: () {
                  ref.invalidate(schoolProfileDataProvider(widget.schoolId));
                  ref.read(platformProvider.notifier).loadAll();
                },
              ),
              _buildOutlineButton(
                icon: Icons.auto_awesome_rounded,
                label: 'Quota IA',
                onTap: () => _openQuotaDialog(data),
              ),
              _buildOutlineButton(
                icon: Icons.card_membership_rounded,
                label: 'Changer Forfait',
                onTap: () => _openPlanDialog(data),
              ),
              _buildOutlineButton(
                icon: Icons.picture_as_pdf_rounded,
                label: 'Facture PDF',
                onTap: () => _openInvoiceDialog(data),
              ),
              _buildStatusToggleButton(data),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // LEFT COLUMN: IDENTITY CARD
  // ═══════════════════════════════════════════════════
  Widget _buildSchoolIdentityCard(SchoolProfileData data) {
    final school = data.school;
    final name = (school['name'] as String?) ?? 'Établissement';
    final email = (school['email'] as String?) ?? '—';
    final phone = (school['phone'] as String?) ?? '—';
    final address = (school['address'] as String?) ?? 'Non renseignée';
    final rawCode = (school['code'] ?? '—').toString().toUpperCase();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Change Avatar
          Center(
            child: Stack(
              children: [
                _buildSchoolAvatar(school, size: 76),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _isUploadingLogo ? null : () => _pickAndUploadLogo(school['id']),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6D4CF6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: _isUploadingLogo
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Code: $rawCode',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),

          // Fields
          _buildInfoRow(
            Icons.email_outlined,
            'Email Directeur',
            email,
            copyable: email != '—',
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            Icons.phone_outlined,
            'Téléphone',
            phone,
            copyable: phone != '—',
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            Icons.location_on_outlined,
            'Adresse',
            address,
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            Icons.groups_outlined,
            'Capacité Élèves',
            '${data.studentCount} / ${data.maxCapacity} inscrits',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // LEFT COLUMN: SUBSCRIPTION & LICENSE CARD
  // ═══════════════════════════════════════════════════
  Widget _buildSubscriptionCard(SchoolProfileData data) {
    final plan = data.plan;
    final planName = (plan?['name'] as String?) ?? 'Plan Pro';
    final price = plan?['price_tnd_monthly'] ?? 850;
    final sub = data.subscription;
    final billingCycle = (sub?['billing_cycle'] as String?) ?? 'monthly';

    String periodEnd = 'Renouvellement auto';
    if (sub?['current_period_end'] != null) {
      try {
        final dt = DateTime.parse(sub!['current_period_end'].toString());
        periodEnd = DateFormat('dd/MM/yyyy').format(dt);
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ABONNEMENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF94A3B8),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  planName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$price TND',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                billingCycle == 'yearly' ? '/ an' : '/ mois',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildCheckItem('Quota IA: \$${data.aiBudgetUsd.toStringAsFixed(0)} USD inclus / mois'),
          _buildCheckItem('Capacité maximale: ${data.maxCapacity} élèves'),
          _buildCheckItem('Accès Espace Direction & Enseignants'),
          _buildCheckItem('Télémétrie IA et Facturation automatisée'),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Prochaine échéance',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              Text(
                periodEnd,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _openPlanDialog(data),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6D4CF6),
                side: const BorderSide(color: Color(0xFFDDD6FE)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Modifier le forfait', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // RIGHT COLUMN: 4 GOLDEN-RATIO METRIC CARDS
  // ═══════════════════════════════════════════════════
  Widget _buildStatsGrid(SchoolProfileData data) {
    return Row(
      children: [
        // 1. MRR
        Expanded(
          child: _buildMetricCard(
            title: 'MRR MENSUEL',
            value: '${data.mrrTnd.toStringAsFixed(0)} TND',
            subtitle: 'Facturation active',
            icon: Icons.trending_up_rounded,
            iconColor: ConsoleColors.success,
            badge: 'À JOUR',
            badgeColor: const Color(0xFFECFDF5),
            badgeTextColor: const Color(0xFF059669),
          ),
        ),
        const SizedBox(width: 16),

        // 2. AI Spend
        Expanded(
          child: _buildMetricCard(
            title: 'DÉPENSES IA',
            value: '\$${data.aiSpentUsd.toStringAsFixed(2)}',
            subtitle: '${data.aiTokensMonth} tokens • Quota \$${data.aiBudgetUsd.toStringAsFixed(0)}',
            icon: Icons.auto_awesome_rounded,
            iconColor: ConsoleColors.brand,
            badge: '${((data.aiSpentUsd / max(1.0, data.aiBudgetUsd)) * 100).toInt()}%',
            badgeColor: const Color(0xFFF5F3FF),
            badgeTextColor: const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(width: 16),

        // 3. Students
        Expanded(
          child: _buildMetricCard(
            title: 'ÉLÈVES INSCRITS',
            value: '${data.studentCount}',
            subtitle: 'Max ${data.maxCapacity} • ${data.teacherCount} professeurs',
            icon: Icons.school_rounded,
            iconColor: ConsoleColors.primary,
            badge: '${((data.studentCount / max(1, data.maxCapacity)) * 100).toInt()}% cap.',
            badgeColor: const Color(0xFFEFF6FF),
            badgeTextColor: const Color(0xFF2563EB),
          ),
        ),
        const SizedBox(width: 16),

        // 4. Invoices
        Expanded(
          child: _buildMetricCard(
            title: 'TOTAL RECOUVRÉ',
            value: '${data.totalPaidTnd.toStringAsFixed(0)} TND',
            subtitle: '${data.pendingInvoicesCount} impayée(s) • ${data.pendingAmountTnd.toStringAsFixed(0)} TND',
            icon: Icons.receipt_long_rounded,
            iconColor: ConsoleColors.warning,
            badge: data.pendingInvoicesCount == 0 ? 'RÉGLÉ' : 'RELANCE',
            badgeColor: data.pendingInvoicesCount == 0 ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
            badgeTextColor: data.pendingInvoicesCount == 0 ? const Color(0xFF059669) : const Color(0xFFD97706),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Color(0xFF94A3B8),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // RIGHT COLUMN: TABBED SECTIONS
  // ═══════════════════════════════════════════════════
  Widget _buildTabbedSection(SchoolProfileData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Tab Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                _buildTabButton(0, 'Facturation (${data.invoices.length})', Icons.receipt_long_outlined),
                const SizedBox(width: 8),
                _buildTabButton(1, 'Consommation IA', Icons.auto_awesome_outlined),
                const SizedBox(width: 8),
                _buildTabButton(2, 'Utilisateurs (${data.users.length})', Icons.people_outline_rounded),
                const SizedBox(width: 8),
                _buildTabButton(3, 'Journal d\'Activité', Icons.history_rounded),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Tab Content
          IndexedStack(
            index: _activeTabIndex,
            children: [
              _buildInvoicesTab(data),
              _buildAiTelemetryTab(data),
              _buildUsersTab(data),
              _buildAuditTab(data),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isActive = _activeTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _activeTabIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF1F5F9) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 1: FACTURATION ──
  Widget _buildInvoicesTab(SchoolProfileData data) {
    if (data.invoices.isEmpty) {
      return _buildEmptyState(
        Icons.receipt_long_outlined,
        'Aucune facture émise pour cet établissement.',
        actionLabel: 'Générer une facture',
        onAction: () => _openInvoiceDialog(data),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        horizontalMargin: 20,
        headingRowHeight: 42,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 56,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
        headingTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF94A3B8),
        ),
        columns: const [
          DataColumn(label: Text('FACTURE N°')),
          DataColumn(label: Text('DATE ÉMISSION')),
          DataColumn(label: Text('ÉCHÉANCE')),
          DataColumn(label: Text('MONTANT')),
          DataColumn(label: Text('STATUT')),
        ],
        rows: data.invoices.map((inv) {
          final number = inv['invoice_number'] ?? '—';
          final amount = (inv['amount'] as num?)?.toDouble() ?? 0.0;
          final status = (inv['status'] as String? ?? 'pending').toLowerCase();
          final isPaid = status == 'paid';

          return DataRow(
            cells: [
              DataCell(
                Text(
                  number,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              DataCell(Text(inv['issue_date'] ?? '—', style: const TextStyle(fontSize: 12))),
              DataCell(Text(inv['due_date'] ?? '—', style: const TextStyle(fontSize: 12))),
              DataCell(
                Text(
                  '${amount.toStringAsFixed(2)} TND',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? 'Payée' : 'En attente',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isPaid ? const Color(0xFF059669) : const Color(0xFFD97706),
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── TAB 2: CONSOMMATION IA ──
  Widget _buildAiTelemetryTab(SchoolProfileData data) {
    final spent = data.aiSpentUsd;
    final budget = max(1.0, data.aiBudgetUsd);
    final ratio = (spent / budget).clamp(0.0, 1.0);
    final isHardLocked = data.aiQuota?['kill_switch_enabled'] == true;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Budget & Quota Mensuel',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${spent.toStringAsFixed(2)} consommés sur un budget de \$${budget.toStringAsFixed(0)} USD',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _openQuotaDialog(data),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Ajuster le quota'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6D4CF6),
                  side: const BorderSide(color: Color(0xFFDDD6FE)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation(
                ratio >= 0.9 ? const Color(0xFFDC2626) : const Color(0xFF6D4CF6),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isHardLocked ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isHardLocked ? 'Kill Switch: ACTIF (Requêtes bloquées)' : 'Kill Switch: INACTIF',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isHardLocked ? const Color(0xFFDC2626) : const Color(0xFF059669),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${data.aiTokensMonth} tokens consommés',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Dernières requêtes IA enregistrées',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),
          if (data.aiLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Aucune requête IA enregistrée pour le moment.', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            )
          else
            Column(
              children: data.aiLogs.take(8).map((log) {
                final model = log['model'] ?? 'gemini-1.5-flash';
                final tokens = log['total_tokens'] ?? 0;
                final cost = (log['cost_usd'] as num?)?.toDouble() ?? 0.0;
                final dt = log['created_at']?.toString().split('.')[0] ?? '—';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF6D4CF6)),
                      const SizedBox(width: 10),
                      Text(
                        model,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      Text('$tokens tokens', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      const SizedBox(width: 16),
                      Text(
                        '\$${cost.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 16),
                      Text(dt, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ── TAB 3: UTILISATEURS ──
  Widget _buildUsersTab(SchoolProfileData data) {
    if (data.users.isEmpty) {
      return _buildEmptyState(
        Icons.group_off_outlined,
        'Aucun utilisateur rattaché à cet établissement.',
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 24,
        horizontalMargin: 20,
        headingRowHeight: 42,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 56,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
        headingTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF94A3B8),
        ),
        columns: const [
          DataColumn(label: Text('UTILISATEUR')),
          DataColumn(label: Text('RÔLE')),
          DataColumn(label: Text('EMAIL')),
          DataColumn(label: Text('TÉLÉPHONE')),
          DataColumn(label: Text('STATUT')),
        ],
        rows: data.users.map((u) {
          final fullName = u['full_name'] ?? 'Utilisateur';
          final email = u['email'] ?? '—';
          final phone = u['phone'] ?? '—';
          final role = (u['role'] as String? ?? 'student').toLowerCase();
          final isActive = u['is_active'] == true;

          String roleLabel = 'Élève';
          Color roleColor = const Color(0xFF2563EB);
          Color roleBg = const Color(0xFFEFF6FF);
          if (role == 'teacher') {
            roleLabel = 'Professeur';
            roleColor = const Color(0xFF7C3AED);
            roleBg = const Color(0xFFF5F3FF);
          } else if (role == 'admin' || role == 'director') {
            roleLabel = 'Direction';
            roleColor = const Color(0xFF059669);
            roleBg = const Color(0xFFECFDF5);
          } else if (role == 'staff') {
            roleLabel = 'Manager';
            roleColor = const Color(0xFFD97706);
            roleBg = const Color(0xFFFFFBEB);
          }

          return DataRow(
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: roleBg,
                      child: Text(
                        fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: roleColor),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      fullName,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: roleBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    roleLabel,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: roleColor),
                  ),
                ),
              ),
              DataCell(Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
              DataCell(Text(phone, style: const TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: Color(0xFF64748B)))),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isActive ? 'Actif' : 'Bloqué',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── TAB 4: AUDIT ──
  Widget _buildAuditTab(SchoolProfileData data) {
    if (data.auditLogs.isEmpty) {
      return _buildEmptyState(
        Icons.history_rounded,
        'Aucun événement d\'audit enregistré pour cet établissement.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: data.auditLogs.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
      itemBuilder: (context, i) {
        final log = data.auditLogs[i];
        final action = log['action'] ?? 'ACTION';
        final details = log['details']?.toString() ?? '';
        final dt = log['created_at']?.toString().split('.')[0] ?? '—';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.toString().toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    if (details.isNotEmpty)
                      Text(details, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Text(dt, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════
  // REUSABLE ATOMS & DIALOGS
  // ═══════════════════════════════════════════════════
  Widget _buildSchoolAvatar(Map<String, dynamic> school, {double size = 48}) {
    final logoUrl = (school['logo_url'] as String?)?.trim();
    final name = (school['name'] as String?) ?? 'École';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'E';

    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: Image.network(
          logoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackAvatar(initial, size),
        ),
      );
    }
    return _fallbackAvatar(initial, size);
  }

  Widget _fallbackAvatar(String initial, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9FE),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF6D4CF6),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: const Color(0xFF475569)),
        tooltip: tooltip,
        onPressed: onTap,
        splashRadius: 20,
      ),
    );
  }

  Widget _buildOutlineButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: const Color(0xFF475569)),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFE2E8F0)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.white,
      ),
    );
  }

  Widget _buildStatusToggleButton(SchoolProfileData data) {
    final isActive = data.school['is_active'] == true;
    return ElevatedButton.icon(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final ok = await ref.read(platformProvider.notifier).toggleSchoolStatus(data.school['id'], !isActive);
        if (!mounted) return;
        if (ok) {
          ref.invalidate(schoolProfileDataProvider(widget.schoolId));
          messenger.showSnackBar(
            SnackBar(
              content: Text(isActive ? 'Établissement suspendu.' : 'Établissement réactivé !'),
              backgroundColor: isActive ? ConsoleColors.warning : ConsoleColors.success,
            ),
          );
        }
      },
      icon: Icon(isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 15),
      label: Text(
        isActive ? 'Suspendre' : 'Réactiver',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? const Color(0xFFDC2626) : const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool copyable = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
              ),
            ],
          ),
        ),
        if (copyable)
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copié dans le presse-papier'), duration: Duration(seconds: 1)),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Widget _buildCheckItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF059669)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message, {String? actionLabel, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: const Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6D4CF6),
                  side: const BorderSide(color: Color(0xFFDDD6FE)),
                ),
                child: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(Object error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
            const SizedBox(height: 16),
            Text('Erreur de chargement: $error', style: const TextStyle(color: Color(0xFFDC2626))),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(schoolProfileDataProvider(widget.schoolId)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D4CF6)),
              child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.domain_disabled_rounded, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            const Text(
              'Établissement introuvable',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cet établissement a peut-être été supprimé ou l\'identifiant est invalide.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.go('/schools'),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Retour à la liste'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D4CF6),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // MODAL ACTIONS
  // ═══════════════════════════════════════════════════
  Future<void> _pickAndUploadLogo(String schoolId) async {
    setState(() => _isUploadingLogo = true);
    final url = await ref.read(platformProvider.notifier).pickAndUploadSchoolLogo(schoolId: schoolId);
    if (mounted) {
      setState(() => _isUploadingLogo = false);
      if (url != null) {
        ref.invalidate(schoolProfileDataProvider(widget.schoolId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo mis à jour avec succès!'), backgroundColor: ConsoleColors.success),
        );
      }
    }
  }

  void _openQuotaDialog(SchoolProfileData data) {
    final budgetCtrl = TextEditingController(text: data.aiBudgetUsd.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Modifier Quota IA & Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Budget mensuel USD alloué aux requêtes IA de l\'école:'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: budgetCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    suffixText: 'USD / mois',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDlgState(() => isSaving = true);
                final budgetVal = double.tryParse(budgetCtrl.text.trim()) ?? 25.0;
                final ok = await ref.read(platformProvider.notifier).updateSchoolAiQuota(
                  schoolId: data.school['id'],
                  monthlyBudgetUsd: budgetVal,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted && ok) {
                  ref.invalidate(schoolProfileDataProvider(widget.schoolId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Quota IA mis à jour !'), backgroundColor: ConsoleColors.success),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6D4CF6), foregroundColor: Colors.white),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlanDialog(SchoolProfileData data) {
    final platformState = ref.read(platformProvider);
    final plans = platformState.plans;
    String selectedPlanId = data.plan?['id'] ?? (plans.isNotEmpty ? plans.first['id'] : '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Changer de Forfait', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sélectionnez la formule d\'abonnement :'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedPlanId,
                isExpanded: true,
                items: plans.map((p) {
                  return DropdownMenuItem<String>(
                    value: p['id'] as String,
                    child: Text('${p['name']} — ${p['price_tnd_monthly']} TND/m'),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setDlgState(() => selectedPlanId = v);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                setDlgState(() => isSaving = true);
                final ok = await ref.read(platformProvider.notifier).updateSchoolSubscriptionPlan(
                  schoolId: data.school['id'],
                  planId: selectedPlanId,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted && ok) {
                  ref.invalidate(schoolProfileDataProvider(widget.schoolId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Forfait modifié avec succès !'), backgroundColor: ConsoleColors.success),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }

  void _openInvoiceDialog(SchoolProfileData data) {
    final invNumCtrl = TextEditingController(text: 'FAC-${DateTime.now().year}-${Random().nextInt(9000) + 1000}');
    final amountCtrl = TextEditingController(text: data.mrrTnd.toStringAsFixed(0));
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Générer Facture PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Numéro de facture :'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: invNumCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Montant net (TND) :'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  decoration: InputDecoration(
                    suffixText: 'TND',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                if (!formKey.currentState!.validate()) return;
                setDlgState(() => isSaving = true);
                final amt = double.tryParse(amountCtrl.text.trim()) ?? data.mrrTnd;
                final now = DateTime.now();
                final due = now.add(const Duration(days: 30));

                final res = await ref.read(platformProvider.notifier).createDetailedInvoice(
                  schoolId: data.school['id'],
                  invoiceNumber: invNumCtrl.text.trim(),
                  issueDate: DateFormat('yyyy-MM-dd').format(now),
                  dueDate: DateFormat('yyyy-MM-dd').format(due),
                  clientName: data.school['name'] ?? 'Établissement',
                  issuerName: 'PythaOne SaaS Technologies',
                  issuerCountry: 'Tunisie',
                  matriculeFiscale: '1234567/A/M/000',
                  items: [
                    {
                      'description': 'Abonnement SaaS PythaOne - ${data.plan?['name'] ?? 'Plan Pro'}',
                      'quantity': 1,
                      'unit_price': amt,
                      'total': amt,
                    }
                  ],
                  totalHt: amt,
                  tvaRate: 19.0,
                  tvaAmount: amt * 0.19,
                  timbreFiscal: 1.0,
                  totalTtc: amt * 1.19 + 1.0,
                  netToPay: amt * 1.19 + 1.0,
                  amountInWords: '${amt.toStringAsFixed(0)} dinars tunisiens',
                );

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted && res != null) {
                  ref.invalidate(schoolProfileDataProvider(widget.schoolId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Facture générée avec succès !'), backgroundColor: ConsoleColors.success),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Émettre la facture'),
            ),
          ],
        ),
      ),
    );
  }
}
