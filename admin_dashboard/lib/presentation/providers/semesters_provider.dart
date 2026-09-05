import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/config/supabase_config.dart';

class SemesterModel {
  final String id;
  final String name;
  final int number;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;
  final String? academicYearId;
  final String? academicYearName;

  SemesterModel({
    required this.id,
    required this.name,
    required this.number,
    required this.startDate,
    required this.endDate,
    this.isCurrent = false,
    this.academicYearId,
    this.academicYearName,
  });

  factory SemesterModel.fromJson(Map<String, dynamic> json) => SemesterModel(
    id: json['id'],
    name: json['name'] ?? '',
    number: json['number'] ?? 1,
    startDate: DateTime.parse(json['start_date']),
    endDate: DateTime.parse(json['end_date']),
    isCurrent: json['is_current'] ?? false,
    academicYearId: json['academic_year_id'],
    academicYearName: json['academic_years']?['name'],
  );
}

class AcademicYearModel {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCurrent;

  AcademicYearModel({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.isCurrent = false,
  });

  factory AcademicYearModel.fromJson(Map<String, dynamic> json) =>
      AcademicYearModel(
        id: json['id'],
        name: json['name'] ?? '',
        startDate: DateTime.parse(json['start_date']),
        endDate: DateTime.parse(json['end_date']),
        isCurrent: json['is_current'] ?? false,
      );
  AcademicYearModel copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool? isCurrent,
  }) => AcademicYearModel(
    id: id ?? this.id,
    name: name ?? this.name,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    isCurrent: isCurrent ?? this.isCurrent,
  );
}

class VacationPeriodModel {
  final String id;
  final String schoolId;
  final String academicYearId;
  final String? name;
  final DateTime startDate;
  final DateTime endDate;
  final String type; // 'auto_gap' | 'manual'

  VacationPeriodModel({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    this.name,
    required this.startDate,
    required this.endDate,
    required this.type,
  });

  factory VacationPeriodModel.fromJson(Map<String, dynamic> json) =>
      VacationPeriodModel(
        id: json['id'],
        schoolId: json['school_id'],
        academicYearId: json['academic_year_id'],
        name: json['name'],
        startDate: DateTime.parse(json['start_date']),
        endDate: DateTime.parse(json['end_date']),
        type: json['type'] ?? 'manual',
      );

  VacationPeriodModel copyWith({
    String? id,
    String? schoolId,
    String? academicYearId,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? type,
  }) => VacationPeriodModel(
    id: id ?? this.id,
    schoolId: schoolId ?? this.schoolId,
    academicYearId: academicYearId ?? this.academicYearId,
    name: name ?? this.name,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    type: type ?? this.type,
  );
}

class ExamPeriodModel {
  final String id;
  final String schoolId;
  final String academicYearId;
  final String? name;
  final DateTime startDate;
  final DateTime endDate;

  ExamPeriodModel({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    this.name,
    required this.startDate,
    required this.endDate,
  });

  factory ExamPeriodModel.fromJson(Map<String, dynamic> json) => ExamPeriodModel(
    id: json['id'],
    schoolId: json['school_id'],
    academicYearId: json['academic_year_id'],
    name: json['name'],
    startDate: DateTime.parse(json['start_date']),
    endDate: DateTime.parse(json['end_date']),
  );

  ExamPeriodModel copyWith({
    String? id,
    String? schoolId,
    String? academicYearId,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
  }) => ExamPeriodModel(
    id: id ?? this.id,
    schoolId: schoolId ?? this.schoolId,
    academicYearId: academicYearId ?? this.academicYearId,
    name: name ?? this.name,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
  );
}

class SemestersState {
  final List<SemesterModel> semesters;
  final List<AcademicYearModel> academicYears;
  final List<VacationPeriodModel> vacationPeriods;
  final List<ExamPeriodModel> examPeriods;
  final String? selectedAcademicYearId;

  SemestersState({
    this.semesters = const [],
    this.academicYears = const [],
    this.vacationPeriods = const [],
    this.examPeriods = const [],
    this.selectedAcademicYearId,
  });

  SemesterModel? get current => semesters.where((s) => s.isCurrent).firstOrNull;

  AcademicYearModel? get currentAcademicYear =>
      academicYears.where((y) => y.isCurrent).firstOrNull;

