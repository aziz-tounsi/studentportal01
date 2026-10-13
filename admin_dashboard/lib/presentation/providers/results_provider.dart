import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/grading_config_model.dart';
import '../../data/models/student_result_model.dart';
import '../../data/models/tunisian_coefficients.dart';
import '../../repositories/results_repository.dart';

/// Filter options for results
enum ResultsFilterType {
  byStudent, // Single student
  byClass, // By class
  byGradeLevel, // By grade level (all classes)
  bySchool, // Entire school
}

/// View mode for results
enum ResultsViewMode {
  table, // Table view
  cards, // Card view
  bulletin, // Report card view
}

/// Provider for managing results/grades
class ResultsProvider extends ChangeNotifier {
  final ResultsRepository _repository;

  ResultsProvider(SupabaseClient client)
    : _repository = ResultsRepository(client);

  // State
  bool _isLoading = true;
  String? _error;

  // Filters
  String? _selectedAcademicYearId;
  String? _selectedSemesterId;
  String? _selectedNiveauId;
  String? _selectedSectionId;
  String? _selectedClassId;
  String _searchQuery = '';
  ResultsFilterType _filterType = ResultsFilterType.byClass;
  ResultsViewMode _viewMode = ResultsViewMode.table;

  // Data
  List<Map<String, dynamic>> _academicYears = [];
  List<Map<String, dynamic>> _semesters = [];
  List<Map<String, dynamic>> _niveaux = [];
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _subjectOfferings = [];
  List<Map<String, dynamic>> _enrolledStudents = [];
  List<Map<String, dynamic>> _allEnrolledStudents = []; // global search (not filtered by class)

  // Results
  ClassResult? _classResult;
  StudentResult? _selectedStudentResult;
  GradingConfiguration? _gradingConfig;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;

  String? get selectedAcademicYearId => _selectedAcademicYearId;
  String? get selectedSemesterId => _selectedSemesterId;
  String? get selectedNiveauId => _selectedNiveauId;
  String? get selectedSectionId => _selectedSectionId;
  String? get selectedClassId => _selectedClassId;
  String get searchQuery => _searchQuery;
  ResultsFilterType get filterType => _filterType;
  ResultsViewMode get viewMode => _viewMode;

  List<Map<String, dynamic>> get academicYears => _academicYears;
  List<Map<String, dynamic>> get semesters => _semesters;
  List<Map<String, dynamic>> get niveaux => _niveaux;
  List<Map<String, dynamic>> get sections => _sections;
  List<Map<String, dynamic>> get classes => _classes;

  /// Get classes filtered by selected niveau
  List<Map<String, dynamic>> get filteredClasses {
    if (_selectedNiveauId == null) {
      return _classes;
    }
    final base = _classes.where((c) => c['niveau_id'] == _selectedNiveauId);
    if (_selectedSectionId == null) {
      return base.toList();
    }
    return base.where((c) => c['section_id'] == _selectedSectionId).toList();
  }

  /// Get sections filtered by selected niveau
  List<Map<String, dynamic>> get filteredSections {
    if (_selectedNiveauId == null) {
      return [];
    }
    return _sections;
  }

  bool get selectedNiveauHasSections {
    if (_selectedNiveauId == null) return false;
    final niveau = _niveaux.firstWhere(
      (n) => n['id'] == _selectedNiveauId,
      orElse: () => {},
    );
    return (niveau['has_sections'] == true);
  }

  List<Map<String, dynamic>> get subjectOfferings => _subjectOfferings;
  List<Map<String, dynamic>> get enrolledStudents => _enrolledStudents;
  List<Map<String, dynamic>> get allEnrolledStudents => _allEnrolledStudents;

  ClassResult? get classResult => _classResult;
  StudentResult? get selectedStudentResult => _selectedStudentResult;
  GradingConfiguration? get gradingConfig => _gradingConfig;

  /// Get current academic year name
  String get currentAcademicYearName {
    if (_selectedAcademicYearId == null) return '';
    final year = _academicYears.firstWhere(
      (y) => y['id'] == _selectedAcademicYearId,
      orElse: () => {},
    );
    return year['name'] ?? '';
  }

  /// Get current class name
  String get currentClassName {
    if (_selectedClassId == null) return '';
    final cls = _classes.firstWhere(
      (c) => c['id'] == _selectedClassId,
      orElse: () => {},
    );
    return cls['name'] ?? '';
  }

