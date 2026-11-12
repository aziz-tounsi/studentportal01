import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/console_theme.dart';
import '../providers/console_auth_provider.dart';
import '../providers/platform_provider.dart';
import '../widgets/console_sidebar.dart';
import '../widgets/console_skeleton_loader.dart';

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
    final authState = ref.watch(consoleAuthProvider);
    final platformState = ref.watch(platformProvider);

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
                _buildPageHeader(authState.user, platformState),
                Expanded(
                  child: platformState.isLoading
                      ? _skeletonForRoute()
                      : platformState.errorMessage != null
                          ? _buildErrorState(platformState.errorMessage!)
                          : _pageForRoute(platformState),
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

  Widget _pageForRoute(PlatformState state) {
    switch (widget.currentRoute) {
      case '/schools':
        return _buildSchoolsPage(state);
      case '/billing':
        return _buildBillingPage(state);
      case '/ai-telemetry':
        return _buildAiTelemetryPage(state);
      case '/audit':
        return _buildAuditPage(state);
      case '/bugs':
        return _buildBugReportsPage(state);
      case '/dashboard':
      case '/':
      default:
        return _buildOverviewPage(state);
    }
  }

  (String, String) _headerMeta() {
    switch (widget.currentRoute) {
      case '/schools':
        return (
          'Écoles & Tenants',
          'Création, logos, abonnements et suspension des établissements',
        );
      case '/billing':
        return (
          'Facturation & Paiements',
          'Validation des virements et suivi des factures SaaS',
        );
      case '/ai-telemetry':
        return (
          'Télémétrie IA & Kill-Switch',
          'Contrôle de la consommation et coupure d\'urgence plateforme',
        );
      case '/audit':
        return (
          'Journaux d\'Audit',
          'Traçabilité complète des actions sensibles multi-tenants',
        );
      case '/bugs':
        return (
          'Signalements & Bugs',
          'Suivi des incidents remontés depuis les applications',
        );
      case '/dashboard':
      case '/':
      default:
        return (
          'Vue d\'ensemble',
          'Pilotage global de la plateforme SaaS et des établissements',
        );
    }
  }

  Widget _buildPageHeader(Map<String, dynamic>? user, PlatformState state) {
    final (title, subtitle) = _headerMeta();

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
                hintText: 'Rechercher...',
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
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: () => ref.read(platformProvider.notifier).loadAll(),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: ConsoleColors.textSecondary,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: ConsoleColors.cardBorder),
              ),
            ),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
                label: const Text('Nouvelle École'),
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
                label: const Text('Facture Manuelle'),
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

  Widget _buildErrorState(String message) {
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
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 1. OVERVIEW PAGE
  // ══════════════════════════════════════════════════════════════
  Widget _buildOverviewPage(PlatformState state) {
    final kpis = state.kpis;
    final schools = state.schools.where((s) {
      if (_searchQuery.isEmpty) return true;
      final name = (s['name'] ?? '').toString().toLowerCase();
      final code = (s['code'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || code.contains(_searchQuery);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Écoles Inscrites',
                  '${kpis['totalSchools'] ?? 0}',
                  '${kpis['activeSchools'] ?? 0} actives sur la plateforme',
                  Icons.domain_rounded,
                  ConsoleColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Revenu Mensuel (MRR)',
                  '${(kpis['mrrTnd'] as double? ?? 0.0).toStringAsFixed(0)} TND',
                  'Abonnements actifs & essai',
                  Icons.trending_up_rounded,
                  ConsoleColors.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Dépense IA (Mois)',
                  '\$${(kpis['aiSpendUsd'] as double? ?? 0.0).toStringAsFixed(2)}',
                  'Consommation OpenRouter',
                  Icons.auto_awesome_rounded,
                  ConsoleColors.brand,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Virements en Attente',
                  '${kpis['pendingCount'] ?? 0}',
                  'Paiements à vérifier',
                  Icons.pending_actions_rounded,
                  ConsoleColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _surfaceCard(
                  title: 'Établissements récents',
                  trailing: TextButton(
                    onPressed: () => context.go('/schools'),
                    child: const Text('Voir tout'),
                  ),
                  child: schools.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Text(
                              'Aucun établissement enregistré.',
                              style: TextStyle(
                                  color: ConsoleColors.textSecondary),
                            ),
                          ),
                        )
                      : Column(
                          children: schools.take(6).map((s) {
                            final subs =
                                s['school_subscriptions'] as List? ?? [];
                            final sub = subs.isNotEmpty ? subs[0] : null;
                            final isActive = s['is_active'] == true;
                            final subStatus = isActive
                                ? (sub?['status']?.toString() ?? 'active')
                                : 'suspended';
                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                      color: ConsoleColors.divider),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildSchoolLogoThumb(
                                    s['logo_url'] as String?,
                                    size: 36,
                                    radius: 9,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s['name'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                            color: ConsoleColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          s['code'] ?? '—',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: ConsoleColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildStatusBadge(subStatus),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _surfaceCard(
                  title: 'Accès rapide',
                  child: Column(
                    children: [
                      _quickActionRow(
                        icon: Icons.add_business_outlined,
                        color: ConsoleColors.brand,
                        title: 'Créer une école',
                        subtitle: 'Provisionner un workspace & directeur',
                        onTap: () =>
                            _showCreateSchoolModal(context, state.plans),
                      ),
                      const SizedBox(height: 10),
                      _quickActionRow(
                        icon: Icons.receipt_long_outlined,
                        color: ConsoleColors.success,
                        title: 'Vérifier les paiements',
                        subtitle:
                            '${kpis['pendingCount'] ?? 0} virement(s) en attente',
                        onTap: () => context.go('/billing'),
                      ),
                      const SizedBox(height: 10),
                      _quickActionRow(
                        icon: Icons.bug_report_outlined,
                        color: ConsoleColors.error,
                        title: 'Signalements bugs',
                        subtitle:
                            '${kpis['openBugsCount'] ?? 0} ticket(s) ouverts',
                        onTap: () => context.go('/bugs'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ConsoleColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ConsoleColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ConsoleColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: ConsoleColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: ConsoleColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 2. SCHOOLS PAGE
  // ══════════════════════════════════════════════════════════════
  Widget _buildSchoolsPage(PlatformState state) {
    final schools = state.schools.where((s) {
      if (_searchQuery.isEmpty) return true;
      final name = (s['name'] ?? '').toString().toLowerCase();
      final code = (s['code'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          code.contains(_searchQuery) ||
          email.contains(_searchQuery);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _surfaceCard(
            title: 'Établissements Clients (${schools.length})',
            child: schools.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Aucun établissement ne correspond à la recherche.',
                        style: TextStyle(color: ConsoleColors.textSecondary),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columns: const [
                        DataColumn(label: Text('Établissement')),
                        DataColumn(label: Text('Code / Slug')),
                        DataColumn(label: Text('Formule')),
                        DataColumn(label: Text('Statut SaaS')),
                        DataColumn(label: Text('Conso IA')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: schools.map((s) {
                        final subs = s['school_subscriptions'] as List? ?? [];
                        final sub = subs.isNotEmpty ? subs[0] : null;
                        final plan = sub?['plan'] as Map<String, dynamic>?;
                        final quota =
                            (s['ai_school_quotas'] as List? ?? []).isNotEmpty
                                ? s['ai_school_quotas'][0]
                                : null;
                        final isActive = s['is_active'] == true;
                        final subStatus = isActive
                            ? (sub?['status']?.toString() ?? 'active')
                            : 'suspended';
                        final spent =
                            (quota?['spent_current_month_usd'] as num?)
                                    ?.toDouble() ??
                                0.0;
                        final budget = (quota?['monthly_budget_usd'] as num?)
                                ?.toDouble() ??
                            25.0;

                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildSchoolLogoThumb(
                                    s['logo_url'] as String?,
                                    size: 32,
                                    radius: 8,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    s['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: ConsoleColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text(
                              s['code'] ?? '—',
                              style: const TextStyle(
                                  color: ConsoleColors.textSecondary),
                            )),
                            DataCell(Text(
                              plan?['name'] ?? 'Essai Standard',
                              style: const TextStyle(
                                  color: ConsoleColors.textSecondary),
                            )),
                            DataCell(_buildStatusBadge(subStatus)),
                            DataCell(Text(
                              '\$${spent.toStringAsFixed(2)} / \$${budget.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: ConsoleColors.textSecondary),
                            )),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.image_outlined,
                                      color: ConsoleColors.primary,
                                      size: 20,
                                    ),
                                    tooltip: 'Changer le logo de l\'école',
                                    onPressed: () =>
                                        _showSchoolLogoModal(context, s),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip:
                                        'Statut abonnement (active / past_due / suspended)',
                                    icon: const Icon(
                                      Icons.credit_score_outlined,
                                      color: ConsoleColors.brand,
                                      size: 20,
                                    ),
                                    onSelected: (status) => ref
                                        .read(platformProvider.notifier)
                                        .updateSchoolSubscriptionStatus(
                                            s['id'], status),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'active',
                                        child: Text('Active (Accès complet)',
                                            style: TextStyle(
                                                color: ConsoleColors.success)),
                                      ),
                                      PopupMenuItem(
                                        value: 'past_due',
                                        child: Text(
                                            'Past Due (Bannière préavis)',
                                            style: TextStyle(
                                                color: ConsoleColors.warning)),
                                      ),
                                      PopupMenuItem(
                                        value: 'suspended',
                                        child: Text('Suspended (Gel complet)',
                                            style: TextStyle(
                                                color: ConsoleColors.error)),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      isActive
                                          ? Icons.pause_circle_outline
                                          : Icons.play_circle_outline,
                                      color: isActive
                                          ? ConsoleColors.warning
                                          : ConsoleColors.success,
                                      size: 20,
                                    ),
                                    tooltip: isActive
                                        ? 'Suspendre l\'école'
                                        : 'Réactiver l\'école',
                                    onPressed: () => ref
                                        .read(platformProvider.notifier)
                                        .toggleSchoolStatus(s['id'], !isActive),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 3. BILLING PAGE
  // ══════════════════════════════════════════════════════════════
  Widget _buildBillingPage(PlatformState state) {
    final pending = state.pendingPayments;
    final invoices = state.invoices.where((inv) {
      if (_searchQuery.isEmpty) return true;
      final num = (inv['invoice_number'] ?? '').toString().toLowerCase();
      final sName =
          ((inv['school'] as Map?)?['name'] ?? '').toString().toLowerCase();
      return num.contains(_searchQuery) || sName.contains(_searchQuery);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _surfaceCard(
            title: 'Virements en Attente (${pending.length})',
            child: pending.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'Aucun virement en attente. Tout est à jour !',
                        style: TextStyle(color: ConsoleColors.textSecondary),
                      ),
                    ),
                  )
                : Column(
                    children: pending.map((p) {
                      final inv = p['invoice'] as Map<String, dynamic>?;
                      final school = inv?['school'] as Map<String, dynamic>?;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: ConsoleColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ConsoleColors.brand.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: ConsoleColors.brandSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.account_balance_outlined,
                                color: ConsoleColors.brand,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${school?['name'] ?? "École"} — Facture ${inv?['invoice_number'] ?? ""}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      color: ConsoleColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Réf: ${p['transaction_ref'] ?? "N/A"} • Montant: ${p['amount']} TND',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: ConsoleColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final ok = await ref
                                    .read(platformProvider.notifier)
                                    .verifyPayment(p['id']);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? 'Paiement validé et abonnement prolongé !'
                                        : 'Erreur validation.'),
                                    backgroundColor: ok
                                        ? ConsoleColors.success
                                        : ConsoleColors.error,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: const Text('Valider Virement'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: ConsoleColors.success,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 22),
          _surfaceCard(
            title: 'Factures Émises (${invoices.length})',
            child: invoices.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'Aucune facture trouvée.',
                        style: TextStyle(color: ConsoleColors.textSecondary),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columns: const [
                        DataColumn(label: Text('Numéro')),
                        DataColumn(label: Text('Établissement')),
                        DataColumn(label: Text('Montant')),
                        DataColumn(label: Text('Échéance')),
                        DataColumn(label: Text('Statut')),
                      ],
                      rows: invoices.map((inv) {
                        final school = inv['school'] as Map<String, dynamic>?;
                        return DataRow(
                          cells: [
                            DataCell(Text(
                              inv['invoice_number'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: ConsoleColors.textPrimary,
                              ),
                            )),
                            DataCell(Text(
                              school?['name'] ?? '—',
                              style: const TextStyle(
                                  color: ConsoleColors.textSecondary),
                            )),
                            DataCell(Text(
                              '${inv['amount']} ${inv['currency'] ?? 'TND'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: ConsoleColors.textPrimary,
                              ),
                            )),
                            DataCell(Text(
                              inv['due_date'] ?? '—',
                              style: const TextStyle(
                                  color: ConsoleColors.textSecondary),
                            )),
                            DataCell(
                                _buildStatusBadge(inv['status'] ?? 'issued')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 4. AI TELEMETRY PAGE
  // ══════════════════════════════════════════════════════════════
  Widget _buildAiTelemetryPage(PlatformState state) {
    final settings = state.platformSettings;
    final killSwitch = settings?['global_ai_kill_switch'] == true;
    final logs = state.recentAiLogs.where((l) {
      if (_searchQuery.isEmpty) return true;
      final model = (l['model'] ?? '').toString().toLowerCase();
      final sName =
          ((l['school'] as Map?)?['name'] ?? '').toString().toLowerCase();
      return model.contains(_searchQuery) || sName.contains(_searchQuery);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: killSwitch ? ConsoleColors.errorSoft : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    killSwitch ? ConsoleColors.error : ConsoleColors.cardBorder,
              ),
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
                    color:
                        killSwitch ? ConsoleColors.error : ConsoleColors.success,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interrupteur Général d\'Urgence IA (Global Kill-Switch)',
                        style: TextStyle(
                          color: ConsoleColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Coupe instantanément tous les appels OpenRouter sur l\'ensemble des établissements.',
                        style: TextStyle(
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
          const SizedBox(height: 22),
          _surfaceCard(
            title: 'Inférences IA en Direct (${logs.length})',
            child: logs.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'Aucun log IA enregistré.',
                        style: TextStyle(color: ConsoleColors.textSecondary),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor:
                          WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columns: const [
                        DataColumn(label: Text('École')),
                        DataColumn(label: Text('Modèle')),
                        DataColumn(label: Text('Tokens Total')),
                        DataColumn(label: Text('Coût USD')),
                        DataColumn(label: Text('Latence')),
                        DataColumn(label: Text('Statut')),
                      ],
                      rows: logs.map((l) {
                        final school = l['school'] as Map<String, dynamic>?;
                        final cost =
                            (l['cost_usd'] as num?)?.toDouble() ?? 0.0;
                        return DataRow(
                          cells: [
                            DataCell(Text(school?['name'] ?? '—')),
                            DataCell(Text(
                              l['model'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: ConsoleColors.textSecondary,
                              ),
                            )),
                            DataCell(Text('${l['total_tokens'] ?? 0}')),
                            DataCell(Text(
                              '\$${cost.toStringAsFixed(5)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: ConsoleColors.success,
                              ),
                            )),
                            DataCell(Text('${l['latency_ms'] ?? "—"} ms')),
                            DataCell(
                                _buildStatusBadge(l['status'] ?? 'success')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 5. AUDIT PAGE
  // ══════════════════════════════════════════════════════════════
  Widget _buildAuditPage(PlatformState state) {
    final logs = state.auditLogs.where((a) {
      if (_searchQuery.isEmpty) return true;
      final act = (a['action'] ?? '').toString().toLowerCase();
      final tbl = (a['target_table'] ?? '').toString().toLowerCase();
      final role = (a['actor_role'] ?? '').toString().toLowerCase();
      return act.contains(_searchQuery) ||
          tbl.contains(_searchQuery) ||
          role.contains(_searchQuery);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: _surfaceCard(
        title: 'Journal d\'Audit Système (${logs.length})',
        child: logs.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'Aucune entrée d\'audit trouvée.',
                    style: TextStyle(color: ConsoleColors.textSecondary),
                  ),
                ),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Établissement')),
                    DataColumn(label: Text('Acteur')),
                    DataColumn(label: Text('Action')),
                    DataColumn(label: Text('Cible')),
                  ],
                  rows: logs.map((a) {
                    final school = a['school'] as Map<String, dynamic>?;
                    final date = a['created_at'] != null
                        ? a['created_at'].toString().split('.')[0]
                        : '';
                    return DataRow(
                      cells: [
                        DataCell(Text(date,
                            style: const TextStyle(
                                fontSize: 12,
                                color: ConsoleColors.textSecondary))),
                        DataCell(Text(school?['name'] ?? 'Plateforme')),
                        DataCell(Text(
                          a['actor_role'] ?? 'system',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: ConsoleColors.brand,
                          ),
                        )),
                        DataCell(Text(
                          a['action'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        )),
                        DataCell(Text(a['target_table'] ?? '')),
                      ],
                    );
                  }).toList(),
                ),
              ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // 6. BUG REPORTS PAGE
  // ══════════════════════════════════════════════════════════════
  Widget _buildBugReportsPage(PlatformState state) {
    final reports = state.bugReports.where((b) {
      if (_searchQuery.isEmpty) return true;
      final t = (b['title'] ?? '').toString().toLowerCase();
      final d = (b['description'] ?? '').toString().toLowerCase();
      final s = (b['student_name'] ?? '').toString().toLowerCase();
      return t.contains(_searchQuery) ||
          d.contains(_searchQuery) ||
          s.contains(_searchQuery);
    }).toList();

    final total = reports.length;
    final openCount = reports
        .where((b) => b['status'] == 'open' || b['status'] == 'sent')
        .length;
    final inProgressCount =
        reports.where((b) => b['status'] == 'in_progress').length;
    final resolvedCount = reports
        .where((b) => b['status'] == 'resolved' || b['status'] == 'closed')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Signalements',
                  '$total',
                  'Tous les rapports reçus',
                  Icons.bug_report_outlined,
                  ConsoleColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Bugs Ouverts',
                  '$openCount',
                  'En attente d\'analyse',
                  Icons.error_outline,
                  ConsoleColors.error,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'En Cours',
                  '$inProgressCount',
                  'Pris en charge',
                  Icons.hourglass_top_rounded,
                  ConsoleColors.warning,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Résolus / Fermés',
                  '$resolvedCount',
                  'Corrigés',
                  Icons.check_circle_outline,
                  ConsoleColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _surfaceCard(
            title: 'Rapports de Bugs des Utilisateurs',
            child: reports.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'Aucun rapport de bug soumis pour l\'instant.',
                        style: TextStyle(color: ConsoleColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reports.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) {
                      final bug = reports[idx];
                      final id = bug['id']?.toString() ?? '';
                      final title = bug['title']?.toString() ?? 'Sans titre';
                      final desc = bug['description']?.toString() ?? '';
                      final status =
                          bug['status']?.toString().toLowerCase() ?? 'open';
                      final category = bug['category']?.toString() ?? 'Général';
                      final studentName = bug['student_name']?.toString() ??
                          'Étudiant anonyme';
                      final studentCode = bug['student_code']?.toString();
                      final schoolName = bug['schools']?['name']?.toString() ??
                          bug['school_id']?.toString() ??
                          'Non spécifié';
                      final createdAt = bug['created_at']?.toString() ?? '';
                      final isFallback = bug['_source'] == 'suggestions';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ConsoleColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ConsoleColors.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ConsoleColors.brandSoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    category.toUpperCase(),
                                    style: const TextStyle(
                                      color: ConsoleColors.brand,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: ConsoleColors.textPrimary,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '$studentName ${studentCode != null ? "($studentCode)" : ""} • $schoolName • ${createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt}',
                                        style: const TextStyle(
                                          color: ConsoleColors.textSecondary,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  initialValue: status,
                                  onSelected: (val) => ref
                                      .read(platformProvider.notifier)
                                      .updateBugReportStatus(id, val,
                                          isFallback: isFallback),
                                  child: _buildBugStatusBadge(status),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'open',
                                        child: Text('Marquer Ouvert')),
                                    PopupMenuItem(
                                        value: 'in_progress',
                                        child: Text('Marquer En cours')),
                                    PopupMenuItem(
                                        value: 'resolved',
                                        child: Text('Marquer Résolu')),
                                    PopupMenuItem(
                                        value: 'closed',
                                        child: Text('Marquer Fermé')),
                                  ],
                                ),
                              ],
                            ),
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: ConsoleColors.cardBorder),
                                ),
                                child: Text(
                                  desc,
                                  style: const TextStyle(
                                    color: ConsoleColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
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
    Color color,
  ) {
    return Container(
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
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: ConsoleColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: ConsoleColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: ConsoleColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ],
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
    final codeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final directorNameCtrl = TextEditingController();
    final directorEmailCtrl = TextEditingController();
    final directorPassCtrl = TextEditingController(text: 'Director2026!');
    String selectedPlanId = plans.isNotEmpty ? plans[0]['id'] : '';
    String? selectedLogoUrl;
    bool uploadingLogo = false;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: StatefulBuilder(
          builder: (sbContext, setSbState) => AlertDialog(
            title: const Text(
              'Créer un Nouvel Établissement',
              style: TextStyle(
                color: ConsoleColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: ConsoleColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: ConsoleColors.cardBorder),
                          ),
                          child: uploadingLogo
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : _buildSchoolLogoThumb(
                                  selectedLogoUrl,
                                  size: 60,
                                  radius: 14,
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: uploadingLogo
                                    ? null
                                    : () async {
                                        setSbState(() => uploadingLogo = true);
                                        try {
                                          final url = await ref
                                              .read(platformProvider.notifier)
                                              .pickAndUploadSchoolLogo(
                                                schoolId: codeCtrl.text
                                                        .trim()
                                                        .isNotEmpty
                                                    ? codeCtrl.text.trim()
                                                    : 'new_school',
                                              );
                                          if (!ctx.mounted) return;
                                          if (url != null) {
                                            setSbState(
                                                () => selectedLogoUrl = url);
                                          }
                                        } catch (_) {} finally {
                                          if (ctx.mounted) {
                                            setSbState(
                                                () => uploadingLogo = false);
                                          }
                                        }
                                      },
                                icon:
                                    const Icon(Icons.image_outlined, size: 16),
                                label:
                                    const Text('Logo de l\'école (optionnel)'),
                              ),
                              if (selectedLogoUrl != null)
                                TextButton(
                                  onPressed: () =>
                                      setSbState(() => selectedLogoUrl = null),
                                  child: const Text('Par défaut'),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Nom de l\'établissement *'),
                      onChanged: (val) {
                        codeCtrl.text = val
                            .toLowerCase()
                            .replaceAll(RegExp(r'[^a-z0-9]'), '');
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Code École (ex: esb, insat) *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Email Contact Établissement *'),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    TextField(
                      controller: directorNameCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Nom complet du Directeur *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: directorEmailCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Email connexion Directeur *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: directorPassCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Mot de passe temporaire *'),
                    ),
                    const SizedBox(height: 16),
                    if (plans.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: selectedPlanId,
                        decoration: const InputDecoration(
                            labelText: 'Formule d\'abonnement'),
                        items: plans.map((p) {
                          return DropdownMenuItem<String>(
                            value: p['id'] as String,
                            child: Text(
                                '${p['name']} (${p['price_tnd_monthly']} TND/m)'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setSbState(() => selectedPlanId = val);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler')),
              ElevatedButton(
                onPressed: uploadingLogo
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty ||
                            codeCtrl.text.trim().isEmpty ||
                            directorEmailCtrl.text.trim().isEmpty) {
                          return;
                        }
                        Navigator.pop(ctx);
                        final ok = await ref
                            .read(platformProvider.notifier)
                            .createSchool(
                              name: nameCtrl.text.trim(),
                              code: codeCtrl.text.trim(),
                              email: emailCtrl.text.trim(),
                              logoUrl: selectedLogoUrl,
                              directorName: directorNameCtrl.text.trim(),
                              directorEmail: directorEmailCtrl.text.trim(),
                              directorPassword: directorPassCtrl.text.trim(),
                              planId: selectedPlanId,
                            );

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Établissement créé avec succès !'
                                : 'Erreur de création.'),
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
                child: const Text('Créer l\'Établissement'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualInvoiceModal(
    BuildContext context,
    List<Map<String, dynamic>> schools,
  ) {
    if (schools.isEmpty) return;
    String selectedSchoolId = schools[0]['id'];
    final amountCtrl = TextEditingController(text: '850.00');
    final dueDateCtrl = TextEditingController(
      text: DateTime.now()
          .add(const Duration(days: 14))
          .toIso8601String()
          .split('T')[0],
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: StatefulBuilder(
          builder: (sbContext, setSbState) => AlertDialog(
            title: const Text(
              'Émettre Facture Manuelle',
              style: TextStyle(
                color: ConsoleColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedSchoolId,
                    decoration:
                        const InputDecoration(labelText: 'Établissement'),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Montant (TND) *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dueDateCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Date d\'échéance (YYYY-MM-DD) *'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  final ok = await ref
                      .read(platformProvider.notifier)
                      .issueManualInvoice(
                        schoolId: selectedSchoolId,
                        amount: amount,
                        dueDate: dueDateCtrl.text.trim(),
                      );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok
                          ? 'Facture émise avec succès !'
                          : 'Erreur lors de l\'émission.'),
                      backgroundColor:
                          ok ? ConsoleColors.success : ConsoleColors.error,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ConsoleColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Émettre'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
