import '../../core/l10n/app_localizations.dart';

class DocumentTypeHelper {
  static const Map<String, String> types = {
    'administrative': 'Administratif',
    'attestation': 'Attestation de scolarité',
    'releve_notes': 'Relevé de notes',
    'certificat': 'Certificat d\'inscription',
    'carte_etudiant': 'Carte d\'étudiant',
    'exams': 'Examens & Évaluations',
    'planning': 'Emploi du temps & Planning',
    'courses': 'Supports de cours & Syllabus',
    'stage_pfe': 'Convention de stage / PFE',
    'reglement': 'Règlement intérieur',
    'other': 'Autre document',
  };

  static String getLabel(String? category, [AppLocalizations? l10n]) {
    if (category == null || category.isEmpty || category == 'all' || category == '__ALL__') {
      return l10n?.allTypes ?? 'Tous les types';
    }
    if (l10n != null) {
      final key = 'doc_type_$category';
      final localized = l10n.translate(key);
      if (localized != key && localized.isNotEmpty) {
        return localized;
      }
    }
    return types[category] ?? (category[0].toUpperCase() + category.substring(1));
  }
}

class DocumentModel {
  final String id;
  final String schoolId;
  final String? classId;
  final String title;
  final String? description;
  final String category; // administrative, attestation, releve_notes, certificat, carte_etudiant, exams, planning, courses, stage_pfe, reglement, other
  final int? semester;
  final String fileUrl;
  final String fileName;
  final int? fileSize;
  final String? mimeType;
  final String? uploadedBy;
  final String? studentId;
  final String? studentName;
  final String? studentCode;
  final DateTime createdAt;

  DocumentModel({
    required this.id,
    required this.schoolId,
    this.classId,
    required this.title,
    this.description,
    required this.category,
    this.semester,
    required this.fileUrl,
    required this.fileName,
    this.fileSize,
    this.mimeType,
    this.uploadedBy,
    this.studentId,
    this.studentName,
    this.studentCode,
    required this.createdAt,
  });

  static final RegExp _semesterTagRegex =
      RegExp(r'\[Semestre:\s*(\d+)\]', caseSensitive: false);
  static final RegExp _typeTagRegex =
      RegExp(r'\[Type:\s*([^\]]+)\]', caseSensitive: false);
  static final RegExp _studentTagRegex =
      RegExp(r'\[Student:\s*([^\]]+)\]', caseSensitive: false);
  static final RegExp _allMetaTagsRegex =
      RegExp(r'\s*\[(?:Semestre|Type|Student):\s*[^\]]*\]', caseSensitive: false);

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    final rawDescription = json['description'] as String?;

    int? parsedSemester = json['semester'] is int
        ? json['semester'] as int
        : int.tryParse(json['semester']?.toString() ?? '');
    if (parsedSemester == null && rawDescription != null) {
      final semMatch = _semesterTagRegex.firstMatch(rawDescription);
      if (semMatch != null) {
        parsedSemester = int.tryParse(semMatch.group(1) ?? '');
      }
    }

    String? parsedType;
    if (rawDescription != null) {
      final typeMatch = _typeTagRegex.firstMatch(rawDescription);
      if (typeMatch != null) {
        final rawType = typeMatch.group(1)?.trim();
        if (rawType != null && rawType.isNotEmpty) {
          parsedType = rawType;
        }
      }
    }

