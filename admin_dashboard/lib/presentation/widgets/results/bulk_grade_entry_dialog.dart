import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import 'subject_exam_config_dialog.dart';
import '../../../presentation/widgets/ios_loader.dart';

/// Full-screen widget for entering grades in bulk for multiple selected students.
/// The UI mirrors SingleStudentGradeEntry — shows all subjects and their exam
/// components. A single grade input per component sets that grade for EVERY
/// selected student at once.
class BulkGradeEntryDialog extends StatefulWidget {
  /// The enrollment records for the selected students.
  final List<Map<String, dynamic>> selectedStudents;

  /// Subject offerings for the class (same structure as SingleStudentGradeEntry).
  final List<Map<String, dynamic>> subjectOfferings;

  /// Called on back/close.
  final VoidCallback onBack;

  /// Optional refresh callback after config changes.
  final VoidCallback? onRefresh;

  /// Level ID for config propagation.
  final String? levelId;

  /// Semester ID.
  final String? semesterId;

  const BulkGradeEntryDialog({
    super.key,
    required this.selectedStudents,
    required this.subjectOfferings,
    required this.onBack,
    this.onRefresh,
    this.levelId,
    this.semesterId,
  });

  @override
  State<BulkGradeEntryDialog> createState() => _BulkGradeEntryDialogState();
}

class _BulkGradeEntryDialogState extends State<BulkGradeEntryDialog> {
  // gradeControllers[offeringId][componentId] = shared grade for all students
  final Map<String, Map<String, TextEditingController>> _gradeControllers = {};
  // statusMap[offeringId][componentId] = 'OK' | 'ND' | 'NP'
  final Map<String, Map<String, String>> _gradeStatus = {};

