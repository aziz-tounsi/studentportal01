import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/platform_console_provider.dart';
import '../../widgets/admin_sidebar.dart';

class PlatformConsoleScreen extends ConsumerStatefulWidget {
  const PlatformConsoleScreen({super.key});

  @override
  ConsumerState<PlatformConsoleScreen> createState() => _PlatformConsoleScreenState();
}

class _PlatformConsoleScreenState extends ConsumerState<PlatformConsoleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Strict Role Guard
    if (user == null || user.role != 'super_admin') {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF131D31),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security_rounded, size: 56, color: AppColors.error),
                const SizedBox(height: 16),
                const Text(
                  'Accès Restreint — Fondateur Seul',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'La console de pilotage multi-tenant est strictement réservée au rôle super_admin de la plateforme.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/dashboard'),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Retour au Tableau de Bord'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final state = ref.watch(platformConsoleProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/platform-console'),
          Expanded(
            child: Column(
              children: [
                _buildHeader(state),
                _buildTabBar(),
                Expanded(
                  child: state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : state.errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.error_outline, size: 48, color: AppColors.error),
                                  const SizedBox(height: 12),
                                  Text(state.errorMessage!, style: const TextStyle(color: Colors.white70)),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => ref.read(platformConsoleProvider.notifier).loadAll(),
                                    child: const Text('Actualiser'),
                                  ),
                                ],
                              ),
                            )
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _buildOverviewTab(state),
                                _buildSchoolsTab(state),
                                _buildBillingTab(state),
                                _buildAiTelemetryTab(state),
                                _buildAuditTab(state),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(PlatformConsoleState state) {
    final killSwitch = state.platformSettings?['global_ai_kill_switch'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1D),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Console Fondateur SaaS — Pythagore',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Supervision multi-établissements, revenus MRR et télémétrie unifiée',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Global Kill Switch Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: killSwitch
                      ? const Color(0xFFDC2626).withValues(alpha: 0.2)
                      : const Color(0xFF059669).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: killSwitch ? const Color(0xFFF87171) : const Color(0xFF34D399),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      killSwitch ? Icons.warning_rounded : Icons.check_circle_outline,
                      size: 14,
                      color: killSwitch ? const Color(0xFFF87171) : const Color(0xFF34D399),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      killSwitch ? 'IA PLATFORME COUPÉE' : 'IA OPÉRATIONNELLE',
                      style: TextStyle(
                        color: killSwitch ? const Color(0xFFF87171) : const Color(0xFF34D399),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => ref.read(platformConsoleProvider.notifier).loadAll(),
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Actualiser',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF0D1321),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: const Color(0xFF60A5FA),
        unselectedLabelColor: Colors.white60,
        indicatorColor: const Color(0xFF2563EB),
        tabs: const [
          Tab(icon: Icon(Icons.insights, size: 18), text: 'Vue d\'ensemble & MRR'),
          Tab(icon: Icon(Icons.school, size: 18), text: 'Établissements'),
          Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Factures & Règlements'),
          Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'Télémétrie IA & Coûts'),
          Tab(icon: Icon(Icons.history, size: 18), text: 'Journal d\'Audit'),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // 1. Overview Tab
  // ═════════════════════════════════════════════════════════════════
  Widget _buildOverviewTab(PlatformConsoleState state) {
    final kpis = state.kpis;
    final mrr = (kpis['mrrTnd'] as num?)?.toDouble() ?? 0.0;
    final aiSpendUsd = (kpis['totalAiSpendUsd'] as num?)?.toDouble() ?? 0.0;
    final aiSpendTnd = aiSpendUsd * 3.12; // Approx USD/TND rate
    final marginPct = mrr > 0 ? (((mrr - aiSpendTnd) / mrr) * 100).clamp(0, 100).toStringAsFixed(1) : '95.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'MRR Total Souscrit',
                  value: '${mrr.toStringAsFixed(0)} TND / mois',
                  subtitle: 'Revenu récurrent mensuel',
                  icon: Icons.trending_up,
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricTile(
                  title: 'Établissements Actifs',
                  value: '${kpis['activeSchools'] ?? 0} / ${kpis['totalSchools'] ?? 0}',
                  subtitle: 'Comptes écoles déployés',
                  icon: Icons.domain,
                  color: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricTile(
                  title: 'Dépenses IA OpenRouter',
                  value: '\$${aiSpendUsd.toStringAsFixed(2)} (~${aiSpendTnd.toStringAsFixed(1)} TND)',
                  subtitle: 'Coût total API ce mois',
                  icon: Icons.memory,
                  color: const Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricTile(
                  title: 'Marge Brute Estimée',
                  value: '$marginPct%',
                  subtitle: 'Profit net après COGS IA',
                  icon: Icons.pie_chart,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Pending Payments Banner if any
          if ((kpis['pendingVerifications'] as int? ?? 0) > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions, color: Color(0xFFFBBF24)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '${kpis['pendingVerifications']} paiement(s) par virement en attente de vérification et d\'activation.',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _tabController.animateTo(2),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                    ),
                    child: const Text('Vérifier Maintenant'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Quick Actions Row
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showCreateSchoolDialog(context, state.plans),
                icon: const Icon(Icons.add_business),
                label: const Text('Créer un Nouvel Établissement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _showManualInvoiceDialog(context, state.schools),
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Émettre Facture Manuelle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════
  // 2. Schools Tab
  // ═════════════════════════════════════════════════════════════════
  Widget _buildSchoolsTab(PlatformConsoleState state) {
    final schools = state.schools;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Établissements Clients (${schools.length})',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateSchoolDialog(context, state.plans),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une École'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131D31),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.03)),
                columns: const [
                  DataColumn(label: Text('Nom', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Code / Slug', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Formule', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Statut', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Conso IA', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Actions', style: TextStyle(color: Colors.white70))),
                ],
                rows: schools.map((s) {
                  final subs = s['school_subscriptions'] as List? ?? [];
                  final sub = subs.isNotEmpty ? subs[0] : null;
                  final plan = sub?['plan'] as Map<String, dynamic>?;
                  final quota = (s['ai_school_quotas'] as List? ?? []).isNotEmpty ? s['ai_school_quotas'][0] : null;
                  final isActive = s['is_active'] == true;
                  final spentUsd = (quota?['spent_current_month_usd'] as num?)?.toDouble() ?? 0.0;
                  final budgetUsd = (quota?['monthly_budget_usd'] as num?)?.toDouble() ?? 25.0;

                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF2563EB),
                              child: Text(
                                (s['name'] as String? ?? 'E').substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(s['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      DataCell(Text(s['code'] ?? '—', style: const TextStyle(color: Colors.white70))),
                      DataCell(Text(plan?['name'] ?? 'Essai Standard', style: const TextStyle(color: Colors.white70))),
                      DataCell(_buildStatusChip(isActive ? (sub?['status'] ?? 'actif') : 'inactif')),
                      DataCell(Text('\$${spentUsd.toStringAsFixed(2)} / \$${budgetUsd.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                color: isActive ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                                size: 20,
                              ),
                              tooltip: isActive ? 'Suspendre l\'école' : 'Réactiver l\'école',
                              onPressed: () => ref
                                  .read(platformConsoleProvider.notifier)
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

  // ═════════════════════════════════════════════════════════════════
  // 3. Billing & Invoicing Tab
  // ═════════════════════════════════════════════════════════════════
  Widget _buildBillingTab(PlatformConsoleState state) {
    final pending = state.pendingPayments;
    final invoices = state.invoices;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pending Payments Section
          Text(
            'Paiements en Attente de Validation (${pending.length})',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF131D31),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Center(
                child: Text('Aucun paiement en attente. Tout est à jour.', style: TextStyle(color: Colors.white54)),
              ),
            )
          else
            ...pending.map((p) {
              final inv = p['invoice'] as Map<String, dynamic>?;
              final school = inv?['school'] as Map<String, dynamic>?;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D31),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance, color: Color(0xFF60A5FA)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${school?['name'] ?? "École"} — Facture ${inv?['invoice_number'] ?? ""}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Méthode: ${p['payment_method']} | Réf: ${p['transaction_ref'] ?? "N/A"} | Montant: ${p['amount']} TND',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await ref.read(platformConsoleProvider.notifier).verifyPayment(p['id']);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Paiement validé et abonnement prolongé !' : 'Échec de la validation.'),
                            backgroundColor: ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Valider Virement'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 32),

          // Invoices History
          Text(
            'Toutes les Factures Émises (${invoices.length})',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131D31),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.03)),
                columns: const [
                  DataColumn(label: Text('Numéro', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Établissement', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Montant', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Échéance', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Statut', style: TextStyle(color: Colors.white70))),
                ],
                rows: invoices.map((inv) {
                  final school = inv['school'] as Map<String, dynamic>?;
                  return DataRow(
                    cells: [
                      DataCell(Text(inv['invoice_number'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                      DataCell(Text(school?['name'] ?? '—', style: const TextStyle(color: Colors.white70))),
                      DataCell(Text('${inv['amount']} ${inv['currency'] ?? 'TND'}', style: const TextStyle(color: Colors.white))),
                      DataCell(Text(inv['due_date'] ?? '', style: const TextStyle(color: Colors.white70))),
                      DataCell(_buildStatusChip(inv['status'] ?? 'issued')),
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

  // ═════════════════════════════════════════════════════════════════
  // 4. AI Telemetry & Cost Control Tab
  // ═════════════════════════════════════════════════════════════════
  Widget _buildAiTelemetryTab(PlatformConsoleState state) {
    final settings = state.platformSettings;
    final killSwitch = settings?['global_ai_kill_switch'] == true;
    final defaultModel = settings?['default_ai_model'] ?? 'poolside/laguna-s-2.1:free';
    final fallbackModel = settings?['fallback_ai_model'] ?? 'google/gemini-2.0-flash-exp:free';
    final logs = state.recentAiLogs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Emergency Kill-Switch Control
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: killSwitch
                  ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                  : const Color(0xFF131D31),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: killSwitch ? const Color(0xFFF87171) : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  killSwitch ? Icons.power_off : Icons.power,
                  color: killSwitch ? const Color(0xFFF87171) : const Color(0xFF34D399),
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Interrupteur Général d\'Urgence IA (Kill-Switch Global)',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Coupe instantanément tous les appels vers OpenRouter sur l\'ensemble des établissements en cas d\'anomalie ou de dépassement budgétaire.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: killSwitch,
                  activeColor: const Color(0xFFDC2626),
                  onChanged: (val) => ref
                      .read(platformConsoleProvider.notifier)
                      .toggleGlobalAiKillSwitch(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Models Selection Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF131D31),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Modèles OpenRouter par Défaut & Fallback',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text('Modèle Primaire : $defaultModel', style: const TextStyle(color: Colors.white70)),
                    ),
                    Expanded(
                      child: Text('Modèle Secours : $fallbackModel', style: const TextStyle(color: Colors.white70)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Telemetry Inferences Log Table
          Text(
            'Dernières Inférences IA Enregistrées (${logs.length})',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131D31),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.03)),
                columns: const [
                  DataColumn(label: Text('École', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Modèle', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Tokens Total', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Coût USD', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Latence', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Statut', style: TextStyle(color: Colors.white70))),
                ],
                rows: logs.map((l) {
                  final school = l['school'] as Map<String, dynamic>?;
                  final cost = (l['cost_usd'] as num?)?.toDouble() ?? 0.0;
                  final latency = l['latency_ms'] != null ? '${l['latency_ms']} ms' : '—';

                  return DataRow(
                    cells: [
                      DataCell(Text(school?['name'] ?? '—', style: const TextStyle(color: Colors.white))),
                      DataCell(Text(l['model'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                      DataCell(Text('${l['total_tokens'] ?? 0}', style: const TextStyle(color: Colors.white))),
                      DataCell(Text('\$${cost.toStringAsFixed(5)}', style: const TextStyle(color: Color(0xFF34D399)))),
                      DataCell(Text(latency, style: const TextStyle(color: Colors.white70))),
                      DataCell(_buildStatusChip(l['status'] ?? 'success')),
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

  // ═════════════════════════════════════════════════════════════════
  // 5. Audit Log Tab
  // ═════════════════════════════════════════════════════════════════
  Widget _buildAuditTab(PlatformConsoleState state) {
    final auditLogs = state.auditLogs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Journal d\'Audit Forensique Système (${auditLogs.length})',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF131D31),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.03)),
                columns: const [
                  DataColumn(label: Text('Date / Heure', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Établissement', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Rôle Acteur', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Action', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Table Cible', style: TextStyle(color: Colors.white70))),
                ],
                rows: auditLogs.map((a) {
                  final school = a['school'] as Map<String, dynamic>?;
                  final date = a['created_at'] != null ? a['created_at'].toString().split('.')[0] : '';

                  return DataRow(
                    cells: [
                      DataCell(Text(date, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                      DataCell(Text(school?['name'] ?? 'Plateforme', style: const TextStyle(color: Colors.white))),
                      DataCell(Text(a['actor_role'] ?? 'system', style: const TextStyle(color: Color(0xFF60A5FA)))),
                      DataCell(Text(a['action'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                      DataCell(Text(a['target_table'] ?? '', style: const TextStyle(color: Colors.white70))),
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

  // ═════════════════════════════════════════════════════════════════
  // Dialogs & Modals
  // ═════════════════════════════════════════════════════════════════
  void _showCreateSchoolDialog(BuildContext context, List<Map<String, dynamic>> plans) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final directorNameCtrl = TextEditingController();
    final directorEmailCtrl = TextEditingController();
    final directorPassCtrl = TextEditingController(text: 'Director2026!');
    String selectedPlanId = plans.isNotEmpty ? plans[0]['id'] : '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (sbContext, setSbState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Créer un Nouvel Établissement', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom de l\'établissement *'),
                    onChanged: (val) {
                      final generated = val.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                      codeCtrl.text = generated;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(labelText: 'Identifiant / Code École (ex: esb, insat) *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email Contact Établissement *'),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const Text('Directeur / Fondateur de l\'établissement', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: directorNameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom complet du Directeur *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: directorEmailCtrl,
                    decoration: const InputDecoration(labelText: 'Email de connexion Directeur *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: directorPassCtrl,
                    decoration: const InputDecoration(labelText: 'Mot de passe initial *'),
                  ),
                  const SizedBox(height: 16),
                  if (plans.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedPlanId,
                      dropdownColor: const Color(0xFF0F172A),
                      decoration: const InputDecoration(labelText: 'Formule d\'abonnement'),
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
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || codeCtrl.text.trim().isEmpty || directorEmailCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx);
                final ok = await ref.read(platformConsoleProvider.notifier).createSchoolWithDirector(
                  schoolName: nameCtrl.text.trim(),
                  schoolCode: codeCtrl.text.trim(),
                  contactEmail: emailCtrl.text.trim(),
                  directorName: directorNameCtrl.text.trim(),
                  directorEmail: directorEmailCtrl.text.trim(),
                  directorPassword: directorPassCtrl.text.trim(),
                  planId: selectedPlanId,
                );

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Établissement et compte directeur créés avec succès !' : 'Erreur de création.'),
                    backgroundColor: ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                );
              },
              child: const Text('Créer l\'Établissement'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualInvoiceDialog(BuildContext context, List<Map<String, dynamic>> schools) {
    if (schools.isEmpty) return;
    String selectedSchoolId = schools[0]['id'];
    final amountCtrl = TextEditingController(text: '850.00');
    final notesCtrl = TextEditingController(text: 'Facturation ponctuelle / licence');
    final dueDateCtrl = TextEditingController(
      text: DateTime.now().add(const Duration(days: 14)).toIso8601String().split('T')[0],
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (sbContext, setSbState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Émettre une Facture Manuelle', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedSchoolId,
                dropdownColor: const Color(0xFF0F172A),
                decoration: const InputDecoration(labelText: 'Établissement'),
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
                decoration: const InputDecoration(labelText: 'Montant (TND) *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dueDateCtrl,
                decoration: const InputDecoration(labelText: 'Date d\'échéance (YYYY-MM-DD) *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Libellé / Notes'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                final ok = await ref.read(platformConsoleProvider.notifier).issueManualInvoice(
                  schoolId: selectedSchoolId,
                  amount: amount,
                  dueDate: dueDateCtrl.text.trim(),
                  notes: notesCtrl.text.trim(),
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Facture émise avec succès !' : 'Erreur lors de l\'émission.'),
                    backgroundColor: ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                );
              },
              child: const Text('Émettre la Facture'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'active':
      case 'actif':
      case 'paid':
      case 'success':
        bg = const Color(0xFF059669).withValues(alpha: 0.2);
        fg = const Color(0xFF34D399);
        label = status.toUpperCase();
        break;
      case 'trial':
      case 'issued':
        bg = const Color(0xFF2563EB).withValues(alpha: 0.2);
        fg = const Color(0xFF60A5FA);
        label = status.toUpperCase();
        break;
      case 'past_due':
      case 'overdue':
        bg = const Color(0xFFD97706).withValues(alpha: 0.2);
        fg = const Color(0xFFFBBF24);
        label = status.toUpperCase();
        break;
      case 'suspended':
      case 'inactif':
      case 'error':
        bg = const Color(0xFFDC2626).withValues(alpha: 0.2);
        fg = const Color(0xFFF87171);
        label = status.toUpperCase();
        break;
      default:
        bg = Colors.white10;
        fg = Colors.white70;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
