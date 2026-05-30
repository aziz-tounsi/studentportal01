import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/theme/app_theme.dart' show AppColors;
import '../../../data/models/school_models.dart';
import '../../providers/groups_provider.dart';
import '../../widgets/admin_sidebar.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/groups'),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, ref),
                Expanded(child: groupsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erreur: $e')),
                  data: (state) => _buildContent(context, ref, state),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, WidgetRef ref) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: AppColors.surface, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Row(
        children: [
          Text('Groupes', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showGroupDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, GroupsState state) {
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
                  DropdownButton<String?>(
                    value: state.selectedClassId,
                    hint: const Text('Filtrer par classe'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Toutes les classes')),
                      ...state.classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) => ref.read(groupsProvider.notifier).setClassFilter(v),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildTable(context, ref, state)),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context, WidgetRef ref, GroupsState state) {
    final groups = state.filtered;
    return DataTable2(
      columnSpacing: 12,
      horizontalMargin: 16,
      minWidth: 600,
      columns: const [
        DataColumn2(label: Text('Nom', style: TextStyle(fontWeight: FontWeight.bold)), size: ColumnSize.L),
        DataColumn2(label: Text('Classe', style: TextStyle(fontWeight: FontWeight.bold)), size: ColumnSize.L),
        DataColumn2(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold)), fixedWidth: 120),
      ],
      rows: groups.map((g) {
        final className = state.classes.firstWhere((c) => c.id == g.classId, orElse: () => state.classes.first).name;
        return DataRow2(
          cells: [
            DataCell(Text(g.name)),
            DataCell(Text(className)),
            DataCell(Row(children: [
              IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _showGroupDialog(context, ref, group: g), tooltip: 'Modifier'),
              IconButton(icon: Icon(Icons.delete, size: 20, color: AppColors.error), onPressed: () => _confirmDelete(context, ref, g), tooltip: 'Supprimer'),
            ])),
          ],
        );
      }).toList(),
      empty: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.folder, size: 64, color: AppColors.textTertiary),
        const SizedBox(height: 16),
        Text('Aucun groupe', style: TextStyle(color: AppColors.textSecondary)),
      ])),
    );
  }

  void _showGroupDialog(BuildContext context, WidgetRef ref, {GroupModel? group}) {
    final state = ref.read(groupsProvider).value;
    if (state == null || state.classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Veuillez creer une classe dabord'), backgroundColor: AppColors.accent));
      return;
    }

    final nameController = TextEditingController(text: group?.name ?? '');
    String selectedClassId = group?.classId ?? state.classes.first.id;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(group == null ? 'Nouveau groupe' : 'Modifier groupe'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nom du groupe', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedClassId,
              decoration: const InputDecoration(labelText: 'Classe', border: OutlineInputBorder()),
              items: state.classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (v) => selectedClassId = v!,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE8EAF0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (nameController.text.isEmpty) return;
                      if (group == null) {
                        ref.read(groupsProvider.notifier).create(classId: selectedClassId, name: nameController.text);
                      } else {
                        ref.read(groupsProvider.notifier).updateGroup(id: group.id, classId: selectedClassId, name: nameController.text);
                      }
                      Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(group == null ? 'Créer' : 'Modifier', style: const TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void _confirmDelete(BuildContext context, WidgetRef ref, GroupModel g) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer groupe ?'),
        content: Text('Voulez-vous supprimer "${g.name}" ?'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE8EAF0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () { ref.read(groupsProvider.notifier).delete(g.id); Navigator.pop(ctx); },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}