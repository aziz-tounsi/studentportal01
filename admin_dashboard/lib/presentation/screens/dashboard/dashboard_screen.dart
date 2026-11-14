import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/error_messages.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/skeleton_loader.dart';
import '../../../data/models/dashboard_models.dart';
import '../timetables/timetables_screen.dart' show selectedClassProvider, ClassInfo;

// ═══════════════════════════════════════════════════════════════════
// ░░░  MODERN MINIMALIST ADMIN DASHBOARD — GOLDEN RATIO EDITION  ░░░
// ═══════════════════════════════════════════════════════════════════

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Current real week days: 0: Lun .. 5: Sam
  late int _selectedDayIndex;
  int _selectedCalendarTab = 0; // 0: Séances, 1: Examens
  String _selectedInterval = 'Mensuel'; // 'Hebdomadaire', 'Mensuel', 'Annuel'
  int? _selectedChartIndex;

  @override
  void initState() {
    super.initState();
    // Default to today's day of week (1: Monday .. 6: Saturday, Sunday clamps to Saturday)
    final todayWeekday = DateTime.now().weekday; // 1 = Mon ... 7 = Sun
    _selectedDayIndex = (todayWeekday - 1).clamp(0, 5);
  }

  /// Calculates the 6 days of the current real week (Lun - Sam)
  List<Map<String, dynamic>> _getCurrentWeekDays() {
    final now = DateTime.now();
    // Find Monday of this current week (ISO 8601: 1 = Monday)
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
    return List.generate(6, (i) {
      final date = monday.add(Duration(days: i));
      return {
        'day': dayNames[i],
        'num': date.day.toString(),
        'dow': i + 1, // 1: Lun .. 6: Sam
        'date': date,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final dashboardAsync = ref.watch(dashboardProvider);
    final lastUpdated = dashboardAsync.whenOrNull(data: (s) => s.lastUpdated);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar
          const AdminSidebar(currentRoute: '/dashboard'),

          // Main View Content
          Expanded(
            child: Column(
              children: [
                // ── PERSISTENT TOP HEADER (Never skeleton-loads, borderless pill) ──
                _buildTopBar(context, lastUpdated),

                // ── BODY CONTENT ──
                Expanded(
                  child: dashboardAsync.when(
                    loading: () => const DashboardSkeletonLoader(),
                    error: (e, _) => Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        margin: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 36),
                            const SizedBox(height: 12),
                            const Text(
                              'Une erreur est survenue lors du chargement',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              UserFriendlyError.format(
                                e,
                                fallback: 'Unable to load dashboard data right now. Please try again.',
                              ),
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Réessayer'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6D4CF6),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  PERSISTENT TOP HEADER — BORDERLESS PILL (NO SKELETON LOAD) ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildTopBar(BuildContext context, DateTime? lastUpdated) {
    final now = lastUpdated ?? DateTime.now();
    final nowFormatted = DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(now);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Tableau de bord',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Vue d\'ensemble analytique et gestion en temps réel',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const Spacer(),

          // Last updated pill — BORDERLESS with subtle soft shadow
          InkWell(
            onTap: () => ref.read(dashboardProvider.notifier).refresh(),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    'Mis à jour : $nowFormatted',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.sync_rounded, size: 14, color: Color(0xFF6D4CF6)),
                ],
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ROW 1: 5 METRIC KPI CARDS (Golden ratio hierarchy, borderless icons) ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 980;
              final cards = [
                _buildGoldenMetricCard(
                  icon: Icons.receipt_long_outlined,
                  iconColor: const Color(0xFF6D4CF6),
                  iconBgColor: const Color(0xFFF5F3FF),
                  title: 'Total Revenus',
                  value: currencyFormat.format(kpis.totalPaymentsCollected),
                  trend: '+${kpis.revenueGrowth}%',
                  trendLabel: kpis.revenueGrowthLabel,
                  trendUp: kpis.revenueGrowthUp,
                  onTap: () => context.go('/payments'),
                ),
                _buildGoldenMetricCard(
                  icon: Icons.trending_up_rounded,
                  iconColor: const Color(0xFF10B981),
                  iconBgColor: const Color(0xFFECFDF5),
                  title: 'Croissance Mensuelle',
                  value: '+${kpis.monthlyGrowth}%',
                  trend: '+${kpis.monthlyGrowthTrend}%',
                  trendLabel: kpis.monthlyGrowthLabel,
                  trendUp: kpis.monthlyGrowthUp,
                  onTap: () => context.go('/payments'),
                ),
                _buildGoldenMetricCard(
                  icon: Icons.school_outlined,
                  iconColor: const Color(0xFF8B5CF6),
                  iconBgColor: const Color(0xFFF5F3FF),
                  title: 'Total Inscriptions',
                  value: NumberFormat.decimalPattern().format(kpis.totalStudents),
                  trend: '${kpis.studentTargetDiff}%',
                  trendLabel: kpis.studentTargetLabel,
                  trendUp: kpis.studentTargetUp,
                  onTap: () => context.go('/users'),
                ),
                _buildGoldenMetricCard(
                  icon: Icons.people_outline_rounded,
                  iconColor: const Color(0xFF0284C7),
                  iconBgColor: const Color(0xFFF0F9FF),
                  title: 'Enseignants & Staff',
                  value: (kpis.totalTeachers + kpis.totalStaff).toString(),
                  trend: '+${kpis.teacherStaffGrowth}%',
                  trendLabel: kpis.teacherStaffGrowthLabel,
                  trendUp: kpis.teacherStaffGrowthUp,
                  onTap: () => context.go('/professors'),
                ),
                _buildGoldenMetricCard(
                  icon: Icons.pie_chart_outline_rounded,
                  iconColor: const Color(0xFF6D4CF6),
                  iconBgColor: const Color(0xFFF5F3FF),
                  title: 'Taux de Recouvrement',
                  value: '${kpis.recoveryRate.toStringAsFixed(0)}%',
                  trend: '${kpis.recoveryRateDiff}%',
                  trendLabel: kpis.recoveryRateLabel,
                  trendUp: kpis.recoveryRateUp,
                  onTap: () => context.go('/payments'),
                ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      Expanded(child: cards[i]),
                      if (i < cards.length - 1) const SizedBox(width: 14),
                    ],
                  ],
                );
              } else {
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 14) / 2, child: c)).toList(),
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // ── ROW 2: CASHFLOW LINE CHART & REVENUE BY CATEGORY (GOLDEN PROPORTIONS 62% : 38%) ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 980;
              if (isWide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cashflow line chart (62%)
                      Expanded(
                        flex: 62,
                        child: _buildCashflowChartCard(context, state, currencyFormat),
                      ),
                      const SizedBox(width: 20),
                      // Répartition par Catégorie (38%)
                      Expanded(
                        flex: 38,
                        child: _buildCategoryBreakdownCard(context, state, currencyFormat),
                      ),
                    ],
                  ),
                );
              } else {
                return Column(
                  children: [
                    _buildCashflowChartCard(context, state, currencyFormat),
                    const SizedBox(height: 20),
                    _buildCategoryBreakdownCard(context, state, currencyFormat),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),

          // ── ROW 3: THREE CARDS (Filière 30%, Calendrier & Séances 40%, Présence 30%) ──
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
                        child: _buildFiliereDonutCard(context, state),
                      ),
                      const SizedBox(width: 18),

                      // Calendrier & Séances / Examens (40%)
                      Expanded(
                        flex: 4,
                        child: _buildCalendarScheduleCard(context, state),
                      ),
                      const SizedBox(width: 18),

                      // Taux de Présence par Niveau (30%)
                      Expanded(
                        flex: 3,
                        child: _buildAttendanceByLevelCard(context, state),
                      ),
                    ],
                  ),
                );
              } else {
                return Column(
                  children: [
                    _buildFiliereDonutCard(context, state),
                    const SizedBox(height: 20),
                    _buildCalendarScheduleCard(context, state),
                    const SizedBox(height: 20),
                    _buildAttendanceByLevelCard(context, state),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  GOLDEN METRIC CARD (BORDERLESS ICON, 1.618 SPACING)  ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildGoldenMetricCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String value,
    required String trend,
    required String trendLabel,
    required bool trendUp,
    required VoidCallback onTap,
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
                // Borderless soft icon container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
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

            // Trend Indicator
            Row(
              children: [
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
                Expanded(
                  child: Text(
                    trendLabel,
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

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  CASHFLOW LINE CHART CARD (PILL INTERVAL, ANY-PIXEL CLICK) ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCashflowChartCard(
    BuildContext context,
    DashboardState state,
    NumberFormat currencyFormat,
  ) {
    final CashflowIntervalData activeData;
    switch (_selectedInterval) {
      case 'Hebdomadaire':
        activeData = state.weeklyCashflow;
        break;
      case 'Annuel':
        activeData = state.annualCashflow;
        break;
      case 'Mensuel':
      default:
        activeData = state.monthlyCashflow;
        break;
    }

    final points = activeData.points;
    final spots = points.map((p) => FlSpot(p.x, p.y)).toList();
    final activeSpotIndex = _selectedChartIndex != null && _selectedChartIndex! < points.length
        ? _selectedChartIndex!
        : activeData.peakX.toInt().clamp(0, points.isEmpty ? 0 : points.length - 1);

    final lineBarData = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.35,
      color: const Color(0xFF6D4CF6),
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, barData) => spot.x == activeSpotIndex.toDouble(),
        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
          radius: 5,
          color: const Color(0xFF6D4CF6),
          strokeWidth: 2.5,
          strokeColor: Colors.white,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF6D4CF6).withValues(alpha: 0.16),
            const Color(0xFF6D4CF6).withValues(alpha: 0.0),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          // Header Row with Pill Interval Selector and Styled 3-dots
          Row(
            children: [
              InkWell(
                onTap: () => context.go('/payments'),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Flux de trésorerie',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Legend
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D4CF6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Remboursé ${currencyFormat.format(activeData.reimbursedAmount)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const Spacer(),

              // Interval Selector: MODERN PILL DESIGN
              PopupMenuButton<String>(
                onSelected: (val) {
                  setState(() {
                    _selectedInterval = val;
                    _selectedChartIndex = null;
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFF1F5F9)),
                ),
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                offset: const Offset(0, 36),
                itemBuilder: (context) => [
                  _buildPopupItem('Hebdomadaire', Icons.calendar_view_week_rounded, 'Hebdomadaire', const Color(0xFF6D4CF6)),
                  _buildPopupItem('Mensuel', Icons.calendar_view_month_rounded, 'Mensuel', const Color(0xFF6D4CF6)),
                  _buildPopupItem('Annuel', Icons.calendar_today_rounded, 'Annuel', const Color(0xFF6D4CF6)),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20), // Pill!
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Intervalle : ',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      Text(
                        _selectedInterval,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 3 Dots popup menu: Styled exactly like Users page
              _buildDashboardThreeDots(
                items: [
                  _buildPopupItem('view', Icons.visibility_outlined, 'Voir les paiements', const Color(0xFF6D4CF6)),
                  _buildPopupItem('refresh', Icons.sync_rounded, 'Actualiser les données', const Color(0xFF10B981)),
                ],
                onSelected: (val) {
                  if (val == 'view') context.go('/payments');
                  if (val == 'refresh') ref.read(dashboardProvider.notifier).refresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Live Line Chart Area — CLICK ANY PIXEL TO SHOW DETAILS
          SizedBox(
            height: 230,
            child: spots.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune donnée pour cette période',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, chartConstraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) {
                          // Clicking ANYWHERE on the chart computes the closest point
                          final w = chartConstraints.maxWidth;
                          final fraction = (details.localPosition.dx / w).clamp(0.0, 1.0);
                          final idx = (fraction * (points.length - 1)).round();
                          setState(() {
                            _selectedChartIndex = idx;
                          });
                        },
                        child: LineChart(
                          LineChartData(
                            showingTooltipIndicators: [
                              ShowingTooltipIndicators([
                                LineBarSpot(
                                  lineBarData,
                                  0,
                                  spots[activeSpotIndex],
                                ),
                              ]),
                            ],
                            lineTouchData: LineTouchData(
                              enabled: true,
                              handleBuiltInTouches: true,
                              touchSpotThreshold: 60,
                              touchCallback: (event, touchResponse) {
                                if (touchResponse?.lineBarSpots != null &&
                                    touchResponse!.lineBarSpots!.isNotEmpty) {
                                  final spot = touchResponse.lineBarSpots!.first;
                                  if (_selectedChartIndex != spot.spotIndex) {
                                    setState(() {
                                      _selectedChartIndex = spot.spotIndex;
                                    });
                                  }
                                }
                              },
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (_) => const Color(0xFF0F172A),
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final idx = spot.spotIndex;
                                    final point = (idx >= 0 && idx < points.length) ? points[idx] : null;
                                    return LineTooltipItem(
                                      '${currencyFormat.format(point?.amount ?? (spot.y * 1000))}\n',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: point?.fullDate ?? '',
                                          style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: (activeData.maxY / 4).clamp(1.0, 100.0),
                              getDrawingHorizontalLine: (value) => const FlLine(
                                color: Color(0xFFF1F5F9),
                                strokeWidth: 1,
                                dashArray: [5, 4],
                              ),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 42,
                                  interval: (activeData.maxY / 4).clamp(1.0, 100.0),
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value.toInt()}K',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF94A3B8),
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
                                    final index = value.toInt();
                                    if (index >= 0 && index < points.length) {
                                      final isSelected = index == activeSpotIndex;
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          points[index].label,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isSelected ? const Color(0xFF6D4CF6) : const Color(0xFF64748B),
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
                            maxX: (points.length - 1).toDouble(),
                            minY: activeData.minY,
                            maxY: activeData.maxY,
                            lineBarsData: [lineBarData],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  CATEGORY BREAKDOWN CARD (STYLED THREE DOTS, NAVIGATION)   ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCategoryBreakdownCard(
    BuildContext context,
    DashboardState state,
    NumberFormat currencyFormat,
  ) {
    final categories = state.categories;
    final totalDue = state.kpis.totalPaymentsDue;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          // Header Row with styled 3-dots
          Row(
            children: [
              InkWell(
                onTap: () => context.go('/payments'),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Répartition par Catégorie',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
              const Spacer(),
              _buildDashboardThreeDots(
                items: [
                  _buildPopupItem('view', Icons.visibility_outlined, 'Voir tous les paiements', const Color(0xFF6D4CF6)),
                  _buildPopupItem('refresh', Icons.sync_rounded, 'Actualiser', const Color(0xFF10B981)),
                ],
                onSelected: (val) {
                  if (val == 'view') context.go('/payments');
                  if (val == 'refresh') ref.read(dashboardProvider.notifier).refresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Total Due & Trend
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currencyFormat.format(totalDue),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: const [
                  Icon(Icons.arrow_upward_rounded, size: 13, color: Color(0xFF10B981)),
                  SizedBox(width: 4),
                  Text(
                    '+15% vs 30 jours',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Segmented Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: categories.map((cat) {
                  return Expanded(
                    flex: (cat.percentage.toInt()).clamp(5, 100),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: Color(cat.colorValue),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Category Item Rows
          Column(
            children: categories.map((cat) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(cat.colorValue),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        cat.label,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${currencyFormat.format(cat.amount)} (${cat.percentage.toInt()}%)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  FILIÈRE DONUT CARD (NO GREY PILLS, STYLED THREE DOTS)    ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildFiliereDonutCard(BuildContext context, DashboardState state) {
    final filieres = state.filieres;
    final totalStudents = state.kpis.totalStudents;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          // Header Row with styled 3-dots
          Row(
            children: [
              InkWell(
                onTap: () => context.go('/grade-levels'),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Répartition par Filière',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
              const Spacer(),
              _buildDashboardThreeDots(
                items: [
                  _buildPopupItem('view', Icons.visibility_outlined, 'Voir les niveaux', const Color(0xFF6D4CF6)),
                  _buildPopupItem('refresh', Icons.sync_rounded, 'Actualiser', const Color(0xFF10B981)),
                ],
                onSelected: (val) {
                  if (val == 'view') context.go('/grade-levels');
                  if (val == 'refresh') ref.read(dashboardProvider.notifier).refresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Donut Chart
          SizedBox(
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 42,
                    startDegreeOffset: -90,
                    sections: filieres.map((f) {
                      return PieChartSectionData(
                        value: f.percentage,
                        color: Color(f.colorValue),
                        radius: 18,
                        showTitle: false,
                      );
                    }).toList(),
                  ),
                ),

                // Center Text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalStudents',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Clean 2x2 List WITHOUT grey pill background
          Column(
            children: [
              for (int i = 0; i < filieres.length; i += 2) ...[
                Row(
                  children: [
                    Expanded(child: _buildCleanFiliereItem(filieres[i])),
                    if (i + 1 < filieres.length) ...[
                      const SizedBox(width: 12),
                      Expanded(child: _buildCleanFiliereItem(filieres[i + 1])),
                    ],
                  ],
                ),
                if (i + 2 < filieres.length) const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCleanFiliereItem(FiliereDistributionItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Color(item.colorValue),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              item.label,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${item.percentage.toInt()}%',
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  CALENDAR & SÉANCES / EXAMENS (REAL CURRENT WEEK, PILL DAYS, PILL SALLE, BORDERLESS RECTANGLES) ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCalendarScheduleCard(BuildContext context, DashboardState state) {
    // Current real week days
    final days = _getCurrentWeekDays();
    final currentDow = days[_selectedDayIndex.clamp(0, days.length - 1)]['dow'] as int;
    final isExamTab = _selectedCalendarTab == 1;

    // Filter events for selected day & selected tab (séances vs examens)
    final filteredEvents = state.events.where((e) {
      final matchesDay = e.dayOfWeek == currentDow;
      final matchesType = isExamTab ? e.isExam : !e.isExam;
      return matchesDay && matchesType;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          // Header Row with styled 3-dots
          Row(
            children: [
              InkWell(
                onTap: () => context.go('/timetables'),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Calendrier & Séances',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
              const Spacer(),
              _buildDashboardThreeDots(
                items: [
                  _buildPopupItem('view', Icons.visibility_outlined, 'Voir tout l\'emploi du temps', const Color(0xFF6D4CF6)),
                  _buildPopupItem('refresh', Icons.sync_rounded, 'Actualiser', const Color(0xFF10B981)),
                ],
                onSelected: (val) {
                  if (val == 'view') context.go('/timetables');
                  if (val == 'refresh') ref.read(dashboardProvider.notifier).refresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Day Carousel Selector — CURRENT REAL WEEK, PILL SHAPE & BORDERLESS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Borderless soft pill container
              borderRadius: BorderRadius.circular(30), // Pill!
            ),
            child: Row(
              children: [
                for (int i = 0; i < days.length; i++) ...[
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDayIndex = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedDayIndex == i ? const Color(0xFF6D4CF6) : Colors.transparent,
                            borderRadius: BorderRadius.circular(24), // Pill inside!
                          ),
                          child: Center(
                            child: Text(
                              '${days[i]['day']} ${days[i]['num']}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _selectedDayIndex == i ? FontWeight.w700 : FontWeight.w500,
                                color: _selectedDayIndex == i ? Colors.white : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (i < days.length - 1) const SizedBox(width: 2),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tabs: Séances (Science Icon, NO TRUCK/CAR) vs Examens
          Row(
            children: [
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCalendarTab = 0),
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedCalendarTab == 0 ? const Color(0xFF6D4CF6) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.science_outlined, // Science icon
                            size: 15,
                            color: _selectedCalendarTab == 0 ? const Color(0xFF6D4CF6) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Séances',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _selectedCalendarTab == 0 ? const Color(0xFF6D4CF6) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCalendarTab = 1),
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedCalendarTab == 1 ? const Color(0xFF6D4CF6) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 15,
                            color: _selectedCalendarTab == 1 ? const Color(0xFF6D4CF6) : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Examens',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _selectedCalendarTab == 1 ? const Color(0xFF6D4CF6) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Event List
          if (filteredEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  isExamTab ? 'Aucun examen prévu ce jour-là' : 'Aucune séance prévue ce jour-là',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            Column(
              children: filteredEvents.take(2).map((evt) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildEventCard(evt),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Event Card: BORDERLESS RECTANGLE, PILL ROOM BADGE
  Widget _buildEventCard(DashboardCalendarEvent event) {
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      onTap: () {
        // Direct navigation to that class's timetable
        if (event.classId.isNotEmpty) {
          ref.read(selectedClassProvider.notifier).state = ClassInfo(
            id: event.classId,
            name: event.className,
          );
        }
        context.go('/timetables');
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC), // BORDERLESS soft surface
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  event.time,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Teacher Initials Avatar
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFF6D4CF6),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      event.teacherInitials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${event.teacherName} • ${event.className}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                // Room Badge: PILL SHAPED
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20), // Pill!
                    border: Border.all(color: const Color(0xFF6D4CF6).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.room,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6D4CF6),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.chevron_right_rounded, size: 12, color: Color(0xFF6D4CF6)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ░░░  ATTENDANCE BY LEVEL (SLIM BARS, STYLED THREE DOTS)       ░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildAttendanceByLevelCard(BuildContext context, DashboardState state) {
    final levels = state.attendanceLevels;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
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
          // Header Row with styled 3-dots
          Row(
            children: [
              InkWell(
                onTap: () => context.go('/absences'),
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Taux de Présence par Niveau',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
              const Spacer(),
              _buildDashboardThreeDots(
                items: [
                  _buildPopupItem('view', Icons.visibility_outlined, 'Voir toutes les absences', const Color(0xFF6D4CF6)),
                  _buildPopupItem('refresh', Icons.sync_rounded, 'Actualiser', const Color(0xFF10B981)),
                ],
                onSelected: (val) {
                  if (val == 'view') context.go('/absences');
                  if (val == 'refresh') ref.read(dashboardProvider.notifier).refresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Slim Horizontal Progress Bars List
          for (int i = 0; i < levels.length; i++) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        levels[i].levelName,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      levels[i].label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6D4CF6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: levels[i].rate,
                    backgroundColor: const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6D4CF6)),
                    minHeight: 6, // Slim elegant height
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
  // ░░░  SHARED POPUP MENU & 3-DOTS BUTTON (STYLED LIKE USERS PAGE)░░░
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDashboardThreeDots({
    required List<PopupMenuEntry<String>> items,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF94A3B8)),
      tooltip: 'Actions',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10), // Same border radius as Users page!
        side: const BorderSide(color: Color(0xFFF1F5F9)),
      ),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      offset: const Offset(-140, 36),
      onSelected: onSelected,
      itemBuilder: (context) => items,
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, IconData icon, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}