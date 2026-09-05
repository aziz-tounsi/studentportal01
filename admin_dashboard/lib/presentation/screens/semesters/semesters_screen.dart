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
                  top: -80,
                  right: -80,
                  child: Container(
                    width: 300,
                    height: 300,
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
                        loading: () =>
                            const Center(child: IosLoader(color: _brand)),
                        error: (e, _) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: AppColors.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Erreur: $e',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
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

  Widget _buildHeader(
    BuildContext context,
    AsyncValue<SemestersState> semestersAsync,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Périodes académiques',
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
          // Add button only
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () => _showCreatePeriodsDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Ajouter',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D4CF6),
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: const Color(0xFF6D4CF6).withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, SemestersState state) {
    final semesters = state.filteredSemesters;
    final dateFormat = DateFormat('dd MMM yyyy', 'fr');
    final shortDateFormat = DateFormat('MMM yyyy', 'fr');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Period Cards ──
          if (semesters.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withOpacity(0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun ${state.periodLabel.toLowerCase()}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cliquez sur "Ajouter" pour créer une période',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ...semesters.map((s) => _buildPeriodCard(context, state, s)),

          // ── Exam Period Cards ──
          if (state.filteredExamPeriods.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.school_rounded, size: 18, color: const Color(0xFFEA580C)),
                const SizedBox(width: 8),
                Text(
                  'Périodes d\'examens',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${state.filteredExamPeriods.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...state.filteredExamPeriods.map((ep) => _buildExamPeriodCard(context, ep)),
          ],

          const SizedBox(height: 16),

          // ── Footer ──
          Center(
            child: Text(
              'Affichage de ${semesters.length} ${semesters.length > 1 ? state.periodLabelPlural.toLowerCase() : state.periodLabel.toLowerCase()}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodCard(BuildContext context, SemestersState state, SemesterModel s) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final shortDateFormat = DateFormat('d MMM yyyy', 'fr');
    final duration = s.endDate.difference(s.startDate).inDays;
    final weeks = (duration / 7).ceil();
    final now = DateTime.now();
    final monthsFr = ['Janv.', 'Févr.', 'Mars', 'Avr.', 'Mai', 'Juin', 'Juil.', 'Août', 'Sept.', 'Oct.', 'Nov.', 'Déc.'];

    // Build month list for this period
    final List<DateTime> periodMonthDates = [];
    final List<bool> periodMonthsIsCurrent = [];
    DateTime cursor = DateTime(s.startDate.year, s.startDate.month);
    final endMonth = DateTime(s.endDate.year, s.endDate.month);
    while (!cursor.isAfter(endMonth)) {
      periodMonthDates.add(cursor);
      periodMonthsIsCurrent.add(cursor.year == now.year && cursor.month == now.month);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: s.isCurrent ? _brand.withOpacity(0.2) : AppColors.border.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: s.isCurrent
            ? [BoxShadow(color: _brand.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))]
            : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row (clone of overview card header) ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: s.isCurrent ? _brand : _brandLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.calendar_month_rounded, color: s.isCurrent ? Colors.white : _brand, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                          ),
                          if (s.isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _brandLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Actuel',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _brand),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${shortDateFormat.format(s.startDate)} → ${shortDateFormat.format(s.endDate)}',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                // Actions
                _actionBtn(
                  Icons.edit_rounded,
                  _brand,
                  _brandLight,
                  onTap: () => _showSemesterDialog(context, semester: s),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  Icons.delete_rounded,
                  const Color(0xFFDC2626),
                  const Color(0xFFFEF2F2),
                  onTap: () => _confirmDelete(context, s),
                ),
              ],
            ),
            // ── Stats row ──
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _brandLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timeline_rounded, color: _brand, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '$weeks semaines · $duration jours',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _brand),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
              ],
            ),
            // ── Horizontal timeline (exact clone of header) ──
            if (periodMonthDates.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: periodMonthDates.length,
                  itemBuilder: (context, i) {
                    final mDate = periodMonthDates[i];
                    final isCur = periodMonthsIsCurrent[i];
                    final isLast = i == periodMonthDates.length - 1;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (i == 0) const SizedBox(width: 4),
                        Column(
                          children: [
                            // Month label
                            Text(
                              monthsFr[mDate.month - 1].toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isCur ? _brand : AppColors.textTertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Node
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isCur ? _brand : _brandLight,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCur ? _brand : _brand.withOpacity(0.3),
                                  width: isCur ? 2 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isCur ? Colors.white : _brand,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Status
                            if (isCur)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _brandLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Actuel',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _brand),
                                ),
                              )
                            else
                              Text(
                                monthsFr[mDate.month - 1],
                                style: TextStyle(fontSize: 9, color: AppColors.textTertiary),
                              ),
                          ],
                        ),
                        // Connector line
                        if (!isLast)
                          Container(
                            margin: const EdgeInsets.only(top: 18),
                            width: 24,
                            height: 2,
                            decoration: BoxDecoration(
                              color: _brand.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        if (isLast) const SizedBox(width: 4),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExamPeriodCard(BuildContext context, ExamPeriodModel ep) {
    final dateFormat = DateFormat('dd MMM yyyy', 'fr');
    final duration = ep.endDate.difference(ep.startDate).inDays;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isActive = !today.isBefore(ep.startDate) && !today.isAfter(ep.endDate);
    final isPast = today.isAfter(ep.endDate);
    final isFuture = today.isBefore(ep.startDate);

    final statusColor = isActive ? const Color(0xFF059669) : isPast ? Colors.grey.shade400 : const Color(0xFFEA580C);
    final statusText = isActive ? 'En cours' : isPast ? 'Terminé' : 'À venir';
    final statusBg = isActive ? const Color(0xFFECFDF5) : isPast ? Colors.grey.shade100 : const Color(0xFFFEF3C7);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFFEA580C).withOpacity(0.3) : AppColors.border.withOpacity(0.5),
          width: 1,
        ),
        boxShadow: isActive
            ? [BoxShadow(color: const Color(0xFFEA580C).withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))]
            : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFEA580C) : const Color(0xFFFED7AA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.school_rounded,
                color: isActive ? Colors.white : const Color(0xFFEA580C),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ep.name ?? 'Examen',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${dateFormat.format(ep.startDate)} → ${dateFormat.format(ep.endDate)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$duration jour${duration > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    Color iconColor,
    Color bgColor, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }

  void _showSemesterDialog(BuildContext context, {SemesterModel? semester}) {
    final asyncState = ref.read(semestersProvider);
    final state = asyncState.value;
    if (state == null) return;

    final isNew = semester == null;
    final lockedType = state.allowedPeriodType;

    // Period type: locked if periods exist, otherwise admin chooses
    String chosenType = lockedType ?? state.periodType;

    // Auto-name based on chosen type
    int autoNumber = isNew ? 1 : semester.number;
    String autoName = isNew ? '$chosenType $autoNumber' : semester.name;

    final nameCtrl = TextEditingController(text: autoName);
    int semesterNumber = autoNumber;

    final minStartDate = state.minStartDateForNewSemester;
    DateTime startDate = semester?.startDate ?? minStartDate ?? DateTime.now();

    // Auto-calculate duration based on type
    int durationDays = chosenType == 'trimestre' ? 92 : 183;
    DateTime endDate =
        semester?.endDate ?? startDate.add(Duration(days: durationDays));

    String? selectedYearId =
        semester?.academicYearId ?? state.selectedAcademicYearId;
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
            } else if (minStartDate != null &&
                isNew &&
                startDate.isBefore(minStartDate)) {
              errorMessage =
                  'Le nouveau ${chosenType == 'trimestre' ? 'trimestre' : 'semestre'} doit commencer après le ${DateFormat('dd/MM/yyyy').format(minStartDate.subtract(const Duration(days: 1)))}';
            }
            // Check overlap with existing periods
            final overlap = state.validateOverlap(
              startDate,
              endDate,
              excludeId: semester?.id,
            );
            if (overlap != null) {
              errorMessage = overlap;
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: 480,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _brandLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isNew ? Icons.add_rounded : Icons.edit_rounded,
                              size: 20,
                              color: _brand,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isNew
                                      ? 'Nouveau ${chosenType == 'trimestre' ? 'trimestre' : 'semestre'}'
                                      : 'Modifier le ${state.periodLabel.toLowerCase()}',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isNew
                                      ? 'Créer une nouvelle période académique'
                                      : 'Mettre à jour les informations',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(height: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 20),
                      // Year selector
                      _semLabel('Année scolaire'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
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
                            hint: Text(
                              'Sélectionner l\'année',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                            items: state.academicYears
                                .map(
                                  (year) => DropdownMenuItem(
                                    value: year.id,
                                    child: Text(year.name),
                                  ),
                                )
                                .toList(),
                            onChanged: isNew
                                ? (v) =>
                                      setDialogState(() => selectedYearId = v)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Period type selector (only when no periods exist yet)
                      if (isNew && lockedType == null) ...[
                        _semLabel('Type de période'),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() {
                                  chosenType = 'semestre';
                                  durationDays = 183;
                                  endDate = startDate.add(
                                    Duration(days: durationDays),
                                  );
                                  autoNumber = 1;
                                  nameCtrl.text = 'Semestre 1';
                                  semesterNumber = 1;
                                  validateDates();
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: chosenType == 'semestre'
                                        ? _brand
                                        : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: chosenType == 'semestre'
                                          ? _brand
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.date_range_rounded,
                                        color: chosenType == 'semestre'
                                            ? Colors.white
                                            : Colors.grey.shade500,
                                        size: 20,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Semestre',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: chosenType == 'semestre'
                                              ? Colors.white
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      Text(
                                        '~6 mois',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: chosenType == 'semestre'
                                              ? Colors.white70
                                              : Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setDialogState(() {
                                  chosenType = 'trimestre';
                                  durationDays = 92;
                                  endDate = startDate.add(
                                    Duration(days: durationDays),
                                  );
                                  autoNumber = 1;
                                  nameCtrl.text = 'Trimestre 1';
                                  semesterNumber = 1;
                                  validateDates();
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: chosenType == 'trimestre'
                                        ? _brand
                                        : const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: chosenType == 'trimestre'
                                          ? _brand
                                          : Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.view_week_rounded,
                                        color: chosenType == 'trimestre'
                                            ? Colors.white
                                            : Colors.grey.shade500,
                                        size: 20,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Trimestre',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: chosenType == 'trimestre'
                                              ? Colors.white
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                      Text(
                                        '~3 mois',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: chosenType == 'trimestre'
                                              ? Colors.white70
                                              : Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Number + Name
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _semLabel('N°'),
                                const SizedBox(height: 6),
                                TextField(
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  keyboardType: TextInputType.number,
                                  controller: TextEditingController(
                                    text: '$semesterNumber',
                                  ),
                                  decoration: _semInputDeco('N°'),
                                  onChanged: (v) {
                                    final n = int.tryParse(v);
                                    if (n != null && n > 0) {
                                      semesterNumber = n;
                                      nameCtrl.text =
                                          '${chosenType == 'trimestre' ? 'Trimestre' : 'Semestre'} $n';
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _semLabel('Nom'),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: nameCtrl,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: _semInputDeco(
                                    'Ex: ${chosenType == 'trimestre' ? 'Trimestre' : 'Semestre'} 1',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (isNew && minStartDate != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _brandLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: _brand,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Le ${state.periodLabel.toLowerCase()} précédent se termine le ${DateFormat('dd/MM/yyyy').format(minStartDate.subtract(const Duration(days: 1)))}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _brand,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Date pickers
                      Row(
                        children: [
                          Expanded(
                            child: _datePicker(
                              ctx,
                              'Date de début',
                              startDate,
                              setDialogState,
                              (d) {
                                startDate = d;
                                // Auto-calculate end date based on period type
                                endDate = startDate.add(
                                  Duration(days: durationDays),
                                );
                                validateDates();
                              },
                              firstDate: minStartDate ?? DateTime(2020),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _datePicker(
                              ctx,
                              'Date de fin',
                              endDate,
                              setDialogState,
                              (d) {
                                endDate = d;
                                validateDates();
                              },
                              firstDate: startDate,
                            ),
                          ),
                        ],
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                              ),
                              child: const Text(
                                'Annuler',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              onPressed:
                                  errorMessage != null ||
                                      nameCtrl.text.isEmpty ||
                                      selectedYearId == null
                                  ? null
                                  : () async {
                                      final notifier = ref.read(
                                        semestersProvider.notifier,
                                      );
                                      if (isNew) {
                                        await notifier.create(
                                          name: nameCtrl.text,
                                          number: semesterNumber,
                                          startDate: startDate,
                                          endDate: endDate,
                                          academicYearId: selectedYearId!,
                                        );
                                      } else {
                                        await notifier.updateSemester(
                                          id: semester.id,
                                          name: nameCtrl.text,
                                          number: semesterNumber,
                                          startDate: startDate,
                                          endDate: endDate,
                                        );
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brand,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _brand.withOpacity(
                                  0.3,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                isNew ? 'Créer' : 'Modifier',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _datePicker(
    BuildContext ctx,
    String label,
    DateTime date,
    void Function(void Function()) setDialogState,
    void Function(DateTime) onPicked, {
    required DateTime firstDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _semLabel(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: date,
              firstDate: firstDate,
              lastDate: DateTime(2030),
            );
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
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMMM yyyy', 'fr').format(date),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _semLabel(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF111827),
      ),
    ),
  );

  static InputDecoration _semInputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(
      color: Colors.grey.shade400,
      fontWeight: FontWeight.w400,
      fontSize: 14,
    ),
    filled: true,
    fillColor: const Color(0xFFF9FAFB),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey.shade200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _brand, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    isDense: true,
  );

  void _showCreatePeriodsDialog(BuildContext context) {
    final state = ref.read(semestersProvider).value;
    if (state == null) return;

    final year = state.currentAcademicYear;
    if (year == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucune année scolaire active'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    var selectedType = 'semestre';
    var ranges = _splitYear(year.startDate, year.endDate, 2);
    var manualVacations = <({DateTime start, DateTime end})>[];
    var examPeriods = <({DateTime start, DateTime end})>[];
    String? errorMessage;

    List<({DateTime start, DateTime end})> computeAutoGaps() {
      if (ranges.isEmpty) return [];
      final sorted = [...ranges]
        ..sort((a, b) => a.start.compareTo(b.start));
      final gaps = <({DateTime start, DateTime end})>[];

      if (sorted.first.start.isAfter(year.startDate)) {
        gaps.add((
          start: year.startDate,
          end: sorted.first.start.subtract(const Duration(days: 1)),
        ));
      }
      for (var i = 0; i < sorted.length - 1; i++) {
        final nextStart = sorted[i + 1].start;
        final prevEnd = sorted[i].end;
        if (nextStart.isAfter(prevEnd.add(const Duration(days: 1)))) {
          gaps.add((
            start: prevEnd.add(const Duration(days: 1)),
            end: nextStart.subtract(const Duration(days: 1)),
          ));
        }
      }
      if (sorted.last.end.isBefore(year.endDate)) {
        gaps.add((
          start: sorted.last.end.add(const Duration(days: 1)),
          end: year.endDate,
        ));
      }
      return gaps;
    }

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final label = selectedType == 'trimestre' ? 'Trimestre' : selectedType == 'single' ? 'Période' : 'Semestre';
          final autoGaps = computeAutoGaps();

          void validate() {
            errorMessage = null;

            // Each range must be valid
            for (var i = 0; i < ranges.length; i++) {
              if (ranges[i].start.isAfter(ranges[i].end)) {
                errorMessage =
                    'La date de début doit être avant la date de fin pour $label ${i + 1}';
                break;
              }
            }

            // Within academic year bounds
            if (errorMessage == null) {
              if (ranges.first.start.isBefore(year.startDate)) {
                errorMessage =
                    'La première période ne peut pas commencer avant le début de l\'année scolaire';
              } else if (ranges.last.end.isAfter(year.endDate)) {
                errorMessage =
                    'La dernière période ne peut pas se terminer après la fin de l\'année scolaire';
              }
            }

            // No overlap with existing periods
            if (errorMessage == null) {
              for (var i = 0; i < ranges.length; i++) {
                final overlap = state.validateOverlap(
                  ranges[i].start,
                  ranges[i].end,
                );
                if (overlap != null) {
                  errorMessage = '$label ${i + 1}: $overlap';
                  break;
                }
              }
            }

            setDialogState(() {});
          }

           void onTypeChanged(String type) {
            selectedType = type;
            if (type == 'single') {
              ranges = [(start: year.startDate, end: year.endDate)];
            } else {
              ranges = _splitYear(
                year.startDate,
                year.endDate,
                type == 'semestre' ? 2 : 3,
              );
            }
            validate();
          }

          void onStartChanged(int index, DateTime d) {
            ranges = [
              for (var i = 0; i < ranges.length; i++)
                if (i == index) (start: d, end: ranges[i].end) else ranges[i],
            ];
            validate();
          }

          void onEndChanged(int index, DateTime d) {
            ranges = [
              for (var i = 0; i < ranges.length; i++)
                if (i == index) (start: ranges[i].start, end: d) else ranges[i],
            ];
            validate();
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: 560,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _brandLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 20,
                              color: _brand,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nouvelles périodes',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Année scolaire: ${year.name}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(height: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 20),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      // Type selector
                      _semLabel('Type de période'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _typeOption(
                            'Période unique',
                            'single',
                            selectedType,
                            Icons.today_rounded,
                            onTypeChanged,
                          ),
                          const SizedBox(width: 12),
                          _typeOption(
                            'Semestre',
                            'semestre',
                            selectedType,
                            Icons.date_range_rounded,
                            onTypeChanged,
                          ),
                          const SizedBox(width: 12),
                          _typeOption(
                            'Trimestre',
                            'trimestre',
                            selectedType,
                            Icons.view_week_rounded,
                            onTypeChanged,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Date ranges
                      ...List.generate(ranges.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$label ${index + 1}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: _datePicker(
                                      ctx,
                                      'Date de début',
                                      ranges[index].start,
                                      setDialogState,
                                      (d) => onStartChanged(index, d),
                                      firstDate: DateTime(2020),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _datePicker(
                                      ctx,
                                      'Date de fin',
                                      ranges[index].end,
                                      setDialogState,
                                      (d) => onEndChanged(index, d),
                                      firstDate: ranges[index].start,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      // Auto vacations (gaps between periods)
                      if (autoGaps.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _semLabel('Vacances automatiques (gaps)'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: autoGaps.map((g) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Text(
                              '${DateFormat('dd MMM', 'fr').format(g.start)} - ${DateFormat('dd MMM', 'fr').format(g.end)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                            ),
                          )).toList(),
                        ),
                      ],
                      // Manual vacations
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _semLabel('Vacances supplémentaires'),
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                manualVacations.add((
                                  start: year.startDate,
                                  end: year.startDate,
                                ));
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.add, size: 14, color: Color(0xFF374151)),
                                  SizedBox(width: 4),
                                  Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (manualVacations.isEmpty)
                        Text('Aucune vacance supplémentaire', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      ...List.generate(manualVacations.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: _datePicker(
                                  ctx,
                                  'Début',
                                  manualVacations[index].start,
                                  setDialogState,
                                  (d) => setDialogState(() {
                                    manualVacations[index] = (start: d, end: manualVacations[index].end);
                                  }),
                                  firstDate: DateTime(2020),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _datePicker(
                                  ctx,
                                  'Fin',
                                  manualVacations[index].end,
                                  setDialogState,
                                  (d) => setDialogState(() {
                                    manualVacations[index] = (start: manualVacations[index].start, end: d);
                                  }),
                                  firstDate: manualVacations[index].start,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade400),
                                onPressed: () => setDialogState(() => manualVacations.removeAt(index)),
                              ),
                            ],
                          ),
                        );
                      }),
                      // Exam periods
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _semLabel('Périodes d\'examens'),
                          GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                examPeriods.add((
                                  start: year.startDate,
                                  end: year.startDate,
                                ));
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.add, size: 14, color: Color(0xFF374151)),
                                  SizedBox(width: 4),
                                  Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (examPeriods.isEmpty)
                        Text('Aucune période d\'examen', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                       ...List.generate(examPeriods.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: _datePicker(
                                  ctx,
                                  'Début',
                                  examPeriods[index].start,
                                  setDialogState,
                                  (d) => setDialogState(() {
                                    examPeriods[index] = (start: d, end: d.isAfter(examPeriods[index].end) ? d : examPeriods[index].end);
                                  }),
                                  firstDate: DateTime(2020),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _datePicker(
                                  ctx,
                                  'Fin',
                                  examPeriods[index].end,
                                  setDialogState,
                                  (d) => setDialogState(() {
                                    examPeriods[index] = (start: examPeriods[index].start, end: d);
                                  }),
                                  firstDate: examPeriods[index].start,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade400),
                                onPressed: () => setDialogState(() => examPeriods.removeAt(index)),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 16,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                               ),
                             ],
                           ),
                         ),
                       ], // end errorMessage spread
                       ], // end inner Column children
                       ), // end inner Column
                       ), // end SingleChildScrollView
                       ), // end Flexible
                       const SizedBox(height: 20),
                      Divider(height: 1, color: Colors.grey.shade200),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 40,
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF6B7280),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                              ),
                              child: const Text(
                                'Annuler',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              onPressed: errorMessage != null
                                  ? null
                                  : () async {
                                      final notifier = ref.read(
                                        semestersProvider.notifier,
                                      );
                                      await notifier.createPeriods(
                                        type: selectedType,
                                        ranges: ranges,
                                        manualVacations: manualVacations,
                                        examPeriods: examPeriods,
                                      );
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brand,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _brand.withOpacity(
                                  0.3,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Créer',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<({DateTime start, DateTime end})> _splitYear(
    DateTime start,
    DateTime end,
    int count,
  ) {
    final totalDays = end.difference(start).inDays + 1;
    final partDays = totalDays ~/ count;
    final result = <({DateTime start, DateTime end})>[];
    for (var i = 0; i < count; i++) {
      final partStart = start.add(Duration(days: i * partDays));
      final partEnd = i == count - 1
          ? end
          : start.add(Duration(days: (i + 1) * partDays - 1));
      result.add((start: partStart, end: partEnd));
    }
    return result;
  }

  Widget _typeOption(
    String title,
    String type,
    String selectedType,
    IconData icon,
    ValueChanged<String> onChanged,
  ) {
    final isSelected = selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF3F0FF) : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _brand : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? _brand : Colors.grey.shade500,
                size: 20,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? _brand : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, SemesterModel s) {
    final periodLabel =
        ref.read(semestersProvider).value?.periodLabel ?? 'Semestre';
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Supprimer le ${periodLabel.toLowerCase()} ?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Voulez-vous supprimer "${s.name}" ? Cette action est irréversible.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey.shade600,
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            child: const Text(
                              'Annuler',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed: () {
                              ref.read(semestersProvider.notifier).delete(s.id);
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Supprimer',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
