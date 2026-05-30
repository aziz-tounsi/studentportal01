import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../user_avatar.dart';

/// A panel for entering grades per student across all subjects and exam types
/// Shows a grid where admin can enter all grades for one student at a time
class StudentGradeEntryPanel extends StatefulWidget {
  final List<Map<String, dynamic>> subjectOfferings;
  final List<Map<String, dynamic>> enrolledStudents;
  final Function(List<Map<String, dynamic>> grades) onSaveGrades;
  final VoidCallback? onRefresh;

  const StudentGradeEntryPanel({
    super.key,
    required this.subjectOfferings,
    required this.enrolledStudents,
    required this.onSaveGrades,
    this.onRefresh,
  });

  @override
  State<StudentGradeEntryPanel> createState() => _StudentGradeEntryPanelState();
}

class _StudentGradeEntryPanelState extends State<StudentGradeEntryPanel> {
  int _selectedStudentIndex = 0;
  final Map<String, Map<String, TextEditingController>> _gradeControllers = {};
  final Map<String, Map<String, String>> _gradeStatus =
      {}; // subject_offering_id -> component_id -> status
  bool _isSaving = false;
  bool _isLoading = false;

  Map<String, dynamic> get _currentStudent {
    if (widget.enrolledStudents.isEmpty) return {};
    return widget.enrolledStudents[_selectedStudentIndex];
  }

  String get _currentEnrollmentId => _currentStudent['id'] as String? ?? '';