  bool _isSaving = false;

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
    for (final sub in _gradeControllers.values) {
      for (final c in sub.values) c.dispose();
    }
    _gradeControllers.clear();
    _gradeStatus.clear();
  }

  void _initControllers() {
    _disposeControllers();
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

  Future<void> _saveGrades() async {
    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final gradesToUpsert = <Map<String, dynamic>>[];

      for (final student in widget.selectedStudents) {
        final enrollmentId = student['id'] as String? ?? '';
        final userId = (student['user_id'] as String?) ??
            ((student['users'] as Map<String, dynamic>?)?['id'] as String?);
        if (enrollmentId.isEmpty || userId == null) continue;

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
              gradeValue =
                  double.tryParse(controller.text.replaceAll(',', '.'));
            }

            if (gradeValue != null || status != 'OK') {
              gradesToUpsert.add({
                'enrollment_id': enrollmentId,
                'student_id': userId,
                'subject_offering_id': offeringId,
                'component_id': componentId,
                'grade_value': gradeValue,
                'status': status,
              });
            }
          }
        }
      }

      if (gradesToUpsert.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune note à enregistrer'),
            backgroundColor: AppColors.warning,
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      await supabase.from('grades').upsert(
        gradesToUpsert,
        onConflict: 'enrollment_id,component_id',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notes enregistrées pour ${widget.selectedStudents.length} élèves',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onBack();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showExamConfigDialog(
    String subjectOfferingId,
    String subjectName,
    String subjectId,
    List<dynamic> currentComponents,
  ) {
    showDialog(
      context: context,
      builder: (context) => SubjectExamConfigDialog(
        subjectOfferingId: subjectOfferingId,
        subjectName: subjectName,
        subjectId: subjectId,
        levelId: widget.levelId,
        semesterId: widget.semesterId,
        currentComponents:
            currentComponents.map((c) => c as Map<String, dynamic>).toList(),
        onSaved: () => widget.onRefresh?.call(),
      ),
    );
  }

  // ─── helpers identical to SingleStudentGradeEntry ──────────────────────

  String _getComponentDisplayName(String name) {
    switch (name.toUpperCase()) {
      case 'ORALE':
        return 'Orale';
      case 'CC':
        return 'Contrôle Continu';
      case 'SYNTHESE':
      case 'SYNTHÈSE':
        return 'Synthèse';
      case 'TP':
        return 'Travaux Pratiques';
      case 'EXAMEN':
        return 'Examen';
      default:
        return name;
    }
  }

  Color _getComponentColor(String name) {
    switch (name.toUpperCase()) {
      case 'ORALE':
        return const Color(0xFF3B82F6);
      case 'CC':
        return const Color(0xFF8B5CF6);
      case 'SYNTHESE':
      case 'SYNTHÈSE':
        return const Color(0xFFEC4899);
      case 'TP':
        return const Color(0xFF10B981);
      case 'EXAMEN':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getComponentIcon(String name) {
    switch (name.toUpperCase()) {
      case 'ORALE':
        return Icons.mic;
      case 'CC':
        return Icons.quiz;
      case 'SYNTHESE':
      case 'SYNTHÈSE':
        return Icons.description;
      case 'TP':
        return Icons.science;
      case 'EXAMEN':
        return Icons.assignment;
      default:
        return Icons.grade;
    }
  }

  // ─── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1),
          Expanded(
            child: widget.subjectOfferings.isEmpty
                ? _buildNoSubjectsMessage()
                : _buildSubjectsList(),
          ),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final count = widget.selectedStudents.length;
    final shown = widget.selectedStudents.take(3).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back, size: 20),
            color: AppColors.textTertiary,
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Colors.transparent),
              ),
            ),
            constraints:
                const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: 12),
          // Mini avatar stack
          SizedBox(
            width: 20.0 + shown.length * 20.0,
            height: 36,
            child: Stack(
              children: List.generate(shown.length, (i) {
                final s = shown[i];
                final users =
                    s['users'] as Map<String, dynamic>? ?? {};
                final name = users['full_name']?.toString() ?? '';
                final parts = name
                    .trim()
                    .split(RegExp(r'\s+'))
                    .take(2)
                    .map((p) =>
                        p.isNotEmpty ? p[0].toUpperCase() : '')
                    .join('');
                return Positioned(
                  left: i * 20.0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        parts.isNotEmpty ? parts : '?',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6D4CF6),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 12),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saisie groupée des notes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  '$count élève${count > 1 ? 's' : ''} sélectionné${count > 1 ? 's' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          // Subject count
          Text(
            '${widget.subjectOfferings.length} matières',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSubjectsMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined,
              size: 64, color: AppColors.slate400),
          const SizedBox(height: 16),
          const Text(
            'Aucune matière configurée',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Les matières et types d\'examens doivent être configurés\npour cette classe et ce semestre',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (widget.onRefresh != null)
            OutlinedButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
            ),
        ],
      ),
    );
  }

  Widget _buildSubjectsList() {
    return ListView.builder(
      padding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: widget.subjectOfferings.length,
      itemBuilder: (context, index) {
        final offering = widget.subjectOfferings[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _buildSubjectCard(offering),
        );
      },
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> offering) {
    final subject = offering['subjects'] as Map<String, dynamic>?;
    final subjectName = subject?['name'] as String? ?? 'Matière';
    final subjectCode = subject?['code'] as String? ?? '';
    final subjectId = subject?['id'] as String? ?? '';
    final coefficient = offering['coefficient'] as num? ?? 1.0;
    final components = offering['grade_components'] as List?;
    final offeringId = offering['id'] as String;
    final hasComponents =
        components != null && components.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
              color: AppColors.border.withOpacity(0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Subject info — fixed width
          SizedBox(
            width: 240,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (subjectCode.isNotEmpty)
                            Text(
                              '$subjectCode • ',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary),
                            ),
                          Text(
                            'Coef $coefficient',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showExamConfigDialog(
                    offeringId,
                    subjectName,
                    subjectId,
                    components ?? [],
                  ),
                  icon: const Icon(Icons.tune, size: 16),
                  tooltip: 'Configurer',
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.textTertiary,
                    hoverColor: AppColors.slate100,
                  ),
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          if (!hasComponents)
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: AppColors.warning, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Aucun type configuré',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.warning),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => _showExamConfigDialog(
                        offeringId, subjectName, subjectId, []),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Configurer',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: components!
                    .map((comp) =>
                        _buildGradeField(offeringId, comp))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGradeField(
      String offeringId, Map<String, dynamic> component) {
    final componentId = component['id'] as String;
    final name = component['name'] as String? ?? 'Note';
    final weight = component['weight_percent'] as num? ?? 0;
    final displayName = _getComponentDisplayName(name);
    final color = _getComponentColor(name);
    final icon = _getComponentIcon(name);

    final controller = _gradeControllers[offeringId]?[componentId];
    final currentStatus =
        _gradeStatus[offeringId]?[componentId] ?? 'OK';

    if (controller == null) return const SizedBox.shrink();

    return Container(
      width: 220,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.slate50.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          Container(
            width: 90,
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$weight%',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Input
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: controller,
                enabled: currentStatus == 'OK',
                keyboardType:
                    const TextInputType.numberWithOptions(
                        decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*[.,]?\d{0,2}')),
                ],
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                      fontSize: 13, color: AppColors.slate400),
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                        color: currentStatus == 'OK'
                            ? AppColors.border
                            : Colors.transparent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide:
                        BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(
                        color: const Color(0xFF655DD5)
                            .withOpacity(0.6),
                        width: 1.5),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                        color: Colors.transparent),
                  ),
                  filled: true,
                  fillColor: currentStatus == 'OK'
                      ? Colors.white
                      : AppColors.slate100,
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: currentStatus == 'OK'
                      ? AppColors.textPrimary
                      : AppColors.slate400,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Status popup
          PopupMenuButton<String>(
            initialValue: currentStatus,
            tooltip: 'Statut de la note',
            padding: EdgeInsets.zero,
            position: PopupMenuPosition.under,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            elevation: 3,
            shadowColor: Colors.black.withOpacity(0.05),
            onSelected: (value) {
              setState(() {
                _gradeStatus[offeringId]![componentId] = value;
                if (value != 'OK') controller.clear();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'OK',
                height: 36,
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppColors.success, size: 16),
                    SizedBox(width: 8),
                    Text('Note standard',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151))),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'ND',
                height: 36,
                child: Row(
                  children: [
                    Icon(Icons.remove_circle_outline,
                        color: AppColors.warning, size: 16),
                    SizedBox(width: 8),
                    Text('ND (Non Dispensé)',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151))),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'NP',
                height: 36,
                child: Row(
                  children: [
                    Icon(Icons.highlight_off,
                        color: AppColors.error, size: 16),
                    SizedBox(width: 8),
                    Text('NP (Non Présent)',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151))),
                  ],
                ),
              ),
            ],
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: currentStatus == 'OK'
                    ? Colors.transparent
                    : currentStatus == 'ND'
                        ? AppColors.warningSoft
                        : AppColors.errorSoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                currentStatus == 'OK'
                    ? Icons.more_vert
                    : currentStatus == 'ND'
                        ? Icons.remove_circle_outline
                        : Icons.cancel_outlined,
                size: 16,
                color: currentStatus == 'OK'
                    ? AppColors.textSecondary
                    : currentStatus == 'ND'
                        ? AppColors.warning
                        : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveGrades,
              icon: _isSaving
                  ? const IosLoader(
                      size: 16,
                      color: Colors.white,
                    )
                  : const Icon(Icons.save, size: 18),
              label: Text(
                _isSaving
                    ? 'Enregistrement...'
                    : 'Enregistrer pour ${widget.selectedStudents.length} élève${widget.selectedStudents.length > 1 ? 's' : ''}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D4CF6),
                foregroundColor: Colors.white,
                elevation: 2,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                shadowColor:
                    const Color(0xFF6D4CF6).withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
