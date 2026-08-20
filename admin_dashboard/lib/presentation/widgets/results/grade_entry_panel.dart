import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../presentation/widgets/ios_loader.dart';

/// A panel for entering grades by subject and exam type
/// Workflow: Select Subject → Select Exam Type → Enter grades for all students
class GradeEntryPanel extends StatefulWidget {
  final List<Map<String, dynamic>> subjectOfferings;
  final List<Map<String, dynamic>> enrolledStudents;
  final Function(List<Map<String, dynamic>> grades) onSaveGrades;
  final VoidCallback? onRefresh;

  const GradeEntryPanel({
    super.key,
    required this.subjectOfferings,
    required this.enrolledStudents,
    required this.onSaveGrades,
    this.onRefresh,
  });

  @override
  State<GradeEntryPanel> createState() => _GradeEntryPanelState();
}

class _GradeEntryPanelState extends State<GradeEntryPanel> {
  String? _selectedSubjectOfferingId;
  String? _selectedComponentId;
  final Map<String, TextEditingController> _gradeControllers = {};
  final Map<String, String> _gradeStatus = {}; // 'OK', 'ND', 'NP'
  bool _isSaving = false;

  Map<String, dynamic>? get _selectedSubject {
    if (_selectedSubjectOfferingId == null) return null;
    return widget.subjectOfferings.firstWhere(
      (s) => s['id'] == _selectedSubjectOfferingId,
      orElse: () => {},
    );
  }

  List<Map<String, dynamic>> get _components {
    final subject = _selectedSubject;
    if (subject == null) return [];
    final comps = subject['grade_components'] as List?;
    return comps?.cast<Map<String, dynamic>>() ?? [];
  }

  Map<String, dynamic>? get _selectedComponent {
    if (_selectedComponentId == null) return null;
    return _components.firstWhere(
      (c) => c['id'] == _selectedComponentId,
      orElse: () => {},
    );
  }

