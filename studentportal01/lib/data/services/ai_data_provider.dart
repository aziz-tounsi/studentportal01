/// AI Data Provider
/// Aggregates ALL student-specific data into a rich, comprehensive snapshot for the AI.
/// Scoped strictly to the authenticated student (zero PII leak, zero admin data).
/// Direct data access: timetable, absences, results, payment/solde, documents, messages.
library;

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/core_data_service.dart';
import '../../presentation/providers/student_context_provider.dart';
import '../../presentation/providers/announcements_provider.dart';
import '../../presentation/providers/suggestions_provider.dart';
import '../../presentation/screens/resultats/resultats_screen.dart' show gradesProvider;
import '../../presentation/screens/absences/absences_screen.dart' show absencesProvider;
import '../models/absence_model.dart' show SubjectAbsenceSummary;

/// Complete financial summary for the AI
class StudentFinancialSummary {
  final double totalAmount;
  final double totalPaid;
  final double remainingBalance;
  final String status;
  final String currency;
  final Map<String, ({double amount, double paid, double remaining})> categories;

  const StudentFinancialSummary({
    required this.totalAmount,
    required this.totalPaid,
    required this.remainingBalance,
    required this.status,
    this.currency = 'DT',
    this.categories = const {},
  });
}

/// Next class calculation result
class NextClassInfo {
  final String subjectName;
  final String dayName;
  final String startTime;
  final String endTime;
  final String? room;
  final String? teacherName;
  final bool isToday;
  final bool isNow;

  const NextClassInfo({
    required this.subjectName,
    required this.dayName,
    required this.startTime,
    required this.endTime,
    this.room,
    this.teacherName,
    required this.isToday,
    this.isNow = false,
  });
}

/// Complete snapshot of a student's data for the AI context
class StudentAISnapshot {
  final StudentContext? studentContext;
  final Map<String, dynamic>? studentUserDetails;
  final Map<String, dynamic>? schoolInfo;
  final List<SemesterInfo> semesters;
  final SemesterInfo? currentSemester;
  final List<TimetableSlotInfo> timetable;
  final List<AbsenceSummary> absences;
  final Map<String, List<SubjectAbsenceSummary>> allSemesterAbsences;
  final SemesterResults results;
  final Map<String, SemesterResults> allSemesterResults;
  final List<PaymentPlanInfo> payments;
  final StudentFinancialSummary financialSummary;
  final List<StudentAnnouncement> notifications;
  final List<StudentAnnouncement> messages;
  final List<Suggestion> suggestions;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> courses;
  final DateTime fetchedAt;

  const StudentAISnapshot({
    this.studentContext,
    this.studentUserDetails,
    this.schoolInfo,
    this.semesters = const [],
    this.currentSemester,
    this.timetable = const [],
    this.absences = const [],
    this.allSemesterAbsences = const {},
    required this.results,
    this.allSemesterResults = const {},
    this.payments = const [],
    required this.financialSummary,
    this.notifications = const [],
    this.messages = const [],
    this.suggestions = const [],
    this.documents = const [],
    this.courses = const [],
    required this.fetchedAt,
  });

  bool get hasData => studentContext != null;
}

