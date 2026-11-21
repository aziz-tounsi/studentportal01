library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/arabic_typography.dart';
import '../../data/services/core_data_service.dart';
import '../providers/student_context_provider.dart';

enum LockedModuleType {
  timetable,
  absences,
  grades,
  documents,
  general,
}

/// Helper function to check if a semester is locked (upcoming/future).
/// Past and current semesters are unlocked.
bool isSemesterLocked(int semesterNumber, List<SemesterInfo> semesters) {
  if (semesters.isEmpty) return false;
  final sem = semesters.where((s) => s.number == semesterNumber).firstOrNull;
  if (sem != null && sem.isCurrent) return false;

  final currentSemNum = resolveCurrentSemesterNumber(semesters);
  if (semesterNumber > currentSemNum) return true;

  final now = DateTime.now();
  if (sem?.startDate != null && now.isBefore(sem!.startDate!) && !sem.isCurrent) {
    return true;
  }
  return false;
}

/// A premium iOS 26 glass card displaying a locked/upcoming semester state.
/// Matches the design of the empty timetable card.
class LockedSemesterCard extends ConsumerWidget {
  final DateTime? startDate;
  final LockedModuleType moduleType;
  final String? customTitle;
  final String? customSubtitle;

  const LockedSemesterCard({
    super.key,
    this.startDate,
    this.moduleType = LockedModuleType.general,
    this.customTitle,
    this.customSubtitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final isArabic = lang == 'ar';

    final semesters = ref.watch(semestersProvider).value ?? [];
    final count = semesters.length;
    final periodUnit = SemesterInfo.getPeriodUnitName(count);
    final periodUnitLower = periodUnit.toLowerCase();

    final formattedDate = startDate != null
        ? (isArabic
            ? ArabicTypography.toLatinDigits(
                DateFormat('d MMMM yyyy', lang).format(startDate!),
              )
            : DateFormat('d MMMM yyyy', lang).format(startDate!))
        : null;

    final String title = customTitle ?? (lang == 'fr'
        ? '$periodUnit à venir'
        : (isArabic
            ? (count == 3 ? 'الثلاثي القادم' : (count == 2 ? 'الفصل القادم' : 'الفترة القادمة'))
            : l10n.upcomingSemester));
    final String subtitle = customSubtitle ?? _getSubtitle(lang, formattedDate, l10n, periodUnitLower, count);

    final gradientColors = _getGradientColors();

    return Align(
      alignment: const Alignment(0, -0.35),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 34,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: ArabicTypography.headerStyle(
                  context,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2937),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: ArabicTypography.bodyStyle(
                  context,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _getGradientColors() {
    switch (moduleType) {
      case LockedModuleType.timetable:
        return const [Color(0xFFEA580C), Color(0xFFF97316)];
      case LockedModuleType.absences:
        return const [Color(0xFFEC4899), Color(0xFFF43F5E)];
      case LockedModuleType.grades:
        return const [Color(0xFF3B82F6), Color(0xFF2563EB)];
      case LockedModuleType.documents:
        return const [Color(0xFF10B981), Color(0xFF059669)];
      case LockedModuleType.general:
        return const [Color(0xFF8B5CF6), Color(0xFF7C3AED)];
    }
  }

  String _getSubtitle(
    String lang,
    String? date,
    AppLocalizations l10n,
    String periodUnitLower,
    int count,
  ) {
    final arUnit = count == 3 ? 'الثلاثي' : (count == 2 ? 'الفصل الدراسي' : 'الفترة');
    if (lang == 'ar') {
      if (date != null) {
        switch (moduleType) {
          case LockedModuleType.timetable:
            return 'سيكون جدول الأوقات متاحاً ابتداءً من $date.';
          case LockedModuleType.absences:
            return 'سيكون تتبع الغيابات متاحاً ابتداءً من $date.';
          case LockedModuleType.grades:
            return 'ستكون النتائج والدرجات متاحة ابتداءً من $date.';
          case LockedModuleType.documents:
            return 'ستكون مستندات هذا $arUnit متاحة ابتداءً من $date.';
          case LockedModuleType.general:
            return 'هذا $arUnit لم يبدأ بعد. ستكون البيانات متاحة ابتداءً من $date.';
        }
      } else {
        switch (moduleType) {
          case LockedModuleType.timetable:
            return 'سيكون جدول الأوقات متاحاً مع بداية $arUnit.';
          case LockedModuleType.absences:
            return 'سيكون تتبع الغيابات متاحاً مع بداية $arUnit.';
          case LockedModuleType.grades:
            return 'ستكون النتائج والدرجات متاحة مع بداية $arUnit.';
          case LockedModuleType.documents:
            return 'ستُنشر المستندات مع بداية $arUnit.';
          case LockedModuleType.general:
            return 'هذا $arUnit لم يبدأ بعد. ستكون البيانات متاحة قريباً.';
        }
      }
    } else if (lang == 'fr') {
      if (date != null) {
        switch (moduleType) {
          case LockedModuleType.timetable:
            return "L'emploi du temps sera disponible à partir du $date.";
          case LockedModuleType.absences:
            return "Le suivi des absences sera disponible à partir du $date.";
          case LockedModuleType.grades:
            return "Les résultats et notes seront disponibles à partir du $date.";
          case LockedModuleType.documents:
            return "Les documents de ce $periodUnitLower seront disponibles à partir du $date.";
          case LockedModuleType.general:
            return "Ce $periodUnitLower n'a pas encore commencé. Les données seront disponibles à partir du $date.";
        }
      } else {
        switch (moduleType) {
          case LockedModuleType.timetable:
            return "L'emploi du temps sera disponible dès le début du $periodUnitLower.";
          case LockedModuleType.absences:
            return "Le suivi des absences sera disponible dès le début du $periodUnitLower.";
          case LockedModuleType.grades:
            return "Les résultats et notes seront disponibles dès le début du $periodUnitLower.";
          case LockedModuleType.documents:
            return "Les documents seront publiés dès le début du $periodUnitLower.";
          case LockedModuleType.general:
            return "Ce $periodUnitLower n'a pas encore commencé. Les informations seront disponibles prochainement.";
        }
      }
    } else {
      final enUnit = count == 3 ? 'trimester' : (count == 2 ? 'semester' : (count == 4 ? 'quarter' : 'period'));
      if (date != null) {
        switch (moduleType) {
          case LockedModuleType.timetable:
            return 'Timetable will be available starting from $date.';
          case LockedModuleType.absences:
            return 'Absence tracking will be available starting from $date.';
          case LockedModuleType.grades:
            return 'Grades and results will be available starting from $date.';
          case LockedModuleType.documents:
            return 'Documents for this $enUnit will be available starting from $date.';
          case LockedModuleType.general:
            return 'This $enUnit has not started yet. Data will be available starting from $date.';
        }
      } else {
        switch (moduleType) {
          case LockedModuleType.timetable:
            return 'Timetable will be available at the start of the $enUnit.';
          case LockedModuleType.absences:
            return 'Absence tracking will be available at the start of the $enUnit.';
          case LockedModuleType.grades:
            return 'Grades and results will be available at the start of the $enUnit.';
          case LockedModuleType.documents:
            return 'Documents will be published at the start of the $enUnit.';
          case LockedModuleType.general:
            return 'This $enUnit has not started yet. Data will be available soon.';
        }
      }
    }
  }
}