  AcademicYearModel? get selectedAcademicYear => selectedAcademicYearId != null
      ? academicYears.where((y) => y.id == selectedAcademicYearId).firstOrNull
      : currentAcademicYear;

  List<SemesterModel> get filteredSemesters => selectedAcademicYearId != null
      ? semesters
            .where((s) => s.academicYearId == selectedAcademicYearId)
            .toList()
      : semesters;

  List<VacationPeriodModel> filteredVacations(String? yearId) => yearId == null
      ? vacationPeriods
      : vacationPeriods.where((v) => v.academicYearId == yearId).toList();

  List<ExamPeriodModel> filteredExams(String? yearId) => yearId == null
      ? examPeriods
      : examPeriods.where((e) => e.academicYearId == yearId).toList();

  List<ExamPeriodModel> get filteredExamPeriods {
    final yearId = selectedAcademicYearId;
    return yearId == null
        ? examPeriods
        : examPeriods.where((e) => e.academicYearId == yearId).toList();
  }

  bool isDateVacation(DateTime date, {String? yearId}) {
    final candidates = yearId == null
        ? vacationPeriods
        : vacationPeriods.where((v) => v.academicYearId == yearId);
    final d = DateTime(date.year, date.month, date.day);
    for (final v in candidates) {
      if (!d.isBefore(v.startDate) && !d.isAfter(v.endDate)) return true;
    }
    return false;
  }

  /// Period type based on number of periods in the selected academic year.
  /// 2 periods → 'semestre' (6 months each), 3+ → 'trimestre' (3 months each).
  String get periodType {
    final count = filteredSemesters.length;
    return count >= 3 ? 'trimestre' : 'semestre';
  }

  /// Locked period type once periods exist. Null when DB is empty (admin can choose).
  String? get allowedPeriodType {
    if (filteredSemesters.isEmpty) return null;
    return periodType;
  }

  /// Duration in days for the current period type.
  int get periodTypeDuration => periodType == 'trimestre' ? 92 : 183;

  String get periodLabel =>
      periodType == 'trimestre' ? 'Trimestre' : 'Semestre';
  String get periodLabelPlural =>
      periodType == 'trimestre' ? 'Trimestres' : 'Semestres';

  /// Get the next semester number for the selected academic year
  int get nextSemesterNumber {
    final filtered = filteredSemesters;
    if (filtered.isEmpty) return 1;
    return filtered.map((s) => s.number).reduce((a, b) => a > b ? a : b) + 1;
  }

  /// Generate auto name for next period
  String get nextSemesterName => '$periodLabel $nextSemesterNumber';

  /// Check if a date range overlaps with any existing period.
  String? validateOverlap(DateTime start, DateTime end, {String? excludeId}) {
    for (final s in filteredSemesters) {
      if (excludeId != null && s.id == excludeId) continue;
      // Two ranges overlap if one starts before the other ends AND vice versa
      if (!start.isAfter(s.endDate) && !end.isBefore(s.startDate)) {
        return 'Chevauche avec ${s.name} (du ${DateFormat('dd/MM/yyyy').format(s.startDate)} au ${DateFormat('dd/MM/yyyy').format(s.endDate)})';
      }
    }
    return null;
  }

  /// Get the minimum start date for new semester (must be after previous semester ends)
  DateTime? get minStartDateForNewSemester {
    final filtered = filteredSemesters;
    if (filtered.isEmpty) return null;
    // Sort by end date descending
    final sorted = [...filtered]
      ..sort((a, b) => b.endDate.compareTo(a.endDate));
    return sorted.first.endDate.add(const Duration(days: 1));
  }

  SemestersState copyWith({
    List<SemesterModel>? semesters,
    List<AcademicYearModel>? academicYears,
    List<VacationPeriodModel>? vacationPeriods,
    List<ExamPeriodModel>? examPeriods,
    String? selectedAcademicYearId,
  }) => SemestersState(
    semesters: semesters ?? this.semesters,
    academicYears: academicYears ?? this.academicYears,
    vacationPeriods: vacationPeriods ?? this.vacationPeriods,
    examPeriods: examPeriods ?? this.examPeriods,
    selectedAcademicYearId:
        selectedAcademicYearId ?? this.selectedAcademicYearId,
  );
}

class SemestersNotifier extends AsyncNotifier<SemestersState> {
  @override
  Future<SemestersState> build() async => _load();

