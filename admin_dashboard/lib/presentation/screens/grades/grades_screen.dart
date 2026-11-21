import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart' show AppColors;
import '../../../core/utils/error_messages.dart';
import '../../providers/grades_provider.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/ios_loader.dart';

class GradesScreen extends ConsumerWidget {
  const GradesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradesAsync = ref.watch(gradesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/grades'),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(child: gradesAsync.when(
                  loading: () => const Center(child: IosLoader()),
                  error: (e, _) => Center(
                    child: Text(
                      UserFriendlyError.format(
                        e,
                        fallback: 'Unable to load grades right now. Please try again.',
                      ),
                    ),
                  ),
                  data: (state) => _buildContent(context, ref, state),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: AppColors.surface, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Row(
        children: [
          Text('Notes', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, GradesState state) {
    final list = state.filtered;
    final dateFormat = DateFormat('d MMM yyyy', 'fr_FR');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('${list.length} note(s)', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
            Expanded(
              child: DataTable2(
                columnSpacing: 12,
                horizontalMargin: 16,
                minWidth: 800,
                columns: const [
                  DataColumn2(label: Text('Etudiant', style: TextStyle(fontWeight: FontWeight.bold)), size: ColumnSize.L),
                  DataColumn2(label: Text('Classe', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn2(label: Text('Matiere', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn2(label: Text('Note', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn2(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn2(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn2(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)), fixedWidth: 80),
                ],
                rows: list.map((g) => DataRow2(
                  cells: [
                    DataCell(Text(g.studentName)),
                    DataCell(Text(g.className ?? '-')),
                    DataCell(Text(g.subjectName)),
                    DataCell(_GradeChip(value: g.grade, maxValue: g.maxGrade)),
                    DataCell(Text(g.gradeType ?? '-')),
                    DataCell(Text(dateFormat.format(g.createdAt))),
                    DataCell(IconButton(icon: Icon(Icons.delete, size: 20, color: AppColors.error), onPressed: () => ref.read(gradesProvider.notifier).delete(g.id), tooltip: 'Supprimer')),
                  ],
                )).toList(),
                empty: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.grade, size: 64, color: AppColors.textTertiary), const SizedBox(height: 16), Text('Aucune note', style: TextStyle(color: AppColors.textSecondary))])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeChip extends StatelessWidget {
  final double value;
  final double maxValue;
  const _GradeChip({required this.value, required this.maxValue});

  @override
  Widget build(BuildContext context) {
    final pct = maxValue > 0 ? value / maxValue : 0;
    Color bg;
    Color fg;
    if (pct >= 0.7) {
      bg = AppColors.success.withOpacity(0.2);
      fg = AppColors.success;
    } else if (pct >= 0.5) {
      bg = AppColors.accentSoft;
      fg = AppColors.accent;
    } else {
      bg = AppColors.errorSoft;
      fg = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text('${value.toStringAsFixed(1)}/${maxValue.toStringAsFixed(0)}', style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}