    String? parsedStudentId = json['student_id'] as String?;
    String? parsedStudentName = json['student_name'] as String?;
    String? parsedStudentCode = json['student_code'] as String?;
    if ((parsedStudentId == null || parsedStudentId.isEmpty) &&
        rawDescription != null) {
      final studentMatch = _studentTagRegex.firstMatch(rawDescription);
      if (studentMatch != null) {
        final parts = (studentMatch.group(1) ?? '').split('|');
        if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
          parsedStudentId = parts[0].trim();
        }
        if (parts.length > 1 && parts[1].trim().isNotEmpty) {
          parsedStudentName = parts[1].trim();
        }
        if (parts.length > 2 && parts[2].trim().isNotEmpty) {
          parsedStudentCode = parts[2].trim();
        }
      }
    }

    final dbCategory = json['category'] as String? ?? 'other';
    final effectiveCategory = parsedType ?? dbCategory;

    return DocumentModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String,
      classId: json['class_id'] as String?,
      title: json['title'] as String,
      description: rawDescription,
      category: effectiveCategory,
      semester: parsedSemester,
      fileUrl: json['file_url'] as String,
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] is int
          ? json['file_size'] as int
          : int.tryParse(json['file_size']?.toString() ?? ''),
      mimeType: json['mime_type'] as String?,
      uploadedBy: json['uploaded_by'] as String?,
      studentId: parsedStudentId,
      studentName: parsedStudentName,
      studentCode: parsedStudentCode,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'class_id': classId,
      'title': title,
      'description': description,
      'category': category,
      'semester': semester,
      'file_url': fileUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'uploaded_by': uploadedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  int get effectiveSemester {
    if (semester != null && semester! > 0) return semester!;
    final lower = title.toLowerCase();
    if (lower.contains('s1') || lower.contains('semestre 1') || lower.contains('semester 1')) return 1;
    if (lower.contains('s2') || lower.contains('semestre 2') || lower.contains('semester 2')) return 2;
    if (lower.contains('s3') || lower.contains('semestre 3') || lower.contains('semester 3')) return 3;
    if (lower.contains('s4') || lower.contains('semestre 4') || lower.contains('semester 4')) return 4;
    if (createdAt.month >= 9 || createdAt.month == 1) return 1;
    if (createdAt.month >= 2 && createdAt.month <= 6) return 2;
    return 1;
  }

  /// User-facing description with internal admin metadata tags stripped.
  String? get cleanDescription {
    if (description == null) return null;
    final cleaned = description!.replaceAll(_allMetaTagsRegex, '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Enforces per-student, per-class, or school-wide visibility rules:
  /// - Dedicated `[Student: id|...]` doc -> only that student sees it
  /// - Class doc (`classId != null`) -> only students in that class see it
  /// - Otherwise -> school-wide document visible to all students in the school
  bool isVisibleToStudent({String? userId, String? classId}) {
    if (studentId != null && studentId!.isNotEmpty) {
      return userId != null && userId == studentId;
    }
    if (this.classId != null && this.classId!.isNotEmpty) {
      return classId != null && classId == this.classId;
    }
    return true;
  }

  /// Whether the document belongs to [selectedSemesterNumber].
  /// Docs explicitly tagged (or titled) with a semester match strictly;
  /// completely untagged docs remain accessible in any semester view.
  bool matchesSemester(int selectedSemesterNumber) {
    if (semester != null && semester! > 0) {
      return semester == selectedSemesterNumber;
    }
    final lower = title.toLowerCase();
    if (lower.contains('s1') ||
        lower.contains('semestre 1') ||
        lower.contains('semester 1') ||
        lower.contains('trimestre 1')) {
      return selectedSemesterNumber == 1;
    }
    if (lower.contains('s2') ||
        lower.contains('semestre 2') ||
        lower.contains('semester 2') ||
        lower.contains('trimestre 2')) {
      return selectedSemesterNumber == 2;
    }
    if (lower.contains('s3') ||
        lower.contains('semestre 3') ||
        lower.contains('semester 3') ||
        lower.contains('trimestre 3')) {
      return selectedSemesterNumber == 3;
    }
    return true;
  }

  String displayCategory([AppLocalizations? l10n]) => DocumentTypeHelper.getLabel(category, l10n);

  String get displayFileSize {
    if (fileSize == null) return '';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isPdf => mimeType == 'application/pdf' || fileName.endsWith('.pdf');
  bool get isImage => mimeType?.startsWith('image/') ?? false;
}
