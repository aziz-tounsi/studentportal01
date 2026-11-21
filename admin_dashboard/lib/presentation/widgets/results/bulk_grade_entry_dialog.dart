import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_messages.dart';
import 'subject_exam_config_dialog.dart';
import '../../../presentation/widgets/ios_loader.dart';
import '../../../presentation/widgets/user_avatar.dart';

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
            content: Text(
              UserFriendlyError.format(
                e,
                fallback: 'Unable to save grades right now. Please try again.',
              ),
            ),
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
    final shown = widget.selectedStudents.take(4).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      child: Row(
        children: [
          // Back button
          InkWell(
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 16),
          // Mini avatar stack
          if (shown.isNotEmpty) ...[
            SizedBox(
              width: 24.0 + (shown.length - 1) * 22.0,
              height: 38,
              child: Stack(
                children: List.generate(shown.length, (i) {
                  final s = shown[i];
                  final users = s['users'] as Map<String, dynamic>? ?? {};
                  final name = users['full_name']?.toString() ?? 'Élève';
                  return Positioned(
                    left: i * 22.0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: UserAvatar(
                        name: name,
                        photoUrl: users['photo_url']?.toString(),
                        gender: users['gender']?.toString(),
                        radius: 17,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 14),
          ],
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Saisie groupée des notes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Text(
                        '$count élève${count > 1 ? 's' : ''} sélectionné${count > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6D4CF6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•   Les notes saisies s\'appliqueront à toute la sélection',
                      style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Subject count pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.book_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  '${widget.subjectOfferings.length} matières',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
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
          Icon(Icons.book_outlined, size: 64, color: AppColors.slate400),
          const SizedBox(height: 16),
          const Text(
            'Aucune matière configurée',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
    final count = widget.selectedStudents.length;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      itemCount: widget.subjectOfferings.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6D4CF6).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF6D4CF6)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Entrez une note ou définissez un statut (ND = Non Dispensé, NP = Non Présent). La valeur sera automatiquement attribuée aux $count élèves sélectionnés.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          );
        }
        final offering = widget.subjectOfferings[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
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
    final hasComponents = components != null && components.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of card
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_stories_rounded, size: 18, color: Color(0xFF6D4CF6)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subjectName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1E293B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (subjectCode.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              subjectCode,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Coef $coefficient',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6D4CF6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _showExamConfigDialog(
                  offeringId,
                  subjectName,
                  subjectId,
                  components ?? [],
                ),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Configurer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasComponents)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Aucun type d\'examen configuré pour cette matière',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showExamConfigDialog(offeringId, subjectName, subjectId, []),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFD97706)),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: components
                  .map((comp) => _buildGradeField(offeringId, comp as Map<String, dynamic>))
                  .toList(),
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
    final currentStatus = _gradeStatus[offeringId]?[componentId] ?? 'OK';

    if (controller == null) return const SizedBox.shrink();

    return Container(
      width: 230,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 12, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  '$weight%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    controller: controller,
                    enabled: currentStatus == 'OK',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
                    ],
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: currentStatus == 'OK' ? '0.00' : '—',
                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      filled: true,
                      fillColor: currentStatus == 'OK' ? Colors.white : const Color(0xFFF1F5F9),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: currentStatus == 'OK' ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                initialValue: currentStatus,
                tooltip: 'Statut de la note',
                padding: EdgeInsets.zero,
                position: PopupMenuPosition.under,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                elevation: 4,
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
                        Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
                        SizedBox(width: 8),
                        Text('Note standard (OK)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'ND',
                    height: 36,
                    child: Row(
                      children: [
                        Icon(Icons.remove_circle_outline, color: AppColors.warning, size: 16),
                        SizedBox(width: 8),
                        Text('ND (Non Dispensé)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'NP',
                    height: 36,
                    child: Row(
                      children: [
                        Icon(Icons.highlight_off, color: AppColors.error, size: 16),
                        SizedBox(width: 8),
                        Text('NP (Non Présent)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: currentStatus == 'OK'
                        ? Colors.white
                        : (currentStatus == 'ND' ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2)),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: currentStatus == 'OK'
                          ? const Color(0xFFCBD5E1)
                          : (currentStatus == 'ND' ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      currentStatus,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: currentStatus == 'OK'
                            ? const Color(0xFF475569)
                            : (currentStatus == 'ND' ? const Color(0xFFD97706) : const Color(0xFFDC2626)),
                      ),
                    ),
                  ),
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
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: widget.onBack,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Annuler', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveGrades,
              icon: _isSaving
                  ? const IosLoader(size: 16, color: Colors.white)
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(
                _isSaving
                    ? 'Enregistrement en cours...'
                    : 'Enregistrer pour ${widget.selectedStudents.length} élève${widget.selectedStudents.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D4CF6),
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                shadowColor: const Color(0xFF6D4CF6).withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
