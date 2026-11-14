import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/localization/console_translations.dart';
import '../../core/services/invoice_pdf_generator.dart';
import '../../core/theme/console_theme.dart';
import '../providers/console_auth_provider.dart';
import '../providers/platform_provider.dart';
import '../widgets/console_settings_view.dart';
import '../widgets/console_sidebar.dart';
import '../widgets/console_skeleton_loader.dart';

Map<String, dynamic>? _extractRelationMap(dynamic value) {
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

class ConsoleDashboardScreen extends ConsumerStatefulWidget {
  final String currentRoute;
  const ConsoleDashboardScreen({super.key, this.currentRoute = '/dashboard'});

  @override
  ConsumerState<ConsoleDashboardScreen> createState() =>
      _ConsoleDashboardScreenState();
}

class _ConsoleDashboardScreenState
    extends ConsumerState<ConsoleDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _schoolsStatusFilter = 'all'; // 'all', 'active', 'suspended'
  int _schoolsPage = 0;
  int _schoolsPageSize = 10;
  String _bugStatusFilter = 'all'; // 'all', 'open', 'in_progress', 'resolved'
  int _bugsPage = 0;
  int _bugsPageSize = 10;
  String _auditActionFilter = 'all';
  int _auditPage = 0;
  int _auditPageSize = 10;
  int _telemetryPage = 0;
  int _telemetryPageSize = 10;

  @override
  void didUpdateWidget(covariant ConsoleDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentRoute != widget.currentRoute) {
      _searchController.clear();
      _searchQuery = '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(consoleTranslationsProvider);
    final authState = ref.watch(consoleAuthProvider);
    final platformState = ref.watch(platformProvider);

    // While checking/restoring Supabase session on page reload, show skeleton (do NOT kick to login!)
    if (!authState.isInitialized || authState.isLoading) {
      return const Scaffold(
        backgroundColor: ConsoleColors.background,
        body: ConsoleOverviewSkeleton(),
      );
    }

    // Only redirect to /login once initialization is done and user is genuinely not authenticated
    if (!authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return const Scaffold(
        backgroundColor: ConsoleColors.background,
        body: ConsoleOverviewSkeleton(),
      );
    }

    return Scaffold(
      backgroundColor: ConsoleColors.background,
      body: Row(
        children: [
          ConsoleSidebar(currentRoute: widget.currentRoute),
          Expanded(
            child: Column(
              children: [
                _buildPageHeader(authState.user, platformState, tr),
                Expanded(
                  child: platformState.isLoading
                      ? _skeletonForRoute()
                      : platformState.errorMessage != null
                          ? _buildErrorState(platformState.errorMessage!, tr)
                          : _pageForRoute(platformState, tr, authState.user),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletonForRoute() {
    switch (widget.currentRoute) {
      case '/settings':
        return const ConsoleSettingsSkeleton();
      case '/schools':
        return const ConsoleSchoolsSkeleton();
      case '/billing':
        return const ConsoleBillingSkeleton();
      case '/ai-telemetry':
        return const ConsoleAiTelemetrySkeleton();
      case '/audit':
        return const ConsoleAuditSkeleton();
      case '/bugs':
        return const ConsoleBugReportsSkeleton();
      case '/dashboard':
      case '/':
      default:
        return const ConsoleOverviewSkeleton();
    }
  }

  Widget _pageForRoute(
      PlatformState state, ConsoleStrings tr, Map<String, dynamic>? user) {
    switch (widget.currentRoute) {
      case '/settings':
        return ConsoleSettingsView(platformState: state, user: user);
      case '/schools':
        return _buildOverviewPage(state, tr);
      case '/billing':
        return _buildBillingPage(state, tr);
      case '/ai-telemetry':
        return _buildAiTelemetryPage(state, tr);
      case '/audit':
        return _buildAuditPage(state, tr);
      case '/bugs':
        return _buildBugReportsPage(state, tr);
      case '/dashboard':
      case '/':
      default:
        return _buildOverviewPage(state, tr);
    }
  }

  (String, String) _headerMeta(ConsoleStrings tr) {
    switch (widget.currentRoute) {
      case '/settings':
        return (
          tr.headerSettingsTitle,
          tr.headerSettingsSubtitle,
        );
      case '/schools':
        return (
          tr.headerSchoolsTitle,
          tr.headerSchoolsSubtitle,
        );
      case '/billing':
        return (
          tr.headerBillingTitle,
          tr.headerBillingSubtitle,
        );
      case '/ai-telemetry':
        return (
          tr.headerAiTitle,
          tr.headerAiSubtitle,
        );
      case '/audit':
        return (
          tr.headerAuditTitle,
          tr.headerAuditSubtitle,
        );
      case '/bugs':
        return (
          tr.headerBugsTitle,
          tr.headerBugsSubtitle,
        );
      case '/dashboard':
      case '/':
      default:
        return (
          tr.headerOverviewTitle,
          tr.headerOverviewSubtitle,
        );
    }
  }

  Widget _buildPageHeader(
      Map<String, dynamic>? user, PlatformState state, ConsoleStrings tr) {
    final (title, subtitle) = _headerMeta(tr);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: ConsoleColors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: ConsoleColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Exact Documents / Admin search bar
          SizedBox(
            width: 280,
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: tr.searchPlaceholder,
                hintStyle: const TextStyle(
                  color: ConsoleColors.textTertiary,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: ConsoleColors.textTertiary,
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: ConsoleColors.cardBorder),
                          ),
                          child: const Text(
                            '⌘K',
                            style: TextStyle(
                              fontSize: 10,
                              color: ConsoleColors.textTertiary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: ConsoleColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: ConsoleColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: ConsoleColors.brand.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (widget.currentRoute == '/schools' ||
              widget.currentRoute == '/dashboard' ||
              widget.currentRoute == '/') ...[
            const SizedBox(width: 10),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => _showCreateSchoolModal(context, state.plans),
                icon: const Icon(Icons.add_business_outlined, size: 17),
                label: Text(tr.newSchoolBtn),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ConsoleColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
          if (widget.currentRoute == '/billing') ...[
            const SizedBox(width: 10),
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showManualInvoiceModal(context, state.schools),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: Text(tr.manualInvoiceBtn),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ConsoleColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(String message, ConsoleStrings tr) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ConsoleColors.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 44, color: ConsoleColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: ConsoleColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(platformProvider.notifier).loadAll(),
              style: ElevatedButton.styleFrom(
                backgroundColor: ConsoleColors.brand,
                foregroundColor: Colors.white,
              ),
              child: Text(tr.refreshTooltip),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 1. OVERVIEW PAGE & UNIFIED SCHOOLS TABLE
  // ══════════════════════════════════════════════════════════════
  Widget _buildOverviewPage(PlatformState state, ConsoleStrings tr) {
    final kpis = state.kpis;
    final allSchools = state.schools;

    // Filter by search query
    final searchedSchools = allSchools.where((s) {
      if (_searchQuery.isEmpty) return true;
      final name = (s['name'] ?? '').toString().toLowerCase();
      final code = (s['code'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? '').toString().toLowerCase();
      final phone = (s['phone'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          code.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          phone.contains(_searchQuery);
    }).toList();

    // Counts for tabs
    final totalCount = searchedSchools.length;
    final activeCount = searchedSchools.where((s) => s['is_active'] == true).length;
    final suspendedCount = searchedSchools.where((s) => s['is_active'] != true).length;

    // Filter by status tab
    final filteredSchools = searchedSchools.where((s) {
      if (_schoolsStatusFilter == 'active') return s['is_active'] == true;
      if (_schoolsStatusFilter == 'suspended') return s['is_active'] != true;
      return true;
    }).toList();

    // Pagination
    final pageStart = _schoolsPage * _schoolsPageSize;
    final paginatedSchools = filteredSchools.skip(pageStart).take(_schoolsPageSize).toList();

    final realAiSpend = (kpis['aiSpendUsd'] as double? ?? 0.0);
    final realAiTokens = (kpis['aiTokensMonth'] as int? ?? 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KPI METRICS ROW (GOLDEN RATIO SPACING & TYPOGRAPHY) ──
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  tr.kpiActiveSchools,
                  '${kpis['activeSchools'] ?? 0}',
                  '${kpis['totalSchools'] ?? 0} total enregistrées',
                  Icons.domain_rounded,
                  ConsoleColors.primary,
                  trend: '+${kpis['activeSchools'] ?? 0}',
                  trendLabel: 'sur ${kpis['totalSchools'] ?? 0} total',
                  trendUp: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  tr.kpiTotalMrr,
                  '${(kpis['mrrTnd'] as double? ?? 0.0).toStringAsFixed(0)} TND',
                  tr.mrrSubtitle,
                  Icons.trending_up_rounded,
                  ConsoleColors.success,
                  trend: '+8.3%',
                  trendLabel: 'vs mois dernier',
                  trendUp: true,
                  onTap: () => context.go('/billing'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  tr.totalCostUsd,
                  '\$${realAiSpend.toStringAsFixed(4)}',
                  '$realAiTokens tokens • Dépenses réelles API',
                  Icons.auto_awesome_rounded,
                  ConsoleColors.brand,
                  trend: '$realAiTokens',
                  trendLabel: 'tokens ce mois',
                  trendUp: true,
                  onTap: () => context.go('/ai-telemetry'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  tr.pendingInvoicesCount,
                  '${kpis['pendingCount'] ?? 0}',
                  tr.statusPending,
                  Icons.receipt_long_rounded,
                  ConsoleColors.warning,
                  trend: '0%',
                  trendLabel: 'impayés nécessitant relance',
                  trendUp: false,
                  onTap: () => context.go('/billing'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── FLOATING STATUS FILTER PILLS (EXACT USERS SCREEN LAYOUT) ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusChip(
                      'Tous',
                      totalCount,
                      _schoolsStatusFilter == 'all',
                      () => setState(() {
                        _schoolsStatusFilter = 'all';
                        _schoolsPage = 0;
                      }),
                    ),
                    _buildStatusChip(
                      'Actifs',
                      activeCount,
                      _schoolsStatusFilter == 'active',
                      () => setState(() {
                        _schoolsStatusFilter = 'active';
                        _schoolsPage = 0;
                      }),
                    ),
                    _buildStatusChip(
                      'Suspendus',
                      suspendedCount,
                      _schoolsStatusFilter == 'suspended',
                      () => setState(() {
                        _schoolsStatusFilter = 'suspended';
                        _schoolsPage = 0;
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── EXACT USERS PAGE TABLE CONTAINER (NO INNER CARD HEADER) ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  filteredSchools.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.domain_disabled_rounded, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  tr.noSchoolsRegistered,
                                  style: const TextStyle(fontSize: 14, color: ConsoleColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildSchoolsDataTable(paginatedSchools, state),
                  _buildPagination(filteredSchools.length),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // STATUS CHIP (EXACT USERS SCREEN SEGMENTED PILL)
  // ═══════════════════════════════════════════════════
  Widget _buildStatusChip(String label, int count, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: isActive ? const Color(0xFF64748B) : const Color(0xFF94A3B8).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // SCHOOL AVATAR (EXACT USER AVATAR CLONE)
  // ═══════════════════════════════════════════════════
  Widget _buildSchoolAvatar(Map<String, dynamic> school) {
    final logoUrl = (school['logo_url'] as String?)?.trim();
    final name = (school['name'] as String?) ?? 'École';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'E';

    const pastelBgs = [
      Color(0xFFEDE9FE),
      Color(0xFFE0E7FF),
      Color(0xFFDCFCE7),
      Color(0xFFFEF3C7),
      Color(0xFFFCE7F3),
      Color(0xFFE0F2FE),
    ];
    const textColors = [
      Color(0xFF6D28D9),
      Color(0xFF4338CA),
      Color(0xFF15803D),
      Color(0xFFB45309),
      Color(0xFFBE185D),
      Color(0xFF0369A1),
    ];

    final colorIndex = name.hashCode.abs() % pastelBgs.length;
    final bg = pastelBgs[colorIndex];
    final fg = textColors[colorIndex];

    if (logoUrl != null && logoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          logoUrl,
          width: 34,
          height: 34,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => CircleAvatar(
            radius: 17,
            backgroundColor: bg,
            child: Text(
              initial,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 17,
      backgroundColor: bg,
      child: Text(
        initial,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // SCHOOLS DATA TABLE (EACH INFO IN ITS OWN COLUMN)
  // ═══════════════════════════════════════════════════
  Widget _buildSchoolsDataTable(List<Map<String, dynamic>> paginatedSchools, PlatformState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const schoolW = 220.0;
        const codeW = 110.0;
        const emailW = 210.0;
        const phoneW = 120.0;
        const planW = 110.0;
        const priceW = 110.0;
        const quotaW = 125.0;
        const statusW = 85.0;
        const createdW = 80.0;
        const actionsW = 44.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: availableWidth),
            child: DataTable(
              columnSpacing: 0,
              horizontalMargin: 0,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 60,
              headingRowHeight: 44,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
                fontSize: 11,
                letterSpacing: 0.5,
              ),
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              dividerThickness: 0.0001,
              showCheckboxColumn: false,
              columns: [
                DataColumn(label: SizedBox(width: schoolW, child: _headerLabel('ÉTABLISSEMENT'))),
                DataColumn(label: SizedBox(width: codeW, child: _headerLabel('CODE'))),
                DataColumn(label: SizedBox(width: emailW, child: _headerLabel('EMAIL DIRECTEUR'))),
                DataColumn(label: SizedBox(width: phoneW, child: _headerLabel('TÉLÉPHONE'))),
                DataColumn(label: SizedBox(width: planW, child: _headerLabel('FORFAIT'))),
                DataColumn(label: SizedBox(width: priceW, child: _headerLabel('TARIF'))),
                DataColumn(label: SizedBox(width: quotaW, child: _headerLabel('QUOTA IA'))),
                DataColumn(label: SizedBox(width: statusW, child: _headerLabel('STATUT'))),
                DataColumn(label: SizedBox(width: createdW, child: _headerLabel('CRÉÉ LE'))),
                DataColumn(label: SizedBox(width: actionsW, child: Container())),
              ],
              rows: paginatedSchools.map((s) {
                final sub = _extractRelationMap(s['school_subscriptions']);
                final plan = _extractRelationMap(sub?['plan']);
                final quota = _extractRelationMap(s['ai_school_quotas']);
                final isActive = s['is_active'] == true;
                final spent = (quota?['spent_current_month_usd'] as num?)?.toDouble() ?? 0.0;
                final budget = (quota?['monthly_budget_usd'] as num?)?.toDouble() ?? 25.0;
                final isQuotaExceeded = quota?['is_quota_exceeded'] == true || spent >= budget;

                final directorPhone = s['phone'] as String?;
                final email = s['email'] as String? ?? '—';

                String formattedCreated = '—';
                if (s['created_at'] != null) {
                  try {
                    final dt = DateTime.parse(s['created_at'].toString());
                    formattedCreated = DateFormat('dd/MM/yy').format(dt);
                  } catch (_) {
                    formattedCreated = s['created_at'].toString().split('T')[0];
                  }
                }

                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (states.contains(WidgetState.hovered)) return const Color(0xFFF9FAFB);
                    return null;
                  }),
                  cells: [
                    // 1. Établissement (Avatar + Nom)
                    DataCell(
                      SizedBox(
                        width: schoolW,
                        child: Row(
                          children: [
                            _buildSchoolAvatar(s),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 2. Code (Single Pill)
                    DataCell(
                      SizedBox(
                        width: codeW,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (s['code'] ?? '—').toString().toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 3. Email Directeur
                    DataCell(
                      SizedBox(
                        width: emailW,
                        child: Text(
                          email,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // 4. Téléphone
                    DataCell(
                      SizedBox(
                        width: phoneW,
                        child: Text(
                          (directorPhone != null && directorPhone.isNotEmpty) ? directorPhone : '—',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // 5. Forfait (Single Pill)
                    DataCell(
                      SizedBox(
                        width: planW,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              plan?['name'] ?? 'Plan Pro',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7C3AED),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 6. Tarif
                    DataCell(
                      SizedBox(
                        width: priceW,
                        child: Text(
                          '${plan?['price_tnd_monthly'] ?? 850} TND / mois',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // 7. Quota IA
                    DataCell(
                      SizedBox(
                        width: quotaW,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${spent.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isQuotaExceeded ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              ' / \$${budget.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 8. Statut (Single Pill)
                    DataCell(
                      SizedBox(
                        width: statusW,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isActive ? 'Actif' : 'Suspendu',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: isActive ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 9. Créé le
                    DataCell(
                      SizedBox(
                        width: createdW,
                        child: Text(
                          formattedCreated,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ),
                    // 10. Actions (3 dots)
                    DataCell(
                      SizedBox(
                        width: actionsW,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz, size: 18, color: Color(0xFF94A3B8)),
                          tooltip: 'Actions',
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: const Color(0xFFE2E8F0).withValues(alpha: 0.6)),
                          ),
                          elevation: 6,
                          shadowColor: Colors.black.withValues(alpha: 0.08),
                          offset: const Offset(-160, 40),
                          onSelected: (val) async {
                            switch (val) {
                              case 'quota':
                                _showEditAiQuotaModal(context, s);
                                break;
                              case 'invoice':
                                _showInvoiceGeneratorModal(
                                  context,
                                  state.schools,
                                  preselectedSchoolId: s['id'],
                                );
                                break;
                              case 'logo':
                                _showSchoolLogoModal(context, s);
                                break;
                              case 'plan':
                                _showChangePlanModal(context, s, state.plans);
                                break;
                              case 'toggle_status':
                                final messenger = ScaffoldMessenger.of(context);
                                final ok = await ref
                                    .read(platformProvider.notifier)
                                    .toggleSchoolStatus(s['id'], !isActive);
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? (isActive
                                            ? 'Établissement suspendu.'
                                            : 'Établissement réactivé !')
                                        : 'Erreur lors du changement de statut.'),
                                    backgroundColor: ok
                                        ? (isActive ? ConsoleColors.warning : ConsoleColors.success)
                                        : ConsoleColors.error,
                                  ),
                                );
                                break;
                            }
                          },
                          itemBuilder: (_) => [
                            _buildPopupItem('quota', Icons.auto_awesome_rounded, 'Modifier Quota IA & Budget', const Color(0xFF6D4CF6)),
                            _buildPopupItem('invoice', Icons.picture_as_pdf_rounded, 'Générer Facture PDF', const Color(0xFF059669)),
                            _buildPopupItem('logo', Icons.image_outlined, 'Changer le Logo', const Color(0xFF2563EB)),
                            _buildPopupItem('plan', Icons.card_membership_rounded, 'Changer de Forfait', const Color(0xFF7C3AED)),
                            const PopupMenuItem<String>(
                              enabled: false,
                              height: 9,
                              padding: EdgeInsets.zero,
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0xFFF1F5F9),
                              ),
                            ),
                            _buildPopupItem(
                              'toggle_status',
                              isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                              isActive ? 'Suspendre l\'école' : 'Réactiver l\'école',
                              isActive ? const Color(0xFFDC2626) : const Color(0xFF059669),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════
  // PAGINATION (CLEAN BORDERLESS ARROWS)
  // ═══════════════════════════════════════════════════
  Widget _buildPagination(int totalItems) {
    final totalPages = _schoolsPageSize == -1 ? 1 : (totalItems / _schoolsPageSize).ceil();
    final currentPageDisplay = _schoolsPage + 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFB),
        border: Border(top: BorderSide(color: const Color(0xFFE2E8F0).withValues(alpha: 0.5))),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          // Items per page
          const Text('Afficher par ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _schoolsPageSize,
                isDense: true,
                borderRadius: BorderRadius.circular(10),
                dropdownColor: Colors.white,
                elevation: 4,
                menuMaxHeight: 200,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF94A3B8)),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                items: [5, 10, 20, 50].map((v) => DropdownMenuItem(
                  value: v,
                  child: Text('$v', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                )).toList(),
                onChanged: (v) => setState(() {
                  _schoolsPageSize = v!;
                  _schoolsPage = 0;
                }),
              ),
            ),
          ),
          const Spacer(),
          // Page info
          Text(
            'Page $currentPageDisplay sur ${totalPages == 0 ? 1 : totalPages}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(width: 8),
          // Prev/Next (Clean borderless arrow buttons)
          Row(
            children: [
              IconButton(
                onPressed: _schoolsPage > 0 ? () => setState(() => _schoolsPage--) : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                color: const Color(0xFF334155),
                disabledColor: const Color(0xFFCBD5E1),
                splashRadius: 18,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: (_schoolsPage + 1) < totalPages ? () => setState(() => _schoolsPage++) : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                color: const Color(0xFF334155),
                disabledColor: const Color(0xFFCBD5E1),
                splashRadius: 18,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, IconData icon, String label, Color color) {
    return PopupMenuItem(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: value == 'toggle_status' ? color : const Color(0xFF1E293B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChipItem({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    Color activeColor = const Color(0xFF6D4CF6),
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor.withValues(alpha: 0.35) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor.withValues(alpha: 0.15) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? activeColor : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTablePaginationBar({
    required int totalItems,
    required int currentPage,
    required int pageSize,
    required ValueChanged<int> onPageChanged,
    required ValueChanged<int> onPageSizeChanged,
  }) {
    final totalPages = (totalItems / pageSize).ceil();
    final startIdx = totalItems == 0 ? 0 : currentPage * pageSize + 1;
    final endIdx = ((currentPage + 1) * pageSize).clamp(0, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFB),
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          const Text('Afficher par ', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: pageSize,
                isDense: true,
                borderRadius: BorderRadius.circular(8),
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                  DropdownMenuItem(value: 10, child: Text('10', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                  DropdownMenuItem(value: 20, child: Text('20', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                  DropdownMenuItem(value: 50, child: Text('50', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                ],
                onChanged: (v) {
                  if (v != null) onPageSizeChanged(v);
                },
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            totalItems == 0 ? '0 résultat' : '$startIdx–$endIdx sur $totalItems',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Spacer(),
          Text(
            'Page ${totalPages == 0 ? 1 : currentPage + 1} sur ${totalPages == 0 ? 1 : totalPages}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: currentPage > 0 ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
                Container(width: 1, height: 22, color: const Color(0xFFE2E8F0)),
                InkWell(
                  onTap: (currentPage + 1) < totalPages ? () => onPageChanged(currentPage + 1) : null,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: (currentPage + 1) < totalPages ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildSectionIndicator(String title) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF6D4CF6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: Color(0xFF4B5563),
          ),
        ),
      ],
    );
  }

  void _showEditAiQuotaModal(BuildContext context, Map<String, dynamic> school) {
    final schoolId = school['id'] as String;
    final schoolName = school['name'] as String? ?? 'Établissement';
    final quota = _extractRelationMap(school['ai_school_quotas']);
    final currentBudget = (quota?['monthly_budget_usd'] as num?)?.toDouble() ?? 25.0;
    final currentSpent = (quota?['spent_current_month_usd'] as num?)?.toDouble() ?? 0.0;
    final currentDaily = (quota?['daily_messages_per_student'] as num?)?.toInt() ?? 30;
    final currentKill = quota?['kill_switch_enabled'] == true;

    final budgetCtrl = TextEditingController(text: currentBudget.toStringAsFixed(2));
    final dailyCtrl = TextEditingController(text: currentDaily.toString());
    bool killSwitch = currentKill;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: StatefulBuilder(
          builder: (sbContext, setSbState) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: ConsoleColors.brandSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: ConsoleColors.brand, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Quota & Budget IA — $schoolName',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ConsoleColors.textPrimary)),
                            const SizedBox(height: 3),
                            Text('Dépenses actuelles ce mois: \$${currentSpent.toStringAsFixed(4)} USD',
                                style: const TextStyle(fontSize: 12, color: ConsoleColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionIndicator('BUDGET MENSUEL MAXIMUM (USD)'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: budgetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      hintText: '25.00',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSectionIndicator('MESSAGES PAR ÉTUDIANT / JOUR'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dailyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '30',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: killSwitch ? ConsoleColors.errorSoft : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: killSwitch ? ConsoleColors.error : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Arrêt d\'urgence IA (Kill Switch École)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: killSwitch ? ConsoleColors.error : ConsoleColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Désactive immédiatement l\'accès à l\'IA pour cet établissement.',
                                style: TextStyle(fontSize: 11.5, color: ConsoleColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: killSwitch,
                          activeThumbColor: ConsoleColors.error,
                          onChanged: (val) => setSbState(() => killSwitch = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 40,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF6B7280)),
                          child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () async {
                            final budget = double.tryParse(budgetCtrl.text.trim()) ?? currentBudget;
                            final daily = int.tryParse(dailyCtrl.text.trim()) ?? currentDaily;
                            Navigator.pop(ctx);
                            final ok = await ref.read(platformProvider.notifier).updateSchoolAiQuota(
                              schoolId: schoolId,
                              monthlyBudgetUsd: budget,
                              dailyMessagesPerStudent: daily,
                              killSwitchEnabled: killSwitch,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? 'Quota IA mis à jour avec succès !' : 'Erreur mise à jour quota.'),
                                backgroundColor: ok ? ConsoleColors.success : ConsoleColors.error,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D4CF6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text('Enregistrer le Quota', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showChangePlanModal(BuildContext context, Map<String, dynamic> school, List<Map<String, dynamic>> plans) {
    if (plans.isEmpty) return;
    final schoolId = school['id'] as String;
    final schoolName = school['name'] as String? ?? 'Établissement';
    final sub = _extractRelationMap(school['school_subscriptions']);
    String selectedPlanId = sub?['plan_id'] as String? ?? plans.first['id'] as String;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.15),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: StatefulBuilder(
          builder: (sbContext, setSbState) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: ConsoleColors.brandSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.card_membership_rounded, color: ConsoleColors.brand, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Changer le Forfait — $schoolName',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ConsoleColors.textPrimary)),
                            const SizedBox(height: 3),
                            const Text('Sélectionnez la nouvelle formule d\'abonnement.',
                                style: TextStyle(fontSize: 12, color: ConsoleColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionIndicator('CHOISIR UNE FORMULE D\'ABONNEMENT'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: plans.any((p) => p['id'] == selectedPlanId) ? selectedPlanId : plans.first['id'],
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                    ),
                    items: plans.map((p) {
                      return DropdownMenuItem<String>(
                        value: p['id'] as String,
                        child: Text('${p['name']} (${p['price_tnd_monthly']} TND/mois)'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setSbState(() => selectedPlanId = val);
                    },
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 40,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF6B7280)),
                          child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final ok = await ref.read(platformProvider.notifier).updateSchoolSubscriptionPlan(
                              schoolId: schoolId,
                              planId: selectedPlanId,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? 'Forfait mis à jour avec succès !' : 'Erreur mise à jour forfait.'),
                                backgroundColor: ok ? ConsoleColors.success : ConsoleColors.error,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D4CF6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text('Confirmer le changement', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 3. BILLING PAGE
  // ══════════════════════════════════════════════════════════════
  Widget _buildBillingPage(PlatformState state, ConsoleStrings tr) {
    final pending = state.pendingPayments;
    final allInvoices = state.invoices;

    final searchedInvoices = allInvoices.where((inv) {
      if (_searchQuery.isEmpty) return true;
      final num = (inv['invoice_number'] ?? '').toString().toLowerCase();
      final sName = ((inv['school'] as Map?)?['name'] ?? '').toString().toLowerCase();
      return num.contains(_searchQuery) || sName.contains(_searchQuery);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── PENDING PAYMENTS ──
          if (pending.isNotEmpty) ...[
            _surfaceCard(
              title: 'Vérification des Virements en Attente (${pending.length})',
              child: Column(
                children: pending.map((p) {
                  final inv = p['invoice'] as Map<String, dynamic>?;
                  final school = inv?['school'] as Map<String, dynamic>?;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ConsoleColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6D4CF6).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: ConsoleColors.brandSoft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_outlined,
                            color: Color(0xFF6D4CF6),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${school?['name'] ?? "École"} — Facture N° ${inv?['invoice_number'] ?? ""}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: ConsoleColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Réf transaction: ${p['transaction_ref'] ?? "N/A"} • Montant déclaré: ${p['amount']} TND',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ConsoleColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final ok = await ref
                                  .read(platformProvider.notifier)
                                  .verifyPayment(p['id']);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? 'Paiement validé avec succès !'
                                      : 'Erreur lors de la validation du paiement.'),
                                  backgroundColor: ok
                                      ? ConsoleColors.success
                                      : ConsoleColors.error,
                                ),
                              );
                            },
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Valider & Marquer Payé', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ConsoleColors.success,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── INVOICES TABLE MATCHING USERS TABLE ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ConsoleColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Historique des Factures Émises (${searchedInvoices.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: ConsoleColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Factures officielles conformes avec timbre fiscal et arrêté légal en toutes lettres.',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: () => _showInvoiceGeneratorModal(context, state.schools),
                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                          label: const Text('Nouvelle Facture PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D4CF6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: ConsoleColors.divider),

                searchedInvoices.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text(
                                'Aucune facture enregistrée pour l\'instant.',
                                style: TextStyle(fontSize: 14, color: ConsoleColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          headingRowHeight: 46,
                          dataRowMinHeight: 60,
                          dataRowMaxHeight: 64,
                          horizontalMargin: 24,
                          columnSpacing: 28,
                          columns: const [
                            DataColumn(label: Text('N° FACTURE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('ÉTABLISSEMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('MONTANT TOTAL TTC', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('DATE ÉCHÉANCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('STATUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                          ],
                          rows: searchedInvoices.map((inv) {
                            final school = inv['school'] as Map<String, dynamic>?;
                            final schoolName = school?['name']?.toString() ?? 'École';
                            final invNum = inv['invoice_number']?.toString() ?? 'FAC-2026';
                            final amount = (inv['amount'] as num?)?.toDouble() ?? 0.0;
                            final currency = inv['currency']?.toString() ?? 'TND';
                            final dueDate = inv['due_date']?.toString() ?? '—';
                            final status = inv['status']?.toString() ?? 'issued';

                            return DataRow(
                              cells: [
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      invNum,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        color: ConsoleColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    schoolName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: ConsoleColors.textPrimary),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '${InvoicePdfGenerator.formatTnd(amount)} $currency',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: Color(0xFF6D4CF6),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(dueDate, style: const TextStyle(color: ConsoleColors.textSecondary, fontSize: 12.5)),
                                ),
                                DataCell(_buildStatusBadge(status)),
                                DataCell(
                                  SizedBox(
                                    height: 32,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final invoiceData = InvoiceDataModel(
                                          invoiceNumber: invNum,
                                          date: DateTime.tryParse(inv['issue_date']?.toString() ?? '') ?? DateTime.now(),
                                          issuerName: 'Aziz Tounsi',
                                          matriculeFiscale: '2007778S',
                                          clientName: schoolName,
                                          timbreFiscal: 1.0,
                                          items: [
                                            InvoiceItemModel(
                                              index: 1,
                                              ref: 'P-0001',
                                              designation: 'Abonnement Plateforme Académique SaaS',
                                              quantity: 1,
                                              unitPriceHt: amount > 1.0 ? amount - 1.0 : amount,
                                              tvaPercent: 0.0,
                                            ),
                                          ],
                                        );
                                        await InvoicePdfGenerator.downloadOrPrintInvoice(invoiceData);
                                      },
                                      icon: const Icon(Icons.download_rounded, size: 14),
                                      label: const Text('Télécharger PDF', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF6D4CF6),
                                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 4. AI TELEMETRY PAGE
  // ══════════════════════════════════════════════════════════════
  Widget _buildAiTelemetryPage(PlatformState state, ConsoleStrings tr) {
    final settings = state.platformSettings;
    final killSwitch = settings?['global_ai_kill_switch'] == true;
    final allLogs = state.recentAiLogs;

    final filteredLogs = allLogs.where((l) {
      if (_searchQuery.isEmpty) return true;
      final model = (l['model'] ?? '').toString().toLowerCase();
      final sName = ((l['school'] as Map?)?['name'] ?? '').toString().toLowerCase();
      return model.contains(_searchQuery) || sName.contains(_searchQuery);
    }).toList();

    final pageStart = _telemetryPage * _telemetryPageSize;
    final paginatedLogs = filteredLogs.skip(pageStart).take(_telemetryPageSize).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── KILL SWITCH ALERT ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: killSwitch ? ConsoleColors.errorSoft : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: killSwitch ? ConsoleColors.error : ConsoleColors.cardBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: killSwitch
                        ? ConsoleColors.error.withValues(alpha: 0.14)
                        : ConsoleColors.successSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    killSwitch ? Icons.power_off : Icons.power,
                    color: killSwitch ? ConsoleColors.error : ConsoleColors.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        killSwitch
                            ? 'Kill Switch IA Général Activé — Requêtes Bloquées'
                            : 'Passerelle IA Active & Opérationnelle',
                        style: TextStyle(
                          color: killSwitch ? ConsoleColors.error : ConsoleColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        killSwitch
                            ? 'Toutes les requêtes Gemini/OpenAI des étudiants et professeurs sont actuellement suspendues.'
                            : 'Supervisez la consommation en jetons et les dépenses réelles API par établissement.',
                        style: const TextStyle(
                          color: ConsoleColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: killSwitch,
                  activeThumbColor: ConsoleColors.error,
                  onChanged: (val) =>
                      ref.read(platformProvider.notifier).toggleAiKillSwitch(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── TELEMETRY LOGS TABLE ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ConsoleColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Consommation IA & Télémétrie (${filteredLogs.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: ConsoleColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Coûts réels en dollars calculés sur les tokens d\'entrée/sortie et latences relevées.',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: ConsoleColors.divider),

                filteredLogs.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_outlined, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text(
                                'Aucun log de télémétrie IA enregistré pour le moment.',
                                style: TextStyle(fontSize: 14, color: ConsoleColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          headingRowHeight: 46,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 60,
                          horizontalMargin: 24,
                          columnSpacing: 28,
                          columns: const [
                            DataColumn(label: Text('ÉTABLISSEMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('MODÈLE IA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('JETONS CONSOMMÉS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('COÛT RÉEL (USD)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('LATENCE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('STATUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                          ],
                          rows: paginatedLogs.map((l) {
                            final school = l['school'] as Map<String, dynamic>?;
                            final cost = (l['cost_usd'] as num?)?.toDouble() ?? 0.0;
                            final model = l['model']?.toString() ?? 'gemini-1.5-flash';
                            final tokens = l['total_tokens'] ?? 0;
                            final latency = l['latency_ms'] ?? '—';
                            final status = l['status']?.toString() ?? 'success';

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    school?['name'] ?? 'Plateforme',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: ConsoleColors.textPrimary),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      model,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(Text('$tokens tokens', style: const TextStyle(fontSize: 12.5))),
                                DataCell(
                                  Text(
                                    '\$${cost.toStringAsFixed(5)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: ConsoleColors.success,
                                    ),
                                  ),
                                ),
                                DataCell(Text('$latency ms', style: const TextStyle(color: ConsoleColors.textSecondary, fontSize: 12))),
                                DataCell(_buildStatusBadge(status)),
                                DataCell(
                                  school != null
                                      ? IconButton(
                                          icon: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF6D4CF6)),
                                          tooltip: 'Ajuster le quota de cette école',
                                          onPressed: () => _showEditAiQuotaModal(context, school),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),

                _buildTablePaginationBar(
                  totalItems: filteredLogs.length,
                  currentPage: _telemetryPage,
                  pageSize: _telemetryPageSize,
                  onPageChanged: (newPage) => setState(() => _telemetryPage = newPage),
                  onPageSizeChanged: (newSize) => setState(() {
                    _telemetryPageSize = newSize;
                    _telemetryPage = 0;
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 5. AUDIT PAGE
  // ══════════════════════════════════════════════════════════════
  Widget _buildAuditPage(PlatformState state, ConsoleStrings tr) {
    final allLogs = state.auditLogs;

    final filteredLogs = allLogs.where((a) {
      final act = (a['action'] ?? '').toString().toLowerCase();
      final tbl = (a['target_table'] ?? '').toString().toLowerCase();
      final role = (a['actor_role'] ?? '').toString().toLowerCase();

      if (_auditActionFilter != 'all') {
        if (!act.contains(_auditActionFilter) && !tbl.contains(_auditActionFilter)) {
          return false;
        }
      }

      if (_searchQuery.isEmpty) return true;
      return act.contains(_searchQuery) || tbl.contains(_searchQuery) || role.contains(_searchQuery);
    }).toList();

    final pageStart = _auditPage * _auditPageSize;
    final paginatedLogs = filteredLogs.skip(pageStart).take(_auditPageSize).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ConsoleColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Journaux d\'Audit Système (${filteredLogs.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ConsoleColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Historique immuable de toutes les actions administratives et de sécurité.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _buildFilterChipItem(
                        label: 'Tous',
                        count: allLogs.length,
                        isSelected: _auditActionFilter == 'all',
                        onTap: () => setState(() {
                          _auditActionFilter = 'all';
                          _auditPage = 0;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChipItem(
                        label: 'Auth',
                        count: allLogs.where((l) => (l['action'] ?? '').toString().contains('login') || (l['target_table'] ?? '').toString().contains('user')).length,
                        isSelected: _auditActionFilter == 'auth',
                        onTap: () => setState(() {
                          _auditActionFilter = 'auth';
                          _auditPage = 0;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChipItem(
                        label: 'Écoles',
                        count: allLogs.where((l) => (l['target_table'] ?? '').toString().contains('school')).length,
                        isSelected: _auditActionFilter == 'school',
                        onTap: () => setState(() {
                          _auditActionFilter = 'school';
                          _auditPage = 0;
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: ConsoleColors.divider),

            filteredLogs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                            'Aucun log d\'audit ne correspond à vos filtres.',
                            style: TextStyle(fontSize: 14, color: ConsoleColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      headingRowHeight: 46,
                      dataRowMinHeight: 56,
                      dataRowMaxHeight: 60,
                      horizontalMargin: 24,
                      columnSpacing: 28,
                      columns: const [
                        DataColumn(label: Text('HORODATAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                        DataColumn(label: Text('ÉTABLISSEMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                        DataColumn(label: Text('ACTEUR / RÔLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                        DataColumn(label: Text('ACTION EFFECTUÉE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                        DataColumn(label: Text('TABLE CIBLE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                      ],
                      rows: paginatedLogs.map((a) {
                        final school = a['school'] as Map<String, dynamic>?;
                        final date = a['created_at'] != null
                            ? a['created_at'].toString().split('.')[0].replaceFirst('T', ' ')
                            : '—';
                        final role = a['actor_role'] ?? 'super_admin';
                        final act = a['action'] ?? 'ACTION';
                        final tbl = a['target_table'] ?? 'system';

                        return DataRow(
                          cells: [
                            DataCell(Text(date, style: const TextStyle(fontSize: 12, color: ConsoleColors.textSecondary))),
                            DataCell(Text(school?['name'] ?? 'Plateforme', style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  role.toString().toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF6D4CF6),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(act, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(tbl, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

            _buildTablePaginationBar(
              totalItems: filteredLogs.length,
              currentPage: _auditPage,
              pageSize: _auditPageSize,
              onPageChanged: (newPage) => setState(() => _auditPage = newPage),
              onPageSizeChanged: (newSize) => setState(() {
                _auditPageSize = newSize;
                _auditPage = 0;
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 6. BUG REPORTS PAGE (MATCHING ANNOUNCEMENTS TABLE)
  // ══════════════════════════════════════════════════════════════
  Widget _buildBugReportsPage(PlatformState state, ConsoleStrings tr) {
    final allReports = state.bugReports;

    final totalCount = allReports.length;
    final openCount = allReports.where((b) => b['status'] == 'open' || b['status'] == 'sent').length;
    final inProgressCount = allReports.where((b) => b['status'] == 'in_progress').length;
    final resolvedCount = allReports.where((b) => b['status'] == 'resolved' || b['status'] == 'closed').length;

    final filteredReports = allReports.where((b) {
      final status = (b['status'] ?? 'open').toString().toLowerCase();
      if (_bugStatusFilter == 'open' && (status != 'open' && status != 'sent')) return false;
      if (_bugStatusFilter == 'in_progress' && status != 'in_progress') return false;
      if (_bugStatusFilter == 'resolved' && (status != 'resolved' && status != 'closed')) return false;

      if (_searchQuery.isEmpty) return true;
      final t = (b['title'] ?? '').toString().toLowerCase();
      final d = (b['description'] ?? '').toString().toLowerCase();
      final s = (b['student_name'] ?? '').toString().toLowerCase();
      final phone = (b['student_phone'] ?? '').toString().toLowerCase();
      return t.contains(_searchQuery) || d.contains(_searchQuery) || s.contains(_searchQuery) || phone.contains(_searchQuery);
    }).toList();

    final pageStart = _bugsPage * _bugsPageSize;
    final paginatedReports = filteredReports.skip(pageStart).take(_bugsPageSize).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── METRIC CARDS ──
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Tickets',
                  '$totalCount',
                  'Signalements reçus',
                  Icons.bug_report_outlined,
                  ConsoleColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'En Attente',
                  '$openCount',
                  'À analyser & qualifier',
                  Icons.error_outline,
                  ConsoleColors.error,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'En Cours',
                  '$inProgressCount',
                  'En investigation active',
                  Icons.hourglass_top_rounded,
                  ConsoleColors.warning,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Résolus',
                  '$resolvedCount',
                  'Corrigés et validés',
                  Icons.check_circle_outline,
                  ConsoleColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── BUG REPORTS TABLE (MATCHING ANNOUNCEMENTS TABLE) ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ConsoleColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Signalements de Bugs & Retours Utilisateurs (${filteredReports.length})',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: ConsoleColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Consultez les détails, coordonnées directes de l\'étudiant et captures d\'écran associées.',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      // Filter tabs: Tous / En attente / En cours / Résolus
                      Row(
                        children: [
                          _buildFilterChipItem(
                            label: 'Tous',
                            count: totalCount,
                            isSelected: _bugStatusFilter == 'all',
                            onTap: () => setState(() {
                              _bugStatusFilter = 'all';
                              _bugsPage = 0;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChipItem(
                            label: 'En attente',
                            count: openCount,
                            isSelected: _bugStatusFilter == 'open',
                            activeColor: ConsoleColors.error,
                            onTap: () => setState(() {
                              _bugStatusFilter = 'open';
                              _bugsPage = 0;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChipItem(
                            label: 'En cours',
                            count: inProgressCount,
                            isSelected: _bugStatusFilter == 'in_progress',
                            activeColor: ConsoleColors.warning,
                            onTap: () => setState(() {
                              _bugStatusFilter = 'in_progress';
                              _bugsPage = 0;
                            }),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChipItem(
                            label: 'Résolus',
                            count: resolvedCount,
                            isSelected: _bugStatusFilter == 'resolved',
                            activeColor: ConsoleColors.success,
                            onTap: () => setState(() {
                              _bugStatusFilter = 'resolved';
                              _bugsPage = 0;
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: ConsoleColors.divider),

                filteredReports.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              const Text(
                                'Aucun ticket de bug dans cette catégorie.',
                                style: TextStyle(fontSize: 14, color: ConsoleColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          headingRowHeight: 46,
                          dataRowMinHeight: 64,
                          dataRowMaxHeight: 68,
                          horizontalMargin: 24,
                          columnSpacing: 28,
                          columns: const [
                            DataColumn(label: Text('ÉTABLISSEMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('RAPPORTEUR & CONTACT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('CATÉGORIE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('TITRE DU SIGNALEMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('STATUT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4B5563)))),
                          ],
                          rows: paginatedReports.map((bug) {
                            final id = bug['id']?.toString() ?? '';
                            final title = bug['title']?.toString() ?? 'Sans titre';
                            final category = bug['category']?.toString() ?? 'Général';
                            final status = bug['status']?.toString().toLowerCase() ?? 'open';
                            final studentName = bug['student_name']?.toString() ?? 'Utilisateur anonyme';
                            final studentPhone = bug['student_phone']?.toString();
                            final schoolName = bug['schools']?['name']?.toString() ?? bug['school_id']?.toString() ?? 'École';
                            final createdAt = bug['created_at'] != null ? bug['created_at'].toString().split('T')[0] : '—';
                            final isFallback = bug['_source'] == 'suggestions';

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(schoolName, style: const TextStyle(fontWeight: FontWeight.w600, color: ConsoleColors.textPrimary)),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        studentName,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ConsoleColors.textPrimary),
                                      ),
                                      if (studentPhone != null && studentPhone.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF6D4CF6)),
                                            const SizedBox(width: 4),
                                            Text(
                                              studentPhone,
                                              style: const TextStyle(fontSize: 11.5, color: ConsoleColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: ConsoleColors.brandSoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      category.toUpperCase(),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6D4CF6)),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 240),
                                    child: Text(
                                      title,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  PopupMenuButton<String>(
                                    initialValue: status,
                                    tooltip: 'Changer le statut',
                                    onSelected: (val) => ref.read(platformProvider.notifier).updateBugReportStatus(id, val, isFallback: isFallback),
                                    child: _buildBugStatusBadge(status),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'open', child: Text('Marquer En attente')),
                                      PopupMenuItem(value: 'in_progress', child: Text('Marquer En cours')),
                                      PopupMenuItem(value: 'resolved', child: Text('Marquer Résolu')),
                                      PopupMenuItem(value: 'closed', child: Text('Marquer Fermé')),
                                    ],
                                  ),
                                ),
                                DataCell(Text(createdAt, style: const TextStyle(fontSize: 12, color: ConsoleColors.textSecondary))),
                                DataCell(
                                  SizedBox(
                                    height: 32,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _showBugDetailModal(context, bug),
                                      icon: const Icon(Icons.visibility_outlined, size: 14),
                                      label: const Text('Détails', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFF1F5F9),
                                        foregroundColor: const Color(0xFF334155),
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),

                _buildTablePaginationBar(
                  totalItems: filteredReports.length,
                  currentPage: _bugsPage,
                  pageSize: _bugsPageSize,
                  onPageChanged: (newPage) => setState(() => _bugsPage = newPage),
                  onPageSizeChanged: (newSize) => setState(() {
                    _bugsPageSize = newSize;
                    _bugsPage = 0;
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBugDetailModal(BuildContext context, Map<String, dynamic> bug) {
    final id = bug['id']?.toString() ?? '';
    final title = bug['title']?.toString() ?? 'Sans titre';
    final desc = bug['description']?.toString() ?? 'Aucune description fournie.';
    final category = bug['category']?.toString() ?? 'Général';
    final status = bug['status']?.toString().toLowerCase() ?? 'open';
    final studentName = bug['student_name']?.toString() ?? 'Étudiant anonyme';
    final studentCode = bug['student_code']?.toString();
    final studentPhone = bug['student_phone']?.toString();
    final studentEmail = bug['student_email']?.toString();
    final schoolName = bug['schools']?['name']?.toString() ?? bug['school_id']?.toString() ?? 'Non spécifié';
    final createdAt = bug['created_at']?.toString() ?? '—';
    final isFallback = bug['_source'] == 'suggestions';
    final screenshotUrl = (bug['screenshot_url'] ?? bug['attachment_url'])?.toString();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: 620,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ConsoleColors.brandSoft,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF6D4CF6)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: ConsoleColors.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: ConsoleColors.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionIndicator('Coordonnées du Rapporteur'),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_rounded, size: 17, color: Color(0xFF6D4CF6)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$studentName ${studentCode != null ? "($studentCode)" : ""}',
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ConsoleColors.textPrimary),
                                    ),
                                  ),
                                  Text(schoolName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.phone_rounded, size: 16, color: ConsoleColors.success),
                                        const SizedBox(width: 8),
                                        SelectableText(
                                          studentPhone ?? 'Téléphone non renseigné',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: studentPhone != null ? ConsoleColors.textPrimary : ConsoleColors.textTertiary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.email_outlined, size: 16, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: SelectableText(
                                            studentEmail ?? 'Email non renseigné',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: studentEmail != null ? ConsoleColors.textSecondary : ConsoleColors.textTertiary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        _buildSectionIndicator('Description Détaillée du Problème'),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: SelectableText(
                            desc,
                            style: const TextStyle(fontSize: 13.5, height: 1.5, color: Color(0xFF334155)),
                          ),
                        ),
                        const SizedBox(height: 22),

                        if (screenshotUrl != null && screenshotUrl.isNotEmpty) ...[
                          _buildSectionIndicator('Capture d\'écran Attachée'),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(screenshotUrl, fit: BoxFit.contain),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              height: 180,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image.network(
                                      screenshotUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (_, _, _) => const Center(child: Text('Image indisponible')),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.zoom_in, color: Colors.white, size: 18),
                                          SizedBox(width: 6),
                                          Text('Cliquer pour agrandir', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                        ],

                        _buildSectionIndicator('Statut Actuel & Prise en Charge'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Statut du ticket: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 10),
                            _buildBugStatusBadge(status),
                            const Spacer(),
                            Text('Date: ${createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt}',
                                style: const TextStyle(fontSize: 12, color: ConsoleColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                    border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: Row(
                    children: [
                      PopupMenuButton<String>(
                        initialValue: status,
                        onSelected: (val) {
                          ref.read(platformProvider.notifier).updateBugReportStatus(id, val, isFallback: isFallback);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF6D4CF6)),
                              SizedBox(width: 8),
                              Text('Changer le statut...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            ],
                          ),
                        ),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'open', child: Text('Marquer En attente')),
                          PopupMenuItem(value: 'in_progress', child: Text('Marquer En cours')),
                          PopupMenuItem(value: 'resolved', child: Text('Marquer Résolu')),
                          PopupMenuItem(value: 'closed', child: Text('Marquer Fermé')),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D4CF6),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Fermer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SHARED LIGHT DESIGN-KIT HELPERS & MODALS
  // ══════════════════════════════════════════════════════════════
  Widget _surfaceCard({
    required String title,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ConsoleColors.cardBorder),
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
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ConsoleColors.textPrimary,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color, {
    String? trend,
    String? trendLabel,
    bool trendUp = true,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.015),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Borderless Icon + Small Navigation Arrow
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(icon, color: color, size: 20),
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 14,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Metric Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Metric Value (Golden ratio typographic weight)
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.6,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Trend or Subtitle Row
            Row(
              children: [
                if (trend != null) ...[
                  Icon(
                    trendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 12,
                    color: trendUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    trend,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: trendUp ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    trendLabel ?? subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'active':
      case 'actif':
      case 'paid':
      case 'success':
        bg = ConsoleColors.successSoft;
        fg = ConsoleColors.success;
        break;
      case 'past_due':
      case 'trial':
      case 'issued':
      case 'pending':
        bg = ConsoleColors.warningSoft;
        fg = ConsoleColors.warning;
        break;
      case 'suspended':
      case 'inactif':
      case 'overdue':
      case 'error':
        bg = ConsoleColors.errorSoft;
        fg = ConsoleColors.error;
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = ConsoleColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildBugStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;
    switch (status.toLowerCase()) {
      case 'open':
      case 'sent':
        bg = ConsoleColors.errorSoft;
        fg = ConsoleColors.error;
        label = 'OUVERT';
        break;
      case 'in_progress':
        bg = ConsoleColors.warningSoft;
        fg = ConsoleColors.warning;
        label = 'EN COURS';
        break;
      case 'resolved':
        bg = ConsoleColors.successSoft;
        fg = ConsoleColors.success;
        label = 'RÉSOLU';
        break;
      case 'closed':
        bg = const Color(0xFFF1F5F9);
        fg = ConsoleColors.textSecondary;
        label = 'FERMÉ';
        break;
      default:
        bg = ConsoleColors.errorSoft;
        fg = ConsoleColors.error;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_drop_down, color: fg, size: 16),
        ],
      ),
    );
  }

  Widget _buildSchoolLogoThumb(
    String? logoUrl, {
    double size = 32,
    double radius = 8,
  }) {
    final trimmed = logoUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: (trimmed != null && trimmed.isNotEmpty)
          ? Image.network(
              trimmed,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: size,
                height: size,
                color: ConsoleColors.brandSoft,
                child: Icon(
                  Icons.school_outlined,
                  size: size * 0.55,
                  color: ConsoleColors.brand,
                ),
              ),
            )
          : Container(
              width: size,
              height: size,
              color: ConsoleColors.brandSoft,
              child: Icon(
                Icons.school_outlined,
                size: size * 0.55,
                color: ConsoleColors.brand,
              ),
            ),
    );
  }

  void _showSchoolLogoModal(BuildContext context, Map<String, dynamic> school) {
    final schoolId = school['id'] as String;
    final schoolName = school['name'] as String? ?? 'École';
    String? draftLogoUrl = school['logo_url'] as String?;
    bool uploading = false;
    bool saving = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: StatefulBuilder(
          builder: (sbContext, setSbState) => AlertDialog(
            title: Text(
              'Logo — $schoolName',
              style: const TextStyle(
                color: ConsoleColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: ConsoleColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: ConsoleColors.cardBorder),
                    ),
                    child: uploading
                        ? const Center(
                            child: CircularProgressIndicator(strokeWidth: 2.5))
                        : Center(
                            child: _buildSchoolLogoThumb(
                              draftLogoUrl,
                              size: 104,
                              radius: 14,
                            ),
                          ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    (draftLogoUrl != null && draftLogoUrl!.isNotEmpty)
                        ? 'Logo personnalisé configuré pour cette école.'
                        : 'Utilise actuellement le logo par défaut.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ConsoleColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: uploading || saving
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                setSbState(() => uploading = true);
                                try {
                                  final url = await ref
                                      .read(platformProvider.notifier)
                                      .pickAndUploadSchoolLogo(
                                          schoolId: schoolId);
                                  if (!ctx.mounted) return;
                                  if (url != null) {
                                    setSbState(() => draftLogoUrl = url);
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Échec téléversement logo: $e'),
                                        backgroundColor: ConsoleColors.error,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (ctx.mounted) {
                                    setSbState(() => uploading = false);
                                  }
                                }
                              },
                        icon: const Icon(Icons.upload, size: 17),
                        label: const Text('Téléverser un logo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ConsoleColors.brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                      ),
                      if (draftLogoUrl != null && draftLogoUrl!.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: uploading || saving
                              ? null
                              : () => setSbState(() => draftLogoUrl = null),
                          icon: const Icon(Icons.restart_alt, size: 17),
                          label: const Text('Réinitialiser'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: uploading || saving
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setSbState(() => saving = true);
                        final ok = await ref
                            .read(platformProvider.notifier)
                            .updateSchoolBranding(
                              schoolId: schoolId,
                              logoUrl: draftLogoUrl,
                              clearLogo: draftLogoUrl == null ||
                                  draftLogoUrl!.isEmpty,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        final errMsg =
                            ref.read(platformProvider).errorMessage;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Logo de $schoolName mis à jour !'
                                : (errMsg ??
                                    'Impossible de sauvegarder le logo.')),
                            backgroundColor: ok
                                ? ConsoleColors.success
                                : ConsoleColors.error,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ConsoleColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateSchoolModal(
    BuildContext context,
    List<Map<String, dynamic>> plans,
  ) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final directorNameCtrl = TextEditingController();
    final directorPhoneCtrl = TextEditingController();
    final directorEmailCtrl = TextEditingController();
    final directorPassCtrl = TextEditingController(text: 'Director2026!');
    final aiBudgetCtrl = TextEditingController(text: '25.00');

    String selectedPlanId = plans.isNotEmpty ? plans[0]['id'] as String : '';
    String? selectedLogoUrl;
    bool uploadingLogo = false;
    bool creating = false;
    bool showPassword = false;

    int getPasswordStrength(String pwd) {
      if (pwd.isEmpty) return 0;
      int score = 0;
      if (pwd.length >= 8) score++;
      if (pwd.length >= 12) score++;
      if (RegExp(r'[A-Z]').hasMatch(pwd) && RegExp(r'[a-z]').hasMatch(pwd)) score++;
      if (RegExp(r'[0-9]').hasMatch(pwd)) score++;
      if (RegExp(r'[!@#\$%&*]').hasMatch(pwd)) score++;
      return score.clamp(0, 4);
    }

    void generatePassword(StateSetter setSbState) {
      final now = DateTime.now().millisecondsSinceEpoch.toString();
      final suffix = now.substring(now.length - 4);
      setSbState(() {
        directorPassCtrl.text = 'Director$suffix!';
      });
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: StatefulBuilder(
          builder: (sbContext, setSbState) {
            final strength = getPasswordStrength(directorPassCtrl.text);
            final strengthColor = strength <= 1
                ? ConsoleColors.error
                : strength == 2
                    ? ConsoleColors.warning
                    : strength == 3
                        ? const Color(0xFF6D4CF6)
                        : ConsoleColors.success;
            final strengthLabel = strength <= 1
                ? 'Faible'
                : strength == 2
                    ? 'Moyen'
                    : strength == 3
                        ? 'Fort'
                        : 'Très fort';

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: 660,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.90,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── HEADER ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Ajouter un nouvel Établissement',
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: ConsoleColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Configurez l\'établissement SaaS, son accès directeur et son forfait.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFF8FAFC),
                              ),
                              child: const Icon(Icons.close, size: 18, color: ConsoleColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── FORM BODY ──
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── SECTION 1: IDENTITÉ DE L'ÉTABLISSEMENT ──
                            _buildSectionIndicator('Identité de l\'établissement'),
                            const SizedBox(height: 16),

                            // Logo Upload Row
                            Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: uploadingLogo
                                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                      : _buildSchoolLogoThumb(selectedLogoUrl, size: 64, radius: 14),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Logo de l\'école (recommandé)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        'Format PNG, JPG ou WebP. Apparaît sur le portail et les factures.',
                                        style: TextStyle(fontSize: 11.5, color: ConsoleColors.textSecondary),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          SizedBox(
                                            height: 34,
                                            child: OutlinedButton.icon(
                                              onPressed: uploadingLogo
                                                  ? null
                                                  : () async {
                                                      setSbState(() => uploadingLogo = true);
                                                      try {
                                                        final url = await ref
                                                            .read(platformProvider.notifier)
                                                            .pickAndUploadSchoolLogo(
                                                              schoolId: nameCtrl.text.trim().isNotEmpty
                                                                  ? nameCtrl.text.trim()
                                                                  : 'new_school',
                                                            );
                                                        if (ctx.mounted && url != null) {
                                                          setSbState(() => selectedLogoUrl = url);
                                                        }
                                                      } catch (_) {} finally {
                                                        if (ctx.mounted) {
                                                          setSbState(() => uploadingLogo = false);
                                                        }
                                                      }
                                                    },
                                              icon: const Icon(Icons.upload_file_rounded, size: 15),
                                              label: const Text('Choisir un logo', style: TextStyle(fontSize: 12)),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: const Color(0xFF6D4CF6),
                                                side: const BorderSide(color: Color(0xFF6D4CF6)),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                            ),
                                          ),
                                          if (selectedLogoUrl != null) ...[
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              height: 34,
                                              child: TextButton(
                                                onPressed: () => setSbState(() => selectedLogoUrl = null),
                                                child: const Text('Par défaut', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // School Name
                            const Text('Nom complet de l\'établissement *',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: nameCtrl,
                              decoration: InputDecoration(
                                hintText: 'Ex: ESPRIT, École Polytechnique, etc.',
                                hintStyle: const TextStyle(color: ConsoleColors.textTertiary, fontSize: 13.5),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // School Contact Email
                            const Text('Email officiel de contact de l\'école *',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: emailCtrl,
                              decoration: InputDecoration(
                                hintText: 'contact@etablissement.tn',
                                hintStyle: const TextStyle(color: ConsoleColors.textTertiary, fontSize: 13.5),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                              ),
                            ),
                            const SizedBox(height: 26),

                            // ── SECTION 2: DIRECTION & ACCÈS DIRECTEUR ──
                            _buildSectionIndicator('Direction & Accès Directeur'),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Nom complet du Directeur *',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: directorNameCtrl,
                                        decoration: InputDecoration(
                                          hintText: 'Ex: Dr. Moncef Larbi',
                                          hintStyle: const TextStyle(color: ConsoleColors.textTertiary, fontSize: 13.5),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Téléphone du Directeur *',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: directorPhoneCtrl,
                                        keyboardType: TextInputType.phone,
                                        decoration: InputDecoration(
                                          hintText: '+216 98 123 456',
                                          prefixIcon: const Icon(Icons.phone_rounded, size: 16, color: Color(0xFF6D4CF6)),
                                          hintStyle: const TextStyle(color: ConsoleColors.textTertiary, fontSize: 13.5),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            const Text('Email connexion Directeur *',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            TextField(
                              controller: directorEmailCtrl,
                              decoration: InputDecoration(
                                hintText: 'directeur@etablissement.tn',
                                hintStyle: const TextStyle(color: ConsoleColors.textTertiary, fontSize: 13.5),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            const Text('Mot de passe temporaire *',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: directorPassCtrl,
                                    obscureText: !showPassword,
                                    onChanged: (_) => setSbState(() {}),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                                      suffixIcon: IconButton(
                                        icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, size: 18, color: Colors.grey),
                                        onPressed: () => setSbState(() => showPassword = !showPassword),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: () => generatePassword(setSbState),
                                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF6D4CF6)),
                                    label: const Text('GÉNÉRER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6D4CF6))),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                                      backgroundColor: const Color(0xFFF8FAFC),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Password Strength Bar
                            Row(
                              children: List.generate(4, (i) {
                                return Expanded(
                                  child: Container(
                                    height: 4,
                                    margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                                    decoration: BoxDecoration(
                                      color: i < strength ? strengthColor : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('FORCE: ${strengthLabel.toUpperCase()}',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: strengthColor)),
                                const Text('Recommandé: 8+ caractères avec chiffres & symboles',
                                    style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: ConsoleColors.textTertiary)),
                              ],
                            ),
                            const SizedBox(height: 26),

                            // ── SECTION 3: ABONNEMENT & QUOTA IA INITIAL ──
                            _buildSectionIndicator('Abonnement & Quota IA Initial'),
                            const SizedBox(height: 16),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Formule d\'abonnement SaaS *',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        value: plans.any((p) => p['id'] == selectedPlanId)
                                            ? selectedPlanId
                                            : (plans.isNotEmpty ? plans[0]['id'] as String : null),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                                        ),
                                        items: plans.map((p) {
                                          return DropdownMenuItem<String>(
                                            value: p['id'] as String,
                                            child: Text('${p['name']} (${p['price_tnd_monthly']} TND/m)'),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setSbState(() => selectedPlanId = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Budget IA initial (USD)',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: aiBudgetCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          prefixText: '\$ ',
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── SUMMARY STRIP ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFAFAFB),
                        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        children: [
                          Row(
                            children: [
                              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF6D4CF6), shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              const Text('TYPE: SAAS ÉTABLISSEMENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ConsoleColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Row(
                            children: [
                              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF94A3B8), shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              const Text('CODE ÉCOLE: AUTO-GÉNÉRÉ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ConsoleColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Row(
                            children: [
                              Container(width: 7, height: 7, decoration: const BoxDecoration(color: ConsoleColors.success, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              const Text('STATUT: ACTIF IMMÉDIAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ConsoleColors.success)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── FOOTER ACTIONS (EXACT 40PX BUTTONS) ──
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 40,
                            child: TextButton(
                              onPressed: creating ? null : () => Navigator.pop(ctx),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF6B7280),
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                              ),
                              child: const Text('Annuler', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: creating || uploadingLogo
                                  ? null
                                  : () async {
                                      final name = nameCtrl.text.trim();
                                      final email = emailCtrl.text.trim();
                                      final dName = directorNameCtrl.text.trim();
                                      final dPhone = directorPhoneCtrl.text.trim();
                                      final dEmail = directorEmailCtrl.text.trim();
                                      final dPass = directorPassCtrl.text.trim();
                                      final budget = double.tryParse(aiBudgetCtrl.text.trim()) ?? 25.0;

                                      if (name.isEmpty || email.isEmpty || dEmail.isEmpty || dPass.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Veuillez remplir tous les champs obligatoires (*).'),
                                            backgroundColor: ConsoleColors.error,
                                          ),
                                        );
                                        return;
                                      }

                                      setSbState(() => creating = true);
                                      final ok = await ref.read(platformProvider.notifier).createSchool(
                                        name: name,
                                        email: email,
                                        directorPhone: dPhone,
                                        logoUrl: selectedLogoUrl,
                                        directorName: dName.isNotEmpty ? dName : 'Directeur $name',
                                        directorEmail: dEmail,
                                        directorPassword: dPass,
                                        planId: selectedPlanId,
                                        initialAiBudgetUsd: budget,
                                      );

                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok
                                              ? 'Établissement "$name" créé avec succès !'
                                              : (ref.read(platformProvider).errorMessage ?? 'Erreur lors de la création.')),
                                          backgroundColor: ok ? ConsoleColors.success : ConsoleColors.error,
                                        ),
                                      );
                                    },
                              icon: creating
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check_rounded, size: 17),
                              label: const Text('Créer l\'Établissement', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6D4CF6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 22),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showInvoiceGeneratorModal(
    BuildContext context,
    List<Map<String, dynamic>> schools, {
    String? preselectedSchoolId,
  }) {
    if (schools.isEmpty) return;

    String selectedSchoolId = preselectedSchoolId ?? schools[0]['id'] as String;
    final now = DateTime.now();
    final invoiceNumberCtrl = TextEditingController(text: 'FAC-${now.year}-${schools.length.toString().padLeft(6, '0')}');
    final designationCtrl = TextEditingController(text: 'application');
    final quantityCtrl = TextEditingController(text: '1');
    final unitPriceCtrl = TextEditingController(text: '3200.000');
    final tvaRateCtrl = TextEditingController(text: '0');
    final timbreFiscalCtrl = TextEditingController(text: '1.000');
    final issuerNameCtrl = TextEditingController(text: 'Aziz Tounsi');
    final matriculeCtrl = TextEditingController(text: '2007778S');

    bool savingAndDownloading = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: StatefulBuilder(
          builder: (sbContext, setSbState) {
            final currentSchool = schools.firstWhere(
              (s) => s['id'] == selectedSchoolId,
              orElse: () => schools[0],
            );
            final clientName = (currentSchool['name'] ?? 'Client').toString();

            final qty = int.tryParse(quantityCtrl.text.trim()) ?? 1;
            final pu = double.tryParse(unitPriceCtrl.text.trim().replaceAll(',', '.')) ?? 3200.0;
            final tvaRate = double.tryParse(tvaRateCtrl.text.trim()) ?? 0.0;
            final timbre = double.tryParse(timbreFiscalCtrl.text.trim().replaceAll(',', '.')) ?? 1.0;

            final totalHt = qty * pu;
            final tvaAmount = totalHt * (tvaRate / 100.0);
            final totalTtc = totalHt + tvaAmount;
            final netToPay = totalTtc + timbre;
            final legalSentence = FrenchNumberToWords.toLegalSentence(netToPay);

            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: 700,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.92,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: ConsoleColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.picture_as_pdf_rounded, color: ConsoleColors.success, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Générateur de Facture Officielle (PDF)',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: ConsoleColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Format identique à FACTURE FAC-2026-000001 (Arrêté légal en toutes lettres & Timbre fiscal)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18, color: ConsoleColors.textSecondary),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Config Form
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionIndicator('Informations de la Facture'),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Établissement Client *',
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        value: selectedSchoolId,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        ),
                                        items: schools.map((s) {
                                          return DropdownMenuItem<String>(
                                            value: s['id'] as String,
                                            child: Text(s['name'] as String? ?? ''),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) setSbState(() => selectedSchoolId = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Numéro de Facture *',
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: invoiceNumberCtrl,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Émetteur (Fournisseur)',
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: issuerNameCtrl,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Matricule Fiscale',
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: matriculeCtrl,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),

                            _buildSectionIndicator('Lignes d\'articles & Tarification'),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Désignation *',
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: designationCtrl,
                                        onChanged: (_) => setSbState(() {}),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Qté',
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: quantityCtrl,
                                        keyboardType: TextInputType.number,
                                        onChanged: (_) => setSbState(() {}),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('P.U HT (DT)',
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: unitPriceCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        onChanged: (_) => setSbState(() {}),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Live Summary & Calculations Card
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total HT:', style: TextStyle(fontSize: 13, color: ConsoleColors.textSecondary)),
                                      Text(InvoicePdfGenerator.formatTnd(totalHt),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ConsoleColors.textPrimary)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('TVA (0%):', style: TextStyle(fontSize: 13, color: ConsoleColors.textSecondary)),
                                      Text(InvoicePdfGenerator.formatTnd(tvaAmount),
                                          style: const TextStyle(fontSize: 13, color: ConsoleColors.textSecondary)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total TTC:', style: TextStyle(fontSize: 13, color: ConsoleColors.textSecondary)),
                                      Text(InvoicePdfGenerator.formatTnd(totalTtc),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ConsoleColors.textPrimary)),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Timbre fiscal:', style: TextStyle(fontSize: 13, color: ConsoleColors.textSecondary)),
                                      Text(InvoicePdfGenerator.formatTnd(timbre),
                                          style: const TextStyle(fontSize: 13, color: ConsoleColors.textSecondary)),
                                    ],
                                  ),
                                  const Divider(height: 18),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Net à payer:',
                                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: ConsoleColors.textPrimary)),
                                      Text(InvoicePdfGenerator.formatTnd(netToPay),
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF6D4CF6))),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      legalSentence,
                                      style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Footer Buttons
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 40,
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: TextButton.styleFrom(foregroundColor: const Color(0xFF6B7280)),
                              child: const Text('Fermer', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Direct Print/Download PDF without DB saving
                          SizedBox(
                            height: 40,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final invoiceData = InvoiceDataModel(
                                  invoiceNumber: invoiceNumberCtrl.text.trim(),
                                  date: now,
                                  issuerName: issuerNameCtrl.text.trim(),
                                  matriculeFiscale: matriculeCtrl.text.trim(),
                                  clientName: clientName,
                                  timbreFiscal: timbre,
                                  items: [
                                    InvoiceItemModel(
                                      index: 1,
                                      ref: 'P-0001',
                                      designation: designationCtrl.text.trim(),
                                      quantity: qty,
                                      unitPriceHt: pu,
                                      tvaPercent: tvaRate,
                                    ),
                                  ],
                                );
                                await InvoicePdfGenerator.downloadOrPrintInvoice(invoiceData);
                              },
                              icon: const Icon(Icons.print_rounded, size: 16),
                              label: const Text('Imprimer / Aperçu PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6D4CF6),
                                side: const BorderSide(color: Color(0xFF6D4CF6)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Save to DB and download PDF
                          SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: savingAndDownloading
                                  ? null
                                  : () async {
                                      setSbState(() => savingAndDownloading = true);
                                      final item = InvoiceItemModel(
                                        index: 1,
                                        ref: 'P-0001',
                                        designation: designationCtrl.text.trim(),
                                        quantity: qty,
                                        unitPriceHt: pu,
                                        tvaPercent: tvaRate,
                                      );
                                      final invoiceData = InvoiceDataModel(
                                        invoiceNumber: invoiceNumberCtrl.text.trim(),
                                        date: now,
                                        issuerName: issuerNameCtrl.text.trim(),
                                        matriculeFiscale: matriculeCtrl.text.trim(),
                                        clientName: clientName,
                                        timbreFiscal: timbre,
                                        items: [item],
                                      );

                                      final inserted = await ref.read(platformProvider.notifier).createDetailedInvoice(
                                        schoolId: selectedSchoolId,
                                        invoiceNumber: invoiceData.invoiceNumber,
                                        issueDate: now.toIso8601String().split('T')[0],
                                        dueDate: now.add(const Duration(days: 30)).toIso8601String().split('T')[0],
                                        clientName: clientName,
                                        issuerName: invoiceData.issuerName,
                                        issuerCountry: 'TN',
                                        matriculeFiscale: invoiceData.matriculeFiscale,
                                        items: [item.toJson()],
                                        totalHt: totalHt,
                                        tvaRate: tvaRate,
                                        tvaAmount: tvaAmount,
                                        timbreFiscal: timbre,
                                        totalTtc: totalTtc,
                                        netToPay: netToPay,
                                        amountInWords: legalSentence,
                                      );

                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (inserted != null) {
                                        await InvoicePdfGenerator.downloadOrPrintInvoice(invoiceData);
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Facture enregistrée et PDF généré avec succès !'),
                                              backgroundColor: ConsoleColors.success,
                                            ),
                                          );
                                        }
                                      } else {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Erreur lors de l\'enregistrement de la facture.'),
                                              backgroundColor: ConsoleColors.error,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              icon: savingAndDownloading
                                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.download_rounded, size: 16),
                              label: const Text('Enregistrer & Télécharger PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6D4CF6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showManualInvoiceModal(
    BuildContext context,
    List<Map<String, dynamic>> schools,
  ) {
    _showInvoiceGeneratorModal(context, schools);
  }
}
