import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/grade_model.dart';
import '../services/offline_cache_service.dart';
import '../../core/services/connectivity_service.dart';

/// Repository for student results/grades
class StudentResultsRepository {
  final SupabaseClient _client;

  StudentResultsRepository(this._client);

  /// Get current student's enrollment info
  Future<Map<String, dynamic>?> getCurrentEnrollment() async {
    final userId = _client.auth.currentUser?.id;
    const cacheKey = 'cached_results_enrollment';

    if (ConnectivityService.instance.isOffline || userId == null) {
      final cached = OfflineCacheService.instance.getMap(cacheKey)
          ?? OfflineCacheService.instance.getMap('cached_enrollment');
      if (cached != null) return cached;
      if (userId == null) return null;
    }

    try {
      final response = await _client
          .from('enrollments')
          .select('''
            id,
            student_code,
            is_active,
            academic_year_id,
            class_id,
            group_id,
            academic_years (
              id,
              name,
              is_current
            ),
            classes (
              id,
              name,
              niveau_id,
              section_id,
              niveaux (
                id,
                name,
                code
              ),
              sections (
                id,
                name,
                code
              )
            )
          ''')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (response != null) {
        await OfflineCacheService.instance.setJson(cacheKey, response);
        ConnectivityService.instance.reportNetworkSuccess();
        return response;
      }
    } catch (e) {
      ConnectivityService.instance.reportNetworkError(e);
      // Fallback with simpler query
      try {
        final response = await _client
            .from('enrollments')
            .select('*, academic_years(*), classes(*)')
            .eq('user_id', userId)
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
        if (response != null) {
          await OfflineCacheService.instance.setJson(cacheKey, response);
          ConnectivityService.instance.reportNetworkSuccess();
          return response;
        }
      } catch (e2) {
        ConnectivityService.instance.reportNetworkError(e2);
      }
    }

    // Offline / error fallback
    final cached = OfflineCacheService.instance.getMap(cacheKey)
        ?? OfflineCacheService.instance.getMap('cached_enrollment');
    if (cached != null) return cached;
    return null;
  }

  /// Get semesters for the current academic year
  Future<List<Map<String, dynamic>>> getSemesters(String academicYearId) async {
    final cacheKey = 'cached_semesters_$academicYearId';
    try {
      final response = await _client
          .from('semesters')
          .select()
          .eq('academic_year_id', academicYearId)
          .order('number');
      final list = List<Map<String, dynamic>>.from(response);
      await OfflineCacheService.instance.setJson(cacheKey, list);
      ConnectivityService.instance.reportNetworkSuccess();
      return list;
    } catch (e) {
      ConnectivityService.instance.reportNetworkError(e);
      final cached = OfflineCacheService.instance.getListOfMaps(cacheKey);
      if (cached != null) return cached;
      return [];
    }
  }