  Future<SemestersState> _load() async {
    final admin = SupabaseConfig.adminClient;
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');

    final profile = await admin
        .from('users')
        .select('school_id')
        .eq('id', user.id)
        .single();
    final schoolId = profile['school_id'];

    // Auto-detect and refresh current semester based on today's date BEFORE loading
    await _refreshCurrentSemester(schoolId);

    // Load academic years
    var academicYearsData = await admin
        .from('academic_years')
        .select()
        .eq('school_id', schoolId)
        .order('start_date', ascending: false);

    var academicYears = (academicYearsData as List)
        .map((e) => AcademicYearModel.fromJson(e))
        .toList();

    // Ensure a current academic year exists based on today's date
    final currentYear = await _ensureCurrentAcademicYear(
      schoolId,
      academicYears,
    );

    // Reload if we created a new year
    if (!academicYears.any((y) => y.id == currentYear.id)) {
      academicYearsData = await admin
          .from('academic_years')
          .select()
          .eq('school_id', schoolId)
          .order('start_date', ascending: false);
      academicYears = (academicYearsData as List)
          .map((e) => AcademicYearModel.fromJson(e))
          .toList();
    }

    // Load semesters with academic year info (now with correct is_current)
    final data = await admin
        .from('semesters')
        .select('*, academic_years(id, name)')
        .eq('school_id', schoolId)
        .order('start_date', ascending: false);

    final semesters = (data as List)
        .map((e) => SemesterModel.fromJson(e))
        .toList();

    // Load vacation and exam periods for the school
    final vacationsData = await admin
        .from('vacation_periods')
        .select()
        .eq('school_id', schoolId)
        .order('start_date', ascending: false);

    final examsData = await admin
        .from('exam_periods')
        .select()
        .eq('school_id', schoolId)
        .order('start_date', ascending: false);

    final vacationPeriods = (vacationsData as List)
        .map((e) => VacationPeriodModel.fromJson(e))
        .toList();

    final examPeriods = (examsData as List)
        .map((e) => ExamPeriodModel.fromJson(e))
        .toList();

    return SemestersState(
      semesters: semesters,
      academicYears: academicYears,
      vacationPeriods: vacationPeriods,
      examPeriods: examPeriods,
      selectedAcademicYearId: currentYear.id,
    );
  }

  void selectAcademicYear(String? yearId) {
    state.whenData((current) {
      state = AsyncData(current.copyWith(selectedAcademicYearId: yearId));
    });
  }

  Future<void> _refreshCurrentSemester(String schoolId) async {
    final admin = SupabaseConfig.adminClient;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final data = await admin
        .from('semesters')
        .select('id, start_date, end_date')
        .eq('school_id', schoolId)
        .order('start_date', ascending: true);

    String? currentId;
    for (final s in data) {
      final start = DateTime.parse(s['start_date']);
      final end = DateTime.parse(s['end_date']);
      if (!today.isBefore(start) && !today.isAfter(end)) {
        currentId = s['id'];
        break;
      }
    }

    // Clear all, then set only the one containing today (or none).
    await admin
        .from('semesters')
        .update({'is_current': false})
        .eq('school_id', schoolId);
    if (currentId != null) {
      await admin
          .from('semesters')
          .update({'is_current': true})
          .eq('id', currentId);
    }
  }

  /// Return the academic year that contains today. Auto-create it if missing.
  Future<AcademicYearModel> _ensureCurrentAcademicYear(
    String schoolId,
    List<AcademicYearModel> years,
  ) async {
    final admin = SupabaseConfig.adminClient;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Try to find a year that contains today
    var current = years.where((y) {
      return !today.isBefore(y.startDate) && !today.isAfter(y.endDate);
    }).firstOrNull;

    if (current != null) {
      // Ensure only this year is marked current
      await admin
          .from('academic_years')
          .update({'is_current': false})
          .eq('school_id', schoolId);
      await admin
          .from('academic_years')
          .update({'is_current': true})
          .eq('id', current.id);
      return current.copyWith(isCurrent: true);
    }

    // Auto-create the academic year that contains today
    // Academic year runs Sep 1 -> Aug 31
    final startYear = today.month >= 9 ? today.year : today.year - 1;
    final startDate = DateTime(startYear, 9, 1);
    final endDate = DateTime(startYear + 1, 8, 31);
    final name = '$startYear-${startYear + 1}';

    // Clear old current flags
    await admin
        .from('academic_years')
        .update({'is_current': false})
        .eq('school_id', schoolId);

    final result = await admin
        .from('academic_years')
        .insert({
          'school_id': schoolId,
          'name': name,
          'start_date': startDate.toIso8601String().split('T')[0],
          'end_date': endDate.toIso8601String().split('T')[0],
          'is_current': true,
        })
        .select()
        .single();

    return AcademicYearModel.fromJson(result);
  }

