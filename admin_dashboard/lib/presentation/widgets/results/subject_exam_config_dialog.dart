import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../presentation/widgets/ios_loader.dart';

/// Dialog for configuring exam types and percentages for a specific subject offering
/// Can apply configuration to all classes in the same niveau/level
class SubjectExamConfigDialog extends StatefulWidget {
  final String subjectOfferingId;
  final String subjectName;
  final String subjectId; // Subject ID to apply to other classes
  final String?
  levelId; // Level/Niveau ID to apply to all classes in this level
  final String? semesterId; // Current semester
  final List<Map<String, dynamic>> currentComponents;
  final VoidCallback onSaved;

  const SubjectExamConfigDialog({
    super.key,
    required this.subjectOfferingId,
    required this.subjectName,
    required this.subjectId,
    this.levelId,
    this.semesterId,
    required this.currentComponents,
    required this.onSaved,
  });

  @override
  State<SubjectExamConfigDialog> createState() =>
      _SubjectExamConfigDialogState();
}

class _SubjectExamConfigDialogState extends State<SubjectExamConfigDialog> {
  List<_ExamComponentEntry> _components = [];
  List<Map<String, dynamic>> _availableExamTypes = [];
  final Map<int, TextEditingController> _nameControllers = {};
  final Map<int, TextEditingController> _weightControllers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  // Apply to all classes in niveau option
  bool _applyToAllClasses = false;
  int _affectedClassesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    for (final controller in _weightControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // Get current user's school_id to scope exam types
      final userId = supabase.auth.currentUser?.id;
      String? schoolId;
      if (userId != null) {
        final userRow = await supabase
            .from('users')
            .select('school_id')
            .eq('id', userId)
            .maybeSingle();
        schoolId = userRow?['school_id'] as String?;
      }

      // Load available exam types scoped to this school only
      var examTypesQuery = supabase
          .from('exam_types')
          .select('id, name, code, description')
          .eq('is_active', true);
      if (schoolId != null) {
        examTypesQuery = examTypesQuery.eq('school_id', schoolId);
      }
      final examTypesData = await examTypesQuery.order('name');

      _availableExamTypes = List<Map<String, dynamic>>.from(examTypesData);

      // Count affected classes if level is provided
      if (widget.levelId != null && widget.semesterId != null) {
        final affectedSubjectOfferings = await supabase
            .from('subject_offerings')
            .select('id, class_id')
            .eq('subject_id', widget.subjectId)
            .eq('semester_id', widget.semesterId!);

        // Filter by classes in the same level (niveau_id column)
        final classesInLevel = await supabase
            .from('classes')
            .select('id')
            .eq('niveau_id', widget.levelId!);

        final classIds = (classesInLevel as List).map((c) => c['id']).toSet();
        _affectedClassesCount = (affectedSubjectOfferings as List)
            .where((so) => classIds.contains(so['class_id']))
            .length;
      }

      // Initialize components from current grade_components
      _components = widget.currentComponents.map((comp) {
        // Support both old (name enum) and new (exam_type_id + display_name) schema
        final displayName =
            comp['display_name'] as String? ?? comp['name']?.toString() ?? '';
        return _ExamComponentEntry(
          id: comp['id'] as String?,
          examTypeId: comp['exam_type_id'] as String?,
          displayName: displayName,
          weightPercent: (comp['weight_percent'] as num?)?.toDouble() ?? 0,
          isNew: false,
        );
      }).toList();

      // Initialize controllers
      _initControllers();

      // If no components exist, add default ones
      if (_components.isEmpty) {
        _addDefaultComponents();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _initControllers() {
    // Clear old controllers
    for (final controller in _nameControllers.values) {
      controller.dispose();
    }
    for (final controller in _weightControllers.values) {
      controller.dispose();
    }
    _nameControllers.clear();
    _weightControllers.clear();

    // Create new controllers
    for (int i = 0; i < _components.length; i++) {
      _nameControllers[i] = TextEditingController(
        text: _components[i].displayName,
      );
      _weightControllers[i] = TextEditingController(
        text: _components[i].weightPercent.toStringAsFixed(0),
      );
    }
  }

  void _addDefaultComponents() {
    // Start with empty components - user must select exam types
    _components = [
      _ExamComponentEntry(displayName: '', weightPercent: 25, isNew: true),
      _ExamComponentEntry(displayName: '', weightPercent: 25, isNew: true),
      _ExamComponentEntry(displayName: '', weightPercent: 50, isNew: true),
    ];
    _initControllers();
  }

  void _addComponent() {
    setState(() {
      final newIndex = _components.length;
      _components.add(
        _ExamComponentEntry(displayName: '', weightPercent: 0, isNew: true),
      );
      _nameControllers[newIndex] = TextEditingController(text: '');
      _weightControllers[newIndex] = TextEditingController(text: '0');
    });
  }

  void _removeComponent(int index) {
    setState(() {
      _nameControllers[index]?.dispose();
      _weightControllers[index]?.dispose();
      _nameControllers.remove(index);
      _weightControllers.remove(index);
      _components.removeAt(index);
      _initControllers();
    });
  }

  double get _totalWeight {
    return _components.fold(0, (sum, c) => sum + c.weightPercent);
  }

  /// Map any exam type name/code to valid database enum values: CC, ORALE, SYNTHESE, TP, EXAMEN
  String _mapToEnumValue(String rawValue) {
    final value = rawValue.toUpperCase().trim();

    // Direct matches first
    if (value == 'CC' ||
        value == 'ORALE' ||
        value == 'SYNTHESE' ||
        value == 'TP' ||
        value == 'EXAMEN') {
      return value;
    }

    // Pattern matching for variations
    // ORALE patterns: oral, recitation, chant (for music), etc.
    if (value.contains('ORAL') ||
        value.contains('ORALE') ||
        value.contains('RECIT') ||
        value.contains('CHANT') ||
        value.contains('PERFORMANCE') ||
        value.contains('PRÉSENTATION') ||
        value.contains('PRESENTATION')) {
      return 'ORALE';
    }
    // CC patterns: continuous assessment, homework, participation, etc.
    if (value.contains('CC') ||
        value.contains('CONTINU') ||
        value.contains('CONTROL') ||
        value.contains('DEVOIR') ||
        value.contains('PARTICIPATION') ||
        value.contains('COMPORTEMENT') ||
        value.contains('CONDUITE')) {
      return 'CC';
    }
    // SYNTHESE patterns: synthesis exams, DS, finals, etc.
    if (value.contains('SYNTH') ||
        value.contains('DS') ||
        value.contains('FINAL') ||
        value.contains('SEMESTR') ||
        value.contains('TRIMEST')) {
      return 'SYNTHESE';
    }
    // TP patterns: practical work, labs, etc.
    if (value.contains('TP') ||
        value.contains('PRATIQUE') ||
        value.contains('TRAVAUX') ||
        value.contains('LABO') ||
        value.contains('ATELIER') ||
        value.contains('EXERCICE')) {
      return 'TP';
    }
    // EXAMEN patterns: exams, projects, tests, etc.
    if (value.contains('EXAM') ||
        value.contains('PROJET') ||
        value.contains('EXPOSE') ||
        value.contains('TEST') ||
        value.contains('PARTIEL') ||
        value.contains('ECRIT') ||
        value.contains('COMPOSITION') ||
        value.contains('ÉPREUVE') ||
        value.contains('EPREUVE')) {
      return 'EXAMEN';
    }

    // Default fallback - use EXAMEN as it's the most generic
    return 'EXAMEN';
  }

  bool get _isValid {
    if (_components.isEmpty) return false;
    // All components must have an exam type selected
    if (_components.any((c) => c.examTypeId == null || c.examTypeId!.isEmpty))
      return false;
    // Total should be 100%
    final total = _totalWeight;
    return (total - 100).abs() < 0.01;
  }

  Future<void> _save() async {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _totalWeight != 100
                ? 'Le total des pourcentages doit être 100% (actuellement ${_totalWeight.toStringAsFixed(0)}%)'
                : 'Tous les types d\'examen doivent avoir un nom',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;

      // Get list of subject_offering_ids to update
      List<String> subjectOfferingIds = [widget.subjectOfferingId];

      if (_applyToAllClasses &&
          widget.levelId != null &&
          widget.semesterId != null) {
        // Get all subject_offerings for this subject in this semester for classes in this level
        final classesInLevel = await supabase
            .from('classes')
            .select('id')
            .eq('niveau_id', widget.levelId!);

        final classIds = (classesInLevel as List)
            .map((c) => c['id'] as String)
            .toList();

        if (classIds.isNotEmpty) {
          final allSubjectOfferings = await supabase
              .from('subject_offerings')
              .select('id, class_id')
              .eq('subject_id', widget.subjectId)
              .eq('semester_id', widget.semesterId!)
              .inFilter('class_id', classIds);

          subjectOfferingIds = (allSubjectOfferings as List)
              .map((so) => so['id'] as String)
              .toList();
        }
      }

      // Delete existing components for all affected subject_offerings
      for (final soId in subjectOfferingIds) {
        await supabase
            .from('grade_components')
            .delete()
            .eq('subject_offering_id', soId);
      }

      // Insert new components for all affected subject_offerings
      // Map exam type codes to valid enum values (CC, ORALE, SYNTHESE, TP, EXAMEN)
      final allComponentsToInsert = <Map<String, dynamic>>[];
      for (final soId in subjectOfferingIds) {
        for (final c in _components) {
          // Find the exam type to get its code and name
          final examType = _availableExamTypes.firstWhere(
            (e) => e['id'] == c.examTypeId,
            orElse: () => <String, dynamic>{},
          );
          // Use code first, then name, then displayName as fallback
          final rawCode =
              (examType['code'] as String? ??
                      examType['name'] as String? ??
                      c.displayName)
                  .toUpperCase();

          // Map to valid enum values: CC, ORALE, SYNTHESE, TP, EXAMEN
          String enumValue = _mapToEnumValue(rawCode);

          // Debug logging
          debugPrint(
            'SubjectExamConfig: Saving component - rawCode: $rawCode -> enumValue: $enumValue for ${widget.subjectName}',
          );

          allComponentsToInsert.add({
            'subject_offering_id': soId,
            'name': enumValue,
            'weight_percent': c.weightPercent,
          });
        }
      }

      if (allComponentsToInsert.isNotEmpty) {
        await supabase.from('grade_components').insert(allComponentsToInsert);
      }

      if (mounted) {
        Navigator.of(context).pop();
        final message = _applyToAllClasses && subjectOfferingIds.length > 1
            ? 'Configuration appliquée à ${subjectOfferingIds.length} classes pour ${widget.subjectName}'
            : 'Configuration enregistrée pour ${widget.subjectName}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.success),
        );
      }

      // Call onSaved AFTER closing the dialog to trigger refresh
      widget.onSaved();
    } catch (e, stackTrace) {
      debugPrint('SubjectExamConfig: Error saving - $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 12,
        shadowColor: Colors.black.withOpacity(0.15),
        child: Container(
          width: 640,
          constraints: const BoxConstraints(maxHeight: 760),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(32, 28, 24, 20),
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.tune, color: Color(0xFF4B5563), size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Configuration des types d\'examen',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configurez les pourcentages pour ${widget.subjectName}.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Color(0xFF4B5563), size: 18),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Content ──
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: IosLoader()),
                    )
                  : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Erreur: $_error', style: const TextStyle(color: AppColors.error)),
                    )
                  : _buildContent(),
            ),

            // ── Footer ──
            const Divider(height: 1, color: Color(0xFFE9EAF2)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              decoration: const BoxDecoration(
                color: Color(0xFFFCFDFD),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4B5563),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving || !_isValid ? null : _save,
                      icon: _isSaving
                          ? const IosLoader(
                              size: 16, color: Colors.white,
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(
                        _isSaving ? 'Création...' : 'Enregistrer la config.',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D4CF6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        disabledBackgroundColor: const Color(0xFFE5E7EB),
                        disabledForegroundColor: const Color(0xFF9CA3AF),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section: PRÉRÉGLAGES ──
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D4CF6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'PRÉRÉGLAGES',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _PresetButton(
                label: 'Tunisien',
                onTap: () => setState(() {
                  _components = [
                    _ExamComponentEntry(displayName: '', weightPercent: 25, isNew: true),
                    _ExamComponentEntry(displayName: '', weightPercent: 25, isNew: true),
                    _ExamComponentEntry(displayName: '', weightPercent: 50, isNew: true),
                  ];
                  _initControllers();
                }),
              ),
              const SizedBox(width: 12),
              _PresetButton(
                label: 'Simple (100%)',
                onTap: () => setState(() {
                  _components = [
                    _ExamComponentEntry(displayName: '', weightPercent: 100, isNew: true),
                  ];
                  _initControllers();
                }),
              ),
              const SizedBox(width: 12),
              _PresetButton(
                label: '50/50',
                onTap: () => setState(() {
                  _components = [
                    _ExamComponentEntry(displayName: '', weightPercent: 50, isNew: true),
                    _ExamComponentEntry(displayName: '', weightPercent: 50, isNew: true),
                  ];
                  _initControllers();
                }),
              ),
            ],
          ),
          const SizedBox(height: 36),

          // ── Section: TYPES D'EXAMEN ──
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF6D4CF6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'STRUCTURE',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Column headers
          const Row(
            children: [
              Expanded(
                flex: 3,
                child: Text('Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
              ),
              SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text('Pourcentage', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF6B7280))),
              ),
              SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 8),

          // Components list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _components.length,
            itemBuilder: (context, index) => _buildComponentRow(index),
          ),

          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _addComponent,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ajouter un type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6D4CF6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),

          // Apply to all classes option
          if (widget.levelId != null) ...[  
            const SizedBox(height: 32),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6D4CF6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'APPLICATION',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6B7280), letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                value: _applyToAllClasses,
                onChanged: (value) => setState(() => _applyToAllClasses = value ?? false),
                activeColor: const Color(0xFF6D4CF6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                title: const Text(
                  'Appliquer à toutes les classes du même niveau',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF111827)),
                ),
                subtitle: _affectedClassesCount > 0
                    ? Text(
                        'S\'appliquera à $_affectedClassesCount classe(s)',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                      )
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComponentRow(int index) {
    final component = _components[index];
    final weightController = _weightControllers[index]!;

    final currentValueExists =
        component.examTypeId != null &&
        component.examTypeId!.isNotEmpty &&
        _availableExamTypes.any((e) => e['id'] == component.examTypeId);
    final dropdownValue = currentValueExists ? component.examTypeId : null;

    final seen = <String>{};
    final dropdownItems = _availableExamTypes
        .where((e) {
          final key = e['id'] as String;
          if (seen.contains(key)) return false;
          seen.add(key);
          return true;
        })
        .map((e) => DropdownMenuItem<String>(
              value: e['id'] as String,
              child: Text(e['name'] as String, style: const TextStyle(fontSize: 13)),
            ))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Exam type dropdown
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 44,
              child: DropdownButtonFormField<String>(
                value: dropdownValue,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7280)),
                decoration: InputDecoration(
                  hintText: 'Sélectionner un type',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE9EAF2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE9EAF2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: dropdownItems,
                onChanged: (examTypeId) {
                  if (examTypeId != null) {
                    final selectedExamType = _availableExamTypes.firstWhere(
                      (e) => e['id'] == examTypeId,
                      orElse: () => {'name': ''},
                    );
                    final displayName = selectedExamType['name'] as String? ?? '';
                    setState(() {
                      _nameControllers[index]!.text = displayName;
                      _components[index] = component.copyWith(examTypeId: examTypeId, displayName: displayName);
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Weight
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                decoration: InputDecoration(
                  suffixText: '%',
                  suffixStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE9EAF2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE9EAF2)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (value) {
                  // Rejeter les caractères non numériques
                  final filtered = value.replaceAll(RegExp(r'[^0-9.]'), '');
                  if (value != filtered) {
                    weightController.text = filtered;
                    weightController.selection = TextSelection.fromPosition(TextPosition(offset: filtered.length));
                  }
                  final weight = double.tryParse(filtered) ?? 0;
                  setState(() {
                    _components[index] = component.copyWith(weightPercent: weight);
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Delete
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _components.length > 1 ? const Color(0xFFFEF2F2) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _components.length > 1 ? const Color(0xFFFEE2E2) : Colors.transparent),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: _components.length > 1 ? () => _removeComponent(index) : null,
              icon: const Icon(Icons.delete_outline, size: 18),
              color: const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamComponentEntry {
  final String? id;
  final String? examTypeId; // Foreign key to exam_types
  final String displayName; // Display name for the exam type
  final double weightPercent;
  final bool isNew;

  _ExamComponentEntry({
    this.id,
    this.examTypeId,
    required this.displayName,
    required this.weightPercent,
    this.isNew = false,
  });

  _ExamComponentEntry copyWith({
    String? id,
    String? examTypeId,
    String? displayName,
    double? weightPercent,
    bool? isNew,
  }) {
    return _ExamComponentEntry(
      id: id ?? this.id,
      examTypeId: examTypeId ?? this.examTypeId,
      displayName: displayName ?? this.displayName,
      weightPercent: weightPercent ?? this.weightPercent,
      isNew: isNew ?? this.isNew,
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
        ),
      ),
    );
  }
}

class _QuickWeightButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickWeightButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
        ),
      ),
    );
  }
}