  /// Get student's grades for a semester
  Future<List<SubjectGradesSummary>> getStudentGrades({
    required String enrollmentId,
    required String semesterId,
    int? semesterNumber,
  }) async {
    final cacheKey = 'cached_grades_${enrollmentId}_$semesterId';

    List<SubjectGradesSummary>? getCachedGrades() {
      final cached = OfflineCacheService.instance.getListOfMaps(cacheKey)
          ?? (semesterNumber != null ? OfflineCacheService.instance.getListOfMaps('cached_grades_sem_$semesterNumber') : null)
          ?? OfflineCacheService.instance.getListOfMaps('cached_grades_latest');
      if (cached != null && cached.isNotEmpty) {
        try {
          return cached.map((m) => SubjectGradesSummary.fromJson(m)).toList();
        } catch (_) {}
      }
      return null;
    }

    if (ConnectivityService.instance.isOffline) {
      final cachedList = getCachedGrades();
      if (cachedList != null && cachedList.isNotEmpty) return cachedList;
    }

    try {
      // Get all subject assignments for the student's grade level and section
      final enrollment = await _client
        .from('enrollments')
        .select('''
          class_id,
          classes (
            niveau_id,
            section_id
          )
        ''')
        .eq('id', enrollmentId)
        .single()
        .timeout(const Duration(seconds: 4));

    final classData = enrollment['classes'] as Map<String, dynamic>?;
    final gradeLevelId = classData?['niveau_id'] ?? classData?['grade_level_id'];
    final sectionId = classData?['section_id'];

    // 1. Resolve all semester IDs matching this semester number to support multi-year / migrated schemas
    final Set<String> targetSemesterIds = {semesterId};
    try {
      final semRow = await _client
          .from('semesters')
          .select('number, school_id')
          .eq('id', semesterId)
          .maybeSingle();
      final semNumber = semRow?['number'] as int?;
      if (semNumber != null) {
        final matchingRows = await _client
            .from('semesters')
            .select('id')
            .eq('number', semNumber);
        for (final r in (matchingRows as List)) {
          final id = r['id']?.toString();
          if (id != null && id.isNotEmpty) {
            targetSemesterIds.add(id);
          }
        }
      }
    } catch (_) {}

    // 2. Get all grades for this enrollment first so we know which offerings have grades
    final grades = await _client
        .from('grades')
        .select('''
          id,
          subject_offering_id,
          component_id,
          grade_value,
          status
        ''')
        .eq('enrollment_id', enrollmentId);

    final Set<String> gradedOfferingIds = (grades as List)
        .map((g) => g['subject_offering_id']?.toString())
        .whereType<String>()
        .toSet();

    // 3. Get subject offerings for matching semester(s)
    var offeringsQuery = _client
        .from('subject_offerings')
        .select('''
          id,
          coefficient,
          subject_id,
          semester_id,
          subjects!inner (
            id,
            name,
            code
          ),
          grade_components (
            id,
            name,
            weight_percent
          )
        ''')
        .eq('class_id', enrollment['class_id']);

    final dynamic rawOfferingsResponse;
    if (targetSemesterIds.length == 1) {
      rawOfferingsResponse = await offeringsQuery.eq('semester_id', targetSemesterIds.first);
    } else {
      rawOfferingsResponse = await offeringsQuery.filter('semester_id', 'in', targetSemesterIds.toList());
    }

    final List<dynamic> rawOfferings = (rawOfferingsResponse as List?) ?? [];

    // Group offerings by normalized subject name / ID, and pick the best offering (preferring ones with grades)
    final Map<String, dynamic> chosenOfferingsMap = {};
    for (final offering in rawOfferings) {
      final subject = offering['subjects'] as Map<String, dynamic>?;
      final subName = (subject?['name']?.toString() ?? offering['subject_id']?.toString() ?? '').trim().toLowerCase();
      if (subName.isEmpty) continue;

      final existing = chosenOfferingsMap[subName];
      if (existing == null) {
        chosenOfferingsMap[subName] = offering;
      } else {
        // Compare how many grades each offering has
        final existingId = existing['id']?.toString();
        final currentId = offering['id']?.toString();
        final existingHasGrade = existingId != null && gradedOfferingIds.contains(existingId);
        final currentHasGrade = currentId != null && gradedOfferingIds.contains(currentId);

        if (!existingHasGrade && currentHasGrade) {
          chosenOfferingsMap[subName] = offering;
        } else if (existingHasGrade && currentHasGrade) {
          // Both have grades, pick the one with higher coefficient or more components
          final existingCoeff = (existing['coefficient'] as num?)?.toDouble() ?? 1.0;
          final currentCoeff = (offering['coefficient'] as num?)?.toDouble() ?? 1.0;
          if (currentCoeff > existingCoeff) {
            chosenOfferingsMap[subName] = offering;
          }
        }
      }
    }

    final List<dynamic> offerings = chosenOfferingsMap.values.toList();

    // Fetch teacher assignments for this class
    final Map<String, Map<String, String>> teacherMap = {};
    try {
      final teacherResp = await _client
          .from('teacher_assignments')
          .select('subject_id, teacher_id, users!teacher_id(full_name, photo_url)')
          .eq('class_id', enrollment['class_id'])
          .eq('is_active', true);
      
      for (final ta in (teacherResp as List)) {
        final subjectId = ta['subject_id'] as String?;
        final teacherData = ta['users'] as Map<String, dynamic>?;
        if (subjectId != null) {
          teacherMap[subjectId] = {
            'name': teacherData?['full_name'] as String? ?? '',
            'photo': teacherData?['photo_url'] as String? ?? '',
          };
        }
      }
    } catch (_) {}

    // Build grade summaries
    final List<SubjectGradesSummary> summaries = [];

    for (final offering in offerings) {
      final subject = offering['subjects'] as Map<String, dynamic>;
      final components = (offering['grade_components'] as List?) ?? [];
      final coefficient = (offering['coefficient'] as num?)?.toDouble() ?? 1.0;

      // Build component grades
      final List<ComponentGrade> componentGrades = [];
      double totalWeighted = 0;
      double totalWeight = 0;
      bool allGraded = true;

      for (final comp in components) {
        final grade = grades.firstWhere(
          (g) =>
              g['subject_offering_id'] == offering['id'] &&
              g['component_id'] == comp['id'],
          orElse: () => <String, dynamic>{},
        );

        final gradeValue = (grade['grade_value'] as num?)?.toDouble();
        final weightPercent = (comp['weight_percent'] as num?)?.toDouble() ?? 0;
        final status = grade['status']?.toString() ?? 'ND';

        componentGrades.add(
          ComponentGrade(
            componentId: comp['id'],
            componentName: comp['name'],
            weightPercent: weightPercent,
            grade: gradeValue,
            status: status,
          ),
        );

        if (gradeValue != null) {
          totalWeighted += gradeValue * weightPercent;
          totalWeight += weightPercent;
        } else {
          allGraded = false;
        }
      }

      // Calculate average
      double? average;
      if (allGraded && totalWeight > 0) {
        average = totalWeighted / totalWeight;
      }

      // Build weights display
      final weightsDisplay = componentGrades
          .map(
            (c) =>
                '${c.componentName.substring(0, 2).toUpperCase()}: ${c.weightPercent.toStringAsFixed(0)}%',
          )
          .join(' | ');

      final subjectId = offering['subject_id'] as String?;
      final teacher = subjectId != null ? teacherMap[subjectId] : null;

      summaries.add(
        SubjectGradesSummary(
          subjectOfferingId: offering['id'],
          subjectName: subject['name'],
          subjectCode: subject['code'],
          coefficient: coefficient,
          weightsDisplay: weightsDisplay,
          components: componentGrades,
          average: average,
          teacherName: teacher?['name'],
          teacherPhotoUrl: teacher?['photo'],
        ),
      );
    }

    // If no offerings found, try using subject_assignments
    final result = summaries.isNotEmpty
        ? summaries
        : await _getGradesFromAssignments(
            enrollmentId: enrollmentId,
            gradeLevelId: gradeLevelId,
            sectionId: sectionId,
            semesterId: semesterId,
          );

    if (result.isNotEmpty) {
      await OfflineCacheService.instance.setJson(
        cacheKey,
        result.map((s) => s.toJson()).toList(),
      );
      if (semesterNumber != null) {
        await OfflineCacheService.instance.setJson(
          'cached_grades_sem_$semesterNumber',
          result.map((s) => s.toJson()).toList(),
        );
      }
      await OfflineCacheService.instance.setJson(
        'cached_grades_latest',
        result.map((s) => s.toJson()).toList(),
      );
    }
    ConnectivityService.instance.reportNetworkSuccess();
    return result;
  } catch (e) {
    debugPrint('getStudentGrades error: $e');
    ConnectivityService.instance.reportNetworkError(e);
    final cachedList = getCachedGrades();
    if (cachedList != null) return cachedList;
    return [];
  }
}