  /// Get filtered students based on search
  List<StudentResult> get filteredStudents {
    if (_classResult == null) return [];

    if (_searchQuery.isEmpty) {
      return _classResult!.students;
    }

    final query = _searchQuery.toLowerCase();
    return _classResult!.students.where((s) {
      return s.studentName.toLowerCase().contains(query) ||
          s.studentCode.toLowerCase().contains(query) ||
          s.className.toLowerCase().contains(query);
    }).toList();
  }

  /// Initialize provider
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      await loadAcademicYears();
      await loadNiveaux();
      await loadClasses();
      await loadEnrolledStudents(); // Load all students for search
      await loadAllEnrolledStudents(); // Separate list for global search
    } catch (e) {
      debugPrint('❌ Error initializing results provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load ALL enrolled students regardless of class (for global search)
  Future<void> loadAllEnrolledStudents() async {
    try {
      _allEnrolledStudents = await _repository.getEnrolledStudents(
        academicYearId: _selectedAcademicYearId,
        classId: null, // no class filter
        searchQuery: null,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading all enrolled students: $e');
    }
  }

  /// Load niveaux (grade levels)
  Future<void> loadNiveaux() async {
    try {
      _niveaux = await _repository.getNiveaux();
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement des niveaux: $e';
      notifyListeners();
    }
  }

  /// Load sections for selected niveau
  Future<void> loadSectionsForNiveau(String? niveauId) async {
    if (niveauId == null || niveauId.isEmpty) {
      _sections = [];
      _selectedSectionId = null;
      notifyListeners();
      return;
    }

    try {
      _sections = await _repository.getSectionsForNiveau(niveauId);
      if (_selectedSectionId != null) {
        final found = _sections.any((s) => s['id'] == _selectedSectionId);
        if (!found) {
          _selectedSectionId = null;
        }
      }
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement des sections: $e';
      notifyListeners();
    }
  }

  /// Load academic years
  Future<void> loadAcademicYears() async {
    try {
      // Load all academic years (same as Semestres page)
      _academicYears = await _repository.getAcademicYears();

      // Select current year by default
      final current = _academicYears.firstWhere(
        (y) => y['is_current'] == true,
        orElse: () => _academicYears.isNotEmpty ? _academicYears.first : {},
      );

      if (current.isNotEmpty) {
        _selectedAcademicYearId = current['id'];
        await loadSemesters();
      }

      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement des années: $e';
      notifyListeners();
    }
  }

  /// Load semesters — loads semesters for the selected academic year only,
  /// then auto-selects is_current = true
  Future<void> loadSemesters() async {
    try {
      // Filter by the currently selected academic year so we don't get
      // Semestre 1 from 2024-2025 AND Semestre 1 from 2025-2026 simultaneously.
      _semesters = await _repository.getSemesters(_selectedAcademicYearId);

      // Sort by number
      _semesters.sort((a, b) {
        final aNum = (a['number'] as num?)?.toInt() ?? 0;
        final bNum = (b['number'] as num?)?.toInt() ?? 0;
        return aNum.compareTo(bNum);
      });

      debugPrint(
        '📅 Loaded ${_semesters.length} semesters: ${_semesters.map((s) => s['name']).toList()}',
      );

      // Always auto-select the semester flagged is_current = true in the DB
      // (this is exactly what the Semestres page controls)
      final current = _semesters.where((s) => s['is_current'] == true).firstOrNull;
      if (current != null) {
        _selectedSemesterId = current['id'];
      } else if (_semesters.isNotEmpty) {
        _selectedSemesterId = _semesters.last['id'];
      }

      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement des semestres: $e';
      debugPrint('❌ Error loading semesters: $e');
      notifyListeners();
    }
  }

  /// Load classes
  Future<void> loadClasses() async {
    try {
      _classes = await _repository.getClasses();
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement des classes: $e';
      notifyListeners();
    }
  }

  /// Load subject offerings
  Future<void> loadSubjectOfferings() async {
    if (_selectedClassId == null || _selectedSemesterId == null) {
      _subjectOfferings = [];
      notifyListeners();
      return;
    }

    try {
      _subjectOfferings = await _repository.getSubjectOfferings(
        classId: _selectedClassId!,
        semesterId: _selectedSemesterId!,
      );
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement des matières: $e';
      notifyListeners();
    }
  }

  /// Load enrolled students
  Future<void> loadEnrolledStudents() async {
    try {
      // First try with academic year filter
      _enrolledStudents = await _repository.getEnrolledStudents(
        academicYearId: _selectedAcademicYearId,
        classId: _selectedClassId,
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      // If no students found and we have a class selected, try without academic year filter
      if (_enrolledStudents.isEmpty && _selectedClassId != null) {
        debugPrint('🔄 No students found with year filter, trying without...');
        _enrolledStudents = await _repository.getEnrolledStudents(
          academicYearId: null,
          classId: _selectedClassId,
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        );
      }

      debugPrint(
        '📚 Loaded ${_enrolledStudents.length} students for class $_selectedClassId',
      );
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement des élèves: $e';
      debugPrint('❌ Error loading students: $e');
      notifyListeners();
    }
  }

  /// Load grading configuration
  Future<void> loadGradingConfig() async {
    if (_selectedClassId == null) {
      _gradingConfig = TunisianCoefficientTables.getDefaultConfiguration(
        EducationLevel.lycee1,
      );
      notifyListeners();
      return;
    }

    try {
      _gradingConfig = await _repository.getConfigurationForClass(
        _selectedClassId!,
      );
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du chargement de la configuration: $e';
      notifyListeners();
    }
  }

  /// Calculate results for current selection
  Future<void> calculateResults() async {
    if (_selectedClassId == null || _selectedAcademicYearId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Ensure config is loaded
      if (_gradingConfig == null) {
        await loadGradingConfig();
      }

      _classResult = await _repository.calculateClassResult(
        classId: _selectedClassId!,
        academicYearId: _selectedAcademicYearId!,
        config: _gradingConfig!,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du calcul des résultats: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculate result for a single student
  Future<void> calculateStudentResult(String enrollmentId) async {
    if (_gradingConfig == null) {
      await loadGradingConfig();
    }

    _isLoading = true;
    notifyListeners();

    try {
      _selectedStudentResult = await _repository.calculateStudentResult(
        enrollmentId: enrollmentId,
        config: _gradingConfig!,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors du calcul: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save a grade
  Future<void> saveGrade({
    required String enrollmentId,
    required String studentId,
    required String subjectOfferingId,
    required String componentId,
    required double? value,
    String status = 'graded',
  }) async {
    try {
      await _repository.saveGrade(
        enrollmentId: enrollmentId,
        studentId: studentId,
        subjectOfferingId: subjectOfferingId,
        componentId: componentId,
        value: value,
        status: status,
      );

      // Recalculate results
      await calculateResults();
    } catch (e) {
      _error = 'Erreur lors de l\'enregistrement: $e';
      notifyListeners();
    }
  }

  /// Save multiple grades
  Future<void> saveBulkGrades(List<GradeEntry> grades) async {
    _isLoading = true;
    notifyListeners();

    try {
      final gradesData = grades.map((g) => g.toJson()).toList();
      await _repository.saveBulkGrades(gradesData);
      await calculateResults();
    } catch (e) {
      _error = 'Erreur lors de l\'enregistrement: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save grading configuration
  Future<void> saveGradingConfig(GradingConfiguration config) async {
    try {
      await _repository.saveGradingConfiguration(config);
      _gradingConfig = config;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur lors de l\'enregistrement: $e';
      notifyListeners();
    }
  }

  // Setters
  void setAcademicYear(String? yearId) {
    _selectedAcademicYearId = yearId;
    _classResult = null;
    loadSemesters();
    loadEnrolledStudents();
  }

  void setSemester(String? semesterId) {
    _selectedSemesterId = semesterId;
    loadSubjectOfferings();
  }

  void setNiveau(String? niveauId) {
    _selectedNiveauId = niveauId;
    // Reset section and class when niveau changes
    _selectedSectionId = null;
    _selectedClassId = null;
    _classResult = null;
    loadSectionsForNiveau(niveauId);
    notifyListeners();
  }

  void setSection(String? sectionId) {
    _selectedSectionId = sectionId;
    // Reset class when section changes
    _selectedClassId = null;
    _classResult = null;
    notifyListeners();
  }

  Future<void> setClass(String? classId) async {
    _selectedClassId = classId;
    _classResult = null;
    if (classId != null) {
      _isLoading = true;
      notifyListeners();
      try {
        await Future.wait([
          loadGradingConfig(),
          loadSubjectOfferings(),
          loadEnrolledStudents(),
        ]);
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    } else {
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    // Debounce search - call loadEnrolledStudents to search in database
    loadEnrolledStudents();
    notifyListeners();
  }

  void setFilterType(ResultsFilterType type) {
    _filterType = type;
    notifyListeners();
  }

  void setViewMode(ResultsViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }

  void selectStudent(StudentResult student) {
    _selectedStudentResult = student;
    notifyListeners();
  }

  void clearSelectedStudent() {
    _selectedStudentResult = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
