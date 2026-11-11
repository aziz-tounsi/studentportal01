import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_messages.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/ios_loader.dart';
import '../../../data/models/dashboard_models.dart';

// ═══════════════════════════════════════════════════════════════════
// ░░░  AURORA GLASS — Modern Analytics Dashboard  ░░░
// ═══════════════════════════════════════════════════════════════════

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedDayIndex = 1; // 0: Dim 5, 1: Lun 6, 2: Mar 7, 3: Mer 8
  int _selectedCalendarTab = 0; // 0: Séances, 1: Réunions
  String _selectedInterval = 'Mensuel';
  bool _showAtRiskSection = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar
          const AdminSidebar(currentRoute: '/dashboard'),

          // Main View Content
          Expanded(
            child: dashboardAsync.when(
              loading: () => const Center(
                child: IosLoader(size: 36, color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  margin: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.errorSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
                      const SizedBox(height: 12),
                      const Text(
                        'Une erreur est survenue lors du chargement',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.error),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        UserFriendlyError.format(
                          e,
                          fallback: 'Unable to load dashboard data right now. Please try again.',
                        ),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Réessayer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (state) => _buildDashboardBody(context, authState, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardBody(BuildContext context, AdminAuthState authState, DashboardState state) {
    final kpis = state.kpis;
    final currencyFormat = NumberFormat.currency(locale: 'fr_TN', symbol: 'TND ', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── TOP HEADER ──
          _buildTopHeader(context, ref),
          const SizedBox(height: 20),

          // ── ROW 1: 5 METRIC KPI CARDS ──
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 950) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.receipt_long_outlined,
                        iconColor: AppColors.primary,
                        title: 'Total Revenus',
                        value: kpis.totalPaymentsCollected > 0
                            ? currencyFormat.format(kpis.totalPaymentsCollected)
                            : '124,500 TND',
                        trend: '+3.5%',
                        trendLabel: 'vs l\'an dernier',
                        trendUp: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.trending_up_rounded,
                        iconColor: AppColors.secondary,
                        title: 'Croissance Mensuelle',
                        value: '+8.3%',
                        trend: '+1.2%',
                        trendLabel: 'vs mois dernier',
                        trendUp: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.school_outlined,
                        iconColor: AppColors.primaryDark,
                        title: 'Total Inscriptions',
                        value: kpis.totalStudents > 0
                            ? NumberFormat.decimalPattern().format(kpis.totalStudents)
                            : '196',
                        trend: '-1.7%',
                        trendLabel: 'vs objectif',
                        trendUp: false,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.people_outline_rounded,
                        iconColor: AppColors.primaryLight,
                        title: 'Enseignants & Staff',
                        value: (kpis.totalTeachers + kpis.totalStaff) > 0
                            ? (kpis.totalTeachers + kpis.totalStaff).toString()
                            : '5',
                        trend: '+2.5%',
                        trendLabel: 'vs semestre préc.',
                        trendUp: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        icon: Icons.pie_chart_outline_rounded,
                        iconColor: AppColors.violet600,
                        title: 'Taux de Recouvrement',
                        value: kpis.paymentProgress > 0
                            ? '${kpis.paymentProgress.toStringAsFixed(0)}%'
                            : '82%',
                        trend: '-2.3%',
                        trendLabel: 'vs l\'an dernier',
                        trendUp: false,
                      ),
                    ),
                  ],
                );
              } else {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMetricCard(
                      icon: Icons.receipt_long_outlined,
                      iconColor: AppColors.primary,
                      title: 'Total Revenus',
                      value: kpis.totalPaymentsCollected > 0
                          ? currencyFormat.format(kpis.totalPaymentsCollected)
                          : '124,500 TND',
                      trend: '+3.5%',
                      trendLabel: 'vs l\'an dernier',
                      trendUp: true,
                    ),
                    _buildMetricCard(
                      icon: Icons.trending_up_rounded,
                      iconColor: AppColors.secondary,
                      title: 'Croissance Mensuelle',
                      value: '+8.3%',
                      trend: '+1.2%',
                      trendLabel: 'vs mois dernier',
                      trendUp: true,
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),

          // ── ROW 2: CASHFLOW LINE CHART & REVENUE BY CATEGORY (EQUAL LENGTH) ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 950;
              if (isWide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 65,
                        child: _buildCashflowChartCard(context, kpis, currencyFormat),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 35,
                        child: _buildCategoryBreakdownCard(context, kpis, currencyFormat),
                      ),
                    ],
                  ),
                );
              } else {
                return Column(
                  children: [
                    _buildCashflowChartCard(context, kpis, currencyFormat),
                    const SizedBox(height: 20),
                    _buildCategoryBreakdownCard(context, kpis, currencyFormat),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),

          // ── ROW 3: THREE CARDS (RESIZED CORRECTLY, NO OVERFLOW, PROPER PROPORTIONS) ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1050;
              if (isWide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Répartition par Filière (30%)
                      Expanded(
                        flex: 3,
                        child: _buildChannelDonutCard(context, kpis),
                      ),
                      const SizedBox(width: 16),

                      // Calendrier & Séances (Compact & balanced, 40%)
                      Expanded(
                        flex: 4,
                        child: _buildCalendarScheduleCard(context),
                      ),
                      const SizedBox(width: 16),

                      // Taux de Présence par Niveau (30%)
                      Expanded(
                        flex: 3,
                        child: _buildAttendanceByLevelCard(context),
                      ),
                    ],
                  ),
                );
              } else {
                return Column(
                  children: [
                    _buildChannelDonutCard(context, kpis),
                    const SizedBox(height: 20),
                    _buildCalendarScheduleCard(context),
                    const SizedBox(height: 20),
                    _buildAttendanceByLevelCard(context),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 20),

          // ── AT-RISK STUDENTS & OPERATIONAL ACTIONS DRAWER ──
          _buildAtRiskSection(context, state.atRiskStudents),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  TOP HEADER  ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildTopHeader(BuildContext context, WidgetRef ref) {
    final nowFormatted = DateFormat('MMM dd, yyyy', 'en_US').format(DateTime.now());

    return Row(
      children: [
        const Text(
          'Analytics & Performance',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const Spacer(),

        // "Last updated: Feb 28, 2024 [Refresh]" pill
        InkWell(
          onTap: () => ref.read(dashboardProvider.notifier).refresh(),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Last updated: $nowFormatted',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.sync_rounded, size: 14, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  KPI METRIC CARD  ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String trend,
    required String trendLabel,
    required bool trendUp,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
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
              // Icon container with soft outline and kit tone
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: iconColor.withValues(alpha: 0.15)),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                trendUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 13,
                color: trendUp ? AppColors.success : AppColors.error,
              ),
              const SizedBox(width: 3),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: trendUp ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                trendLabel,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  CASHFLOW LINE CHART CARD  ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCashflowChartCard(
    BuildContext context,
    DashboardKpis kpis,
    NumberFormat currencyFormat,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              const Text(
                'Cashflow',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 24),
              // Legend: Reimbursed in Sapphire tone
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Remboursé 5,133 TND',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),

              // Time interval dropdown
              PopupMenuButton<String>(
                onSelected: (val) => setState(() => _selectedInterval = val),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'Hebdomadaire', child: Text('Hebdomadaire')),
                  const PopupMenuItem(value: 'Mensuel', child: Text('Mensuel')),
                  const PopupMenuItem(value: 'Annuel', child: Text('Annuel')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Intervalle: ',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                      Text(
                        _selectedInterval,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Line Chart Area with Peak Tooltip
          Expanded(
            child: SizedBox(
              height: 230,
              child: Stack(
                children: [
                  LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 2,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppColors.borderLight,
                          strokeWidth: 1,
                          dashArray: [5, 4],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            interval: 2,
                            getTitlesWidget: (value, meta) {
                              if (value < 0 || value > 10) return const SizedBox.shrink();
                              return Text(
                                '${value.toInt()}K',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              const days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
                              final index = value.toInt();
                              if (index >= 0 && index < days.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Text(
                                    days[index],
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textTertiary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 6,
                      minY: 0,
                      maxY: 10,
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 5.2),
                            FlSpot(0.8, 5.4),
                            FlSpot(1.4, 6.2),
                            FlSpot(2.2, 6.8),
                            FlSpot(3.1, 7.1),
                            FlSpot(3.8, 7.3),
                            FlSpot(4.5, 7.5),
                            FlSpot(5.2, 7.4),
                            FlSpot(5.8, 8.2),
                            FlSpot(6, 7.8),
                          ],
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: AppColors.primary,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            checkToShowDot: (spot, barData) => spot.x == 3.8,
                            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                              radius: 4.5,
                              color: AppColors.primary,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.16),
                                AppColors.primary.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floating Peak Callout Badge "$6,988.13 Jun 15, 2024"
                  Positioned(
                    left: 280,
                    top: 48,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            '6,988.13 TND',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            '15 Juin 2024',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
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

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  CATEGORY BREAKDOWN CARD (MATCHES CASHFLOW HEIGHT)  ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCategoryBreakdownCard(
    BuildContext context,
    DashboardKpis kpis,
    NumberFormat currencyFormat,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header
          Row(
            children: const [
              Text(
                'Répartition par Catégorie',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Spacer(),
              Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textTertiary),
            ],
          ),

          // Total Number & Trend
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kpis.totalPaymentsDue > 0
                    ? currencyFormat.format(kpis.totalPaymentsDue)
                    : '28,389.98 TND',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: const [
                  Icon(Icons.arrow_upward_rounded, size: 13, color: AppColors.success),
                  SizedBox(width: 4),
                  Text(
                    '15% vs 30 jours',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Segmented Progress Bar (Sapphire, Sky Blue, Soft Ice Blue)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 18,
              child: Row(
                children: [
                  Expanded(
                    flex: 55,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 15,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFDBFE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Category Item Rows
          Column(
            children: [
              _buildCategoryItem(
                color: AppColors.primary,
                label: 'Frais de Scolarité',
                amount: '42,000 TND (25%)',
              ),
              const SizedBox(height: 12),
              _buildCategoryItem(
                color: AppColors.primaryLight,
                label: 'Mensualités & Inscription',
                amount: '28,000 TND (18%)',
              ),
              const SizedBox(height: 12),
              _buildCategoryItem(
                color: const Color(0xFF93C5FD),
                label: 'Activités & Cantine',
                amount: '18,000 TND (12%)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem({
    required Color color,
    required String label,
    required String amount,
  }) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  BOTTOM LEFT: CHANNEL DONUT CARD (CORRECT SIZE, NO OVERFLOW) ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildChannelDonutCard(BuildContext context, DashboardKpis kpis) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'Répartition par Filière',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Spacer(),
              Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: 14),

          // Donut Chart
          SizedBox(
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 44,
                    startDegreeOffset: -90,
                    sections: [
                      PieChartSectionData(
                        value: 45,
                        color: AppColors.primary,
                        radius: 20,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 25,
                        color: AppColors.secondary,
                        radius: 20,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 20,
                        color: AppColors.primaryLight,
                        radius: 20,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 10,
                        color: const Color(0xFFC7D2FE),
                        radius: 20,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),

                // Center Text "196 Total"
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kpis.totalStudents > 0 ? '${kpis.totalStudents}' : '196',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Clean, responsive 2x2 legend grid (never overflows!)
          Row(
            children: [
              Expanded(
                child: _buildDonutLegendChip(
                  color: AppColors.primary,
                  label: 'Scientifique',
                  percent: '45%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDonutLegendChip(
                  color: AppColors.secondary,
                  label: 'Mathématiques',
                  percent: '25%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDonutLegendChip(
                  color: AppColors.primaryLight,
                  label: 'Éco & Info',
                  percent: '20%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDonutLegendChip(
                  color: const Color(0xFFC7D2FE),
                  label: 'Autres',
                  percent: '10%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLegendChip({
    required Color color,
    required String label,
    required String percent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            percent,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  BOTTOM MIDDLE: CALENDAR & SESSIONS CARD (BALANCED SIZE) ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCalendarScheduleCard(BuildContext context) {
    final days = [
      {'day': 'Dim', 'num': '5'},
      {'day': 'Lun', 'num': '6'},
      {'day': 'Mar', 'num': '7'},
      {'day': 'Mer', 'num': '8'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: const [
              Text(
                'Calendrier & Séances',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Spacer(),
              Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: 14),

          // Day Carousel Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.chevron_left_rounded, size: 16, color: AppColors.textTertiary),
                const SizedBox(width: 2),
                for (int i = 0; i < days.length; i++) ...[
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDayIndex = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedDayIndex == i ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Center(
                          child: Text(
                            '${days[i]['day']} ${days[i]['num']}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _selectedDayIndex == i ? FontWeight.w700 : FontWeight.w500,
                              color: _selectedDayIndex == i ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (i < days.length - 1) const SizedBox(width: 3),
                ],
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tabs: Séances vs Réunions
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCalendarTab = 0),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _selectedCalendarTab == 0 ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_shipping_outlined,
                          size: 14,
                          color: _selectedCalendarTab == 0 ? AppColors.primary : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Séances',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _selectedCalendarTab == 0 ? AppColors.primary : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCalendarTab = 1),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _selectedCalendarTab == 1 ? AppColors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 14,
                          color: _selectedCalendarTab == 1 ? AppColors.primary : AppColors.textTertiary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Réunions',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _selectedCalendarTab == 1 ? AppColors.primary : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Event Card 1
          _buildEventCard(
            title: 'Conseil Pédagogique - 2S Math',
            time: '9:00 - 10:30 AM',
            duration: '90m',
            actionText: 'Salle R1',
          ),
          const SizedBox(height: 8),

          // Event Card 2
          _buildEventCard(
            title: 'Devoir Synthèse Physique',
            time: '11:00 - 12:30 PM',
            duration: '90m',
            actionText: 'Labo Sc.',
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard({
    required String title,
    required String time,
    required String duration,
    required String actionText,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Overlapping avatars + badge
              SizedBox(
                width: 52,
                height: 20,
                child: Stack(
                  children: [
                    _buildMiniAvatar(0, AppColors.primary, 'A'),
                    _buildMiniAvatar(12, AppColors.secondary, 'M'),
                    _buildMiniAvatar(24, AppColors.success, 'K'),
                    Positioned(
                      left: 36,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Center(
                          child: Text(
                            '+7',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // Duration icon
              const Icon(Icons.schedule_rounded, size: 11, color: AppColors.textTertiary),
              const SizedBox(width: 3),
              Text(
                duration,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
              ),
              const Spacer(),
              // Action Pill Button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 11, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAvatar(double left, Color color, String text) {
    return Positioned(
      left: left,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  BOTTOM RIGHT: ATTENDANCE & LEVEL BARS CARD (CORRECT SIZE) ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAttendanceByLevelCard(BuildContext context) {
    final levels = [
      {'name': '4ème Année (Bac)', 'pct': 0.94, 'label': '94%'},
      {'name': '3ème Année Secondaire', 'pct': 0.88, 'label': '88%'},
      {'name': '2ème Année Secondaire', 'pct': 0.82, 'label': '82%'},
      {'name': '1ère Année Secondaire', 'pct': 0.79, 'label': '79%'},
      {'name': 'Cycle de Base (7B - 9B)', 'pct': 0.96, 'label': '96%'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text(
                'Taux de Présence par Niveau',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              Spacer(),
              Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textTertiary),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal Progress Bars List
          for (int i = 0; i < levels.length; i++) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        levels[i]['name'] as String,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      levels[i]['label'] as String,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: levels[i]['pct'] as double,
                    backgroundColor: AppColors.slate100,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
            if (i < levels.length - 1) const SizedBox(height: 11),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  AT RISK STUDENTS & ACTIONS SECTION  ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAtRiskSection(BuildContext context, List<AtRiskStudent> students) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showAtRiskSection = !_showAtRiskSection),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: students.isNotEmpty ? AppColors.warningSoft : AppColors.successSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      students.isNotEmpty ? Icons.shield_outlined : Icons.verified_outlined,
                      color: students.isNotEmpty ? AppColors.warning : AppColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        students.isNotEmpty
                            ? 'Étudiants à risque (${students.length})'
                            : 'Étudiants à risque (0)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        students.isNotEmpty
                            ? 'Absences supérieures au seuil autorisé'
                            : 'Tous les étudiants sont en situation régulière',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(
                    _showAtRiskSection
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_showAtRiskSection) ...[
            const Divider(height: 1, color: AppColors.border),
            if (students.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Aucun étudiant à risque pour le moment.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.slate50),
                    headingRowHeight: 44,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 52,
                    horizontalMargin: 16,
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('ÉTUDIANT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textSecondary))),
                      DataColumn(label: Text('CLASSE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textSecondary))),
                      DataColumn(label: Text('MATIÈRE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textSecondary))),
                      DataColumn(label: Text('ABSENCES', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textSecondary))),
                      DataColumn(label: Text('STATUT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textSecondary))),
                    ],
                    rows: students.map((s) => DataRow(
                      cells: [
                        DataCell(Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        DataCell(Text(s.className, style: const TextStyle(fontSize: 13))),
                        DataCell(Text(s.subjectName, style: const TextStyle(fontSize: 13))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.errorSoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${s.absencePercent.toStringAsFixed(1)}%',
                              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              s.status.toUpperCase(),
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    )).toList(),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}