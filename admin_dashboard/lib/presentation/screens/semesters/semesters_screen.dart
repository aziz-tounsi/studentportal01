import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/semesters_provider.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/ios_loader.dart';

const _brand = Color(0xFF7C3AED);
const _brandLight = Color(0xFFF3E8FF);

class SemestersScreen extends ConsumerStatefulWidget {
  const SemestersScreen({super.key});
  @override
  ConsumerState<SemestersScreen> createState() => _SemestersScreenState();
}

class _SemestersScreenState extends ConsumerState<SemestersScreen> {
  @override
  Widget build(BuildContext context) {
    final semestersAsync = ref.watch(semestersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/semesters'),
          Expanded(
            child: Stack(
              children: [
                // Decorative blur
                Positioned(
                  top: -80, right: -80,
                  child: Container(
                    width: 300, height: 300,
                    decoration: BoxDecoration(
                      color: _brand.withOpacity(0.03),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Column(
                  children: [
                    _buildHeader(context, semestersAsync),
                    Expanded(
                      child: semestersAsync.when(
                        loading: () => const Center(child: IosLoader(color: _brand)),
                        error: (e, _) => Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text('Erreur: $e', style: TextStyle(color: AppColors.error)),
                          ]),
                        ),
                        data: (state) => _buildContent(context, state),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue<SemestersState> semestersAsync) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title — no icon
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Semestres',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gestion des périodes académiques',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
          const Spacer(),
          // ── Controls pinned far-right ──
          semestersAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (state) {
              final selectedYear = state.academicYears
                  .where((y) => y.id == state.selectedAcademicYearId)
                  .firstOrNull;
              final label = selectedYear?.name ?? 'Année scolaire';
              const double w = 200;
              const double h = 40;
              const double r = 12;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year select
                  PopupMenuButton<String?>(
                    onSelected: (v) => ref.read(semestersProvider.notifier).selectAcademicYear(v),
                    offset: const Offset(0, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r)),
                    elevation: 4,
                    constraints: const BoxConstraints(minWidth: w, maxWidth: w),
                    itemBuilder: (_) => state.academicYears.map((year) => PopupMenuItem<String?>(
                      value: year.id,
                      height: 40,
                      child: Row(children: [
                        Text(year.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                        if (year.isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Actuel', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ]),
                    )).toList(),
                    child: Container(
                      width: w,
                      height: h,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(r),
                        border: Border.all(color: const Color(0xFFECECF3)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        Expanded(
                          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700), overflow: TextOverflow.ellipsis),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF6B7280)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Add button
                  SizedBox(
                    height: h,
                    child: ElevatedButton.icon(
                      onPressed: () => _showSemesterDialog(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Ajouter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D4CF6),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        shadowColor: const Color(0xFF6D4CF6).withOpacity(0.3),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, SemestersState state) {
    final semesters = state.filteredSemesters;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(children: [
            // Table
            Expanded(
            child: semesters.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.calendar_today_rounded, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('Aucun semestre', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                      if (state.selectedAcademicYear != null) ...[
                        const SizedBox(height: 4),
                        Text('pour ${state.selectedAcademicYear!.name}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ]),
                  )
                : SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FixedColumnWidth(64),
                        1: FlexColumnWidth(1.2),
                        2: FlexColumnWidth(1.2),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(1),
                        5: FlexColumnWidth(1),
                        6: FixedColumnWidth(152),
                      },
                      children: [
                        // Header
                        TableRow(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                          ),
                          children: ['N°', 'NOM', 'ANNÉE SCOLAIRE', 'DÉBUT', 'FIN', 'STATUT', 'ACTIONS']
                              .map((h) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    child: h == 'N°' || h == 'ACTIONS'
                                        ? Center(child: Text(h, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5)))
                                        : Text(h, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5)),
                                  ))
                              .toList(),
                        ),
                        // Rows
                        ...semesters.map((s) => TableRow(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                          ),
                          children: [
                            // N°
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Center(
                                child: Container(
                                  width: 28, height: 28,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(child: Text('${s.number}', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 12))),
                                ),
                              ),
                            ),
                            // Nom
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 13)),
                            ),
                            // Année scolaire
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              child: Text(s.academicYearName ?? '-', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary, fontSize: 13)),
                            ),
                            // Début
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              child: Text(dateFormat.format(s.startDate), style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary, fontSize: 13)),
                            ),
                            // Fin
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              child: Text(dateFormat.format(s.endDate), style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textSecondary, fontSize: 13)),
                            ),
                            // Statut
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: s.isCurrent
                                  ? Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                        child: const Text('Actuel', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 11)),
                                      ),
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('-', style: TextStyle(color: AppColors.textTertiary)),
                                    ),
                            ),
                            // Actions
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                _actionBtn(Icons.check_circle_outlined, const Color(0xFF059669), const Color(0xFFECFDF5),
                                    onTap: () => ref.read(semestersProvider.notifier).setCurrentSemester(s.id)),
                                const SizedBox(width: 8),
                                _actionBtn(Icons.edit_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF),
                                    onTap: () => _showSemesterDialog(context, semester: s)),
                                const SizedBox(width: 8),
                                _actionBtn(Icons.delete_rounded, const Color(0xFFDC2626), const Color(0xFFFEF2F2),
                                    onTap: () => _confirmDelete(context, s)),
                              ]),
                            ),
                          ],
                        )),
                      ],
                    ),
                  ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade100))),
            child: Center(
              child: Text('Affichage de ${semesters.length} semestre${semesters.length > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ),
          ),
        ]),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, Color iconColor, Color bgColor, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }

  void _showSemesterDialog(BuildContext context, {SemesterModel? semester}) {
    final asyncState = ref.read(semestersProvider);
    final state = asyncState.value;
    if (state == null) return;

    final isNew = semester == null;
    final autoName = isNew ? state.nextSemesterName : semester.name;
    final autoNumber = isNew ? state.nextSemesterNumber : semester.number;

    final nameCtrl = TextEditingController(text: autoName);
    int semesterNumber = autoNumber;

    final minStartDate = state.minStartDateForNewSemester;
    DateTime startDate = semester?.startDate ?? minStartDate ?? DateTime.now();
    DateTime endDate = semester?.endDate ?? startDate.add(const Duration(days: 120));

    String? selectedYearId = semester?.academicYearId ?? state.selectedAcademicYearId;
    bool isCurrent = semester?.isCurrent ?? false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          void validateDates() {
            errorMessage = null;
            if (startDate.isAfter(endDate)) {
              errorMessage = 'La date de début doit être avant la date de fin';
            } else if (minStartDate != null && isNew && startDate.isBefore(minStartDate)) {
              errorMessage = 'Le nouveau semestre doit commencer après le ${DateFormat('dd/MM/yyyy').format(minStartDate.subtract(const Duration(days: 1)))}';
            }
            setDialogState(() {});
          }

          return Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(color: Colors.black.withOpacity(0.28)),
                ),
              ),
              Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Header
                Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(10)),
                    child: Icon(isNew ? Icons.add_rounded : Icons.edit_rounded, size: 20, color: _brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isNew ? 'Nouveau semestre' : 'Modifier le semestre', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                    const SizedBox(height: 2),
                    Text(isNew ? 'Créer une nouvelle période académique' : 'Mettre à jour les informations', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ])),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade500),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 20),
                // Year selector
                _semLabel('Année scolaire'),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedYearId,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(12),
                      hint: Text('Sélectionner l\'année', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      items: state.academicYears.map((year) => DropdownMenuItem(
                        value: year.id,
                        child: Text(year.name),
                      )).toList(),
                      onChanged: isNew ? (v) => setDialogState(() => selectedYearId = v) : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Number + Name
                Row(children: [
                  SizedBox(
                    width: 80,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _semLabel('N°'),
                      const SizedBox(height: 6),
                      TextField(
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        keyboardType: TextInputType.number,
                        controller: TextEditingController(text: '$semesterNumber'),
                        decoration: _semInputDeco('N°'),
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null && n > 0) {
                            semesterNumber = n;
                            nameCtrl.text = 'Semestre $n';
                          }
                        },
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _semLabel('Nom'),
                    const SizedBox(height: 6),
                    TextField(controller: nameCtrl, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), decoration: _semInputDeco('Ex: Semestre 1')),
                  ])),
                ]),
                const SizedBox(height: 16),
                if (isNew && minStartDate != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: _brand),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Le semestre précédent se termine le ${DateFormat('dd/MM/yyyy').format(minStartDate.subtract(const Duration(days: 1)))}',
                        style: const TextStyle(fontSize: 12, color: _brand),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
                // Date pickers
                Row(children: [
                  Expanded(child: _datePicker(ctx, 'Date de début', startDate, setDialogState, (d) {
                    startDate = d;
                    if (endDate.isBefore(startDate)) endDate = startDate.add(const Duration(days: 120));
                    validateDates();
                  }, firstDate: minStartDate ?? DateTime(2020))),
                  const SizedBox(width: 12),
                  Expanded(child: _datePicker(ctx, 'Date de fin', endDate, setDialogState, (d) {
                    endDate = d;
                    validateDates();
                  }, firstDate: startDate)),
                ]),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFECACA))),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(errorMessage!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)))),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                // Current checkbox
                InkWell(
                  onTap: () => setDialogState(() => isCurrent = !isCurrent),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(children: [
                    Checkbox(
                      value: isCurrent,
                      onChanged: (v) => setDialogState(() => isCurrent = v ?? false),
                      activeColor: _brand,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    const Text('Définir comme semestre actuel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ]),
                ),
                const SizedBox(height: 20),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 16),
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                  SizedBox(
                    height: 40,
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: errorMessage != null || nameCtrl.text.isEmpty || selectedYearId == null
                          ? null
                          : () async {
                              final notifier = ref.read(semestersProvider.notifier);
                              if (isNew) {
                                await notifier.create(name: nameCtrl.text, number: semesterNumber, startDate: startDate, endDate: endDate, academicYearId: selectedYearId!, isCurrent: isCurrent);
                              } else {
                                await notifier.updateSemester(id: semester.id, name: nameCtrl.text, number: semesterNumber, startDate: startDate, endDate: endDate);
                                if (isCurrent && !semester.isCurrent) await notifier.setCurrentSemester(semester.id);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _brand.withOpacity(0.3),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        elevation: 2,
                      ),
                      child: Text(isNew ? 'Créer' : 'Modifier', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
            ],
          );
        },
      ),
    );
  }

  Widget _datePicker(BuildContext ctx, String label, DateTime date, void Function(void Function()) setDialogState, void Function(DateTime) onPicked, {required DateTime firstDate}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _semLabel(label),
      const SizedBox(height: 6),
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: firstDate, lastDate: DateTime(2030));
          if (picked != null) setDialogState(() => onPicked(picked));
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(DateFormat('dd/MM/yyyy').format(date), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
          ]),
        ),
      ),
    ]);
  }

  static Widget _semLabel(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
  );

  static InputDecoration _semInputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400, fontSize: 14),
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    isDense: true,
  );

  void _confirmDelete(BuildContext context, SemesterModel s) {
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withOpacity(0.28)),
            ),
          ),
          Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 24),
            ),
            const SizedBox(height: 16),
            const Text('Supprimer le semestre ?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
            const SizedBox(height: 8),
            Text('Voulez-vous supprimer "${s.name}" ? Cette action est irréversible.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () {
                  ref.read(semestersProvider.notifier).delete(s.id);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w700)),
              )),
            ]),
          ]),
        ),
      ),
        ],
      ),
    );
  }
}
