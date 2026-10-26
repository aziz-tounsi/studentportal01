import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/admin_sidebar.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/subscription'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
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
                                  Text(
                                    state.errorMessage!,
                                    style: TextStyle(color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => ref
                                        .read(subscriptionProvider.notifier)
                                        .loadSubscription(),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Réessayer'),
                                  ),
                                ],
                              ),
                            )
                          : _buildContent(context, state),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1321),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Abonnement & Facturation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gérez votre formule SaaS, vos quotas IA et vos règlements d\'établissement',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              ),
            ],
          ),
          IconButton(
            onPressed: () => ref.read(subscriptionProvider.notifier).loadSubscription(),
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Actualiser',
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, SubscriptionState state) {
    final sub = state.subscriptionData;
    final plan = sub?['plan'] as Map<String, dynamic>?;
    final status = (sub?['status'] as String?) ?? 'trial';
    final periodEnd = sub?['current_period_end'] != null
        ? DateTime.tryParse(sub!['current_period_end'])
        : null;
    final daysRemaining = periodEnd != null
        ? periodEnd.difference(DateTime.now()).inDays
        : 0;

    final quota = state.aiQuota;
    final spentUsd = (quota?['spent_current_month_usd'] as num?)?.toDouble() ?? 0.0;
    final budgetUsd = (quota?['monthly_budget_usd'] as num?)?.toDouble() ?? 20.0;
    final tokens = (quota?['tokens_current_month'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Active Plan Header Card ──
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.verified_outlined, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            plan?['name'] ?? 'Formule Standard',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusBadge(status),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Période active jusqu\'au ${periodEnd != null ? "${periodEnd.day}/${periodEnd.month}/${periodEnd.year}" : "N/A"} (${daysRemaining >= 0 ? "$daysRemaining jours restants" : "Expiré"})',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${plan?['price_tnd_monthly'] ?? 850} TND / mois',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cycle: ${sub?['billing_cycle'] ?? 'Mensuel'}',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Quotas and Telemetry Metrics ──
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Consommation IA (NOVA)',
                  value: '\$${spentUsd.toStringAsFixed(2)} / \$${budgetUsd.toStringAsFixed(2)}',
                  subtitle: '${(tokens / 1000).toStringAsFixed(1)}k tokens utilisés ce mois',
                  icon: Icons.auto_awesome,
                  accentColor: const Color(0xFF8B5CF6),
                  progress: budgetUsd > 0 ? (spentUsd / budgetUsd).clamp(0.0, 1.0) : 0.0,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: 'Capacité Étudiants',
                  value: '${plan?['max_students'] ?? 600} Inscriptions Max',
                  subtitle: 'Quota de la formule contractuelle',
                  icon: Icons.groups_outlined,
                  accentColor: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  title: 'Quota Messages IA',
                  value: '${plan?['daily_ai_messages_per_student'] ?? 60} msgs/jour',
                  subtitle: 'Par élève connecté sur l\'application mobile',
                  icon: Icons.chat_bubble_outline,
                  accentColor: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // ── Invoices Section ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Historique des Factures & Règlements',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showPaymentInstructionsModal(context),
                icon: const Icon(Icons.account_balance_outlined, size: 16),
                label: const Text('Coordonnées Bancaires'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Invoices Table ──
          _buildInvoicesTable(context, state.invoices),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status.toLowerCase()) {
      case 'active':
        bg = const Color(0xFF059669).withOpacity(0.2);
        fg = const Color(0xFF34D399);
        label = 'ACTIF';
        break;
      case 'trial':
        bg = const Color(0xFF2563EB).withOpacity(0.2);
        fg = const Color(0xFF60A5FA);
        label = 'ESSAI';
        break;
      case 'past_due':
        bg = const Color(0xFFD97706).withOpacity(0.2);
        fg = const Color(0xFFFBBF24);
        label = 'EN RETARD';
        break;
      case 'suspended':
        bg = const Color(0xFFDC2626).withOpacity(0.2);
        fg = const Color(0xFFF87171);
        label = 'SUSPENDU';
        break;
      default:
        bg = Colors.white10;
        fg = Colors.white70;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    double? progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
              ),
              Icon(icon, color: accentColor, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoicesTable(BuildContext context, List<Map<String, dynamic>> invoices) {
    if (invoices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF131D31),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: const Center(
          child: Text(
            'Aucune facture émise pour le moment.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.03)),
          columns: const [
            DataColumn(label: Text('Numéro', style: TextStyle(color: Colors.white70))),
            DataColumn(label: Text('Montant', style: TextStyle(color: Colors.white70))),
            DataColumn(label: Text('Date d\'émission', style: TextStyle(color: Colors.white70))),
            DataColumn(label: Text('Échéance', style: TextStyle(color: Colors.white70))),
            DataColumn(label: Text('Statut', style: TextStyle(color: Colors.white70))),
            DataColumn(label: Text('Actions', style: TextStyle(color: Colors.white70))),
          ],
          rows: invoices.map((inv) {
            final status = inv['status'] as String? ?? 'issued';
            final isPaid = status == 'paid';
            final payments = inv['invoice_payments'] as List? ?? [];
            final hasPendingPayment = payments.any((p) => p['is_verified'] == false);

            return DataRow(
              cells: [
                DataCell(Text(inv['invoice_number'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                DataCell(Text('${inv['amount']} ${inv['currency'] ?? 'TND'}', style: const TextStyle(color: Colors.white))),
                DataCell(Text(inv['issue_date'] ?? '', style: const TextStyle(color: Colors.white70))),
                DataCell(Text(inv['due_date'] ?? '', style: const TextStyle(color: Colors.white70))),
                DataCell(_buildStatusBadge(hasPendingPayment && !isPaid ? 'En vérification' : status)),
                DataCell(
                  isPaid
                      ? const Text('Réglée', style: TextStyle(color: Color(0xFF34D399), fontSize: 12))
                      : ElevatedButton(
                          onPressed: () => _showSubmitPaymentDialog(context, inv),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Déclarer Virement', style: TextStyle(fontSize: 12)),
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPaymentInstructionsModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Coordonnées de Règlement', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Effectuez votre virement bancaire ou postal aux coordonnées ci-dessous, puis saisissez le numéro de transaction :',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            _infoRow('Bénéficiaire', 'Pythagore SaaS Platform SARL'),
            _infoRow('Banque', 'BIAT / BNA / Attijari Bank'),
            _infoRow('RIB Tunisien', '08 000 0000000000000 00'),
            _infoRow('D17 / Flouci', '+216 99 000 000'),
            _infoRow('Email Comptabilité', 'billing@pythagore.tn'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label :',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showSubmitPaymentDialog(BuildContext context, Map<String, dynamic> invoice) {
    final refController = TextEditingController();
    final notesController = TextEditingController();
    String method = 'bank_transfer';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(
            'Déclaration de Paiement (${invoice['invoice_number']})',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Montant à régler : ${invoice['amount']} ${invoice['currency'] ?? 'TND'}',
                style: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: method,
                dropdownColor: const Color(0xFF0F172A),
                decoration: const InputDecoration(labelText: 'Moyen de paiement'),
                items: const [
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Virement Bancaire')),
                  DropdownMenuItem(value: 'cheque', child: Text('Chèque')),
                  DropdownMenuItem(value: 'd17', child: Text('D17 / La Poste')),
                  DropdownMenuItem(value: 'flouci', child: Text('Flouci')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => method = val);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: refController,
                decoration: const InputDecoration(
                  labelText: 'Numéro de transaction / Référence chèque *',
                  hintText: 'Ex: TRF-98234823',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes ou observations (facultatif)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (refController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final success = await ref.read(subscriptionProvider.notifier).submitPaymentProof(
                  invoiceId: invoice['id'],
                  amount: (invoice['amount'] as num).toDouble(),
                  paymentMethod: method,
                  transactionRef: refController.text.trim(),
                  notes: notesController.text.trim(),
                );

                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Déclaration transmise avec succès ! En attente de validation.'
                          : 'Erreur lors de la déclaration.',
                    ),
                    backgroundColor: success ? const Color(0xFF059669) : const Color(0xFFDC2626),
                  ),
                );
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }
}
