import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/arabic_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/timetable_model.dart';
import '../../providers/student_context_provider.dart';
import '../../providers/nav_bar_provider.dart';
import '../../widgets/semester_navigator.dart';
import '../../widgets/bouncing_wrapper.dart';
import '../../widgets/emploi_skeleton.dart';

final emploiSemesterProvider = StateProvider<int>((ref) => 1);

// Timetable type selection provider: 'regular' vs 'exam'
final emploiTypeProvider = StateProvider<String>((ref) => 'regular');

// Loading state for emploi refresh
final emploiRefreshingProvider = StateProvider<bool>((ref) => false);

// Detect if currently in an exam period
final isExamPeriodProvider = FutureProvider<bool>((ref) async {
  try {
    final contextAsync = await ref.watch(studentContextProvider.future);
    if (contextAsync == null || contextAsync.schoolId.isEmpty) return false;

    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final examCheck = await Supabase.instance.client
        .rpc('get_active_exam_period', params: {
      'p_school_id': contextAsync.schoolId,
      'p_date': todayStr,
    });
    if (examCheck != null) return true;

    // Fallback direct query on exam_periods table
    final directCheck = await Supabase.instance.client
        .from('exam_periods')
        .select('id')
        .eq('school_id', contextAsync.schoolId)
        .or('is_active.eq.true,and(start_date.lte.$todayStr,end_date.gte.$todayStr)')
        .maybeSingle();

    return directCheck != null;
  } catch (_) {
    return false;
  }
});

String _parseTime(String time) {
  if (time.length >= 5) {
    return time.substring(0, 5);
  }
  if (time.length == 4) {
    return '0$time';
  }
  return time;
}

final Map<String, Color> _presetSubjectColors = {
  'ARABE': const Color(0xFFF59E0B), // Orange / Amber like Pic 2
  'AR': const Color(0xFFF59E0B),
  'MATH': const Color(0xFF10B981),  // Emerald Green like Pic 2
  'FRANCAIS': const Color(0xFFEC4899), // Pink like Pic 2
  'FR': const Color(0xFFEC4899),
  'ANGLAIS': const Color(0xFFEA580C), // Orange like Pic 2
  'ANG': const Color(0xFFEA580C),
  'EN': const Color(0xFFEA580C),
  'PHYSIQUE': const Color(0xFF06B6D4), // Cyan like Pic 2
  'PHYS': const Color(0xFF06B6D4),
  'SVT': const Color(0xFF3B82F6),   // Blue like Pic 2
  'HISTOIRE': const Color(0xFFE11D48), // Magenta / Rose like Pic 2
  'HIST': const Color(0xFFE11D48),
  'GEO': const Color(0xFFEF4444),   // Crimson Red like Pic 2
  'INFO': const Color(0xFF84CC16),  // Lime Green like Pic 2
  'TECH': const Color(0xFFF59E0B),  // Amber like Pic 2
  'ED_ISL': const Color(0xFF14B8A6), // Teal like Pic 2
  'ISL': const Color(0xFF14B8A6),
  'ED_CIV': const Color(0xFF6366F1), // Indigo like Pic 2
  'CIV': const Color(0xFF6366F1),
  'SPORT': const Color(0xFF8B5CF6), // Purple like Pic 2
};

final List<Color> _appColorPalette = const [
  Color(0xFFF59E0B), // Amber
  Color(0xFF10B981), // Emerald
  Color(0xFFEC4899), // Pink
  Color(0xFFEA580C), // Orange
  Color(0xFF06B6D4), // Cyan
  Color(0xFF3B82F6), // Blue
  Color(0xFFE11D48), // Rose
  Color(0xFFEF4444), // Red
  Color(0xFF84CC16), // Lime
  Color(0xFF14B8A6), // Teal
  Color(0xFF8B5CF6), // Violet
  Color(0xFF6366F1), // Indigo
];

