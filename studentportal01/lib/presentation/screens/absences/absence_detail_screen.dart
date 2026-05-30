import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../../data/models/absence_model.dart';

class AbsenceDetailData {
  final String subjectName;
  final String? subjectCode;
  final String? professorName;
  final double coefficient;
  final double totalHours;
  final double weeklyCiHours;
  final double weeklyTpHours;
  final int weeks;
  final List<AbsenceRecordModel> records;
  final List<String> scheduledDays;

  AbsenceDetailData({
    required this.subjectName,
    this.subjectCode,
    this.professorName,
    required this.coefficient,
    required this.totalHours,
    required this.weeklyCiHours,
    required this.weeklyTpHours,
    required this.weeks,
    required this.records,
    required this.scheduledDays,
  });
}

final absenceDetailProvider = FutureProvider.family<AbsenceDetailData?, String>((ref, offeringId) async {
  final authState = ref.watch(authProvider);
  if (!authState.isAuthenticated || authState.enrollment == null) return null;

  final supabase = Supabase.instance.client;
  final enrollmentId = authState.enrollment!.id;

  try {
    final offeringResponse = await supabase
        .from('subject_offerings')
        .select('''
          total_hours,
          weekly_ci_hours,
          weekly_tp_hours,
          weeks,
          coefficient,
          subjects (id, name, code),
          teacher_id
        ''')
        .eq('id', offeringId)
        .maybeSingle();

    if (offeringResponse == null) return null;

    final subject = offeringResponse['subjects'] as Map<String, dynamic>?;
    final subjectName = subject?['name'] as String? ?? 'Matière inconnue';
    final subjectCode = subject?['code'] as String?;
    final totalHours = (offeringResponse['total_hours'] as num?)?.toDouble() ?? 0;
    final weeklyCi = (offeringResponse['weekly_ci_hours'] as num?)?.toDouble() ?? 0;
    final weeklyTp = (offeringResponse['weekly_tp_hours'] as num?)?.toDouble() ?? 0;
    final weeks = (offeringResponse['weeks'] as num?)?.toInt() ?? 14;
    final coefficient = (offeringResponse['coefficient'] as num?)?.toDouble() ?? 1.0;

    String? professorName;
    final teacherId = offeringResponse['teacher_id'] as String?;
    if (teacherId != null) {
      final teacherResponse = await supabase
          .from('users')
          .select('full_name')
          .eq('id', teacherId)
          .maybeSingle();
      professorName = teacherResponse?['full_name'] as String?;
    }

    final recordsResponse = await supabase
        .from('absence_records')
        .select('''
          id,
          enrollment_id,
          subject_offering_id,
          date,
          hours_absent,
          session_type,
          reason,
          justified,
          created_at
        ''')
        .eq('enrollment_id', enrollmentId)
        .eq('subject_offering_id', offeringId)
        .order('date', ascending: true);

    final records = (recordsResponse as List)
        .map((e) => AbsenceRecordModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final timetableResponse = await supabase
        .from('timetable_slots')
        .select('day_of_week')
        .eq('subject_offering_id', offeringId);

    final scheduledDays = (timetableResponse as List)
        .map((e) => e['day_of_week'] as String)
        .toSet()
        .toList();

    return AbsenceDetailData(
      subjectName: subjectName,
      subjectCode: subjectCode,
      professorName: professorName,
      coefficient: coefficient,
      totalHours: totalHours,
      weeklyCiHours: weeklyCi,
      weeklyTpHours: weeklyTp,
      weeks: weeks,
      records: records,
      scheduledDays: scheduledDays,
    );
  } catch (e) {
    debugPrint('absenceDetailProvider error: $e');
    return null;
  }
});

const Color _primaryPink = Color(0xFFFF2D78);
const Color _surfaceColor = Color(0xFFF8F9FC);
const Color _onSurface = Color(0xFF1A1C23);
const Color _secondaryText = Color(0xFF6B7280);
const Color _redAbsence = Color(0xFFFF4D4D);
const Color _blueCI = Color(0xFF4D79FF);

class AbsenceDetailScreen extends ConsumerWidget {
  final String subjectOfferingId;
  const AbsenceDetailScreen({super.key, required this.subjectOfferingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(absenceDetailProvider(subjectOfferingId));
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF8F0FC),
              Color(0xFFF0E6F8),
              Color(0xFFEAF0FA),
              Color(0xFFF4F8FC),
              Color(0xFFFAFCFD),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: detailAsync.when(
          data: (data) => data != null ? _DetailBody(data: data) : const _ErrorBody(),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _ErrorBody(),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text('Impossible de charger les détails'),
        ],
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  final AbsenceDetailData data;
  const _DetailBody({required this.data});
  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _showWeekView = false;
  int _currentWeekIndex = 0;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final absencesByDate = <DateTime, List<AbsenceRecordModel>>{};
    for (final r in d.records) {
      final day = DateTime(r.date.year, r.date.month, r.date.day);
      absencesByDate.putIfAbsent(day, () => []).add(r);
    }
    final totalAbsent = d.records.fold<double>(0, (s, r) => s + r.hoursAbsent);
    final ciHours = d.records.where((r) => r.sessionType == 'CI').fold<double>(0, (s, r) => s + r.hoursAbsent);
    final overallPct = d.totalHours > 0 ? totalAbsent / d.totalHours : 0.0;

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(context, d, overallPct),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildStatsPanel(d),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -22,
                        child: _buildChipsRow(totalAbsent, ciHours),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                  _buildTogglePills(),
                  const SizedBox(height: 20),
                  _buildTimelinePanel(d, absencesByDate),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AbsenceDetailData d, double overallPct) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: Colors.grey[700],
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(d.subjectName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: _onSurface)),
                const SizedBox(height: 2),
                Text('Matière', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 2, color: _secondaryText.withOpacity(0.7))),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildProgressRing(overallPct),
        ],
      ),
    );
  }

  Widget _buildProgressRing(double pct) {
    final clamped = pct.clamp(0.0, 1.0);
    return SizedBox(
      width: 48, height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.4),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
              ],
            ),
          ),
          SizedBox(
            width: 44, height: 44,
            child: CircularProgressIndicator(
              value: clamped,
              strokeWidth: 4,
              backgroundColor: _primaryPink.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(_primaryPink),
            ),
          ),
          Text('${(clamped * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _primaryPink)),
        ],
      ),
    );
  }

  Widget _buildStatsPanel(AbsenceDetailData d) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              _statItem(icon: Icons.balance_rounded, iconBg: _surfaceColor, iconColor: _secondaryText, value: d.coefficient.toStringAsFixed(1), unit: 'Coeff', isPrimary: false),
              Container(width: 1, height: 48, color: const Color(0xFFE1E5F2).withOpacity(0.5)),
              _statItem(icon: Icons.schedule_rounded, iconBg: _primaryPink.withOpacity(0.1), iconColor: _primaryPink, value: '${d.totalHours.toStringAsFixed(0)}h', unit: 'Total', isPrimary: true, iconSize: 26),
              Container(width: 1, height: 48, color: const Color(0xFFE1E5F2).withOpacity(0.5)),
              _statItem(icon: Icons.view_week_rounded, iconBg: _surfaceColor, iconColor: _secondaryText, value: '${d.weeks}', unit: 'Sem.', isPrimary: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem({required IconData icon, required Color iconBg, required Color iconColor, required String value, required String unit, required bool isPrimary, double iconSize = 20}) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: isPrimary ? 24 : 20, fontWeight: FontWeight.w800, color: _onSurface, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(unit, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: isPrimary ? _primaryPink : _secondaryText)),
        ],
      ),
    );
  }

  Widget _buildChipsRow(double totalAbsent, double ciHours) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _glassChip(color: _redAbsence, label: 'Absent', value: '${totalAbsent.toStringAsFixed(0)}h'),
          const SizedBox(width: 12),
          _glassChip(color: _blueCI, label: 'CI', value: '${ciHours.toStringAsFixed(0)}h'),
        ],
      ),
    );
  }

  Widget _glassChip({required Color color, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)]),
          ),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _secondaryText)),
        ],
      ),
    );
  }

  Widget _buildTogglePills() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 56,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / 2;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    left: _showWeekView ? tabWidth : 0,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFF2D78), Color(0xFFFF2D78)],
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryPink.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showWeekView = false),
                          child: Container(
                            alignment: Alignment.center,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _showWeekView ? Colors.grey.shade600 : Colors.white,
                              ),
                              child: const Text('Mois'),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showWeekView = true),
                          child: Container(
                            alignment: Alignment.center,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _showWeekView ? Colors.white : Colors.grey.shade600,
                              ),
                              child: const Text('Semaine'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTimelinePanel(AbsenceDetailData d, Map<DateTime, List<AbsenceRecordModel>> absencesByDate) {
    final monthName = DateFormat('MMMM yyyy', 'fr_FR').format(_currentMonth);

    if (_showWeekView) {
      final startOfWeek = _currentMonth.add(Duration(days: _currentWeekIndex * 7));
      final weekStart = startOfWeek.subtract(Duration(days: startOfWeek.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final weekAbsences = <DateTime, List<AbsenceRecordModel>>{};
      absencesByDate.forEach((date, records) {
        if (!date.isBefore(weekStart) && !date.isAfter(weekEnd)) {
          weekAbsences[date] = records;
        }
      });

      final sortedWeek = weekAbsences.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

      return _glassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonthHeader('Semaine du ${DateFormat('dd/MM').format(weekStart)}',
              onPrev: () => setState(() => _currentWeekIndex = (_currentWeekIndex - 1).clamp(0, 52)),
              onNext: () => setState(() => _currentWeekIndex = (_currentWeekIndex + 1).clamp(0, 52)),
            ),
            const SizedBox(height: 16),
            if (weekAbsences.isEmpty)
              _buildEmptyState()
            else
              ...sortedWeek.map((e) => _buildTimelineItem(e.key, e.value)),
          ],
        ),
      );
    }

    final monthAbsences = <DateTime, List<AbsenceRecordModel>>{};
    absencesByDate.forEach((date, records) {
      if (date.month == _currentMonth.month && date.year == _currentMonth.year) {
        monthAbsences[date] = records;
      }
    });

    final sortedMonth = monthAbsences.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return _glassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMonthHeader(monthName[0].toUpperCase() + monthName.substring(1),
            onPrev: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)),
            onNext: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)),
          ),
          const SizedBox(height: 16),
          if (monthAbsences.isEmpty)
            _buildEmptyState()
          else
            ...sortedMonth.map((e) => _buildTimelineItem(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _glassPanel({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMonthHeader(String title, {required VoidCallback onPrev, required VoidCallback onNext}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _onSurface)),
        Row(
          children: [
            _roundIconButton(Icons.chevron_left, onPrev),
            const SizedBox(width: 8),
            _roundIconButton(Icons.chevron_right, onNext),
          ],
        ),
      ],
    );
  }

  Widget _roundIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: _surfaceColor, shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: _secondaryText),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.more_horiz, size: 32, color: _secondaryText.withOpacity(0.5)),
          const SizedBox(height: 8),
          Text('Aucune absence ce mois-ci', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _secondaryText.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(DateTime date, List<AbsenceRecordModel> absences) {
    final totalH = absences.fold<double>(0, (s, r) => s + r.hoursAbsent);
    final allJustified = absences.every((r) => r.justified);
    final first = absences.first;
    final dotColor = allJustified ? _blueCI : _redAbsence;
    final dayName = DateFormat('EEE', 'fr_FR').format(date);
    final shortDayName = dayName.substring(0, 1).toUpperCase() + dayName.substring(1, 3);
    final status = allJustified
        ? 'Absence Justifiée${first.sessionType != null ? ' (${first.sessionType})' : ''}'
        : 'Absence Non Justifiée';
    final hourStr = absences.length == 1
        ? '${totalH.toStringAsFixed(0)}h'
        : '${absences.length} séances (${totalH.toStringAsFixed(0)}h)';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: (allJustified ? _blueCI : _redAbsence).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${date.day}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: allJustified ? _blueCI : _redAbsence)),
                Text(shortDayName, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: allJustified ? _blueCI : _redAbsence)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _onSurface)),
                const SizedBox(height: 2),
                Text(hourStr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _secondaryText)),
              ],
            ),
          ),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: dotColor.withOpacity(0.6), blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }
}


