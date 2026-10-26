import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/console_theme.dart';
import '../providers/console_auth_provider.dart';
import '../providers/platform_provider.dart';

class ConsoleDashboardScreen extends ConsumerStatefulWidget {
  const ConsoleDashboardScreen({super.key});

  @override
  ConsumerState<ConsoleDashboardScreen> createState() => _ConsoleDashboardScreenState();
}

class _ConsoleDashboardScreenState extends ConsumerState<ConsoleDashboardScreen>
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
    final authState = ref.watch(consoleAuthProvider);
    final platformState = ref.watch(platformProvider);

    if (!authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/login');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: ConsoleColors.background,
      body: Column(
        children: [
          _buildTopBar(authState.user),
          _buildTabBar(),
          Expanded(
            child: platformState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : platformState.errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: ConsoleColors.error),
                            const SizedBox(height: 12),
                            Text(platformState.errorMessage!, style: const TextStyle(color: Colors.white70)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref.read(platformProvider.notifier).loadAll(),
                              child: const Text('Actualiser'),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(platformState),
                          _buildSchoolsTab(platformState),
                          _buildBillingTab(platformState),
                          _buildAiTelemetryTab(platformState),
                          _buildAuditTab(platformState),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(Map<String, dynamic>? user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: const BoxDecoration(
        color: ConsoleColors.card,
        border: Border(bottom: BorderSide(color: ConsoleColors.cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: ConsoleColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pythagore SaaS — Console Propriétaire',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Projet: cazuauxivrboygehrkij | Connecté en tant que: ${user?['email'] ?? "super_admin"}',
                    style: const TextStyle(color: ConsoleColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => ref.read(platformProvider.notifier).loadAll(),
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Actualiser les données',
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(consoleAuthProvider.notifier).signOut();
                  if (mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Déconnexion'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: ConsoleColors.cardBorder),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF0B1120),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: ConsoleColors.primaryLight,
        unselectedLabelColor: Colors.white60,
        indicatorColor: ConsoleColors.primary,
        tabs: const [
          Tab(icon: Icon(Icons.insights, size: 18), text: 'Vue d\'ensemble & MRR'),
          Tab(icon: Icon(Icons.domain, size: 18), text: 'Établissements Clients'),
          Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Factures & Règlements'),
          Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'Télémétrie IA & Coûts'),
          Tab(icon: Icon(Icons.history, size: 18), text: 'Journal d\'Audit'),
        ],
      ),
    );
  }

  // 1. Overview Tab
  Widget _buildOverviewTab(PlatformState state) {
    final kpis = state.kpis;
    final mrr = (kpis['mrrTnd'] as num?)?.toDouble() ?? 0.0;
    final aiSpendUsd = (kpis['aiSpendUsd'] as num?)?.toDouble() ?? 0.0;
    final aiSpendTnd = aiSpendUsd * 3.12;
    final margin = mrr > 0 ? (((mrr - aiSpendTnd) / mrr) * 100).clamp(0, 100).toStringAsFixed(1) : '95.0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'MRR Total Souscrit',
                  '${mrr.toStringAsFixed(0)} TND / m',
                  'Revenu récurrent mensuel',
                  Icons.trending_up,
                  ConsoleColors.success,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Établissements Actifs',
                  '${kpis['activeSchools'] ?? 0} / ${kpis['totalSchools'] ?? 0}',
                  'Comptes écoles déployés',
                  Icons.domain,
                  ConsoleColors.primaryLight,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Dépenses IA OpenRouter',
                  '\$${aiSpendUsd.toStringAsFixed(2)} (~${aiSpendTnd.toStringAsFixed(1)} TND)',
                  'Coût API ce mois',
                  Icons.memory,
                  ConsoleColors.accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Marge Brute Estimée',
                  '$margin%',
                  'Rentabilité nette',
                  Icons.pie_chart,
                  ConsoleColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showCreateSchoolModal(context, state.plans),
                icon: const Icon(Icons.add_business),
                label: const Text('Créer un Nouvel Établissement (3 min)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ConsoleColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => _showManualInvoiceModal(context, state.schools),
                icon: const Icon(Icons.post_add),
                label: const Text('Émettre Facture'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: ConsoleColors.cardBorder),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Schools Tab
  Widget _buildSchoolsTab(PlatformState state) {
    final schools = state.schools;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Établissements Clients (${schools.length})',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () => _showCreateSchoolModal(context, state.plans),
                icon: const Icon(Icons.add),
                label: const Text('Nouvelle École'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: ConsoleColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ConsoleColors.cardBorder),
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
                  final spent = (quota?['spent_current_month_usd'] as num?)?.toDouble() ?? 0.0;
                  final budget = (quota?['monthly_budget_usd'] as num?)?.toDouble() ?? 25.0;

                  return DataRow(
                    cells: [
                      DataCell(Text(s['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                      DataCell(Text(s['code'] ?? '—', style: const TextStyle(color: Colors.white70))),
                      DataCell(Text(plan?['name'] ?? 'Essai Standard', style: const TextStyle(color: Colors.white70))),
                      DataCell(_buildStatusBadge(isActive ? (sub?['status'] ?? 'actif') : 'inactif')),
                      DataCell(Text('\$${spent.toStringAsFixed(2)} / \$${budget.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70))),
                      DataCell(
                        IconButton(
                          icon: Icon(
                            isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                            color: isActive ? ConsoleColors.warning : ConsoleColors.success,
                          ),
                          onPressed: () => ref.read(platformProvider.notifier).toggleSchoolStatus(s['id'], !isActive),
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

  // 3. Billing Tab
  Widget _buildBillingTab(PlatformState state) {
    final pending = state.pendingPayments;
    final invoices = state.invoices;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Virements Bancaires en Attente de Validation (${pending.length})',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (pending.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ConsoleColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ConsoleColors.cardBorder),
              ),
              child: const Center(
                child: Text('Aucun virement en attente. Tout est réglé !', style: TextStyle(color: Colors.white54)),
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
                  color: ConsoleColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ConsoleColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance, color: ConsoleColors.primaryLight),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${school?['name'] ?? "École"} — Facture ${inv?['invoice_number'] ?? ""}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('Réf: ${p['transaction_ref'] ?? "N/A"} | Montant: ${p['amount']} TND',
                              style: const TextStyle(color: ConsoleColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await ref.read(platformProvider.notifier).verifyPayment(p['id']);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Paiement validé et abonnement prolongé !' : 'Erreur validation.'),
                            backgroundColor: ok ? ConsoleColors.success : ConsoleColors.error,
                          ),
                        );
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Valider Virement'),
                      style: ElevatedButton.styleFrom(backgroundColor: ConsoleColors.success),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 32),
          Text('Factures Émises (${invoices.length})',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: ConsoleColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ConsoleColors.cardBorder),
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
                      DataCell(_buildStatusBadge(inv['status'] ?? 'issued')),
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

  // 4. AI Telemetry Tab
  Widget _buildAiTelemetryTab(PlatformState state) {
    final settings = state.platformSettings;
    final killSwitch = settings?['global_ai_kill_switch'] == true;
    final logs = state.recentAiLogs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: killSwitch ? ConsoleColors.error.withValues(alpha: 0.15) : ConsoleColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: killSwitch ? ConsoleColors.error : ConsoleColors.cardBorder),
            ),
            child: Row(
              children: [
                Icon(killSwitch ? Icons.power_off : Icons.power,
                    color: killSwitch ? ConsoleColors.error : ConsoleColors.success, size: 32),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Interrupteur Général d\'Urgence IA (Global Kill-Switch)',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Coupe instantanément tous les appels vers OpenRouter sur l\'ensemble des établissements.',
                          style: TextStyle(color: ConsoleColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Switch(
                  value: killSwitch,
                  activeThumbColor: ConsoleColors.error,
                  onChanged: (val) => ref.read(platformProvider.notifier).toggleAiKillSwitch(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Inférences IA en Direct (${logs.length})',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: ConsoleColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ConsoleColors.cardBorder),
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
                  return DataRow(
                    cells: [
                      DataCell(Text(school?['name'] ?? '—', style: const TextStyle(color: Colors.white))),
                      DataCell(Text(l['model'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                      DataCell(Text('${l['total_tokens'] ?? 0}', style: const TextStyle(color: Colors.white))),
                      DataCell(Text('\$${cost.toStringAsFixed(5)}', style: const TextStyle(color: ConsoleColors.success))),
                      DataCell(Text('${l['latency_ms'] ?? "—"} ms', style: const TextStyle(color: Colors.white70))),
                      DataCell(_buildStatusBadge(l['status'] ?? 'success')),
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

  // 5. Audit Tab
  Widget _buildAuditTab(PlatformState state) {
    final logs = state.auditLogs;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Journal d\'Audit Système (${logs.length})',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: ConsoleColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ConsoleColors.cardBorder),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.03)),
                columns: const [
                  DataColumn(label: Text('Date', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Établissement', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Acteur', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Action', style: TextStyle(color: Colors.white70))),
                  DataColumn(label: Text('Cible', style: TextStyle(color: Colors.white70))),
                ],
                rows: logs.map((a) {
                  final school = a['school'] as Map<String, dynamic>?;
                  final date = a['created_at'] != null ? a['created_at'].toString().split('.')[0] : '';
                  return DataRow(
                    cells: [
                      DataCell(Text(date, style: const TextStyle(color: Colors.white70, fontSize: 11))),
                      DataCell(Text(school?['name'] ?? 'Plateforme', style: const TextStyle(color: Colors.white))),
                      DataCell(Text(a['actor_role'] ?? 'system', style: const TextStyle(color: ConsoleColors.primaryLight))),
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

  // Modals
  void _showCreateSchoolModal(BuildContext context, List<Map<String, dynamic>> plans) {
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
                  TextField(
                    controller: directorNameCtrl,
                    decoration: const InputDecoration(labelText: 'Nom complet du Directeur *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: directorEmailCtrl,
                    decoration: const InputDecoration(labelText: 'Email connexion Directeur *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: directorPassCtrl,
                    decoration: const InputDecoration(labelText: 'Mot de passe initial *'),
                  ),
                  const SizedBox(height: 16),
                  if (plans.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: selectedPlanId,
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
                final ok = await ref.read(platformProvider.notifier).createSchool(
                  name: nameCtrl.text.trim(),
                  code: codeCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  directorName: directorNameCtrl.text.trim(),
                  directorEmail: directorEmailCtrl.text.trim(),
                  directorPassword: directorPassCtrl.text.trim(),
                  planId: selectedPlanId,
                );

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Établissement créé avec succès !' : 'Erreur de création.'),
                    backgroundColor: ok ? ConsoleColors.success : ConsoleColors.error,
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

  void _showManualInvoiceModal(BuildContext context, List<Map<String, dynamic>> schools) {
    if (schools.isEmpty) return;
    String selectedSchoolId = schools[0]['id'];
    final amountCtrl = TextEditingController(text: '850.00');
    final dueDateCtrl = TextEditingController(
      text: DateTime.now().add(const Duration(days: 14)).toIso8601String().split('T')[0],
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (sbContext, setSbState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Émettre Facture Manuelle', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedSchoolId,
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
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                final ok = await ref.read(platformProvider.notifier).issueManualInvoice(
                  schoolId: selectedSchoolId,
                  amount: amount,
                  dueDate: dueDateCtrl.text.trim(),
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Facture émise avec succès !' : 'Erreur.'),
                    backgroundColor: ok ? ConsoleColors.success : ConsoleColors.error,
                  ),
                );
              },
              child: const Text('Émettre'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ConsoleColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ConsoleColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: ConsoleColors.textSecondary, fontSize: 13)),
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

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'active':
      case 'actif':
      case 'paid':
      case 'success':
        bg = ConsoleColors.success.withValues(alpha: 0.2);
        fg = ConsoleColors.success;
        break;
      case 'trial':
      case 'issued':
        bg = ConsoleColors.primary.withValues(alpha: 0.2);
        fg = ConsoleColors.primaryLight;
        break;
      case 'past_due':
      case 'overdue':
        bg = ConsoleColors.warning.withValues(alpha: 0.2);
        fg = ConsoleColors.warning;
        break;
      default:
        bg = ConsoleColors.error.withValues(alpha: 0.2);
        fg = ConsoleColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