Color _getSubjectColor(String subjectCode) {
  final codeUpper = subjectCode.trim().toUpperCase();
  for (final entry in _presetSubjectColors.entries) {
    if (codeUpper == entry.key || codeUpper.startsWith(entry.key) || codeUpper.contains(entry.key)) {
      return entry.value;
    }
  }
  final hash = codeUpper.codeUnits.fold(0, (prev, elem) => prev + elem);
  return _appColorPalette[hash % _appColorPalette.length];
}

final timetableProvider = FutureProvider<List<TimetableSlotModel>>((ref) async {
  final contextAsync = await ref.watch(studentContextProvider.future);

  if (contextAsync == null || contextAsync.classId == null) return [];

  final classId = contextAsync.classId!;
  final supabase = Supabase.instance.client;

  try {
    final isExamPeriodActive = await ref.watch(isExamPeriodProvider.future);
    final selectedType = isExamPeriodActive ? 'exam' : 'regular';
    final selectedSemesterNumber = ref.watch(emploiSemesterProvider);

    // Direct, canonical and resilient query for timetable slots of this student's class
    var query = supabase
        .from('timetable_slots')
        .select('''
          *,
          subject_offerings!inner (
            id, class_id, subject_id, teacher_id, semester_id,
            subjects (name, code),
            semesters (id, name, number, is_current)
          )
        ''')
        .eq('subject_offerings.class_id', classId);

    if (selectedType == 'exam') {
      query = query.inFilter('timetable_type', ['exam', 'examen', 'Exam', 'Examen']);
    } else {
      query = query.or('timetable_type.eq.regular,timetable_type.is.null');
    }

    final slotsResp = await query
        .order('day_of_week')
        .order('start_time');

    final allSlotsList = slotsResp as List;
    if (allSlotsList.isEmpty) return [];

    // Filter strictly by selected semester number
    final activeSlots = allSlotsList.where((slot) {
      final sem = slot['subject_offerings']?['semesters'] as Map<String, dynamic>?;
      if (sem == null) return false;
      final num = sem['number'] as int?;
      return num == selectedSemesterNumber;
    }).toList();

    if (activeSlots.isEmpty) return [];

    // Resolve teacher names/photos from teacher_assignments
    final Map<String, String> subjectClassTeacherMap = {};
    final Map<String, String> subjectClassTeacherPhotoMap = {};
    try {
      final teacherAssResp = await supabase
          .from('teacher_assignments')
          .select(
              'subject_id, class_id, teacher_id, users!teacher_id(full_name, photo_url)')
          .eq('is_active', true);

      for (final ta in (teacherAssResp as List)) {
        final subjectId = ta['subject_id'] as String?;
        final clsId = ta['class_id'] as String?;
        final teacherData = ta['users'] as Map<String, dynamic>?;
        if (subjectId != null && clsId != null) {
          subjectClassTeacherMap['${subjectId}_$clsId'] =
              teacherData?['full_name'] as String? ?? '';
          subjectClassTeacherPhotoMap['${subjectId}_$clsId'] =
              teacherData?['photo_url'] as String? ?? '';
        }
      }
    } catch (_) {}

    return activeSlots.map((json) {
      final offering = json['subject_offerings'] as Map<String, dynamic>?;
      final subject = offering?['subjects'] as Map<String, dynamic>?;

      final subjectId = offering?['subject_id'] as String?;
      final teacherKey = subjectId != null ? '${subjectId}_$classId' : null;

      final teacherNameFromAssignment =
          teacherKey != null ? subjectClassTeacherMap[teacherKey] : null;
      final teacherPhotoFromAssignment =
          teacherKey != null ? subjectClassTeacherPhotoMap[teacherKey] : null;

      final teacherName = (teacherNameFromAssignment?.isNotEmpty == true)
          ? teacherNameFromAssignment
          : (json['teacher_name'] as String?);
      final teacherPhoto = (teacherPhotoFromAssignment?.isNotEmpty == true)
          ? teacherPhotoFromAssignment
          : null;

      final subjectName = (json['subject_name'] as String?) ??
          (subject?['name'] as String?) ??
          (json['title'] as String?) ??
          'Matière';
      final subjectCode = (json['subject_code'] as String?) ??
          (subject?['code'] as String?) ??
          subjectName;

      return TimetableSlotModel(
        id: (json['id'] as String?) ?? '',
        subjectOfferingId: (json['subject_offering_id'] as String?) ?? '',
        groupId: json['group_id'] as String?,
        dayOfWeek: (json['day_of_week'] as String?) ?? 'monday',
        startTime: _parseTime((json['start_time'] as String?) ?? '08:00'),
        endTime: _parseTime((json['end_time'] as String?) ?? '09:00'),
        room: json['room'] as String?,
        teacherName: teacherName,
        teacherPhotoUrl: teacherPhoto,
        sessionType: json['session_type'] as String? ?? 'CI',
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        subjectName: subjectName,
        subjectCode: subjectCode,
      );
    }).toList();
  } catch (e) {
    debugPrint('timetableProvider error: $e');
    return [];
  }
});

