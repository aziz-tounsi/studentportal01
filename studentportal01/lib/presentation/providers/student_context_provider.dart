/// Student Context Provider - Uses CoreDataService canonical queries
/// 
/// This provider manages student context state (user, enrollment, class, etc.)
/// and semesters. All portal screens should use this as the source of truth.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/services/core_data_service.dart';

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
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return null;
  
  final service = ref.watch(coreDataServiceProvider);
  return service.getStudentContext(userId);
});

// ============================================================
// SEMESTERS PROVIDER (Dynamic from DB with auto-refresh)
// ============================================================


final semestersProvider = FutureProvider<List<SemesterInfo>>((ref) async {
  final context = await ref.watch(studentContextProvider.future);
  final service = ref.watch(coreDataServiceProvider);
  final supabase = Supabase.instance.client;

  final schoolId = context?.schoolId;
  String? targetYearId = context?.academicYearId;

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
  if (targetYearId != null && targetYearId.isNotEmpty) {
    final semesters =
        await service.getSemestersForAcademicYear(targetYearId);
    if (semesters.isNotEmpty) {
      return semesters;
    }
  }

  // 3. Fallback: Query all semesters for schoolId or generally
  try {
    var semQuery = supabase
        .from('semesters')
        .select('id, name, number, is_current, start_date, end_date');
    if (schoolId != null && schoolId.isNotEmpty) {
      semQuery = semQuery.eq('school_id', schoolId);
    }
    final semestersResp = await semQuery.order('number');
    if ((semestersResp as List).isNotEmpty) {
      return semestersResp
          .map((e) => SemesterInfo.fromJson(e))
          .toList();
    }
  } catch (_) {}

  // 4. Default fallback
  return [
    SemesterInfo(id: '1', name: 'Semestre 1', number: 1, isCurrent: true),
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

  return semesters.where((s) => s.isCurrent).firstOrNull ?? semesters.first;
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
  final context = await ref.watch(studentContextProvider.future);
  if (context == null) return [];
  
  final service = ref.watch(coreDataServiceProvider);
  return service.getPaymentsForStudent(context.userId);
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
  bool get isCurrent {
    final now = DateTime.now();
    if (startDate != null && endDate != null) {
      return now.isAfter(startDate!) && now.isBefore(endDate!);
    }
    return false;
  }
}
