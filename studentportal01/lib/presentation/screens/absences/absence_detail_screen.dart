import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../providers/auth_provider.dart';
import '../../../data/models/absence_model.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/arabic_typography.dart';
import '../../providers/nav_bar_provider.dart';
import '../../widgets/bouncing_wrapper.dart';
import '../../widgets/ios_edge_swipe_back.dart';

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
          data: (data) => data != null
              ? _DetailBody(data: data, isLoading: false)
              : const _ErrorBody(),
          loading: () => const _DetailBody(data: null, isLoading: true),
          error: (_, _) => const _ErrorBody(),
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
          Text(AppLocalizations.of(context).errorLoadingDetails),
        ],
      ),
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  final AbsenceDetailData? data;
  final bool isLoading;
  const _DetailBody({this.data, this.isLoading = false});
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
    final isLoading = widget.isLoading || d == null;
    final absencesByDate = <DateTime, List<AbsenceRecordModel>>{};
    if (d != null) {
      for (final r in d.records) {
        final day = DateTime(r.date.year, r.date.month, r.date.day);
        absencesByDate.putIfAbsent(day, () => []).add(r);
      }
    }
    final totalAbsent = d != null
        ? d.records.fold<double>(0, (s, r) => s + r.hoursAbsent)
        : 0.0;
    final ciHours = d != null
        ? d.records
            .where((r) => r.sessionType == 'CI')
            .fold<double>(0, (s, r) => s + r.hoursAbsent)
        : 0.0;
    final overallPct =
        (d != null && d.totalHours > 0) ? totalAbsent / d.totalHours : 0.0;

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(context, d, overallPct, isLoading),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildStatsPanel(d, isLoading),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: -22,
                        child: _buildChipsRow(totalAbsent, ciHours, isLoading),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                  _buildTogglePills(),
                  const SizedBox(height: 20),
                  _buildTimelinePanel(d, absencesByDate, isLoading),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getShortcutOrName(AbsenceDetailData? d) {
    if (d == null) return '';
    final name = d.subjectName.trim();
    if (name.length > 15) {
      if (d.subjectCode != null && d.subjectCode!.trim().isNotEmpty) {
        return d.subjectCode!.trim();
      }
      final lower = name.toLowerCase();
      if (lower.contains('sciences de la vie') || lower.contains('svt') || lower.contains('terre')) {
        return 'SVT';
      }
      if (lower.contains('algorithmique') || lower.contains('structure')) {
        return 'ASD';
      }
      if (lower.contains('architecture') || lower.contains('ordinateur')) {
        return 'ARCHI';
      }
      if (lower.contains('math') || lower.contains('analyse') || lower.contains('algebre')) {
        return 'MATH';
      }
      if (lower.contains('compta') || lower.contains('gestion')) {
        return 'COMPTA';
      }
      if (lower.contains('anglais') || lower.contains('english') || lower.contains('francais')) {
        return 'LANG';
      }
      
      // Fallback: take first letters of each word
      final words = name.split(' ').where((w) => w.length > 2).toList();
      if (words.length >= 2) {
         return words.map((w) => w[0].toUpperCase()).join('');
      }
      
      return '${name.substring(0, 15)}...';
    }
    return name;
  }

  Widget _buildHeader(BuildContext context, AbsenceDetailData? d, double overallPct, bool isLoading) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar' ||
        Directionality.of(context) == TextDirection.rtl;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 24, 0),
      child: Row(
        children: [
          BouncingWrapper(
            shrinkScale: 0.86,
            overshootScale: 1.10,
            delayNavigation: false,
            hitPadding: const EdgeInsets.all(12),
            onTap: () {
              final swipeBack = IosEdgeSwipeBack.of(context);
              if (swipeBack != null) {
                swipeBack.animateBack();
              } else {
                final fromAIChat = ref.read(navigatedFromAIChatProvider);
                if (fromAIChat) {
                  ref.read(navigatedFromAIChatProvider.notifier).state = false;
                  context.go('/ai-chat');
                } else {
                  context.go('/absences');
                }
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Icon(
                  isAr ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                  color: Colors.grey[700],
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isLoading || d == null)
                  Shimmer.fromColors(
                    baseColor: const Color(0xFFE2E8F0),
                    highlightColor: Colors.white,
                    child: Container(
                      width: 140,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                else
                  Text(
                    _getShortcutOrName(d),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontFamily: isAr ? GoogleFonts.cairo().fontFamily : null,
                      color: _onSurface,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  l10n.academicSubject,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: _secondaryText.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (isLoading || d == null)
            Shimmer.fromColors(
              baseColor: const Color(0xFFE2E8F0),
              highlightColor: Colors.white,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            )
          else
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
              color: Colors.white.withValues(alpha: 0.4),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
              ],
            ),
          ),
          SizedBox(
            width: 44, height: 44,
            child: CircularProgressIndicator(
              value: clamped,
              strokeWidth: 4,
              backgroundColor: _primaryPink.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(_primaryPink),
            ),
          ),
          Text('${(clamped * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _primaryPink)),
        ],
      ),
    );
  }

  Widget _buildStatsPanel(AbsenceDetailData? d, bool isLoading) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              _statItem(
                icon: Icons.balance_rounded,
                iconBg: _surfaceColor,
                iconColor: _secondaryText,
                value: (isLoading || d == null) ? null : d.coefficient.toStringAsFixed(1),
                unit: AppLocalizations.of(context).coeffLabel,
                isPrimary: false,
              ),
              Container(width: 1, height: 48, color: const Color(0xFFE1E5F2).withValues(alpha: 0.5)),
              _statItem(
                icon: Icons.schedule_rounded,
                iconBg: _primaryPink.withValues(alpha: 0.1),
                iconColor: _primaryPink,
                value: (isLoading || d == null)
                    ? null
                    : '${d.totalHours.toStringAsFixed(0)} ${AppLocalizations.of(context).translate('hour_unit')}',
                unit: AppLocalizations.of(context).totalLabel,
                isPrimary: true,
                iconSize: 26,
              ),
              Container(width: 1, height: 48, color: const Color(0xFFE1E5F2).withValues(alpha: 0.5)),
              _statItem(
                icon: Icons.view_week_rounded,
                iconBg: _surfaceColor,
                iconColor: _secondaryText,
                value: (isLoading || d == null) ? null : '${d.weeks}',
                unit: AppLocalizations.of(context).semLabel,
                isPrimary: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String? value,
    required String unit,
    required bool isPrimary,
    double iconSize = 20,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
            child: Icon(icon, size: iconSize, color: iconColor),
          ),
          const SizedBox(height: 8),
          if (value == null)
            Shimmer.fromColors(
              baseColor: const Color(0xFFE2E8F0),
              highlightColor: Colors.white,
              child: Container(
                width: 42,
                height: isPrimary ? 24 : 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )
          else
            Text(value, style: TextStyle(fontSize: isPrimary ? 24 : 20, fontWeight: FontWeight.w800, color: _onSurface, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(unit, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: isPrimary ? _primaryPink : _secondaryText)),
        ],
      ),
    );
  }

  Widget _buildChipsRow(double totalAbsent, double ciHours, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _glassChip(
            color: _redAbsence,
            label: AppLocalizations.of(context).absentLabel,
            value: isLoading
                ? null
                : '${totalAbsent.toStringAsFixed(0)} ${AppLocalizations.of(context).translate('hour_unit')}',
          ),
          const SizedBox(width: 12),
          _glassChip(
            color: _blueCI,
            label: AppLocalizations.of(context).ciLabel,
            value: isLoading
                ? null
                : '${ciHours.toStringAsFixed(0)} ${AppLocalizations.of(context).translate('hour_unit')}',
          ),
        ],
      ),
    );
  }

  Widget _glassChip({required Color color, required String label, required String? value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]),
          ),
          const SizedBox(width: 8),
          if (value == null)
            Shimmer.fromColors(
              baseColor: const Color(0xFFE2E8F0),
              highlightColor: Colors.white,
              child: Container(
                width: 38,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )
          else
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
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / 2;
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Stack(
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
                            color: _primaryPink.withValues(alpha: 0.5),
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
                        child: BouncingWrapper(
                          behavior: HitTestBehavior.opaque,
                          hitPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          delayNavigation: false,
                          shrinkScale: 0.92,
                          overshootScale: 1.06,
                          onTap: () {
                            if (_showWeekView) setState(() => _showWeekView = false);
                          },
                          child: Container(
                            height: double.infinity,
                            alignment: Alignment.center,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontFamily: Localizations.localeOf(context).languageCode == 'ar'
                                    ? GoogleFonts.cairo().fontFamily
                                    : null,
                                fontSize: Localizations.localeOf(context).languageCode == 'ar' ? 15 : 14,
                                fontWeight: FontWeight.w700,
                                color: _showWeekView ? Colors.grey.shade600 : Colors.white,
                              ),
                              child: Text(AppLocalizations.of(context).month),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: BouncingWrapper(
                          behavior: HitTestBehavior.opaque,
                          hitPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          delayNavigation: false,
                          shrinkScale: 0.92,
                          overshootScale: 1.06,
                          onTap: () {
                            if (!_showWeekView) setState(() => _showWeekView = true);
                          },
                          child: Container(
                            height: double.infinity,
                            alignment: Alignment.center,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              style: TextStyle(
                                fontFamily: Localizations.localeOf(context).languageCode == 'ar'
                                    ? GoogleFonts.cairo().fontFamily
                                    : null,
                                fontSize: Localizations.localeOf(context).languageCode == 'ar' ? 15 : 14,
                                fontWeight: FontWeight.w700,
                                color: _showWeekView ? Colors.white : Colors.grey.shade600,
                              ),
                              child: Text(AppLocalizations.of(context).week),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTimelinePanel(AbsenceDetailData? d, Map<DateTime, List<AbsenceRecordModel>> absencesByDate, bool isLoading) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final rawMonth = DateFormat('MMMM yyyy', localeCode).format(_currentMonth);
    final monthName = ArabicTypography.toLatinDigits(rawMonth);

    if (isLoading || d == null) {
      return _glassPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMonthHeader(
              monthName[0].toUpperCase() + monthName.substring(1),
              onPrev: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1)),
              onNext: () => setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1)),
            ),
            const SizedBox(height: 16),
            _buildTimelineSkeletonItem(),
            _buildTimelineSkeletonItem(),
          ],
        ),
      );
    }

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
            _buildMonthHeader(
              ArabicTypography.toLatinDigits(
                localeCode == 'ar'
                    ? 'أسبوع ${DateFormat('dd/MM').format(weekStart)}'
                    : (localeCode == 'en'
                        ? 'Week of ${DateFormat('dd/MM').format(weekStart)}'
                        : 'Semaine du ${DateFormat('dd/MM').format(weekStart)}'),
              ),
              onPrev: () => setState(() => _currentWeekIndex = (_currentWeekIndex - 1).clamp(0, 52)),
              onNext: () => setState(() => _currentWeekIndex = (_currentWeekIndex + 1).clamp(0, 52)),
            ),
            const SizedBox(height: 16),
            if (weekAbsences.isEmpty)
              _buildEmptyState(isWeek: true)
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

  Widget _buildTimelineSkeletonItem() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Shimmer.fromColors(
            baseColor: const Color(0xFFE2E8F0),
            highlightColor: Colors.white,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Shimmer.fromColors(
                  baseColor: const Color(0xFFE2E8F0),
                  highlightColor: Colors.white,
                  child: Container(
                    width: 140,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Shimmer.fromColors(
                  baseColor: const Color(0xFFE2E8F0),
                  highlightColor: Colors.white,
                  child: Container(
                    width: 70,
                    height: 11,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Shimmer.fromColors(
            baseColor: const Color(0xFFE2E8F0),
            highlightColor: Colors.white,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
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
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
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

  Widget _buildEmptyState({bool isWeek = false}) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.more_horiz, size: 32, color: _secondaryText.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(
            isWeek ? l10n.noAbsencesWeek : l10n.noAbsencesMonth,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _secondaryText.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(DateTime date, List<AbsenceRecordModel> absences) {
    final totalH = absences.fold<double>(0, (s, r) => s + r.hoursAbsent);
    final allJustified = absences.every((r) => r.justified);
    final first = absences.first;
    final dotColor = allJustified ? _blueCI : _redAbsence;
    final localeCode = Localizations.localeOf(context).languageCode;
    final l10n = AppLocalizations.of(context);
    final dayName = DateFormat('EEE', localeCode).format(date);
    final shortDayName = dayName.length >= 3
        ? dayName.substring(0, 1).toUpperCase() + dayName.substring(1, 3)
        : dayName;
    final status = allJustified
        ? '${l10n.justifiedAbsence}${first.sessionType != null ? ' (${first.sessionType})' : ''}'
        : l10n.unjustifiedAbsence;
    final hourUnit = l10n.translate('hour_unit');
    final hourStr = absences.length == 1
        ? '${totalH.toStringAsFixed(0)} $hourUnit'
        : '${absences.length} ${l10n.sessionsCount} (${totalH.toStringAsFixed(0)} $hourUnit)';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: (allJustified ? _blueCI : _redAbsence).withValues(alpha: 0.1),
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
              boxShadow: [BoxShadow(color: dotColor.withValues(alpha: 0.6), blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }
}