  /// Get the student's full name from nested users object
  String get _currentStudentName {
    final users = _currentStudent['users'] as Map<String, dynamic>?;
    if (users != null) {
      return users['full_name'] as String? ?? 'Élève';
    }
    // Fallback to direct fields
    final firstName = _currentStudent['first_name'] ?? '';
    final lastName = _currentStudent['last_name'] ?? '';
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      return '$firstName $lastName'.trim();
    }
    return 'Élève';
  }

  /// Get initials for the avatar
  String get _currentStudentInitials {
    final name = _currentStudentName;
    if (name.isEmpty || name == 'Élève') return '?';
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  /// Get student code from enrollment or nested users object
  String get _currentStudentCode {
    // First try enrollment's student_code
    final enrollmentCode = _currentStudent['student_code'];
    if (enrollmentCode != null && enrollmentCode.toString().isNotEmpty) {
      return enrollmentCode.toString();
    }
    // Then try from nested users object
    final users = _currentStudent['users'] as Map<String, dynamic>?;
    if (users != null) {
      final userCode = users['student_code'];
      if (userCode != null && userCode.toString().isNotEmpty) {
        return userCode.toString();
      }
    }
    return 'N/A';
  }

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final subjectControllers in _gradeControllers.values) {
      for (final controller in subjectControllers.values) {
        controller.dispose();
      }
    }
    _gradeControllers.clear();
    _gradeStatus.clear();
  }

  void _initControllers() {
    _disposeControllers();

    // Create controllers for each subject offering and each component
    for (final offering in widget.subjectOfferings) {
      final offeringId = offering['id'] as String;
      final components = offering['grade_components'] as List?;

      if (components != null && components.isNotEmpty) {
        _gradeControllers[offeringId] = {};
        _gradeStatus[offeringId] = {};

        for (final comp in components) {
          final componentId = comp['id'] as String;
          _gradeControllers[offeringId]![componentId] = TextEditingController();
          _gradeStatus[offeringId]![componentId] = 'OK';
        }
      }
    }
  }

  Future<void> _loadExistingGrades() async {
    // This would be called to load existing grades for the current student
    // For now, we'll clear all fields
    for (final subjectControllers in _gradeControllers.values) {
      for (final controller in subjectControllers.values) {
        controller.clear();
      }
    }
  }

  Future<void> _saveGrades() async {
    if (_currentEnrollmentId.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final grades = <Map<String, dynamic>>[];
      // Get user_id from either direct field or nested users object
      String? userId = _currentStudent['user_id'] as String?;
      if (userId == null) {
        final users = _currentStudent['users'] as Map<String, dynamic>?;
        userId = users?['id'] as String?;
      }

      if (userId == null) {
        throw Exception('User ID not found for student');
      }

      for (final offering in widget.subjectOfferings) {
        final offeringId = offering['id'] as String;
        final subjectControllers = _gradeControllers[offeringId];
        final subjectStatus = _gradeStatus[offeringId];

        if (subjectControllers == null || subjectStatus == null) continue;

        for (final entry in subjectControllers.entries) {
          final componentId = entry.key;
          final controller = entry.value;
          final status = subjectStatus[componentId] ?? 'OK';

          double? gradeValue;
          if (controller.text.isNotEmpty) {
            gradeValue = double.tryParse(controller.text.replaceAll(',', '.'));
          }

          grades.add({
            'enrollment_id': _currentEnrollmentId,
            'student_id': userId,
            'subject_offering_id': offeringId,
            'component_id': componentId,
            'grade_value': gradeValue,
            'status': status,
          });
        }
      }

      await widget.onSaveGrades(grades);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notes enregistrées pour $_currentStudentName'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _navigateToStudent(int delta) {
    final newIndex = _selectedStudentIndex + delta;
    if (newIndex >= 0 && newIndex < widget.enrolledStudents.length) {
      setState(() {
        _selectedStudentIndex = newIndex;
      });
      _loadExistingGrades();
    }
  }

  String _getComponentDisplayName(String name) {
    switch (name.toUpperCase()) {
      case 'ORALE':
        return 'Orale';
      case 'CC':
        return 'CC';
      case 'SYNTHESE':
      case 'SYNTHÈSE':
        return 'Synthèse';
      default:
        return name;
    }
  }

  Color _getComponentColor(String name) {
    switch (name.toUpperCase()) {
      case 'ORALE':
        return const Color(0xFF3B82F6); // Blue
      case 'CC':
        return const Color(0xFF8B5CF6); // Purple
      case 'SYNTHESE':
      case 'SYNTHÈSE':
        return const Color(0xFFEC4899); // Pink
      default:
        return const Color(0xFF64748B); // Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.enrolledStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: AppColors.slate400),
            const SizedBox(height: 16),
            Text(
              'Aucun élève inscrit',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (widget.subjectOfferings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: AppColors.slate400),
            const SizedBox(height: 16),
            Text(
              'Aucune matière assignée à cette classe',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Veuillez configurer les matières pour cette classe',
              style: TextStyle(fontSize: 14, color: AppColors.slate500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildStudentNavigator(),
        const Divider(height: 1),
        Expanded(child: _buildGradeGrid()),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildStudentNavigator() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          // Previous student button
          IconButton(
            onPressed: _selectedStudentIndex > 0
                ? () => _navigateToStudent(-1)
                : null,
            icon: const Icon(Icons.chevron_left),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: const Color(0xFF3B82F6),
              disabledBackgroundColor: AppColors.slate200,
            ),
          ),
          const SizedBox(width: 12),
          // Student info
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    name: _currentStudentName,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentStudentName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Matricule: $_currentStudentCode',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${_selectedStudentIndex + 1} / ${widget.enrolledStudents.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Next student button
          IconButton(
            onPressed:
                _selectedStudentIndex < widget.enrolledStudents.length - 1
                ? () => _navigateToStudent(1)
                : null,
            icon: const Icon(Icons.chevron_right),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: const Color(0xFF3B82F6),
              disabledBackgroundColor: AppColors.slate200,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeGrid() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Saisissez les notes pour chaque matière et type d\'examen. Laissez vide si non disponible.',
                    style: TextStyle(fontSize: 13, color: AppColors.slate700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Grade grid
          ...widget.subjectOfferings.map((offering) {
            return _buildSubjectRow(offering);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(Map<String, dynamic> offering) {
    final subject = offering['subjects'] as Map<String, dynamic>?;
    final subjectName = subject?['name'] as String? ?? 'Matière';
    final coefficient = offering['coefficient'] as num? ?? 1.0;
    final components = offering['grade_components'] as List?;
    final offeringId = offering['id'] as String;

    if (components == null || components.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.book, color: AppColors.slate400),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subjectName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Coef: $coefficient',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Aucun type d\'examen',
                style: TextStyle(fontSize: 13, color: AppColors.slate500),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject header
            Row(
              children: [
                const Icon(Icons.book, color: Color(0xFF3B82F6), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subjectName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Coef: $coefficient',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Component grades
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: components.map((comp) {
                return _buildComponentField(offeringId, comp);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentField(
    String offeringId,
    Map<String, dynamic> component,
  ) {
    final componentId = component['id'] as String;
    final name = component['name'] as String? ?? 'Note';
    final weight = component['weight_percent'] as num? ?? 0;
    final displayName = _getComponentDisplayName(name);
    final color = _getComponentColor(name);

    final controller = _gradeControllers[offeringId]?[componentId];
    final currentStatus = _gradeStatus[offeringId]?[componentId] ?? 'OK';

    if (controller == null) return const SizedBox.shrink();

    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$weight%',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: currentStatus == 'OK',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*[.,]?\d{0,2}'),
                    ),
                  ],
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppColors.slate400,
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(
                        color: Color(0xFF3B82F6),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: currentStatus == 'OK'
                        ? AppColors.surface
                        : AppColors.slate100,
                    suffixText: '/20',
                    suffixStyle: TextStyle(
                      fontSize: 11,
                      color: AppColors.slate500,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                initialValue: currentStatus,
                onSelected: (value) {
                  setState(() {
                    _gradeStatus[offeringId]![componentId] = value;
                    if (value != 'OK') {
                      controller.clear();
                    }
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'OK', child: Text('Note')),
                  const PopupMenuItem(
                    value: 'ND',
                    child: Text('ND (Non Dispensé)'),
                  ),
                  const PopupMenuItem(
                    value: 'NP',
                    child: Text('NP (Non Présent)'),
                  ),
                ],
                icon: Icon(
                  currentStatus == 'OK' ? Icons.edit : Icons.info_outline,
                  size: 18,
                  color: currentStatus == 'OK'
                      ? AppColors.slate400
                      : AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.slate200)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (widget.onRefresh != null)
            OutlinedButton.icon(
              onPressed: _isSaving ? null : widget.onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Actualiser'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          const Spacer(),
          OutlinedButton(
            onPressed: _isSaving
                ? null
                : () {
                    // Clear all fields
                    for (final subjectControllers in _gradeControllers.values) {
                      for (final controller in subjectControllers.values) {
                        controller.clear();
                      }
                    }
                    setState(() {});
                  },
            child: const Text('Effacer tout'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveGrades,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.textOnPrimary),
                    ),
                  )
                : const Icon(Icons.save, size: 18),
            label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