const List<String> _timeSlots = [
  '08:00', '09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00',
];
const List<String> _dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
const List<String> _dayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];
const List<String> _fullDayLabels = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi'];

String _getDayLabel(int dayIndex, bool isFullScreen, String langCode) {
  if (langCode == 'ar') {
    const arShort = ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت'];
    const arFull = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    if (dayIndex >= 0 && dayIndex < 6) {
      return isFullScreen ? arFull[dayIndex] : arShort[dayIndex];
    }
  } else if (langCode == 'en') {
    const enShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const enFull = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    if (dayIndex >= 0 && dayIndex < 6) {
      return isFullScreen ? enFull[dayIndex] : enShort[dayIndex];
    }
  }
  return isFullScreen ? _fullDayLabels[dayIndex] : _dayLabels[dayIndex];
}

class EmploiScreen extends ConsumerStatefulWidget {
  const EmploiScreen({super.key});

  @override
  ConsumerState<EmploiScreen> createState() => _EmploiScreenState();
}

class _EmploiScreenState extends ConsumerState<EmploiScreen>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  late final TransformationController _zoomController;
  late final AnimationController _zoomAnimCtrl;
  late final AnimationController _blurAnimCtrl;
  Animation<Matrix4>? _zoomAnimation;
  bool _isZoomed = false;
  OverlayEntry? _overlayEntry;
  List<TimetableSlotModel>? _currentSlots;

  @override
  void initState() {
    super.initState();
    _zoomController = TransformationController();
    _zoomAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 440),
    );
    _blurAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _zoomController.addListener(_onZoomChanged);
  }

  void _removeZoomOverlay() {
    try {
      _overlayEntry?.remove();
    } catch (_) {}
    _overlayEntry = null;
  }

  void _showZoomOverlay(List<TimetableSlotModel> slots) {
    _removeZoomOverlay();
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _blurAnimCtrl,
                builder: (context, _) {
                  final blurVal = 16.0 * _blurAnimCtrl.value;
                  return Positioned.fill(
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: blurVal, sigmaY: blurVal),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.06 * _blurAnimCtrl.value),
                        ),
                      ),
                    ),
                  );
                },
              ),
              SafeArea(
                child: Center(
                  child: InteractiveViewer(
                    transformationController: _zoomController,
                    minScale: 0.85,
                    maxScale: 6.0,
                    boundaryMargin: const EdgeInsets.all(400),
                    onInteractionEnd: _handleInteractionEnd,
                    child: GestureDetector(
                      onDoubleTap: _resetZoom,
                      child: _buildScrollableTimetable(overlayContext, slots, isFullScreen: true),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(overlayContext).padding.top + 16,
                right: 20,
                child: BouncingWrapper(
                  shrinkScale: 0.86,
                  overshootScale: 1.10,
                  onTap: _resetZoom,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 24,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _startZoom(List<TimetableSlotModel> slots) {
    if (!_isZoomed) {
      _currentSlots = slots;
      setState(() {
        _isZoomed = true;
      });
      _blurAnimCtrl.forward();
      _showZoomOverlay(slots);
    }
  }

  void _onZoomChanged() {
    final scale = _zoomController.value.getMaxScaleOnAxis();
    if (scale > 1.05 && !_isZoomed && _currentSlots != null) {
      _startZoom(_currentSlots!);
    }
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    final scale = _zoomController.value.getMaxScaleOnAxis();
    if (scale < 1.15) {
      _resetZoom();
    }
  }

  void _resetZoom() {
    _blurAnimCtrl.reverse();
    _zoomAnimation = Matrix4Tween(
      begin: _zoomController.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(
      parent: _zoomAnimCtrl,
      curve: Curves.easeOutCubic,
    ));

    _zoomAnimCtrl.reset();
    void listener() {
      if (_zoomAnimation != null) {
        _zoomController.value = _zoomAnimation!.value;
      }
    }
    _zoomAnimation!.addListener(listener);
    _zoomAnimCtrl.forward().then((_) {
      _zoomAnimation?.removeListener(listener);
      _removeZoomOverlay();
      if (mounted) {
        setState(() {
          _isZoomed = false;
        });
      }
    });
  }

  void _setExpanded(bool expanded) {
    if (_isExpanded != expanded) {
      if (_isZoomed) {
        _resetZoom();
      }
      setState(() {
        _isExpanded = expanded;
      });
      ref.read(navBarHiddenProvider.notifier).state = expanded;
    }
  }

  @override
  void deactivate() {
    _removeZoomOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    _removeZoomOverlay();
    _zoomController.removeListener(_onZoomChanged);
    _zoomController.dispose();
    _zoomAnimCtrl.dispose();
    _blurAnimCtrl.dispose();
    if (_isExpanded) {
      Future.microtask(() {
        ref.read(navBarHiddenProvider.notifier).state = false;
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final timetableAsync = ref.watch(timetableProvider);
    final selectedSemester = ref.watch(emploiSemesterProvider);
    final isExamPeriodActive = ref.watch(isExamPeriodProvider).valueOrNull ?? false;
    final selectedType = isExamPeriodActive ? 'exam' : 'regular';
    final isRefreshing = ref.watch(emploiRefreshingProvider);

    return Material(
      type: MaterialType.transparency,
      child: Container(
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
        child: PopScope(
          canPop: !_isExpanded && !_isZoomed,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_isZoomed) {
              _resetZoom();
              return;
            }
            if (_isExpanded) {
              _setExpanded(false);
              return;
            }
          },
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: RefreshIndicator(
                  color: const Color(0xFFFF2D78),
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    ref.read(emploiRefreshingProvider.notifier).state = true;
                    try {
                      // ignore: unused_result
                      await ref.refresh(timetableProvider.future);
                    } finally {
                      ref.read(emploiRefreshingProvider.notifier).state = false;
                    }
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                          child: SizedBox(
                            height: 72,
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: selectedType == 'exam'
                                          ? const [Color(0xFFEA580C), Color(0xFFF97316)]
                                          : const [Color(0xFF10B981), Color(0xFF059669)],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (selectedType == 'exam'
                                                ? const Color(0xFFEA580C)
                                                : const Color(0xFF10B981))
                                            .withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    selectedType == 'exam'
                                        ? Icons.school_rounded
                                        : Icons.calendar_month_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        selectedType == 'exam'
                                            ? (Localizations.localeOf(context).languageCode == 'ar'
                                                ? 'جدول الامتحانات'
                                                : (Localizations.localeOf(context).languageCode == 'en'
                                                    ? 'Exam Timetable'
                                                    : 'Emploi d\'examen'))
                                            : l10n.emploi,
                                        style: ArabicTypography.headerStyle(
                                          context,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF1F2937),
                                          letterSpacing: -0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        selectedType == 'exam'
                                            ? l10n.examTimetableSubtitle
                                            : l10n.emploiSubtitle,
                                        style: ArabicTypography.subtitleStyle(
                                          context,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF1F2937),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                BouncingWrapper(
                                  shrinkScale: 0.86,
                                  overshootScale: 1.10,
                                  onTap: () => _setExpanded(true),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.fullscreen_rounded,
                                      color: selectedType == 'exam'
                                          ? const Color(0xFFEA580C)
                                          : const Color(0xFF10B981),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: DynamicSemesterNav(
                            selectedSemesterNumber: selectedSemester,
                            accentColor: selectedType == 'exam'
                                ? const Color(0xFFEA580C)
                                : const Color(0xFF10B981),
                            secondaryColor: selectedType == 'exam'
                                ? const Color(0xFFF97316)
                                : const Color(0xFF059669),
                            onChanged: (v) => ref
                                .read(emploiSemesterProvider.notifier)
                                .state = v,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: isRefreshing
                            ? const EmploiSkeleton()
                            : timetableAsync.when(
                          loading: () => const EmploiSkeleton(),
                          error: (e, _) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline,
                                    size: 48, color: Colors.red.shade300),
                                const SizedBox(height: 16),
                                Text('Erreur: $e',
                                    style: TextStyle(color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          data: (slots) {
                            if (slots.isEmpty) {
                              final semestersAsync = ref.watch(semestersProvider);
                              final semObj = semestersAsync.valueOrNull
                                  ?.where((s) => s.number == selectedSemester)
                                  .firstOrNull;
                              final now = DateTime.now();
                              final isFuture = semObj != null &&
                                  !semObj.isCurrent &&
                                  semObj.startDate != null &&
                                  now.isBefore(semObj.startDate!);

                              return _buildEmptyState(
                                context,
                                isExam: selectedType == 'exam',
                                isFuture: isFuture,
                                startDate: semObj?.startDate,
                              );
                            }
                            return _buildScrollableTimetable(context, slots);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isExpanded && !_isZoomed)
                timetableAsync.when(
                  data: (slots) => Positioned.fill(
                    child: Container(
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
                      child: SafeArea(
                        child: Stack(
                          children: [
                            Center(
                              child: _buildScrollableTimetable(context, slots, isFullScreen: true),
                            ),
                            Positioned(
                              top: 16,
                              right: 20,
                              child: BouncingWrapper(
                                shrinkScale: 0.86,
                                overshootScale: 1.10,
                                onTap: () => _setExpanded(false),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.12),
                                        blurRadius: 12,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 24,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableTimetable(BuildContext context, List<TimetableSlotModel> slots, {bool isFullScreen = false}) {
    final container = Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
      margin: isFullScreen 
          ? const EdgeInsets.fromLTRB(16, 100, 16, 20)
          : const EdgeInsets.fromLTRB(24, 0, 24, 140),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;

          const timeColWidth = 35.0;
          final headerHeight = isFullScreen ? 75.0 : 40.0;
          
          final dayColWidth = (availableWidth - timeColWidth) / _dayKeys.length;
          final calculatedHeight = isFullScreen
              ? MediaQuery.of(context).size.height - 100
              : (MediaQuery.of(context).size.height * 0.68).clamp(580.0, 750.0);
          final gridHeight = (availableHeight.isInfinite || availableHeight <= 0)
              ? calculatedHeight - headerHeight
              : availableHeight - headerHeight;
          final rowHeight = gridHeight / _timeSlots.length;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: availableWidth,
                height: gridHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ...List.generate(_timeSlots.length * 2 + 1, (i) {
                      final isHour = i % 2 == 0;
                      return Positioned(
                        left: timeColWidth,
                        right: 0,
                        bottom: i * (rowHeight / 2),
                        child: Container(
                          height: isHour ? 1.5 : 0.5,
                          color: isHour 
                              ? Colors.grey.withValues(alpha: 0.35) 
                              : Colors.grey.withValues(alpha: 0.1),
                        ),
                      );
                    }),
                    ...List.generate(_dayKeys.length + 1, (i) {
                      return Positioned(
                        left: timeColWidth + i * dayColWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1.0,
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      );
                    }),
                    // Current time - highlight remaining study time with green gradient
                    if (_isCurrentTimeInRange())
                      Positioned(
                        left: timeColWidth,
                        right: 0,
                        bottom: _getCurrentTimePosition(rowHeight),
                        top: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                const Color(0xFF10B981).withValues(alpha: 0.10),
                                const Color(0xFF10B981).withValues(alpha: 0.03),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ...List.generate(_timeSlots.length, (i) {
                      final isCurrentHour = _isCurrentHour(i);
                      return Positioned(
                        left: 0,
                        bottom: i * rowHeight,
                        width: timeColWidth,
                        height: rowHeight,
                        child: Center(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              _timeSlots[i],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isCurrentHour ? FontWeight.w800 : FontWeight.w600,
                                color: isCurrentHour ? const Color(0xFF10B981) : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    ...slots.map((s) {
                      final dayIndex = _dayKeys.indexOf(s.dayOfWeek.toLowerCase());
                      if (dayIndex == -1) return const SizedBox.shrink();

                      final startMin = _timeToMinutes(s.startTime);
                      final endMin = _timeToMinutes(s.endTime);
                      final dayStartMin = _timeToMinutes(_timeSlots.first); 
                      
                      final visibleStartMin = startMin < dayStartMin ? dayStartMin : startMin;
                      
                      final bottom = ((visibleStartMin - dayStartMin) / 60) * rowHeight;
                      final height = ((endMin - visibleStartMin) / 60) * rowHeight;

                      return Positioned(
                        left: timeColWidth + dayIndex * dayColWidth,
                        bottom: bottom,
                        width: dayColWidth,
                        height: height,
                        child: _buildSlotCell(s, height, dayColWidth),
                      );
                    }),
                  ],
                ),
              ),
              Container(
                height: headerHeight,
                width: availableWidth,
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.withValues(alpha: 0.15), width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(width: timeColWidth),
                    ...List.generate(_dayKeys.length, (dayIndex) {
                      final isToday = DateTime.now().weekday == dayIndex + 1;
                      return SizedBox(
                        width: dayColWidth,
                        child: Center(
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Text(
                              _getDayLabel(dayIndex, isFullScreen, Localizations.localeOf(context).languageCode),
                              style: TextStyle(
                                fontSize: isFullScreen ? 12 : 13,
                                fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                color: isToday ? const Color(0xFF10B981) : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ));

    if (isFullScreen) {
      return GestureDetector(
        onScaleStart: (details) {
          if (details.pointerCount >= 2) {
            _startZoom(slots);
          }
        },
        child: container,
      );
    }

    return SizedBox(
      height: (MediaQuery.of(context).size.height * 0.68).clamp(580.0, 750.0),
      child: GestureDetector(
        onScaleStart: (details) {
          if (details.pointerCount >= 2) {
            _startZoom(slots);
          }
        },
        onDoubleTap: () {
          _startZoom(slots);
          _zoomAnimation = Matrix4Tween(
            begin: Matrix4.identity(),
            end: Matrix4.diagonal3Values(1.5, 1.5, 1.0),
          ).animate(CurvedAnimation(
            parent: _zoomAnimCtrl,
            curve: Curves.easeOutCubic,
          ));
          _zoomAnimCtrl.reset();
          void listener() {
            if (_zoomAnimation != null) {
              _zoomController.value = _zoomAnimation!.value;
            }
          }
          _zoomAnimation!.addListener(listener);
          _zoomAnimCtrl.forward().then((_) {
            _zoomAnimation?.removeListener(listener);
          });
        },
        child: container,
      ),
    );
  }

  String _cleanRoomName(String? room) {
    if (room == null || room.trim().isEmpty) return '';
    String text = room.trim();
    // If it contains "Salle", "Labo", "Atelier", "Amphi", extract that part:
    final match = RegExp(
      r'(Salle\s*[A-Z0-9]+|Labo\s*[A-Z0-9]+|Atelier\s*[A-Z0-9]+|Amphi\s*[A-Z0-9]+)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      return match.group(1)!;
    }
    // Remove Block prefix (e.g. "Bloc A - ", "Bloc B - ")
    text = text.replaceAll(RegExp(r'^Bloc\s+[A-Z0-9]+\s*[-·]\s*', caseSensitive: false), '');
    // Remove "Principal - " or "Principal · "
    text = text.replaceAll(RegExp(r'^Principal\s*[-·]\s*', caseSensitive: false), '');
    // Remove prefixes like "S1 · ", "S2 · "
    text = text.replaceAll(RegExp(r'^S\d+\s*[-·]\s*', caseSensitive: false), '');
    if (text.contains('·')) {
      return text.split('·').last.trim();
    }
    return text.trim();
  }

  String _formatDetailLocation(String? room) {
    if (room == null || room.trim().isEmpty) return '';
    String text = room.trim();
    if (text.toLowerCase().startsWith('salle:')) {
      text = text.substring(6).trim();
    }
    // Remove "Principal" or "- Principal" or "· Principal"
    text = text.replaceAll(RegExp(r'[-·]?\s*\bPrincipal\b\s*[-·]?', caseSensitive: false), '·');
    // Shorten "Xème étage" or "Xer étage" to "Xème" / "Xer"
    text = text.replaceAllMapped(
      RegExp(r'(\d+(?:ème|er))\s+étage', caseSensitive: false),
      (match) => match.group(1)!,
    );
    // Clean double separators like "· ·" or "- ·"
    text = text.replaceAll(RegExp(r'\s*[-·]\s*[-·]\s*'), ' · ');
    text = text.replaceAll(RegExp(r'^\s*[-·]\s*|\s*[-·]\s*$'), '');
    return text.trim();
  }

  String _getSubjectDisplay(TimetableSlotModel slot) {
    if (slot.subjectName != null && slot.subjectName!.trim().isNotEmpty) {
      final name = slot.subjectName!.trim();
      if (name.length <= 14) return name.toUpperCase();
    }
    if (slot.subjectCode != null && slot.subjectCode!.trim().isNotEmpty) {
      return slot.subjectCode!.trim().toUpperCase();
    }
    return (slot.subjectName ?? '').toUpperCase();
  }

  Widget _buildSlotCell(TimetableSlotModel slot, double height, double width) {
    final color = _getSubjectColor(slot.subjectCode ?? slot.subjectName ?? 'DEFAULT');
    final timeRange = '${_formatTime(slot.startTime)}–${_formatTime(slot.endTime)}';
    final roomText = _cleanRoomName(slot.room);
    final subjectText = _getSubjectDisplay(slot);
    final teacherText = slot.teacherName?.trim();

    return Directionality(
      textDirection: TextDirection.ltr,
      child: BouncingWrapper(
        shrinkScale: 0.90,
        overshootScale: 1.055,
        onTap: () {
          _showSlotDetails(context, slot, color, timeRange);
        },
      child: Container(
        margin: const EdgeInsets.all(2.5),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRect(
          child: RotatedBox(
            quarterTurns: 3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 1. Subject Name (FIRST / TOP)
                  Text(
                    subjectText,
                    style: const TextStyle(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                  ),
                  // 2. Room Name (SECOND)
                  if (roomText.isNotEmpty) ...[
                    const SizedBox(height: 1.5),
                    Text(
                      roomText,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                      maxLines: 1,
                    ),
                  ],
                  // 3. Teacher Name (THIRD, if present)
                  if (teacherText != null && teacherText.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      teacherText,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                    ),
                  ],
                  // 4. Time Range (FOURTH / BOTTOM)
                  const SizedBox(height: 1.5),
                  Text(
                    timeRange,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }

  void _showSlotDetails(BuildContext context, TimetableSlotModel slot, Color color, String timeRange) {
    final l10n = AppLocalizations.of(context);
    final fullName = (slot.subjectName != null && slot.subjectName!.trim().isNotEmpty)
        ? slot.subjectName!.trim()
        : (slot.subjectCode ?? 'Matière');
    final detailLocation = _formatDetailLocation(slot.room);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Center(
          child: Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      fullName,
                      style: ArabicTypography.headerStyle(
                        dialogContext,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time_filled, size: 20, color: Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      Text(
                        timeRange,
                        style: ArabicTypography.bodyStyle(
                          dialogContext,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  if (detailLocation.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.location_on_rounded, size: 18, color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            detailLocation,
                            style: ArabicTypography.bodyStyle(
                              dialogContext,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1F2937),
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 16),
                  Text(
                    l10n.translate('teacher'),
                    style: ArabicTypography.subtitleStyle(
                      dialogContext,
                      fontSize: 14,
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.grey.shade100,
                        backgroundImage: slot.teacherPhotoUrl != null
                            ? NetworkImage(slot.teacherPhotoUrl!)
                            : null,
                        child: slot.teacherPhotoUrl == null
                            ? const Icon(Icons.person, color: Color(0xFF9CA3AF))
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        slot.teacherName ?? l10n.translate('not_assigned'),
                        style: ArabicTypography.bodyStyle(
                          dialogContext,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        l10n.closeLabel,
                        style: (Localizations.localeOf(dialogContext).languageCode == 'ar'
                            ? GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)
                            : const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8 * animation.value,
            sigmaY: 8 * animation.value,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  String _formatTime(String time) {
    final parts = time.split(':');
    return '${parts[0]}:${parts[1]}';
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  bool _isCurrentTimeInRange() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _timeToMinutes(_timeSlots.first);
    final endMinutes = _timeToMinutes(_timeSlots.last) + 60; // Add 1 hour for the last slot
    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  double _getCurrentTimePosition(double rowHeight) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final startMinutes = _timeToMinutes(_timeSlots.first);
    return ((currentMinutes - startMinutes) / 60) * rowHeight;
  }

  bool _isCurrentHour(int slotIndex) {
    final now = DateTime.now();
    final currentHour = now.hour;
    final slotHour = _timeToMinutes(_timeSlots[slotIndex]) ~/ 60;
    return currentHour == slotHour;
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required bool isExam,
    bool isFuture = false,
    DateTime? startDate,
  }) {
    final l10n = AppLocalizations.of(context);
    final String title;
    final String subtitle;
    if (isFuture) {
      final lang = Localizations.localeOf(context).languageCode;
      final formattedDate = startDate != null
          ? ArabicTypography.toLatinDigits(DateFormat('d MMMM yyyy', lang).format(startDate))
          : null;
      title = l10n.upcomingSemester;
      subtitle = formattedDate != null
          ? l10n.translate('timetable_available_from', {'date': formattedDate})
          : l10n.translate('timetable_available_start');
    } else if (isExam) {
      title = l10n.noExamsScheduled;
      subtitle = l10n.noExamsDesc;
    } else {
      title = l10n.timetableNotAvailable;
      subtitle = l10n.timetableNotAvailableDesc;
    }

    return Align(
      alignment: const Alignment(0, -0.45),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isFuture
                        ? const [Color(0xFFFF2B6D), Color(0xFFE11D48)]
                        : isExam
                            ? const [Color(0xFFEA580C), Color(0xFFF97316)]
                            : const [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isFuture
                              ? const Color(0xFFFF2B6D)
                              : isExam
                                  ? const Color(0xFFEA580C)
                                  : const Color(0xFF10B981))
                          .withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  isFuture
                      ? Icons.calendar_month_rounded
                      : isExam
                          ? Icons.school_rounded
                          : Icons.calendar_today_rounded,
                  size: 34,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: ArabicTypography.headerStyle(
                  context,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2937),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: ArabicTypography.bodyStyle(
                  context,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
