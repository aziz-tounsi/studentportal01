import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/admin_sidebar.dart';
import '../../../data/models/dashboard_models.dart';

// ═══════════════════════════════════════════════════════════════════
// ░░░  AURORA GLASS — Dashboard Screen  ░░░
// ═══════════════════════════════════════════════════════════════════

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/dashboard'),
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, ref, authState),
                Expanded(
                  child: dashboardAsync.when(
                    loading: () => Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppShadows.card,
                        ),
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          ),
                        ),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Container(
                        padding: const EdgeInsets.all(36),
                        margin: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.errorSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.error.withOpacity(0.2)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 28),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Une erreur est survenue',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('$e', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    data: (state) => _buildDashboardContent(context, ref, state),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Flat Header ──
  Widget _buildHeader(BuildContext context, WidgetRef ref, AdminAuthState authState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tableau de bord',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Vue d\'ensemble de votre établissement',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),

          // Toolbar
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
               children: [
                 IconButton(
                   onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
                   icon: const Icon(Icons.refresh_rounded, size: 20),
                   tooltip: 'Actualiser',
                 ),
                 const SizedBox(width: 8),
                 IconButton(
                   onPressed: () {},
                   icon: const Icon(Icons.notifications_none_rounded, size: 20),
                 ),
                 const SizedBox(width: 16),
                 Container(width: 1, height: 24, color: AppColors.border),
                 const SizedBox(width: 16),
                 Row(
                   children: [
                     Container(
                       width: 32,
                       height: 32,
                       decoration: BoxDecoration(
                         color: AppColors.primary,
                         borderRadius: BorderRadius.circular(8),
                       ),
                       child: Center(
                         child: Text(
                           authState.user?.fullName.substring(0, 1).toUpperCase() ?? 'A',
                           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                         ),
                       ),
                     ),
                     const SizedBox(width: 12),
                     Text(
                       authState.user?.fullName ?? 'Administrateur',
                       style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                     ),
                   ],
                 ),
               ],
            ),
          )
        ],
      ),
    );
  }

  // ── Flat KPI Card ──
  Widget _buildFlatKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String subtitle,
    String? trend,
    bool? trendUp,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (trendUp ?? true) ? AppColors.successSoft : AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        (trendUp ?? true) ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 12,
                        color: (trendUp ?? true) ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        trend,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: (trendUp ?? true) ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Action Button ──
  Widget _buildQuickAction(BuildContext context, String label, IconData icon, Color color) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dashboard Content ──
  Widget _buildDashboardContent(BuildContext context, WidgetRef ref, DashboardState state) {
    final kpis = state.kpis;
    final currencyFormat = NumberFormat.currency(locale: 'fr_DZ', symbol: 'DZD ', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Actions Rapides ──
          Row(
            children: [
              _buildQuickAction(context, 'Ajouter un étudiant', Icons.person_add_alt_1_rounded, AppColors.primary),
              const SizedBox(width: 12),
              _buildQuickAction(context, 'Nouvelle classe', Icons.class_rounded, AppColors.secondary),
              const SizedBox(width: 12),
              _buildQuickAction(context, 'Saisir les notes', Icons.drive_file_rename_outline_rounded, AppColors.success),
              const Spacer(),
              Text(
                'Dernière mise à jour: ${DateFormat('HH:mm').format(DateTime.now())}',
                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── KPI Cards Row 1 — Core metrics ──
          Row(
            children: [
              Expanded(
                child: _buildFlatKpiCard(
                  title: 'Étudiants',
                  value: kpis.totalStudents.toString(),
                  icon: Icons.school_outlined,
                  color: AppColors.primary,
                  subtitle: 'Inscrits actifs',
                  trend: '+12%',
                  trendUp: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFlatKpiCard(
                  title: 'Enseignants',
                  value: kpis.totalTeachers.toString(),
                  icon: Icons.people_outline_rounded,
                  color: AppColors.success,
                  subtitle: 'Personnel actif',
                  trend: '+3%',
                  trendUp: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFlatKpiCard(
                  title: 'Classes',
                  value: kpis.totalClasses.toString(),
                  icon: Icons.layers_outlined,
                  color: AppColors.warning,
                  subtitle: 'Total actives',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFlatKpiCard(
                  title: 'À risque',
                  value: state.atRiskStudents.length.toString(),
                  icon: Icons.shield_outlined,
                  color: AppColors.error,
                  subtitle: 'Étudiants',
                  trend: state.atRiskStudents.isNotEmpty ? 'Attention' : null,
                  trendUp: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── KPI Cards Row 2 — Financial ──
          Row(
            children: [
              Expanded(
                child: _buildFlatKpiCard(
                  title: 'Paiements dus',
                  value: currencyFormat.format(kpis.totalPaymentsDue),
                  icon: Icons.account_balance_wallet_outlined,
                  color: const Color(0xFF8B5CF6),
                  subtitle: 'Total à percevoir',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFlatKpiCard(
                  title: 'Encaissés',
                  value: currencyFormat.format(kpis.totalPaymentsCollected),
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF14B8A6),
                  subtitle: '${kpis.paymentProgress.toStringAsFixed(1)}% du total',
                  trend: '+${kpis.paymentProgress.toStringAsFixed(0)}%',
                  trendUp: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFlatKpiCard(
                  title: 'Restant',
                  value: currencyFormat.format(kpis.outstandingPayments),
                  icon: Icons.schedule_rounded,
                  color: const Color(0xFFF59E0B),
                  subtitle: 'À recouvrer',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFlatKpiCard(
                  title: 'Suggestions',
                  value: kpis.openSuggestions.toString(),
                  icon: Icons.chat_bubble_outline_rounded,
                  color: const Color(0xFF6366F1),
                  subtitle: 'Non traitées',
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Charts Row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildAbsenceChart(context)),
              const SizedBox(width: 20),
              Expanded(child: _buildPaymentDonut(context, kpis)),
            ],
          ),
          const SizedBox(height: 28),

          // ── At Risk Table ──
          _buildAtRiskTable(context, state.atRiskStudents),
        ],
      ),
    );
  }

  // ── Absence Trend Chart ──
  Widget _buildAbsenceChart(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.show_chart_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tendance des absences',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Heures d\'absence par semaine',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('7 derniers jours',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                    dashArray: [6, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      getTitlesWidget: (v, m) => Text(
                        '${v.toInt()}h',
                        style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, m) => Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'S${v.toInt() + 1}',
                          style: TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 12),
                      FlSpot(1, 18),
                      FlSpot(2, 15),
                      FlSpot(3, 22),
                      FlSpot(4, 19),
                      FlSpot(5, 14),
                      FlSpot(6, 16),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: AppColors.primary,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 5,
                        color: Colors.white,
                        strokeWidth: 3,
                        strokeColor: AppColors.primary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment Donut Chart ──
  Widget _buildPaymentDonut(BuildContext context, DashboardKpis kpis) {
    final collected = kpis.totalPaymentsCollected;
    final remaining = kpis.outstandingPayments;
    final total = collected + remaining;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.donut_small_rounded, color: AppColors.success, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recouvrement',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Progression des paiements',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: total > 0
                ? PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 48,
                      sections: [
                        PieChartSectionData(
                          value: collected,
                          color: AppColors.success,
                          title: '${(collected / total * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          radius: 46,
                          titlePositionPercentageOffset: 0.55,
                        ),
                        PieChartSectionData(
                          value: remaining,
                          color: AppColors.error,
                          title: '${(remaining / total * 100).toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                          radius: 46,
                          titlePositionPercentageOffset: 0.55,
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.inbox_outlined, color: AppColors.textTertiary, size: 28),
                        ),
                        const SizedBox(height: 12),
                        const Text('Aucune donnée',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _AuroraLegendItem(
                color: AppColors.success,
                label: 'Payé',
              ),
              const SizedBox(width: 28),
              _AuroraLegendItem(
                color: AppColors.error,
                label: 'Restant',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── At Risk Students Table ──
  Widget _buildAtRiskTable(BuildContext context, List<AtRiskStudent> students) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.shield_outlined, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Étudiants à risque',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Absences supérieures au seuil autorisé',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
                child: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                  label: const Text('Voir tout'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: students.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(48),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.successSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified_outlined, color: AppColors.success, size: 30),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucun étudiant à risque',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tous les étudiants sont en règle',
                            style: TextStyle(color: Colors.grey, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppColors.slate50),
                      headingRowHeight: 48,
                      dataRowMinHeight: 58,
                      dataRowMaxHeight: 58,
                      horizontalMargin: 20,
                      columnSpacing: 28,
                      dividerThickness: 0.5,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'ÉTUDIANT',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: Colors.grey, fontSize: 11, letterSpacing: 0.5),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'CLASSE',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: Colors.grey, fontSize: 11, letterSpacing: 0.5),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'MATIÈRE',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: Colors.grey, fontSize: 11, letterSpacing: 0.5),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'ABSENCES',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: Colors.grey, fontSize: 11, letterSpacing: 0.5),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'STATUT',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: Colors.grey, fontSize: 11, letterSpacing: 0.5),
                          ),
                        ),
                      ],
                      rows: students.map((s) => DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Center(
                                    child: Text(
                                      s.studentName.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  s.studentName,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          DataCell(Text(s.className, style: const TextStyle(fontSize: 13))),
                          DataCell(Text(s.subjectName, style: const TextStyle(fontSize: 13))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.errorSoft,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.error.withOpacity(0.15)),
                              ),
                              child: Text(
                                '${s.absencePercent.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          DataCell(_AuroraStatusChip(status: s.status)),
                        ],
                      )).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ░░░  AURORA GLASS — Dashboard Internal Widgets  ░░░
// ═══════════════════════════════════════════════════════════════════

/// Frosted icon button with optional notification badge
class _AuroraIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final int badgeCount;

  const _AuroraIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.badgeCount = 0,
  });

  @override
  State<_AuroraIconButton> createState() => _AuroraIconButtonState();
}

class _AuroraIconButtonState extends State<_AuroraIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip ?? '',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _hovered ? AppColors.primarySoft : AppColors.slate50,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: _hovered ? AppColors.primary.withOpacity(0.2) : AppColors.border.withOpacity(0.5),
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: _hovered ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              if (widget.badgeCount > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 19,
                    height: 19,
                    decoration: BoxDecoration(
                      gradient: AppColors.errorGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium KPI Card with top accent gradient bar
class _AuroraKpiCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Gradient gradient;
  final String subtitle;
  final String? trend;
  final bool trendUp;

  const _AuroraKpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.gradient,
    required this.subtitle,
    this.trend,
    this.trendUp = true,
  });

  @override
  State<_AuroraKpiCard> createState() => _AuroraKpiCardState();
}

class _AuroraKpiCardState extends State<_AuroraKpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_isHovered ? 1.0 : 0.92),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: _isHovered
              ? AppShadows.coloredGlow(widget.accentColor)
              : AppShadows.card,
          border: Border.all(
            color: _isHovered
                ? widget.accentColor.withOpacity(0.2)
                : AppColors.border.withOpacity(0.35),
          ),
        ),
        transform: _isHovered ? (Matrix4.identity()..translate(0.0, -3.0)) : Matrix4.identity(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top accent gradient bar
            Container(
              height: 3,
              decoration: BoxDecoration(gradient: widget.gradient),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Row(
                children: [
                  // Gradient icon container
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: widget.gradient,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.value,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.subtitle,
                                style: TextStyle(
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.trend != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: widget.trendUp
                                      ? AppColors.successSoft
                                      : AppColors.errorSoft,
                                  borderRadius: BorderRadius.circular(AppRadius.full),
                                  border: Border.all(
                                    color: (widget.trendUp ? AppColors.success : AppColors.error)
                                        .withOpacity(0.15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.trendUp
                                          ? Icons.north_rounded
                                          : Icons.south_rounded,
                                      size: 10,
                                      color: widget.trendUp ? AppColors.success : AppColors.error,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      widget.trend!,
                                      style: TextStyle(
                                        color: widget.trendUp ? AppColors.success : AppColors.error,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
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
            ),
          ],
        ),
      ),
    );
  }
}

/// Legend dot + label for charts
class _AuroraLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _AuroraLegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.3), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Flat status chip with colored dot — no heavy gradient pills
class _AuroraStatusChip extends StatelessWidget {
  final String status;

  const _AuroraStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    Color bg;
    String label;

    switch (status) {
      case 'warning':
        color = AppColors.warning;
        bg = AppColors.warningSoft;
        label = 'Attention';
        break;
      case 'critical':
        color = AppColors.error;
        bg = AppColors.errorSoft;
        label = 'Critique';
        break;
      case 'elimination':
        color = const Color(0xFF991B1B);
        bg = const Color(0xFFFEE2E2);
        label = 'Éliminé';
        break;
      default:
        color = AppColors.success;
        bg = AppColors.successSoft;
        label = 'OK';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}