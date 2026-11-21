/// Student Context Provider - Uses CoreDataService canonical queries
/// 
/// This provider manages student context state (user, enrollment, class, etc.)
/// and semesters. All portal screens should use this as the source of truth.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/connectivity_service.dart';
import '../../data/services/core_data_service.dart';
import '../../data/services/offline_cache_service.dart';
import 'auth_provider.dart';

// ============================================================
// CORE DATA SERVICE PROVIDER
// ============================================================

final coreDataServiceProvider = Provider<CoreDataService>((ref) {
  return CoreDataService.instance;
});

// ============================================================
// STUDENT CONTEXT PROVIDER
// ============================================================

final studentContextProvider = FutureProvider<StudentContext?>((ref) async {
  final authState = ref.watch(authProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id 
      ?? authState.user?.id 
      ?? OfflineCacheService.instance.getMap('cached_user')?['id'] as String?;
  if (userId == null) return null;

  StudentContext? getCachedStudentContext() {
    final cached = OfflineCacheService.instance.getMap('student_context_$userId')
        ?? OfflineCacheService.instance.getMap('cached_student_context');
    if (cached != null) {
      return StudentContext.fromJson(cached);
    }

    // Synthesize from cached_user and cached_enrollment if direct context wasn't saved
    final cachedUser = OfflineCacheService.instance.getMap('cached_user');
    final cachedEnrollment = OfflineCacheService.instance.getMap('cached_enrollment');
    if (cachedUser != null) {
      final classMap = cachedEnrollment?['class'] as Map?;
      final niveauMap = classMap?['niveaux'] as Map? ?? cachedEnrollment?['niveau'] as Map?;
      return StudentContext(
        userId: userId,
        schoolId: cachedUser['school_id']?.toString() ?? '',
        fullName: cachedUser['full_name']?.toString(),
        email: cachedUser['email']?.toString(),
        studentCode: cachedUser['student_code']?.toString() ?? cachedEnrollment?['student_code']?.toString(),
        enrollmentId: cachedEnrollment?['id']?.toString(),
        classId: cachedEnrollment?['class_id']?.toString() ?? classMap?['id']?.toString(),
        groupId: cachedEnrollment?['group_id']?.toString(),
        academicYearId: cachedEnrollment?['academic_year_id']?.toString(),
        className: classMap?['name']?.toString(),
        niveauId: classMap?['niveau_id']?.toString() ?? niveauMap?['id']?.toString(),
        niveauCode: niveauMap?['code']?.toString(),
        niveauName: niveauMap?['name']?.toString(),
        cycle: niveauMap?['cycle']?.toString(),
      );
    }
    return null;
  }

  // Fast offline return
  if (ConnectivityService.instance.isOffline) {
    final cached = getCachedStudentContext();
    if (cached != null) return cached;
  }
  
  final service = ref.watch(coreDataServiceProvider);
  try {
    final ctx = await service.getStudentContext(userId).timeout(const Duration(seconds: 4));
    if (ctx != null) return ctx;
  } catch (e) {
    ConnectivityService.instance.reportNetworkError(e);
  }

  return getCachedStudentContext();
});

// ============================================================
// SEMESTERS PROVIDER (Dynamic from DB with auto-refresh)
// ============================================================


/// Deduplicate semesters by period number (preferring the active one) and sort ascending.
/// Never injects synthetic periods or periods from other years.
List<SemesterInfo> normalizeSemesterList(List<SemesterInfo> raw) {
  final byNumber = <int, SemesterInfo>{};
  for (final s in raw) {
    final existing = byNumber[s.number];
    if (existing == null || (!existing.isCurrent && s.isCurrent)) {
      byNumber[s.number] = s;
    }
  }
  final result = byNumber.values.toList()
    ..sort((a, b) => a.number.compareTo(b.number));
  final totalCount = result.length;
  return result
      .map((s) => s.copyWith(
            name: SemesterInfo.formatDynamicPeriodName(
              s.name,
              totalCount,
              s.number,
            ),
          ))
      .toList();
}

/// Resolve the active semester number matching admin_dashboard semantics:
/// 1) explicit isCurrent flag, 2) date range containing today, 3) first available period.
int resolveCurrentSemesterNumber(
  List<SemesterInfo> semesters, {
  DateTime? now,
}) {
  if (semesters.isEmpty) return 1;
  final sorted = normalizeSemesterList(semesters);
  final flagged = sorted.where((s) => s.isCurrent).firstOrNull;
  if (flagged != null) return flagged.number;

  final refNow = now ?? DateTime.now();
  final today = DateTime(refNow.year, refNow.month, refNow.day);
  final byDate = sorted.where((s) {
    if (s.startDate == null || s.endDate == null) return false;
    final start = DateTime(s.startDate!.year, s.startDate!.month, s.startDate!.day);
    final end = DateTime(s.endDate!.year, s.endDate!.month, s.endDate!.day);
    return !today.isBefore(start) && !today.isAfter(end);
  }).firstOrNull;
  if (byDate != null) return byDate.number;

  return sorted.first.number;
}

/// Prefer the school's active (`is_current = true`) academic year over a potentially
/// stale enrollment academic year so admin period changes always appear in the app.
List<String> prioritizeAcademicYearIds({
  String? activeCurrentYearId,
  String? enrolledYearId,
}) {
  final ordered = <String>[];
  void addIfValid(String? id) {
    final trimmed = id?.trim();
    if (trimmed != null && trimmed.isNotEmpty && !ordered.contains(trimmed)) {
      ordered.add(trimmed);
    }
  }

  addIfValid(activeCurrentYearId);
  addIfValid(enrolledYearId);
  return ordered;
}

final semestersProvider = FutureProvider<List<SemesterInfo>>((ref) async {
  final context = await ref.watch(studentContextProvider.future);
  final authState = ref.watch(authProvider);
  final supabase = Supabase.instance.client;

  final schoolId = context?.schoolId ?? authState.user?.schoolId;
  final enrolledYearId =
      context?.academicYearId ?? authState.enrollment?.academicYearId;

  List<SemesterInfo>? getCachedSemesters() {
    final candidateYearIds = prioritizeAcademicYearIds(
      activeCurrentYearId: null,
      enrolledYearId: enrolledYearId,
    );
    final cacheKeys = <String>[
      if (schoolId != null && schoolId.isNotEmpty) 'semesters_school_$schoolId',
      for (final yearId in candidateYearIds) 'semesters_$yearId',
      'semesters_latest',
    ];
    for (final key in cacheKeys) {
      final cached = OfflineCacheService.instance.getListOfMaps(key);
      if (cached != null && cached.isNotEmpty) {
        return normalizeSemesterList(
          cached.map((e) => SemesterInfo.fromJson(e)).toList(),
        );
      }
    }
    return null;
  }

  // 0. Fast return when offline
  if (ConnectivityService.instance.isOffline) {
    final cached = getCachedSemesters();
    if (cached != null && cached.isNotEmpty) return cached;
  }

  // Listen for live period/year edits in Supabase if Realtime is enabled on the project.
  RealtimeChannel? channel;
  try {
    final filter = (schoolId != null && schoolId.isNotEmpty)
        ? PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'school_id',
            value: schoolId,
          )
        : null;
    channel = supabase
        .channel('student_semesters_${schoolId ?? 'global'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'semesters',
          filter: filter,
          callback: (_) => ref.invalidateSelf(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'academic_years',
          filter: filter,
          callback: (_) => ref.invalidateSelf(),
        )
        .subscribe();
    ref.onDispose(() {
      if (channel != null) {
        try {
          supabase.removeChannel(channel);
        } catch (_) {}
      }
    });
  } catch (_) {}

  // 1. Always resolve the school's active (`is_current = true`) academic year FIRST,
  // because admin_dashboard Period Management always operates on the active school year.
  String? activeYearId;
  try {
    var query = supabase
        .from('academic_years')
        .select('id')
        .eq('is_current', true);
    if (schoolId != null && schoolId.isNotEmpty) {
      query = query.eq('school_id', schoolId);
    }
    final activeYearResp = await query
        .order('start_date', ascending: false)
        .limit(1)
        .maybeSingle()
        .timeout(const Duration(seconds: 4));
    activeYearId = activeYearResp?['id'] as String?;
  } catch (e) {
    ConnectivityService.instance.reportNetworkError(e);
  }

  final candidateYearIds = prioritizeAcademicYearIds(
    activeCurrentYearId: activeYearId,
    enrolledYearId: enrolledYearId,
  );

  // 2. Fetch semesters strictly for the resolved academic year (never merge across years).
  for (final yearId in candidateYearIds) {
    try {
      final response = await supabase
          .from('semesters')
          .select(
            'id, school_id, academic_year_id, name, number, start_date, end_date, is_current',
          )
          .eq('academic_year_id', yearId)
          .order('number')
          .timeout(const Duration(seconds: 4));
      final rows = List<Map<String, dynamic>>.from(response as List);
      final parsed = normalizeSemesterList(
        rows.map((e) => SemesterInfo.fromJson(e)).toList(),
      );
      if (parsed.isNotEmpty) {
        final cachePayload = parsed.map((s) => s.toJson()).toList();
        if (schoolId != null && schoolId.isNotEmpty) {
          OfflineCacheService.instance
              .setJson('semesters_school_$schoolId', cachePayload);
        }
        OfflineCacheService.instance.setJson('semesters_$yearId', cachePayload);
        OfflineCacheService.instance.setJson('semesters_latest', cachePayload);
        ConnectivityService.instance.reportNetworkSuccess();
        return parsed;
      }
    } catch (e) {
      ConnectivityService.instance.reportNetworkError(e);
    }
  }

  // 3. Offline/network-failure fallback: restore last known semesters from persistent cache.
  final cached = getCachedSemesters();
  if (cached != null && cached.isNotEmpty) {
    return cached;
  }

  // 4. Last resort fallback when the school has zero periods configured anywhere yet.
  return [
    SemesterInfo(id: '1', name: 'Semestre 1', number: 1, isCurrent: true),
    SemesterInfo(id: '2', name: 'Semestre 2', number: 2, isCurrent: false),
    SemesterInfo(id: '3', name: 'Semestre 3', number: 3, isCurrent: false),
  ];
});

// Selected semester state (by number, not hardcoded)
final selectedSemesterNumberProvider = StateProvider<int>((ref) => 1);

// Selected semester info (resolved from semesters list without side-effects)
final selectedSemesterProvider = Provider<SemesterInfo?>((ref) {
  final semesters = ref.watch(semestersProvider).valueOrNull ?? [];
  final selectedNumber = ref.watch(selectedSemesterNumberProvider);
  
  if (semesters.isEmpty) return null;

  final matched = semesters.where((s) => s.number == selectedNumber).firstOrNull;
  if (matched != null) return matched;

  return semesters.where((s) => s.isCurrent).firstOrNull ??
         semesters.where((s) => s.number == 1).firstOrNull ??
         semesters.first;
});

// ============================================================
// CURRICULUM PROVIDER
// ============================================================

final curriculumProvider = FutureProvider<List<CurriculumEntry>>((ref) async {
  final context = await ref.watch(studentContextProvider.future);
  if (context == null || context.niveauId == null) return [];
  
  final service = ref.watch(coreDataServiceProvider);
  return service.getCurriculumForNiveauSection(
    schoolId: context.schoolId,
    niveauId: context.niveauId!,
    sectionId: context.sectionId,
  );
});

// ============================================================
// TIMETABLE PROVIDER
// ============================================================

final timetableProvider = FutureProvider<List<TimetableSlotInfo>>((ref) async {
  final context = await ref.watch(studentContextProvider.future);
  final semester = ref.watch(selectedSemesterProvider);
  
  if (context == null || semester == null) return [];
  
  final service = ref.watch(coreDataServiceProvider);
  return service.getTimetableForStudentSemester(
    userId: context.userId,
    semesterId: semester.id,
  );
});

// ============================================================
// ABSENCES PROVIDER
// ============================================================

final absencesDataProvider = FutureProvider<List<AbsenceSummary>>((ref) async {
  final context = await ref.watch(studentContextProvider.future);
  final semester = ref.watch(selectedSemesterProvider);
  
  if (context == null || semester == null) return [];
  
  final service = ref.watch(coreDataServiceProvider);
  return service.getAbsencesForStudentSemester(
    userId: context.userId,
    semesterId: semester.id,
  );
});

// ============================================================
// RESULTS/GRADES PROVIDER
// ============================================================

final resultsDataProvider = FutureProvider<SemesterResults>((ref) async {
  final context = await ref.watch(studentContextProvider.future);
  final semester = ref.watch(selectedSemesterProvider);
  
  if (context == null || semester == null) {
    return SemesterResults(subjects: [], totalCoefficient: 0);
  }
  
  final service = ref.watch(coreDataServiceProvider);
  return service.getResultsForStudentSemester(
    userId: context.userId,
    semesterId: semester.id,
  );
});

// ============================================================
// PAYMENTS PROVIDER
// ============================================================

final paymentsDataProvider = FutureProvider<List<PaymentPlanInfo>>((ref) async {
  final authState = ref.watch(authProvider);
  final context = await ref.watch(studentContextProvider.future);
  final userId = context?.userId 
      ?? authState.user?.id 
      ?? OfflineCacheService.instance.getMap('cached_user')?['id'] as String?;
  if (userId == null) return [];

  List<PaymentPlanInfo>? getCachedPayments() {
    final cached = OfflineCacheService.instance.getListOfMaps('payments_$userId')
        ?? OfflineCacheService.instance.getListOfMaps('payments_latest');
    if (cached != null && cached.isNotEmpty) {
      return cached.map((e) => PaymentPlanInfo.fromJson(e)).toList();
    }
    return null;
  }

  if (ConnectivityService.instance.isOffline) {
    final cached = getCachedPayments();
    if (cached != null) return cached;
  }
  
  final service = ref.watch(coreDataServiceProvider);
  try {
    final list = await service.getPaymentsForStudent(userId);
    if (list.isNotEmpty) return list;
  } catch (e) {
    ConnectivityService.instance.reportNetworkError(e);
  }

  return getCachedPayments() ?? [];
});

// ============================================================
// HELPER EXTENSIONS
// ============================================================

extension StudentContextX on StudentContext {
  String get displayName => fullName ?? email ?? 'Étudiant';
  String get classDisplay => className ?? 'Classe inconnue';
  String get niveauDisplay => niveauCode ?? niveauName ?? '';
  String get sectionDisplay => sectionCode ?? sectionName ?? '';
  
  String get fullClassDisplay {
    if (sectionCode != null) {
      return '$className ($niveauCode - $sectionCode)';
    }
    return '$className ($niveauCode)';
  }
}

extension SemesterInfoX on SemesterInfo {
  bool get isCurrentByDate {
    final now = DateTime.now();
    if (startDate != null && endDate != null) {
      return now.isAfter(startDate!) && now.isBefore(endDate!);
    }
    return false;
  }
}