/// Builds the complete student AI snapshot - resilient multi-strategy fetching.
final studentAISnapshotProvider = FutureProvider<StudentAISnapshot>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    return StudentAISnapshot(
      results: SemesterResults(subjects: [], totalCoefficient: 0),
      financialSummary: const StudentFinancialSummary(
        totalAmount: 0,
        totalPaid: 0,
        remainingBalance: 0,
        status: 'Non connecté',
      ),
      fetchedAt: DateTime.now(),
    );
  }

  final service = ref.watch(coreDataServiceProvider);

  // 1. Student Context & User Profile
  var ctx = await service.getStudentContext(userId);

  Map<String, dynamic>? userDetails;
  try {
    userDetails = await supabase
        .from('users')
        .select('full_name, email, student_code, date_of_birth, phone, address, photo_url')
        .eq('id', userId)
        .maybeSingle();
  } catch (_) {}

  // Direct database fallback if getStudentContext returned null
  if (ctx == null) {
    try {
      final enrollResp = await supabase
          .from('enrollments')
          .select('''
            id, user_id, class_id, academic_year_id, student_code, status,
            classes (id, name, niveau_id, section_id, school_id,
              niveaux (id, name, code, cycle),
              sections (id, name, code)
            ),
            academic_years (id, name, is_current),
            users (id, full_name, email, student_code, school_id)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (enrollResp != null) {
        final cl = enrollResp['classes'] as Map<String, dynamic>?;
        final niv = cl?['niveaux'] as Map<String, dynamic>?;
        final sec = cl?['sections'] as Map<String, dynamic>?;
        final ay = enrollResp['academic_years'] as Map<String, dynamic>?;
        final u = enrollResp['users'] as Map<String, dynamic>?;
        ctx = StudentContext(
          userId: userId,
          schoolId: cl?['school_id']?.toString() ?? u?['school_id']?.toString() ?? '',
          fullName: u?['full_name']?.toString() ?? userDetails?['full_name']?.toString(),
          email: u?['email']?.toString() ?? userDetails?['email']?.toString(),
          studentCode: enrollResp['student_code']?.toString() ?? u?['student_code']?.toString() ?? userDetails?['student_code']?.toString(),
          enrollmentId: enrollResp['id']?.toString(),
          classId: enrollResp['class_id']?.toString() ?? cl?['id']?.toString(),
          academicYearId: enrollResp['academic_year_id']?.toString() ?? ay?['id']?.toString(),
          className: cl?['name']?.toString(),
          niveauId: niv?['id']?.toString(),
          niveauName: niv?['name']?.toString(),
          niveauCode: niv?['code']?.toString(),
          cycle: niv?['cycle']?.toString(),
          sectionId: sec?['id']?.toString(),
          sectionName: sec?['name']?.toString(),
          sectionCode: sec?['code']?.toString(),
          academicYearName: ay?['name']?.toString(),
          isCurrentYear: ay?['is_current'] == true,
        );
      }
    } catch (_) {}
  }

  // 2. School Info
  Map<String, dynamic>? schoolInfo;
  if (ctx?.schoolId != null && ctx!.schoolId.isNotEmpty) {
    try {
      schoolInfo = await supabase
          .from('schools')
          .select('name, address, phone, email, logo_url')
          .eq('id', ctx.schoolId)
          .maybeSingle();
    } catch (_) {}
  }

  // 3. Resolve Academic Year (Context first, fallback to is_current in academic_years)
  String? academicYearId = ctx?.academicYearId;
  if (academicYearId == null || academicYearId.isEmpty) {
    try {
      final yResp = await supabase
          .from('academic_years')
          .select('id')
          .eq('is_current', true)
          .order('start_date', ascending: false)
          .maybeSingle();
      academicYearId = yResp?['id'] as String?;
    } catch (_) {}
  }

  // 4. Semesters (Source of truth from semestersProvider)
  List<SemesterInfo> semesters = [];
  SemesterInfo? currentSemester;
  try {
    semesters = await ref.watch(semestersProvider.future);
  } catch (_) {}

  if (semesters.isEmpty && academicYearId != null) {
    try {
      semesters = await service.getSemestersForAcademicYear(academicYearId);
    } catch (_) {}
    if (semesters.isEmpty) {
      try {
        final sResp = await supabase
            .from('semesters')
            .select('id, name, number, start_date, end_date, is_current')
            .eq('academic_year_id', academicYearId)
            .order('number');
        semesters = (sResp as List).map((e) => SemesterInfo(
          id: e['id'] ?? '',
          name: e['name'] ?? '',
          number: e['number'] ?? 0,
          isCurrent: e['is_current'] ?? false,
          startDate: e['start_date'] != null ? DateTime.tryParse(e['start_date'].toString()) : null,
          endDate: e['end_date'] != null ? DateTime.tryParse(e['end_date'].toString()) : null,
        )).toList();
      } catch (_) {}
    }
  }

  final appSelectedSem = ref.watch(selectedSemesterProvider);
  final appSemNum = ref.watch(selectedSemesterNumberProvider);

  currentSemester = (appSelectedSem != null ? semesters.firstWhereOrNull((s) => s.id == appSelectedSem.id) : null) ??
      semesters.firstWhereOrNull((s) => s.number == appSemNum) ??
      semesters.firstWhereOrNull((s) => s.isCurrent) ??
      semesters.firstWhereOrNull((s) => s.number == 1) ??
      semesters.firstOrNull;

  final semId = currentSemester?.id ?? '';

  // 5. Parallel fetch of all student-specific modules
  final results = await Future.wait([
    semId.isNotEmpty
        ? service.getTimetableForStudentSemester(userId: userId, semesterId: semId)
        : Future.value(<TimetableSlotInfo>[]),
    semId.isNotEmpty
        ? service.getAbsencesForStudentSemester(userId: userId, semesterId: semId)
        : Future.value(<AbsenceSummary>[]),
    semId.isNotEmpty
        ? service.getResultsForStudentSemester(userId: userId, semesterId: semId)
        : Future.value(SemesterResults(subjects: [], totalCoefficient: 0)),
    service.getPaymentsForStudent(userId),
    _fetchDocuments(supabase, ctx?.classId),
  ]);

  List<TimetableSlotInfo> timetable = results[0] as List<TimetableSlotInfo>;
  List<AbsenceSummary> absences = results[1] as List<AbsenceSummary>;
  SemesterResults grades = results[2] as SemesterResults;
  List<PaymentPlanInfo> payments = results[3] as List<PaymentPlanInfo>;
  final docs = results[4] as List<Map<String, dynamic>>;

  // Fallback for Timetable if RPC was empty but class_id exists
  if (timetable.isEmpty && ctx?.classId != null) {
    try {
      final slotsResp = await supabase
          .from('timetable_slots')
          .select('''
            id, day_of_week, start_time, end_time, room, session_type,
            subject_offerings!inner (
              id, class_id,
              subjects (name, code),
              teachers:users!subject_offerings_teacher_id_fkey (full_name)
            )
          ''')
          .eq('subject_offerings.class_id', ctx!.classId!);
      timetable = (slotsResp as List).map((s) {
        final off = s['subject_offerings'] as Map<String, dynamic>?;
        final sub = off?['subjects'] as Map<String, dynamic>?;
        final teacher = off?['teachers'] as Map<String, dynamic>?;
        return TimetableSlotInfo(
          id: s['id']?.toString() ?? '',
          subjectOfferingId: off?['id']?.toString() ?? '',
          dayOfWeek: s['day_of_week']?.toString() ?? 'monday',
          startTime: s['start_time']?.toString() ?? '08:00',
          endTime: s['end_time']?.toString() ?? '09:00',
          subjectName: sub?['name']?.toString() ?? 'Matière',
          subjectCode: sub?['code']?.toString() ?? '',
          sessionType: s['session_type']?.toString() ?? 'regular',
          room: s['room']?.toString(),
          teacherName: teacher?['full_name']?.toString(),
        );
      }).toList();
    } catch (_) {}
  }

  // 5a. Primary: Load complete screen-aligned absences for ALL semesters directly from absencesProvider
  final allSemesterAbsences = <String, List<SubjectAbsenceSummary>>{};
  for (final sem in semesters) {
    try {
      final screenAbs = await ref.read(absencesProvider(sem.number).future);
      allSemesterAbsences[sem.id] = screenAbs;
      allSemesterAbsences[sem.number.toString()] = screenAbs;
      allSemesterAbsences['Semestre ${sem.number}'] = screenAbs;
      if (sem.number == (currentSemester?.number ?? 1) || sem.id == currentSemester?.id) {
        absences = screenAbs.map((sa) => AbsenceSummary(
          subjectOfferingId: sa.subjectOfferingId,
          subjectCode: sa.subjectCode ?? '',
          subjectName: sa.subjectName,
          totalHours: sa.totalHours,
          totalAbsentHours: sa.totalAbsentHours,
          absencePercent: sa.absencePercent,
          absences: [],
        )).toList();
      }
    } catch (_) {}
  }

  final allSemesterResults = <String, SemesterResults>{};

  // 5a. Primary: Load complete screen-aligned grades for ALL semesters directly from gradesProvider
  for (final sem in semesters) {
    try {
      final screenGrades = await ref.read(gradesProvider(sem.number).future);
      if (screenGrades.isNotEmpty) {
        double totalWeightedSum = 0;
        double totalCoeffSum = 0;
        final list = <SubjectResult>[];
        for (final sg in screenGrades) {
          final comps = sg.components.map((c) => GradeComponent(
            componentId: c.componentId,
            componentName: c.componentName,
            weightPercent: c.weightPercent,
            gradeValue: c.grade,
            status: c.status,
          )).toList();
          if (sg.average != null) {
            totalWeightedSum += sg.average! * sg.coefficient;
            totalCoeffSum += sg.coefficient;
          }
          list.add(SubjectResult(
            subjectOfferingId: sg.subjectOfferingId,
            subjectCode: sg.subjectCode ?? '',
            subjectName: sg.subjectName,
            coefficient: sg.coefficient,
            components: comps,
            average: sg.average,
          ));
        }
        final genAvg = totalCoeffSum > 0 ? (totalWeightedSum / totalCoeffSum) : null;
        final semResult = SemesterResults(
          subjects: list,
          totalCoefficient: totalCoeffSum,
          generalAverage: genAvg,
        );
        allSemesterResults[sem.id] = semResult;
        allSemesterResults[sem.number.toString()] = semResult;
        allSemesterResults['Semestre ${sem.number}'] = semResult;
        if (sem.number == (currentSemester?.number ?? 1) || sem.id == currentSemester?.id) {
          grades = semResult;
        }
      }
    } catch (_) {}
  }

  // 5b. Fallback: Direct DB query if allSemesterResults is still empty
  if (allSemesterResults.isEmpty && ctx?.enrollmentId != null) {
    try {
      final gradesResp = await supabase
          .from('grades')
          .select('''
            grade_value, status,
            grade_components (
              id, name, weight_percent,
              subject_offerings (
                coefficient,
                semester_id,
                subjects (name, code)
              )
            )
          ''')
          .eq('enrollment_id', ctx!.enrollmentId!);

      // Group rows by semester_id
      final semesterRows = <String, List<Map<String, dynamic>>>{};
      for (final row in (gradesResp as List)) {
        final gc = row['grade_components'] as Map<String, dynamic>?;
        final so = gc?['subject_offerings'] as Map<String, dynamic>?;
        final sId = so?['semester_id']?.toString() ?? '';
        if (sId.isNotEmpty) {
          semesterRows.putIfAbsent(sId, () => []).add(row as Map<String, dynamic>);
        }
      }

      for (final sEntry in semesterRows.entries) {
        final currentSemId = sEntry.key;
        final rows = sEntry.value;

        final subGradesMap = <String, List<GradeComponent>>{};
        final subNames = <String, String>{};
        final subCodes = <String, String>{};
        final subCoeffs = <String, double>{};

        for (final row in rows) {
          final gc = row['grade_components'] as Map<String, dynamic>?;
          final so = gc?['subject_offerings'] as Map<String, dynamic>?;
          final sub = so?['subjects'] as Map<String, dynamic>?;

          final subName = sub?['name']?.toString() ?? 'Matière';
          final subCode = sub?['code']?.toString() ?? '';
          final coeff = (so?['coefficient'] as num?)?.toDouble() ?? 1.0;

          subNames[subName] = subName;
          subCodes[subName] = subCode;
          subCoeffs[subName] = coeff;

          final comp = GradeComponent(
            componentId: gc?['id']?.toString() ?? '',
            componentName: gc?['name']?.toString() ?? 'Contrôle',
            weightPercent: (gc?['weight_percent'] as num?)?.toDouble() ?? 20.0,
            gradeValue: (row['grade_value'] as num?)?.toDouble(),
            status: row['status']?.toString() ?? 'OK',
          );
          subGradesMap.putIfAbsent(subName, () => []).add(comp);
        }

        double totalWeightedSum = 0;
        double totalCoeffSum = 0;
        final subjectResultsList = <SubjectResult>[];

        for (final entry in subGradesMap.entries) {
          final comps = entry.value;
          final coeff = subCoeffs[entry.key] ?? 1.0;
          double subWeightedSum = 0;
          double subWeightTotal = 0;
          for (final c in comps) {
            if (c.gradeValue != null) {
              subWeightedSum += c.gradeValue! * (c.weightPercent / 100);
              subWeightTotal += (c.weightPercent / 100);
            }
          }
          final subAvg = subWeightTotal > 0 ? (subWeightedSum / subWeightTotal) : null;
          if (subAvg != null) {
            totalWeightedSum += subAvg * coeff;
            totalCoeffSum += coeff;
          }

          subjectResultsList.add(SubjectResult(
            subjectOfferingId: '',
            subjectCode: subCodes[entry.key] ?? '',
            subjectName: entry.key,
            coefficient: coeff,
            components: comps,
            average: subAvg,
          ));
        }

        final genAvg = totalCoeffSum > 0 ? (totalWeightedSum / totalCoeffSum) : null;
        final semResult = SemesterResults(
          subjects: subjectResultsList,
          totalCoefficient: totalCoeffSum,
          generalAverage: genAvg,
        );
        allSemesterResults[currentSemId] = semResult;
        if (grades.subjects.isEmpty) {
          grades = semResult;
        }
      }
    } catch (_) {}
  }

  // 6. Financial Summary Calculation (covers payment_plans and payment_pricing table)
  double totalAmount = 0;
  double totalPaid = 0;
  final categoryMap = <String, ({double amount, double paid, double remaining})>{};

  for (final plan in payments) {
    final cat = plan.category ?? plan.planType;
    final amt = plan.amountTotal;
    final paid = plan.totalPaid;
    final rem = plan.remaining;
    totalAmount += amt;
    totalPaid += paid;
    categoryMap[cat] = (amount: amt, paid: paid, remaining: rem);
  }

  // Check payment_pricing fallback if plans were not set
  if (totalAmount == 0 && ctx != null) {
    try {
      var query = supabase.from('payment_pricing').select('category, amount');
      if (ctx.schoolId.isNotEmpty) query = query.eq('school_id', ctx.schoolId);
      if (ctx.niveauId != null && ctx.niveauId!.isNotEmpty) query = query.eq('niveau_id', ctx.niveauId!);
      final pricingResp = await query;
      for (final r in (pricingResp as List)) {
        final cat = r['category']?.toString() ?? 'Scolarité';
        final amt = (r['amount'] as num?)?.toDouble() ?? 0.0;
        if (amt > 0) {
          totalAmount += amt;
          categoryMap.putIfAbsent(cat, () => (amount: amt, paid: 0, remaining: amt));
        }
      }
    } catch (_) {}
  }

  final remainingBalance = (totalAmount - totalPaid).clamp(0, double.infinity).toDouble();
  final paymentStatus = totalAmount == 0
      ? 'Aucun frais enregistré'
      : (remainingBalance == 0
          ? 'Totalement réglé (Solde = 0 DT)'
          : (totalPaid > 0 ? 'Partiellement payé (Reste à payer)' : 'En attente de paiement'));

  final financialSummary = StudentFinancialSummary(
    totalAmount: totalAmount,
    totalPaid: totalPaid,
    remainingBalance: remainingBalance,
    status: paymentStatus,
    currency: 'DT',
    categories: categoryMap,
  );

  // 7. Courses / Learning Resources
  List<Map<String, dynamic>> courses = [];
  if (ctx?.classId != null) {
    try {
      final coursesResp = await supabase
          .from('courses')
          .select('''
            id, title, description, file_url, created_at,
            subject_offerings!inner (
              class_id,
              subjects (name, code)
            )
          ''')
          .eq('subject_offerings.class_id', ctx!.classId!)
          .order('created_at', ascending: false)
          .limit(20);
      courses = (coursesResp as List).cast<Map<String, dynamic>>();
    } catch (_) {
      try {
        final simpleResp = await supabase
            .from('courses')
            .select('id, title, description, file_url, created_at')
            .order('created_at', ascending: false)
            .limit(20);
        courses = (simpleResp as List).cast<Map<String, dynamic>>();
      } catch (_) {}
    }
  }

  // 8. Notifications, class messages, suggestions
  List<StudentAnnouncement> notifications = [];
  try {
    notifications = await ref.read(globalAnnouncementsProvider.future);
  } catch (_) {
    if (ctx?.schoolId != null && ctx!.schoolId.isNotEmpty) {
      try {
        final resp = await supabase
            .from('announcements_global')
            .select()
            .eq('school_id', ctx.schoolId)
            .isFilter('deleted_at', null)
            .order('is_pinned', ascending: false)
            .order('published_at', ascending: false)
            .limit(20);
        notifications = (resp as List).map((j) => StudentAnnouncement.fromJson(j)).toList();
      } catch (_) {}
    }
  }

  List<StudentAnnouncement> classMessages = [];
  try {
    classMessages = await ref.read(classMessagesProvider.future);
  } catch (_) {
    if (ctx?.classId != null && ctx!.classId!.isNotEmpty) {
      try {
        final resp = await supabase
            .from('class_messages')
            .select()
            .eq('class_id', ctx.classId!)
            .isFilter('deleted_at', null)
            .order('published_at', ascending: false)
            .limit(20);
        classMessages = (resp as List).map((j) => StudentAnnouncement.fromJson(j)).toList();
      } catch (_) {}
    }
  }

  List<Suggestion> suggestions = [];
  try {
    suggestions = await ref.read(suggestionsProvider.future);
  } catch (_) {
    try {
      final resp = await supabase
          .from('suggestions')
          .select('*, suggestion_replies(*)')
          .eq('student_id', userId)
          .order('created_at', ascending: false)
          .limit(10);
      suggestions = (resp as List).map((j) => Suggestion.fromJson(j)).toList();
    } catch (_) {}
  }

  return StudentAISnapshot(
    studentContext: ctx,
    studentUserDetails: userDetails,
    schoolInfo: schoolInfo,
    semesters: semesters,
    currentSemester: currentSemester,
    timetable: timetable,
    absences: absences,
    allSemesterAbsences: allSemesterAbsences,
    results: grades,
    allSemesterResults: allSemesterResults,
    payments: payments,
    financialSummary: financialSummary,
    notifications: notifications,
    messages: classMessages,
    suggestions: suggestions,
    documents: docs,
    courses: courses,
    fetchedAt: DateTime.now(),
  );
});

/// Fetch school and class documents matching schema
Future<List<Map<String, dynamic>>> _fetchDocuments(
  SupabaseClient supabase,
  String? classId,
) async {
  try {
    var query = supabase
        .from('documents')
        .select('id, title, file_name, file_url, created_at, description, category');
    if (classId != null && classId.isNotEmpty) {
      query = query.or('class_id.eq.$classId,class_id.is.null');
    }
    final response = await query.order('created_at', ascending: false).limit(20);
    return (response as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return [];
  }
}

/// Calculate the exact next or current class based on DateTime.now()
NextClassInfo? _computeNextClass(List<TimetableSlotInfo> timetable, DateTime now) {
  if (timetable.isEmpty) return null;

  final dayMap = {
    1: 'monday',
    2: 'tuesday',
    3: 'wednesday',
    4: 'thursday',
    5: 'friday',
    6: 'saturday',
    7: 'sunday',
  };

  final currentDayName = dayMap[now.weekday] ?? 'monday';
  final currentHourStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

  // 1. Check if student is currently IN a class or has another class TODAY
  final todaySlots = timetable
      .where((s) => s.dayOfWeek.toLowerCase() == currentDayName)
      .toList()
    ..sort((a, b) => a.startTime.compareTo(b.startTime));

  for (final s in todaySlots) {
    if (s.startTime.compareTo(currentHourStr) <= 0 && s.endTime.compareTo(currentHourStr) >= 0) {
      return NextClassInfo(
        subjectName: s.subjectName,
        dayName: 'Aujourd\'hui (${_capitalizeDay(s.dayOfWeek)})',
        startTime: s.startTime,
        endTime: s.endTime,
        room: s.room,
        teacherName: s.teacherName,
        isToday: true,
        isNow: true,
      );
    }
    if (s.startTime.compareTo(currentHourStr) > 0) {
      return NextClassInfo(
        subjectName: s.subjectName,
        dayName: 'Aujourd\'hui (${_capitalizeDay(s.dayOfWeek)})',
        startTime: s.startTime,
        endTime: s.endTime,
        room: s.room,
        teacherName: s.teacherName,
        isToday: true,
        isNow: false,
      );
    }
  }

  // 2. Search future days of the week (circular)
  for (int offset = 1; offset <= 7; offset++) {
    final nextWeekday = ((now.weekday - 1 + offset) % 7) + 1;
    final nextDayName = dayMap[nextWeekday];
    final nextDaySlots = timetable
        .where((s) => s.dayOfWeek.toLowerCase() == nextDayName)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (nextDaySlots.isNotEmpty) {
      final firstSlot = nextDaySlots.first;
      final label = offset == 1 ? 'Demain (${_capitalizeDay(firstSlot.dayOfWeek)})' : _capitalizeDay(firstSlot.dayOfWeek);
      return NextClassInfo(
        subjectName: firstSlot.subjectName,
        dayName: label,
        startTime: firstSlot.startTime,
        endTime: firstSlot.endTime,
        room: firstSlot.room,
        teacherName: firstSlot.teacherName,
        isToday: false,
        isNow: false,
      );
    }
  }

  return null;
}

/// Converts the full snapshot into a structured text context for the AI system prompt.
/// Direct access: includes concrete numbers, totals, next class, profile, and categories.
String buildAISystemContext(StudentAISnapshot snap) {
  final ctx = snap.studentContext;
  final ud = snap.studentUserDetails;
  final sch = snap.schoolInfo;
  final now = DateTime.now();
  final nextClass = _computeNextClass(snap.timetable, now);
  final fin = snap.financialSummary;
  final sb = StringBuffer();

  // 1. Identity & Student Personal File
  sb.writeln('=== 1. STUDENT PERSONAL FILE & IDENTITY ===');
  sb.writeln('Full Name: ${ctx?.fullName ?? 'Étudiant'}');
  sb.writeln('Student Code / Matricule: ${ctx?.studentCode ?? 'STU'}');
  if (ud != null) {
    if (ud['date_of_birth'] != null) sb.writeln('Date of Birth: ${_fmtDateStr(ud['date_of_birth'])}');
    if (ud['phone'] != null) sb.writeln('Phone Number: ${ud['phone']}');
    if (ud['address'] != null) sb.writeln('Home Address: ${ud['address']}');
  }
  sb.writeln('Email: ${ctx?.email ?? ''}');
  sb.writeln('Class: ${ctx?.className ?? 'Classe non assignée'}');
  sb.writeln('Level / Niveau: ${ctx?.niveauName ?? ctx?.niveauCode ?? ''}');
  sb.writeln('Cycle: ${ctx?.cycle ?? ''}');
  if (ctx?.sectionName != null) sb.writeln('Section: ${ctx?.sectionName} (${ctx?.sectionCode})');
  sb.writeln('Academic Year: ${ctx?.academicYearName ?? '2024-2025'}');
  sb.writeln('Current Semester: ${snap.currentSemester?.name ?? 'Semestre 1'}');

  // School Administration Info
  if (sch != null) {
    sb.writeln('School Name: ${sch['name'] ?? ''}');
    if (sch['address'] != null) sb.writeln('School Address: ${sch['address']}');
    if (sch['phone'] != null) sb.writeln('School Phone: ${sch['phone']}');
    if (sch['email'] != null) sb.writeln('School Email: ${sch['email']}');
  }

  // 2. TODAY & NEXT CLASS
  sb.writeln('\n=== 2. NEXT / CURRENT CLASS (INSTANT DIRECT LOOKUP) ===');
  if (nextClass != null) {
    if (nextClass.isNow) {
      sb.writeln('CURRENT CLASS RIGHT NOW: ${nextClass.subjectName}');
      sb.writeln('Time: ${nextClass.startTime} - ${nextClass.endTime} (Currently in progress)');
    } else {
      sb.writeln('NEXT UPCOMING CLASS: ${nextClass.subjectName}');
      sb.writeln('Schedule: ${nextClass.dayName} at ${nextClass.startTime} (until ${nextClass.endTime})');
    }
    if (nextClass.room != null && nextClass.room!.isNotEmpty) {
      sb.writeln('Classroom / Room: ${nextClass.room}');
    }
    if (nextClass.teacherName != null && nextClass.teacherName!.isNotEmpty) {
      sb.writeln('Teacher: ${nextClass.teacherName}');
    }
  } else {
    sb.writeln('No upcoming classes scheduled.');
  }

  // 3. FINANCIAL STATUS & SOLDE
  sb.writeln('\n=== 3. FINANCIAL BALANCE & PAYMENTS (MON SOLDE) ===');
  sb.writeln('Total Tuition/Fees Amount: ${fin.totalAmount.toStringAsFixed(2)} ${fin.currency}');
  sb.writeln('Total Amount Paid: ${fin.totalPaid.toStringAsFixed(2)} ${fin.currency}');
  sb.writeln('Remaining Balance (SOLDE RESTANT À PAYER): ${fin.remainingBalance.toStringAsFixed(2)} ${fin.currency}');
  sb.writeln('Financial Payment Status: ${fin.status}');
  if (fin.categories.isNotEmpty) {
    sb.writeln('Breakdown by Category:');
    for (final entry in fin.categories.entries) {
      final c = entry.value;
      sb.writeln('  • ${entry.key}: Total = ${c.amount.toStringAsFixed(2)} ${fin.currency} | Payé = ${c.paid.toStringAsFixed(2)} ${fin.currency} | Reste = ${c.remaining.toStringAsFixed(2)} ${fin.currency}');
    }
  }
  if (snap.payments.isNotEmpty) {
    sb.writeln('Payment Schedule Installments:');
    for (final plan in snap.payments) {
      sb.writeln('  - Plan: ${plan.planType} (${plan.totalPaid}/${plan.amountTotal} ${plan.currency})');
      for (final p in plan.payments) {
        sb.writeln('    • ${p.amount} ${plan.currency}: ${p.status.toUpperCase()}${p.dueDate != null ? " (Échéance: ${_fmtDate(p.dueDate!)})" : ""}${p.paidAt != null ? " (Payé le: ${_fmtDate(p.paidAt!)})" : ""}');
      }
    }
  }

  // 4. Results & Grades
  sb.writeln('\n=== 4. ACADEMIC RESULTS & GRADES (DEFAULT TO CURRENT SEMESTER: ${snap.currentSemester?.name ?? 'Semestre 1'}) ===');
  final activeSem = snap.currentSemester ?? (snap.semesters.isNotEmpty ? snap.semesters.first : null);
  final activeSemNum = activeSem?.number ?? 1;
  bool wroteAnyResults = false;

  if (snap.semesters.isNotEmpty) {
    for (final sem in snap.semesters) {
      final res = snap.allSemesterResults[sem.id] ??
                  snap.allSemesterResults[sem.number.toString()] ??
                  snap.allSemesterResults['Semestre ${sem.number}'] ??
                  (sem.number == activeSemNum && snap.results.subjects.isNotEmpty ? snap.results : null);
      if (res != null && res.subjects.isNotEmpty) {
        wroteAnyResults = true;
        final isCurrent = sem.number == activeSemNum || sem.id == activeSem?.id;
        sb.writeln('\n--- ${sem.name.toUpperCase()}${isCurrent ? ' [CURRENT ACTIVE SEMESTER - USE THIS BY DEFAULT]' : ' [OTHER SEMESTER - ONLY IF EXPLICITLY ASKED]'} (Moyenne Générale: ${res.averageDisplay}/20, Coeff: ${res.totalCoefficient}) ---');
        final validSubjects = res.subjects.where((s) => s.average != null).toList()
          ..sort((a, b) => b.average!.compareTo(a.average!));
        if (validSubjects.isNotEmpty) {
          sb.writeln('  Best Subject: ${validSubjects.first.subjectName} (${validSubjects.first.averageDisplay}/20)');
          sb.writeln('  Weakest Subject: ${validSubjects.last.subjectName} (${validSubjects.last.averageDisplay}/20)');
        }
        sb.writeln('  Detailed Subject Results:');
        for (final sub in res.subjects) {
          sb.writeln('  • ${sub.subjectName} (Coeff: ${sub.coefficient}): Average = ${sub.averageDisplay}/20');
          for (final comp in sub.components) {
            sb.writeln('      - ${comp.componentName} (${comp.weightPercent}%): ${comp.gradeDisplay}/20 [${comp.status}]');
          }
        }
      }
    }
  }

  if (!wroteAnyResults && snap.results.subjects.isNotEmpty) {
    wroteAnyResults = true;
    sb.writeln('General Average (Moyenne Générale): ${snap.results.averageDisplay}/20');
    sb.writeln('Total Coefficients Sum: ${snap.results.totalCoefficient}');
    for (final sub in snap.results.subjects) {
      sb.writeln('• ${sub.subjectName} (Coeff: ${sub.coefficient}): Average = ${sub.averageDisplay}/20');
      for (final comp in sub.components) {
        sb.writeln('    - ${comp.componentName} (${comp.weightPercent}%): ${comp.gradeDisplay}/20 [${comp.status}]');
      }
    }
  } else if (!wroteAnyResults) {
    sb.writeln('No academic grades published yet.');
  }

  // 5. Absences & Attendance Record
  sb.writeln('\n=== 5. ABSENCES & ATTENDANCE RECORD (PER SEMESTER) ===');
  bool wroteAnyAbsences = false;

  if (snap.semesters.isNotEmpty) {
    for (final sem in snap.semesters) {
      final semAbsList = snap.allSemesterAbsences[sem.id] ??
          snap.allSemesterAbsences[sem.number.toString()] ??
          snap.allSemesterAbsences['Semestre ${sem.number}'];

      final isCurrent = sem.number == activeSemNum || sem.id == activeSem?.id;
      sb.writeln('\n--- ${sem.name.toUpperCase()}${isCurrent ? ' [CURRENT ACTIVE SEMESTER - USE THIS BY DEFAULT]' : ' [OTHER SEMESTER - ONLY IF EXPLICITLY ASKED]'} ---');

      if (semAbsList == null || semAbsList.isEmpty) {
        sb.writeln('No absences recorded for ${sem.name}. 100% regular attendance (0h missed out of 0h, 0.0%).');
      } else {
        wroteAnyAbsences = true;
        double totalH = 0;
        double absentH = 0;
        final subjectsWithAbsences = <SubjectAbsenceSummary>[];

        for (final a in semAbsList) {
          totalH += a.totalHours;
          absentH += a.totalAbsentHours;
          if (a.totalAbsentHours > 0) {
            subjectsWithAbsences.add(a);
          }
        }

        final semPct = totalH > 0 ? (absentH / totalH * 100) : 0.0;
        final attendanceRate = totalH > 0 ? ((totalH - absentH) / totalH * 100).clamp(0, 100) : 100.0;

        sb.writeln('TOTAL ${sem.name.toUpperCase()} ABSENCES: ${absentH.toStringAsFixed(0)}h missed out of ${totalH.toStringAsFixed(0)}h (${semPct.toStringAsFixed(1)}%)');
        sb.writeln('Attendance Rate (Taux d\'assiduité): ${attendanceRate.toStringAsFixed(1)}%');

        if (subjectsWithAbsences.isEmpty) {
          sb.writeln('No absences in any subject for this semester. 100% regular attendance.');
        } else {
          sb.writeln('Subjects with recorded absences:');
          for (final a in subjectsWithAbsences) {
            sb.writeln('  • ${a.subjectName}: ${a.totalAbsentHours.toStringAsFixed(0)}h absent / ${a.totalHours.toStringAsFixed(0)}h total (${a.absencePercent.toStringAsFixed(1)}%) [${a.level.name.toUpperCase()}]');
          }
        }

        if (absentH >= 10 || (totalH > 0 && (absentH / totalH) > 0.15)) {
          sb.writeln('⚠️ WARNING STATUS: Risque d\'avertissement pour absences.');
        } else {
          sb.writeln('Attendance Status: Assiduité régulière et satisfaisante.');
        }
      }
    }
  }

  if (!wroteAnyAbsences && snap.absences.isNotEmpty) {
    double totalH = 0;
    double absentH = 0;
    for (final a in snap.absences) {
      totalH += a.totalHours;
      absentH += a.totalAbsentHours;
      sb.writeln('• ${a.subjectName}: ${a.totalAbsentHours}h absent / ${a.totalHours}h total (${a.absencePercent.toStringAsFixed(1)}%)');
    }
    final attendanceRate = totalH > 0 ? ((totalH - absentH) / totalH * 100).clamp(0, 100) : 100.0;
    sb.writeln('TOTAL ABSENCES: ${absentH}h missed out of ${totalH}h (${totalH > 0 ? (absentH / totalH * 100).toStringAsFixed(1) : 0}%)');
    sb.writeln('Attendance Rate (Taux d\'assiduité): ${attendanceRate.toStringAsFixed(1)}%');
  } else if (!wroteAnyAbsences && snap.semesters.isEmpty) {
    sb.writeln('No absences recorded. 100% regular attendance.');
  }

  // 6. Full Weekly Timetable
  sb.writeln('\n=== 6. FULL WEEKLY TIMETABLE (${snap.currentSemester?.name ?? 'Semestre en cours'}) ===');
  if (snap.timetable.isEmpty) {
    sb.writeln('No weekly timetable slots posted yet.');
  } else {
    final dayGroups = <String, List<TimetableSlotInfo>>{};
    for (final slot in snap.timetable) {
      dayGroups.putIfAbsent(slot.dayOfWeek.toLowerCase(), () => []).add(slot);
    }
    const dayOrder = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    for (final day in dayOrder) {
      final slots = dayGroups[day];
      if (slots == null || slots.isEmpty) continue;
      slots.sort((a, b) => a.startTime.compareTo(b.startTime));
      sb.writeln('${_capitalizeDay(day)}:');
      for (final s in slots) {
        sb.writeln('  - ${s.startTime}-${s.endTime}: ${s.subjectName}${s.room != null ? " (Salle: ${s.room})" : ""}${s.teacherName != null ? " [Prof: ${s.teacherName}]" : ""} (${s.sessionType})');
      }
    }
  }

  // 7. Subjects, Teachers & Classrooms Directory
  sb.writeln('\n=== 7. SUBJECTS, TEACHERS & CLASSROOMS DIRECTORY ===');
  if (snap.timetable.isEmpty) {
    sb.writeln('No subject teacher directory recorded.');
  } else {
    final subjectInfo = <String, ({Set<String> teachers, Set<String> rooms, int sessionCount})>{};
    for (final s in snap.timetable) {
      final sub = s.subjectName;
      final current = subjectInfo[sub] ?? (teachers: <String>{}, rooms: <String>{}, sessionCount: 0);
      if (s.teacherName != null && s.teacherName!.isNotEmpty) {
        current.teachers.add(s.teacherName!);
      }
      if (s.room != null && s.room!.isNotEmpty) {
        current.rooms.add(s.room!);
      }
      subjectInfo[sub] = (
        teachers: current.teachers,
        rooms: current.rooms,
        sessionCount: current.sessionCount + 1,
      );
    }
    for (final entry in subjectInfo.entries) {
      final teachersStr = entry.value.teachers.isNotEmpty ? entry.value.teachers.join(', ') : 'Non assigné';
      final roomsStr = entry.value.rooms.isNotEmpty ? entry.value.rooms.join(', ') : 'Salle standard';
      sb.writeln('• ${entry.key}: Enseignant(e): $teachersStr | Salle(s): $roomsStr | ${entry.value.sessionCount} séances/semaine');
    }
  }

  // 8. Class Learning Materials (Accessed via Documents / Emploi — no standalone courses screen exists)
  sb.writeln('\n=== 8. LEARNING MATERIALS & SUBJECT FILES (NO DEDICATED COURSES PAGE EXISTS IN APP) ===');
  if (snap.courses.isEmpty) {
    sb.writeln('No learning files uploaded. (Remind AI: There is NO /courses page in this app.)');
  } else {
    sb.writeln('(Note for AI: Present details directly here or refer to Documents/Emploi; there is NO /courses page in the app.)');
    for (final c in snap.courses) {
      final so = c['subject_offerings'] as Map<String, dynamic>?;
      final sub = so?['subjects'] as Map<String, dynamic>?;
      final subName = sub?['name'] ?? '';
      final fUrl = (c['file_url'] != null && c['file_url'].toString().isNotEmpty)
          ? ' [Fichier: ${c['file_url']}]'
          : '';
      sb.writeln('• ${subName.isNotEmpty ? "[$subName] " : ""}${c['title'] ?? 'Matière'}: ${c['description'] ?? ''}$fUrl');
    }
  }

  // 9. Notifications
  sb.writeln('\n=== 9. RECENT SCHOOL NOTIFICATIONS ===');
  if (snap.notifications.isEmpty) {
    sb.writeln('No recent announcements.');
  } else {
    for (final n in snap.notifications.take(15)) {
      final bodyClean = n.body.length > 350 ? '${n.body.substring(0, 350)}...' : n.body;
      final fileList = <String>[];
      if (n.attachmentUrl != null && n.attachmentUrl!.isNotEmpty) {
        final isImg = n.attachmentUrl!.toLowerCase().contains('.png') ||
            n.attachmentUrl!.toLowerCase().contains('.jpg') ||
            n.attachmentUrl!.toLowerCase().contains('.jpeg') ||
            n.attachmentUrl!.toLowerCase().contains('.webp');
        fileList.add('${isImg ? "[IMAGE]" : "[FICHIER]"} URL: ${n.attachmentUrl!} (nom: ${n.attachmentName ?? "pièce jointe"})');
      }
      for (final a in n.attachments) {
        if (a.fileUrl.isNotEmpty) {
          final isImg = (a.fileType?.toLowerCase().contains('image') ?? false) ||
              a.fileName.toLowerCase().endsWith('.png') ||
              a.fileName.toLowerCase().endsWith('.jpg') ||
              a.fileName.toLowerCase().endsWith('.jpeg') ||
              a.fileName.toLowerCase().endsWith('.webp');
          fileList.add('${isImg ? "[IMAGE]" : "[FICHIER]"} URL: ${a.fileUrl} (nom: ${a.effectiveName})');
        }
      }
      final filesStr = fileList.isNotEmpty ? ' | Pièces jointes: ${fileList.join(", ")}' : '';
      sb.writeln('• [${_fmtDate(n.publishedAt)}]${n.isPinned ? " 📌" : ""}${n.isImportant ? " ❗" : ""} ${n.title}: $bodyClean$filesStr');
    }
  }

  // 10. Class Messages
  sb.writeln('\n=== 10. CLASS MESSAGES FROM TEACHERS & ADMIN ===');
  if (snap.messages.isEmpty) {
    sb.writeln('No class messages.');
  } else {
    for (final m in snap.messages.take(15)) {
      final bodyClean = m.body.length > 350 ? '${m.body.substring(0, 350)}...' : m.body;
      final sender = m.senderLabel != null ? ' [De: ${m.senderLabel}]' : '';
      final fileList = <String>[];
      if (m.attachmentUrl != null && m.attachmentUrl!.isNotEmpty) {
        final isImg = m.attachmentUrl!.toLowerCase().contains('.png') ||
            m.attachmentUrl!.toLowerCase().contains('.jpg') ||
            m.attachmentUrl!.toLowerCase().contains('.jpeg') ||
            m.attachmentUrl!.toLowerCase().contains('.webp');
        fileList.add('${isImg ? "[IMAGE]" : "[FICHIER]"} URL: ${m.attachmentUrl!} (nom: ${m.attachmentName ?? "pièce jointe"})');
      }
      for (final a in m.attachments) {
        if (a.fileUrl.isNotEmpty) {
          final isImg = (a.fileType?.toLowerCase().contains('image') ?? false) ||
              a.fileName.toLowerCase().endsWith('.png') ||
              a.fileName.toLowerCase().endsWith('.jpg') ||
              a.fileName.toLowerCase().endsWith('.jpeg') ||
              a.fileName.toLowerCase().endsWith('.webp');
          fileList.add('${isImg ? "[IMAGE]" : "[FICHIER]"} URL: ${a.fileUrl} (nom: ${a.effectiveName})');
        }
      }
      final filesStr = fileList.isNotEmpty ? ' | Pièces jointes: ${fileList.join(", ")}' : '';
      sb.writeln('• [${_fmtDate(m.publishedAt)}]$sender ${m.title}: $bodyClean$filesStr');
    }
  }

  // 11. Suggestions & Complaints
  sb.writeln('\n=== 11. STUDENT SUGGESTIONS & TICKETS ===');
  if (snap.suggestions.isEmpty) {
    sb.writeln('No suggestions submitted.');
  } else {
    for (final s in snap.suggestions.take(10)) {
      sb.writeln('• [${_fmtDate(s.createdAt)}] "${s.title}" (Type: ${s.suggestionType}) - Statut: ${s.status}');
      if (s.body.isNotEmpty) {
        sb.writeln('    Contenu: "${s.body}"');
      }
      if (s.replies.isNotEmpty) {
        for (final r in s.replies) {
          sb.writeln('    Admin Response: "${r.replyText}" (${_fmtDate(r.createdAt)})');
        }
      }
    }
  }

  // 12. Documents & Certificates
  sb.writeln('\n=== 12. OFFICIAL DOCUMENTS & CERTIFICATES ===');
  if (snap.documents.isEmpty) {
    sb.writeln('No documents available.');
  } else {
    for (final d in snap.documents) {
      final urlStr = d['file_url']?.toString() ?? '';
      final isImg = urlStr.toLowerCase().contains('.png') ||
          urlStr.toLowerCase().contains('.jpg') ||
          urlStr.toLowerCase().contains('.jpeg') ||
          urlStr.toLowerCase().contains('.webp');
      final fUrl = urlStr.isNotEmpty
          ? ' | ${isImg ? "[IMAGE]" : "[FICHIER]"} URL: $urlStr (nom: ${d['file_name'] ?? d['title'] ?? "document"})'
          : '';
      sb.writeln('• ${d['title'] ?? 'Document'} (${d['category'] ?? d['file_name'] ?? 'Fichier'}) - Date: ${_fmtDateStr(d['created_at'])}$fUrl');
    }
  }

  return sb.toString();
}

String _capitalizeDay(String day) {
  if (day.isEmpty) return day;
  switch (day.toLowerCase()) {
    case 'monday':
      return 'Lundi';
    case 'tuesday':
      return 'Mardi';
    case 'wednesday':
      return 'Mercredi';
    case 'thursday':
      return 'Jeudi';
    case 'friday':
      return 'Vendredi';
    case 'saturday':
      return 'Samedi';
    case 'sunday':
      return 'Dimanche';
    default:
      return day[0].toUpperCase() + day.substring(1);
  }
}

String _fmtDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

String _fmtDateStr(dynamic dateStr) {
  if (dateStr == null) return '';
  try {
    return _fmtDate(DateTime.parse(dateStr.toString()));
  } catch (_) {
    return dateStr.toString();
  }
}
