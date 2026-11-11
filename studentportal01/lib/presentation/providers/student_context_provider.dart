/// Student Context Provider - Uses CoreDataService canonical queries
/// 
/// This provider manages student context state (user, enrollment, class, etc.)
/// and semesters. All portal screens should use this as the source of truth.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  
  final service = ref.watch(coreDataServiceProvider);
  final ctx = await service.getStudentContext(userId);
  if (ctx != null) return ctx;

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
});

// ============================================================
// SEMESTERS PROVIDER (Dynamic from DB with auto-refresh)
// ============================================================


final semestersProvider = FutureProvider<List<SemesterInfo>>((ref) async {
  final context = await ref.watch(studentContextProvider.future);
  final authState = ref.watch(authProvider);
  final service = ref.watch(coreDataServiceProvider);
  final supabase = Supabase.instance.client;

  final schoolId = context?.schoolId ?? authState.user?.schoolId;
  String? targetYearId = context?.academicYearId ?? authState.enrollment?.academicYearId;

  // 1. Fallback to active academic_year only if student has no enrolled academicYearId
  if (targetYearId == null || targetYearId.isEmpty) {
    try {
      var query = supabase
          .from('academic_years')
          .select('id')
          .eq('is_current', true);
      if (schoolId != null && schoolId.isNotEmpty) {
        query = query.eq('school_id', schoolId);
      }
      final activeYearResp = await query.order('start_date', ascending: false).limit(1).maybeSingle();
      if (activeYearResp != null) {
        targetYearId = activeYearResp['id'] as String?;
      }
    } catch (_) {}
  }

  // 2. Fetch semesters for the target academic year
  List<SemesterInfo> semesters = [];
  if (targetYearId != null && targetYearId.isNotEmpty) {
    semesters = await service.getSemestersForAcademicYear(targetYearId);
  }

  // 3. Ensure all standard semesters (1, 2, 3) are present.
  // If any semester numbers (like 1) are missing from the enrolled year, augment from active academic year or school semesters.
  final existingNumbers = semesters.map((s) => s.number).toSet();
  if (semesters.isEmpty || !existingNumbers.contains(1) || existingNumbers.length < 3) {
    try {
      var activeYearQuery = supabase
          .from('academic_years')
          .select('id')
          .eq('is_current', true);
      if (schoolId != null && schoolId.isNotEmpty) {
        activeYearQuery = activeYearQuery.eq('school_id', schoolId);
      }
      final activeYear = await activeYearQuery.order('start_date', ascending: false).limit(1).maybeSingle();
      if (activeYear != null) {
        final activeSemesters = await service.getSemestersForAcademicYear(activeYear['id'] as String);
        for (final s in activeSemesters) {
          if (!existingNumbers.contains(s.number)) {
            semesters.add(s);
            existingNumbers.add(s.number);
          }
        }
      }
    } catch (_) {}

    // Fallback: Query all semesters for schoolId
    if (!existingNumbers.contains(1) || semesters.isEmpty) {
      try {
        var semQuery = supabase
            .from('semesters')
            .select('id, name, number, is_current, start_date, end_date');
        if (schoolId != null && schoolId.isNotEmpty) {
          semQuery = semQuery.eq('school_id', schoolId);
        }
        final semestersResp = await semQuery.order('number');
        if ((semestersResp as List).isNotEmpty) {
          for (final row in semestersResp) {
            final s = SemesterInfo.fromJson(row);
            if (!existingNumbers.contains(s.number)) {
              semesters.add(s);
              existingNumbers.add(s.number);
            }
          }
        }
      } catch (_) {}
    }
  }

  if (semesters.isNotEmpty) {
    semesters.sort((a, b) => a.number.compareTo(b.number));
    return semesters;
  }

  // 4. Default fallback
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
  
  final service = ref.watch(coreDataServiceProvider);
  return service.getPaymentsForStudent(userId);
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