  Future<void> createPeriods({
    required String type,
    required List<({DateTime start, DateTime end})> ranges,
    List<({DateTime start, DateTime end})> manualVacations = const [],
    List<({DateTime start, DateTime end})> examPeriods = const [],
  }) async {
    final admin = SupabaseConfig.adminClient;
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');

    final profile = await admin
        .from('users')
        .select('school_id')
        .eq('id', user.id)
        .single();
    final schoolId = profile['school_id'];

    final year = state.asData?.value.currentAcademicYear;
    if (year == null) throw Exception('Aucune année scolaire active');

    // Check if semesters already exist for this academic year
    final existingSemesters = await admin
        .from('semesters')
        .select('id')
        .eq('academic_year_id', year.id)
        .limit(1);

    // Only insert semesters if none exist yet (prevents duplication)
    if ((existingSemesters as List).isEmpty) {
      final label = type == 'trimestre' ? 'Trimestre' : type == 'single' ? 'Période' : 'Semestre';

      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < ranges.length; i++) {
        final range = ranges[i];
        rows.add({
          'name': ranges.length == 1 ? label : '$label ${i + 1}',
          'number': i + 1,
          'school_id': schoolId,
          'academic_year_id': year.id,
          'start_date': range.start.toIso8601String().split('T')[0],
          'end_date': range.end.toIso8601String().split('T')[0],
          'is_current': false,
        });
      }

      await admin.from('semesters').insert(rows);

      // Rebuild auto-gap vacations for this academic year
      await _rebuildAutoGapVacations(schoolId, year.id, ranges);
    }

    // Save manual vacations (delete existing manual ones first to avoid duplicates)
    await admin
        .from('vacation_periods')
        .delete()
        .eq('academic_year_id', year.id)
        .eq('type', 'manual');

    if (manualVacations.isNotEmpty) {
      final vacationRows = manualVacations.map((v) => {
        'school_id': schoolId,
        'academic_year_id': year.id,
        'name': 'Vacances',
        'start_date': v.start.toIso8601String().split('T')[0],
        'end_date': v.end.toIso8601String().split('T')[0],
        'type': 'manual',
      }).toList();
      await admin.from('vacation_periods').insert(vacationRows);
    }

    // Save exam periods (delete existing ones first to avoid duplicates)
    await admin
        .from('exam_periods')
        .delete()
        .eq('academic_year_id', year.id);

    if (examPeriods.isNotEmpty) {
      final examRows = examPeriods.map((e) => {
        'school_id': schoolId,
        'academic_year_id': year.id,
        'name': 'Examen',
        'start_date': e.start.toIso8601String().split('T')[0],
        'end_date': e.end.toIso8601String().split('T')[0],
      }).toList();
      await admin.from('exam_periods').insert(examRows);
    }

