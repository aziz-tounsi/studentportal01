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
    required this.createdAt,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String,
      classId: json['class_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'other',
      semester: json['semester'] is int
          ? json['semester'] as int
          : int.tryParse(json['semester']?.toString() ?? ''),
      fileUrl: json['file_url'] as String,
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      uploadedBy: json['uploaded_by'] as String?,
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