  @override
  void dispose() {
    for (final c in _gradeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _initControllersForStudents() {
    // Clear old controllers
    for (final c in _gradeControllers.values) {
      c.dispose();
    }
    _gradeControllers.clear();
    _gradeStatus.clear();

    // Create new controllers for each student
    for (final student in widget.enrolledStudents) {
      final id = student['id'] as String;
      _gradeControllers[id] = TextEditingController();
      _gradeStatus[id] = 'OK'; // Default status
    }
  }

  Future<void> _saveGrades() async {
    if (_selectedSubjectOfferingId == null || _selectedComponentId == null) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final grades = <Map<String, dynamic>>[];

      for (final student in widget.enrolledStudents) {
        final enrollmentId = student['id'] as String;
        final userId = student['user_id'] as String;
        final controller = _gradeControllers[enrollmentId];
        final status = _gradeStatus[enrollmentId] ?? 'OK';

        double? gradeValue;
        if (controller != null && controller.text.isNotEmpty) {
          gradeValue = double.tryParse(controller.text.replaceAll(',', '.'));
        }

        grades.add({
          'enrollment_id': enrollmentId,
          'student_id': userId,
          'subject_offering_id': _selectedSubjectOfferingId,
          'component_id': _selectedComponentId,
          'grade_value': gradeValue,
          'status': status == 'OK' && gradeValue != null ? 'OK' : status,
        });
      }

      await widget.onSaveGrades(grades);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${grades.length} notes enregistrées'),
            backgroundColor: const Color(0xFF10B981),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(),
          const Divider(height: 1),

          // Step indicators
          _buildStepIndicators(),
          const Divider(height: 1),

          // Content based on selection state
          Expanded(child: _buildContent()),

          // Save button
          if (_selectedSubjectOfferingId != null &&
              _selectedComponentId != null)
            _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note, color: AppColors.textOnPrimary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saisie des Notes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnPrimary,
                  ),
                ),
                Text(
                  '${widget.enrolledStudents.length} élèves • ${widget.subjectOfferings.length} matières',
                  style: TextStyle(
                    color: AppColors.textOnPrimary.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (widget.onRefresh != null)
            IconButton(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh, color: AppColors.textOnPrimary),
              tooltip: 'Actualiser',
            ),
        ],
      ),
    );
  }

  Widget _buildStepIndicators() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          _buildStep(
            number: 1,
            label: 'Matière',
            isActive: true,
            isCompleted: _selectedSubjectOfferingId != null,
          ),
          _buildStepConnector(_selectedSubjectOfferingId != null),
          _buildStep(
            number: 2,
            label: 'Type d\'examen',
            isActive: _selectedSubjectOfferingId != null,
            isCompleted: _selectedComponentId != null,
          ),
          _buildStepConnector(_selectedComponentId != null),
          _buildStep(
            number: 3,
            label: 'Notes',
            isActive: _selectedComponentId != null,
            isCompleted: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required int number,
    required String label,
    required bool isActive,
    required bool isCompleted,
  }) {
    final color = isCompleted
        ? const Color(0xFF10B981)
        : isActive
        ? const Color(0xFF3B82F6)
        : const Color(0xFF94A3B8);

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted ? color : color.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: AppColors.textOnPrimary, size: 18)
                : Text(
                    '$number',
                    style: TextStyle(color: color, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isActive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedSubjectOfferingId == null) {
      return _buildSubjectSelection();
    }

    if (_selectedComponentId == null) {
      return _buildComponentSelection();
    }

    return _buildGradeEntry();
  }

  Widget _buildSubjectSelection() {
    if (widget.subjectOfferings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 48, color: AppColors.warning),
            const SizedBox(height: 16),
            const Text(
              'Aucune matière disponible',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sélectionnez un semestre pour voir les matières',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.subjectOfferings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final subject = widget.subjectOfferings[index];
        final subjectData = subject['subjects'] as Map<String, dynamic>?;
        final name = subjectData?['name'] ?? 'Matière inconnue';
        final code = subjectData?['code'] ?? '';
        final coef = subject['coefficient'] ?? 1.0;
        final components = (subject['grade_components'] as List?) ?? [];

        return InkWell(
          onTap: () {
            setState(() {
              _selectedSubjectOfferingId = subject['id'];
              _selectedComponentId = null;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                // Subject icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      code.isNotEmpty
                          ? code.substring(0, code.length.clamp(0, 3))
                          : '📚',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Subject info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildTag('Coef $coef', const Color(0xFF6366F1)),
                          const SizedBox(width: 8),
                          _buildTag(
                            '${components.length} types',
                            const Color(0xFF10B981),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildComponentSelection() {
    final subject = _selectedSubject;
    final subjectData = subject?['subjects'] as Map<String, dynamic>?;
    final subjectName = subjectData?['name'] ?? 'Matière';

    if (_components.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 48, color: AppColors.warning),
            const SizedBox(height: 16),
            Text(
              'Aucun type d\'examen pour $subjectName',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedSubjectOfferingId = null;
                });
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Retour aux matières'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Back button and subject name
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFF1F5F9),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedSubjectOfferingId = null;
                    _selectedComponentId = null;
                  });
                },
                icon: const Icon(Icons.arrow_back, size: 20),
                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.book, color: Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text(
                subjectName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        // Component list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _components.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final comp = _components[index];
              final name = _getComponentDisplayName(
                comp['name']?.toString() ?? 'Note',
              );
              final weight = comp['weight_percent'] ?? 0;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedComponentId = comp['id'];
                    _initControllersForStudents();
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _getComponentColor(name).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            _getComponentIcon(name),
                            color: _getComponentColor(name),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Poids: ${weight.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGradeEntry() {
    final subject = _selectedSubject;
    final subjectData = subject?['subjects'] as Map<String, dynamic>?;
    final subjectName = subjectData?['name'] ?? 'Matière';
    final component = _selectedComponent;
    final componentName = _getComponentDisplayName(
      component?['name']?.toString() ?? 'Note',
    );

    return Column(
      children: [
        // Header with back and info
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFF1F5F9),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedComponentId = null;
                  });
                },
                icon: const Icon(Icons.arrow_back, size: 20),
                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subjectName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      componentName,
                      style: const TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Quick stats
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.enrolledStudents.length} élèves',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Students list with grade inputs
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.enrolledStudents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final student = widget.enrolledStudents[index];
              final user = student['users'] as Map<String, dynamic>?;
              final enrollmentId = student['id'] as String;
              final name = user?['full_name'] ?? 'Élève inconnu';
              final code =
                  student['student_code'] ?? user?['student_code'] ?? '';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Student number
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3B82F6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Student info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if (code.isNotEmpty)
                            Text(
                              code,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Status dropdown
                    Container(
                      width: 70,
                      margin: const EdgeInsets.only(right: 8),
                      child: DropdownButtonFormField<String>(
                        value: _gradeStatus[enrollmentId] ?? 'OK',
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'OK',
                            child: Text('OK', style: TextStyle(fontSize: 12)),
                          ),
                          DropdownMenuItem(
                            value: 'ND',
                            child: Text('ND', style: TextStyle(fontSize: 12)),
                          ),
                          DropdownMenuItem(
                            value: 'NP',
                            child: Text('NP', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _gradeStatus[enrollmentId] = v ?? 'OK';
                          });
                        },
                      ),
                    ),
                    // Grade input
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: _gradeControllers[enrollmentId],
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d{0,2}([.,]\d{0,2})?'),
                          ),
                        ],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: '/20',
                          hintStyle: const TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontWeight: FontWeight.w400,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF3B82F6),
                              width: 2,
                            ),
                          ),
                        ),
                        enabled: _gradeStatus[enrollmentId] == 'OK',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          // Cancel button
          TextButton(
            onPressed: _isSaving
                ? null
                : () {
                    setState(() {
                      _selectedSubjectOfferingId = null;
                      _selectedComponentId = null;
                    });
                  },
            child: const Text('Annuler'),
          ),
          const Spacer(),
          // Save button
          FilledButton.icon(
            onPressed: _isSaving ? null : _saveGrades,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            icon: _isSaving
                ? const IosLoader(
                    size: 18,
                    color: AppColors.textOnPrimary,
                  )
                : const Icon(Icons.save),
            label: Text(
              _isSaving ? 'Enregistrement...' : 'Enregistrer les notes',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _getComponentDisplayName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('synthese') || lower.contains('ds'))
      return 'Devoir de Synthèse';
    if (lower.contains('cc') || lower.contains('controle'))
      return 'Contrôle Continu';
    if (lower.contains('oral')) return 'Oral';
    if (lower.contains('tp') || lower.contains('pratique'))
      return 'Travaux Pratiques';
    if (lower.contains('examen')) return 'Examen';
    return name;
  }

  Color _getComponentColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('synthèse') || lower.contains('ds'))
      return const Color(0xFFEF4444);
    if (lower.contains('contrôle') || lower.contains('cc'))
      return const Color(0xFF3B82F6);
    if (lower.contains('oral')) return const Color(0xFF8B5CF6);
    if (lower.contains('tp') || lower.contains('pratique'))
      return const Color(0xFF10B981);
    return const Color(0xFF6366F1);
  }

  IconData _getComponentIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('synthèse') || lower.contains('ds'))
      return Icons.assignment;
    if (lower.contains('contrôle') || lower.contains('cc')) return Icons.quiz;
    if (lower.contains('oral')) return Icons.mic;
    if (lower.contains('tp') || lower.contains('pratique'))
      return Icons.science;
    return Icons.school;
  }
}