  /// Fallback method using subject_assignments table
  Future<List<SubjectGradesSummary>> _getGradesFromAssignments({
    required String enrollmentId,
    required String gradeLevelId,
    String? sectionId,
    required String semesterId,
  }) async {
    // Get subject assignments for this grade level and section
    var query = _client
        .from('subject_assignments')
        .select('''
          id,
          coefficient,
          weekly_hours,
          is_main_subject,
          subject_id,
          subjects!inner (
            id,
            name,
            code
          ),
          subject_exam_config (
            id,
            count_per_semester,
            weight,
            exam_type_id,
            exam_types!inner (
              id,
              name,
              code
            )
          )
        ''')
        .eq('grade_level_id', gradeLevelId)
        .eq('is_active', true);

    if (sectionId != null) {
      query = query.or('section_id.eq.$sectionId,section_id.is.null');
    } else {
      query = query.isFilter('section_id', null);
    }

    final assignments = await query;

    final List<SubjectGradesSummary> summaries = [];

    for (final assignment in assignments) {
      final subject = assignment['subjects'] as Map<String, dynamic>;
      final examConfigs = (assignment['subject_exam_config'] as List?) ?? [];
      final coefficient =
          (assignment['coefficient'] as num?)?.toDouble() ?? 1.0;

      // Build component grades from exam configs
      final List<ComponentGrade> componentGrades = [];

      for (final config in examConfigs) {
        final examType = config['exam_types'] as Map<String, dynamic>;
        final weight = ((config['weight'] as num?)?.toDouble() ?? 0.25) * 100;

        componentGrades.add(
          ComponentGrade(
            componentId: config['id'],
            componentName: examType['name'],
            weightPercent: weight,
            grade: null, // No grades yet
            status: 'ND',
          ),
        );
      }

      // If no exam configs, add default DC/DS
      if (componentGrades.isEmpty) {
        componentGrades.addAll([
          ComponentGrade(
            componentId: 'dc',
            componentName: 'Devoir de Contrôle',
            weightPercent: 25,
            grade: null,
            status: 'ND',
          ),
          ComponentGrade(
            componentId: 'ds',
            componentName: 'Devoir de Synthèse',
            weightPercent: 75,
            grade: null,
            status: 'ND',
          ),
        ]);
      }

      final weightsDisplay = componentGrades
          .map(
            (c) =>
                '${c.componentName.split(' ').map((w) => w[0]).join()}: ${c.weightPercent.toStringAsFixed(0)}%',
          )
          .join(' | ');

      summaries.add(
        SubjectGradesSummary(
          subjectOfferingId: assignment['id'],
          subjectName: subject['name'],
          subjectCode: subject['code'],
          coefficient: coefficient,
          weightsDisplay: weightsDisplay,
          components: componentGrades,
          average: null,
        ),
      );
    }

    return summaries;
  }

  /// Calculate semester average
  double? calculateSemesterAverage(List<SubjectGradesSummary> grades) {
    double totalWeighted = 0;
    double totalCoeff = 0;

    for (final g in grades) {
      if (g.average != null) {
        totalWeighted += g.average! * g.coefficient;
        totalCoeff += g.coefficient;
      }
    }

    if (totalCoeff > 0) {
      return totalWeighted / totalCoeff;
    }
    return null;
  }

  /// Calculate annual average from semesters (Tunisian formula)
  /// Moyenne = (T1 + T2 + 2*T3) / 4 or (S1 + S2) / 2 for 2 semesters
  double? calculateAnnualAverage({
    double? semester1Average,
    double? semester2Average,
    double? semester3Average,
  }) {
    if (semester3Average != null &&
        semester1Average != null &&
        semester2Average != null) {
      // 3 trimesters formula
      return (semester1Average + semester2Average + 2 * semester3Average) / 4;
    } else if (semester1Average != null && semester2Average != null) {
      // 2 semesters
      return (semester1Average + semester2Average) / 2;
    }
    return null;
  }
}
