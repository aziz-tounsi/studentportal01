import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/supabase_config.dart';

class AcademicDocumentType {
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

  static String getLabel(String? category) {
    if (category == null || category.isEmpty || category == 'all') {
      return 'Tous les types';
    }
    return types[category] ?? (category[0].toUpperCase() + category.substring(1));
  }
}

class Document {
  final String id;
  final String schoolId;
  final String? classId;
  final String title;
  final String? description;
  final String category;
  final int semester;
  final String fileUrl;
  final String? fileType;
  final DateTime createdAt;
  final String? className;

  Document({
    required this.id,
    required this.schoolId,
    this.classId,
    required this.title,
    this.description,
    this.category = 'administrative',
    this.semester = 1,
    required this.fileUrl,
    this.fileType,
    required this.createdAt,
    this.className,
  });

  factory Document.fromJson(Map<String, dynamic> json) => Document(
    id: json['id']?.toString() ?? '',
    schoolId: json['school_id']?.toString() ?? '',
    classId: json['class_id']?.toString(),
    title: json['title']?.toString() ?? '',
    description: json['description']?.toString(),
    category: json['category']?.toString() ?? 'administrative',
    semester: json['semester'] is int
        ? json['semester'] as int
        : int.tryParse(json['semester']?.toString() ?? '1') ?? 1,
    fileUrl: json['file_url']?.toString() ?? '',
    fileType: json['file_type']?.toString(),
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    className: json['classes']?['name']?.toString(),
  );
}

class DocumentsState {
  final List<Document> documents;
  DocumentsState({this.documents = const []});

  DocumentsState copyWith({List<Document>? documents}) =>
    DocumentsState(documents: documents ?? this.documents);
}

class DocumentsNotifier extends AsyncNotifier<DocumentsState> {
  @override
  Future<DocumentsState> build() async => _load();

  Future<DocumentsState> _load() async {
    final supabase = SupabaseConfig.client;
    final user = supabase.auth.currentUser;
    if (user == null) throw Exception('Non connecte');

    final profile = await supabase.from('users').select('school_id').eq('id', user.id).single();
    final data = await supabase.from('documents').select('*, classes(name)').eq('school_id', profile['school_id']).order('created_at', ascending: false);

    return DocumentsState(documents: (data as List).map((e) => Document.fromJson(e)).toList());
  }

  Future<void> create({
    required String title,
    String? description,
    required String fileUrl,
    String? fileType,
    String? classId,
    String category = 'administrative',
    int semester = 1,
  }) async {
    final supabase = SupabaseConfig.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final profile = await supabase.from('users').select('school_id').eq('id', user.id).single();
    await supabase.from('documents').insert({
      'school_id': profile['school_id'],
      'class_id': classId,
      'title': title,
      'description': description,
      'file_url': fileUrl,
      'file_type': fileType,
      'category': category,
      'semester': semester,
    });
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await SupabaseConfig.client.from('documents').delete().eq('id', id);
    ref.invalidateSelf();
  }
}

final documentsProvider = AsyncNotifierProvider<DocumentsNotifier, DocumentsState>(DocumentsNotifier.new);