    await _refreshCurrentSemester(schoolId);
    ref.invalidateSelf();
  }

  Future<void> _rebuildAutoGapVacations(
    String schoolId,
    String yearId,
    List<({DateTime start, DateTime end})> ranges,
  ) async {
    final admin = SupabaseConfig.adminClient;
    final year = state.asData?.value.academicYears
        .where((y) => y.id == yearId)
        .firstOrNull;
    if (year == null) return;

    // Delete existing auto-gap vacations for this year
    await admin
        .from('vacation_periods')
        .delete()
        .eq('academic_year_id', yearId)
        .eq('type', 'auto_gap');

    if (ranges.isEmpty) return;

    final sorted = [...ranges]
      ..sort((a, b) => a.start.compareTo(b.start));

    final gaps = <({DateTime start, DateTime end})>[];

    // Gap before first range
    if (sorted.first.start.isAfter(year.startDate)) {
      gaps.add((
        start: year.startDate,
        end: sorted.first.start.subtract(const Duration(days: 1)),
      ));
    }

    // Gaps between ranges
    for (var i = 0; i < sorted.length - 1; i++) {
      final nextStart = sorted[i + 1].start;
      final prevEnd = sorted[i].end;
      if (nextStart.isAfter(prevEnd.add(const Duration(days: 1)))) {
        gaps.add((
          start: prevEnd.add(const Duration(days: 1)),
          end: nextStart.subtract(const Duration(days: 1)),
        ));
      }
    }

    // Gap after last range
    if (sorted.last.end.isBefore(year.endDate)) {
      gaps.add((
        start: sorted.last.end.add(const Duration(days: 1)),
        end: year.endDate,
      ));
    }

    if (gaps.isEmpty) return;

    final vacationRows = gaps.map((g) => {
      'school_id': schoolId,
      'academic_year_id': yearId,
      'name': 'Vacances',
      'start_date': g.start.toIso8601String().split('T')[0],
      'end_date': g.end.toIso8601String().split('T')[0],
      'type': 'auto_gap',
    }).toList();

    await admin.from('vacation_periods').insert(vacationRows);
  }

  Future<void> create({
    required String name,
    required int number,
    required DateTime startDate,
    required DateTime endDate,
    required String academicYearId,
  }) async {
    final admin = SupabaseConfig.adminClient;
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');

    final profile = await admin
        .from('users')
        .select('school_id')
        .eq('id', user.id)
        .single();
    final schoolId = profile['school_id'];

    await admin.from('semesters').insert({
      'name': name,
      'number': number,
      'school_id': schoolId,
      'academic_year_id': academicYearId,
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'is_current': false,
    });

    await _refreshCurrentSemester(schoolId);
    ref.invalidateSelf();
  }

  Future<void> updateSemester({
    required String id,
    required String name,
    required int number,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final admin = SupabaseConfig.adminClient;
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');

    await admin
        .from('semesters')
        .update({
          'name': name,
          'number': number,
          'start_date': startDate.toIso8601String().split('T')[0],
          'end_date': endDate.toIso8601String().split('T')[0],
        })
        .eq('id', id);

    final profile = await admin
        .from('users')
        .select('school_id')
        .eq('id', user.id)
        .single();
    await _refreshCurrentSemester(profile['school_id']);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    final admin = SupabaseConfig.adminClient;
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');

    final profile = await admin
        .from('users')
        .select('school_id')
        .eq('id', user.id)
        .single();
    final schoolId = profile['school_id'];

    await admin.from('semesters').delete().eq('id', id);
    await _refreshCurrentSemester(schoolId);
    ref.invalidateSelf();
  }

  Future<void> deleteVacation(String id) async {
    final admin = SupabaseConfig.adminClient;
    await admin.from('vacation_periods').delete().eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> deleteExam(String id) async {
    final admin = SupabaseConfig.adminClient;
    await admin.from('exam_periods').delete().eq('id', id);
    ref.invalidateSelf();
  }

  Future<void> addManualVacation({
    required DateTime startDate,
    required DateTime endDate,
    String? name,
  }) async {
    final admin = SupabaseConfig.adminClient;
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');

    final profile = await admin
        .from('users')
        .select('school_id')
        .eq('id', user.id)
        .single();
    final schoolId = profile['school_id'];

    final year = state.asData?.value.currentAcademicYear;
    if (year == null) throw Exception('Aucune année scolaire active');

    await admin.from('vacation_periods').insert({
      'school_id': schoolId,
      'academic_year_id': year.id,
      'name': name ?? 'Vacances',
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'type': 'manual',
    });
    ref.invalidateSelf();
  }

  Future<void> addExamPeriod({
    required DateTime startDate,
    required DateTime endDate,
    String? name,
  }) async {
    final admin = SupabaseConfig.adminClient;
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) throw Exception('Non connecté');

    final profile = await admin
        .from('users')
        .select('school_id')
        .eq('id', user.id)
        .single();
    final schoolId = profile['school_id'];

    final year = state.asData?.value.currentAcademicYear;
    if (year == null) throw Exception('Aucune année scolaire active');

    await admin.from('exam_periods').insert({
      'school_id': schoolId,
      'academic_year_id': year.id,
      'name': name ?? 'Examen',
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
    });
    ref.invalidateSelf();
  }
}

final semestersProvider =
    AsyncNotifierProvider<SemestersNotifier, SemestersState>(
      SemestersNotifier.new,
    );
