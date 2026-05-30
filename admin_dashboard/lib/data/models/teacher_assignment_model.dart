/// Model for teacher-subject assignments
/// Links teachers to subjects, niveaux, and classes
library;

class TeacherAssignmentModel {
  final String id;
  final String schoolId;
  final String teacherId;
  final String subjectId;
  final String? niveauId;
  final String? classId;
  final bool isActive;
  final DateTime? createdAt;

  // Joined data
  final String? teacherName;
  final String? teacherEmail;
  final String? teacherPhone;
  final String? subjectName;
  final String? subjectCode;
  final String? niveauName;
  final String? niveauCode;
  final String? className;

  TeacherAssignmentModel({
    required this.id,
    required this.schoolId,
    required this.teacherId,
    required this.subjectId,
    this.niveauId,
    this.classId,
    this.isActive = true,
    this.createdAt,
    this.teacherName,
    this.teacherEmail,
    this.teacherPhone,
    this.subjectName,
    this.subjectCode,
    this.niveauName,
    this.niveauCode,
    this.className,
  });

  factory TeacherAssignmentModel.fromJson(Map<String, dynamic> json) {
    // Extract nested teacher data
    final teacher = json['teacher'] ?? json['users'];
    final subject = json['subject'] ?? json['subjects'];
    final niveau = json['niveau'] ?? json['niveaux'];
    final classe = json['classe'] ?? json['classes'];

    return TeacherAssignmentModel(
      id: json['id'] ?? '',
      schoolId: json['school_id'] ?? '',
      teacherId: json['teacher_id'] ?? '',
      subjectId: json['subject_id'] ?? '',
      niveauId: json['niveau_id'],
      classId: json['class_id'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      teacherName: _extractField(teacher, 'full_name'),
      teacherEmail: _extractField(teacher, 'email'),
      teacherPhone: _extractField(teacher, 'phone'),
      subjectName: _extractField(subject, 'name'),
      subjectCode: _extractField(subject, 'code'),
      niveauName: _extractField(niveau, 'name'),
      niveauCode: _extractField(niveau, 'code'),
      className: _extractField(classe, 'name'),
    );
  }

  static String? _extractField(dynamic data, String field) {
    if (data == null) return null;
    if (data is Map) return data[field]?.toString();
    if (data is List && data.isNotEmpty) return data[0][field]?.toString();
    return null;
  }

  Map<String, dynamic> toJson() => {
        'school_id': schoolId,
        'teacher_id': teacherId,
        'subject_id': subjectId,
        'niveau_id': niveauId,
        'class_id': classId,
        'is_active': isActive,
      };

  TeacherAssignmentModel copyWith({
    String? id,
    String? schoolId,
    String? teacherId,
    String? subjectId,
    String? niveauId,
    String? classId,
    bool? isActive,
    DateTime? createdAt,
    String? teacherName,
    String? teacherEmail,
    String? teacherPhone,
    String? subjectName,
    String? subjectCode,
    String? niveauName,
    String? niveauCode,
    String? className,
  }) {
    return TeacherAssignmentModel(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      teacherId: teacherId ?? this.teacherId,
      subjectId: subjectId ?? this.subjectId,
      niveauId: niveauId ?? this.niveauId,
      classId: classId ?? this.classId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      teacherName: teacherName ?? this.teacherName,
      teacherEmail: teacherEmail ?? this.teacherEmail,
      teacherPhone: teacherPhone ?? this.teacherPhone,
      subjectName: subjectName ?? this.subjectName,
      subjectCode: subjectCode ?? this.subjectCode,
      niveauName: niveauName ?? this.niveauName,
      niveauCode: niveauCode ?? this.niveauCode,
      className: className ?? this.className,
    );
  }
}

/// Grouped view: a teacher with all their assignments
class TeacherWithAssignments {
  final String teacherId;
  final String teacherName;
  final String? teacherEmail;
  final String? teacherPhone;
  final List<TeacherAssignmentModel> assignments;

  TeacherWithAssignments({
    required this.teacherId,
    required this.teacherName,
    this.teacherEmail,
    this.teacherPhone,
    required this.assignments,
  });

  /// Unique subjects this teacher teaches
  Set<String> get subjectNames =>
      assignments.map((a) => a.subjectName ?? '').where((n) => n.isNotEmpty).toSet();

  Set<String> get subjectIds =>
      assignments.map((a) => a.subjectId).toSet();

  /// Unique niveaux this teacher teaches
  Set<String> get niveauNames =>
      assignments
          .where((a) => a.niveauName != null)
          .map((a) => a.niveauName!)
          .toSet();

  Set<String> get niveauIds =>
      assignments
          .where((a) => a.niveauId != null)
          .map((a) => a.niveauId!)
          .toSet();

  /// Unique classes this teacher teaches
  Set<String> get classNames =>
      assignments
          .where((a) => a.className != null)
          .map((a) => a.className!)
          .toSet();

  Set<String> get classIds =>
      assignments
          .where((a) => a.classId != null)
          .map((a) => a.classId!)
          .toSet();

  /// Group assignments by subject
  Map<String, List<TeacherAssignmentModel>> get assignmentsBySubject {
    final map = <String, List<TeacherAssignmentModel>>{};
    for (final a in assignments) {
      final key = a.subjectName ?? a.subjectId;
      map.putIfAbsent(key, () => []).add(a);
    }
    return map;
  }

  /// Factory to create from a list of assignments for a single teacher
  static List<TeacherWithAssignments> groupByTeacher(
      List<TeacherAssignmentModel> allAssignments) {
    final map = <String, List<TeacherAssignmentModel>>{};
    for (final a in allAssignments) {
      map.putIfAbsent(a.teacherId, () => []).add(a);
    }

    return map.entries.map((entry) {
      final first = entry.value.first;
      return TeacherWithAssignments(
        teacherId: entry.key,
        teacherName: first.teacherName ?? 'Inconnu',
        teacherEmail: first.teacherEmail,
        teacherPhone: first.teacherPhone,
        assignments: entry.value,
      );
    }).toList()
      ..sort((a, b) => a.teacherName.compareTo(b.teacherName));
  }
}
