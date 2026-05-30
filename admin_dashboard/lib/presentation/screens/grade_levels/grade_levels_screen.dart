import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart' show AppColors;
import '../../providers/grade_levels_provider.dart';
import '../../widgets/admin_sidebar.dart';
import '../../../data/models/academic_models.dart';

// =====================================================================
// GRADE LEVELS SCREEN — Premium Redesign matching HTML mockup
// =====================================================================

class GradeLevelsScreen extends ConsumerStatefulWidget {
  const GradeLevelsScreen({super.key});
  @override
  ConsumerState<GradeLevelsScreen> createState() => _GradeLevelsScreenState();
}

class _GradeLevelsScreenState extends ConsumerState<GradeLevelsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final Set<String> _collapsedCycles = {};
  bool _showFilterPanel = false;
  String? _filterCycle;
  String? _filterGradeId;
  String? _filterSectionId;
  String? _filterExamTypeId;
  final _teacherSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _teacherSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(gradeLevelsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: Stack(
        children: [
          Row(
            children: [
              const AdminSidebar(currentRoute: '/grade-levels'),
              Expanded(
                child: Column(
                  children: [
                    _buildHeader(context, stateAsync.asData?.value),
                    Expanded(
                      child: stateAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF655DD5),
                          ),
                        ),
                        error: (e, _) => _buildErrorState(e),
                        data: (state) => _buildContent(context, state),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Filter panel overlay — full-app blur
          if (_showFilterPanel) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showFilterPanel = false),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(color: Colors.black.withOpacity(0.28)),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              right: 0,
              top: 0,
              bottom: 0,
              width: 380,
              child: _buildFilterPanel(stateAsync.value),
            ),
          ],
        ],
      ),
    );
  }

  // ====================== HEADER ======================
  Widget _buildHeader(BuildContext context, GradeLevelsState? state) {
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
                'Niveaux & Filières',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gérer les niveaux scolaires, les filières académiques et les types d\'examens associés.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
          const Spacer(),
          // Search bar
          SizedBox(
            width: 320,
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => ref.read(gradeLevelsProvider.notifier).setSearch(v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                hintStyle: TextStyle(color: AppColors.slate400, fontSize: 13),
                prefixIcon: Icon(Icons.search, size: 18, color: AppColors.slate400),
                suffixIcon: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Text('⌘K', style: TextStyle(fontSize: 10, color: AppColors.slate400, fontFamily: 'monospace')),
                  ),
                ),
                filled: true,
                fillColor: AppColors.slate50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.slate200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.slate200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: const Color(0xFF655DD5).withOpacity(0.4), width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter button
          _buildFilterButton(),
          const SizedBox(width: 16),
          // Ajouter popup button
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _headerIconButton(IconData icon) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: IconButton(
        onPressed: () {},
        icon: Icon(icon, size: 20, color: AppColors.slate600),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildFilterButton() {
    final hasFilters = _filterCycle != null ||
        _filterGradeId != null ||
        _filterSectionId != null ||
        _filterExamTypeId != null ||
        _teacherSearchCtrl.text.isNotEmpty;
    // Same height & matching the others
    return SizedBox(
      height: 40,
      width: 40,
      child: IconButton(
        icon: const Icon(Icons.filter_list_rounded, size: 20),
        tooltip: 'Filtres',
        onPressed: () => setState(() => _showFilterPanel = !_showFilterPanel),
        color: (_showFilterPanel || hasFilters) ? const Color(0xFF655DD5) : AppColors.slate500,
        style: IconButton.styleFrom(
          backgroundColor: (_showFilterPanel || hasFilters) ? const Color(0xFF655DD5).withOpacity(0.1) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: (_showFilterPanel || hasFilters) ? const Color(0xFF655DD5).withOpacity(0.2) : Colors.transparent),
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return PopupMenuButton<String>(
      onSelected: (v) => _showAddDialog(v),
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (ctx) => [
        _popupItem('grade', Icons.layers_outlined, 'Ajouter Niveau'),
        _popupItem('section', Icons.account_tree_outlined, 'Ajouter Filière'),
        const PopupMenuDivider(),
        _popupItem('exam', Icons.description_outlined, 'Ajouter Type d\'examen'),
      ],
      child: SizedBox(
        height: 40,
        child: ElevatedButton.icon(
          onPressed: null, // onPressed is handled by PopupMenuButton catching taps on the child
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Ajouter', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6D4CF6),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF6D4CF6),
            disabledForegroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            shadowColor: const Color(0xFF6D4CF6).withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _popupItem(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF655DD5), size: 18),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 52, color: AppColors.error.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('Erreur: $error', style: TextStyle(color: AppColors.slate500)),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => ref.read(gradeLevelsProvider.notifier).refresh(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF655DD5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Réessayer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== CONTENT AREA ====================
  Widget _buildContent(BuildContext context, GradeLevelsState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Tabs
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.slate200)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: const Color(0xFF0F172A),
              unselectedLabelColor: AppColors.slate500,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              indicatorColor: const Color(0xFF655DD5),
              indicatorWeight: 2,
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Niveaux'),
                Tab(text: 'Filières'),
                Tab(text: 'Types d\'examen'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGradesTab(context, state),
                _buildSectionsTab(context, state),
                _buildExamTypesTab(context, state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== GRADES TAB ====================
  Widget _buildGradesTab(BuildContext context, GradeLevelsState state) {
    // Apply local filters on top of provider data
    var college = state.collegeGrades;
    var secondaire = state.secondaireGrades;

    // Filter by cycle
    final showCollege = _filterCycle == null || _filterCycle == 'college';
    final showSecondaire = _filterCycle == null || _filterCycle == 'secondaire';

    // Filter by specific grade
    if (_filterGradeId != null) {
      college = college.where((g) => g.id == _filterGradeId).toList();
      secondaire = secondaire.where((g) => g.id == _filterGradeId).toList();
    }

    // Filter by section
    if (_filterSectionId != null) {
      college = college.where((g) => g.sections.any((s) => s.id == _filterSectionId)).toList();
      secondaire = secondaire.where((g) => g.sections.any((s) => s.id == _filterSectionId)).toList();
    }

    // Filter by teacher / class name search
    final teacherQuery = _teacherSearchCtrl.text.trim().toLowerCase();
    if (teacherQuery.isNotEmpty) {
      bool matchesGrade(GradeLevelModel g) =>
          g.name.toLowerCase().contains(teacherQuery) ||
          g.classes.any((c) => c.name.toLowerCase().contains(teacherQuery));
      college = college.where(matchesGrade).toList();
      secondaire = secondaire.where(matchesGrade).toList();
    }

    final visibleCollege = showCollege ? college : <GradeLevelModel>[];
    final visibleSecondaire = showSecondaire ? secondaire : <GradeLevelModel>[];

    return SingleChildScrollView(
      child: Column(
        children: [
          if (visibleCollege.isNotEmpty)
            _buildCycleCard(
              title: 'Collège',
              icon: Icons.domain,
              grades: visibleCollege,
              cycleKey: 'college',
              state: state,
            ),
          if (visibleCollege.isNotEmpty && visibleSecondaire.isNotEmpty)
            const SizedBox(height: 24),
          if (visibleSecondaire.isNotEmpty)
            _buildCycleCard(
              title: 'Secondaire',
              icon: Icons.account_balance,
              grades: visibleSecondaire,
              cycleKey: 'secondaire',
              state: state,
            ),
          if (visibleCollege.isEmpty && visibleSecondaire.isEmpty)
            _buildEmptyGrades(),
          const SizedBox(height: 16),
          _buildFooter(state),
        ],
      ),
    );
  }

  Widget _buildEmptyGrades() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.school_outlined, size: 56, color: AppColors.slate300),
            const SizedBox(height: 16),
            Text('Aucun niveau scolaire', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.slate500)),
            const SizedBox(height: 8),
            Text('Commencez par ajouter un niveau depuis le bouton "Ajouter".', style: TextStyle(fontSize: 13, color: AppColors.slate400)),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleCard({
    required String title,
    required IconData icon,
    required List<GradeLevelModel> grades,
    required String cycleKey,
    required GradeLevelsState state,
  }) {
    final isCollapsed = _collapsedCycles.contains(cycleKey);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF655DD5).withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF655DD5).withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Cycle Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: isCollapsed
                  ? null
                  : Border(bottom: BorderSide(color: AppColors.slate200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF655DD5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(icon, color: const Color(0xFF655DD5), size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.slate200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${grades.length} NIVEAUX',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () => _showGradeDialog(),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.edit, size: 20, color: AppColors.slate400),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () => setState(() {
                    if (isCollapsed) {
                      _collapsedCycles.remove(cycleKey);
                    } else {
                      _collapsedCycles.add(cycleKey);
                    }
                  }),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isCollapsed ? Icons.expand_more : Icons.expand_less,
                      size: 20,
                      color: AppColors.slate400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Cycle Content
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: grades.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final grade = entry.value;
                  return Column(
                    children: [
                      _buildGradeRow(grade, state),
                      if (idx < grades.length - 1) const SizedBox(height: 16),
                    ],
                  );
                }).toList(),
              ),
            ),
            crossFadeState: isCollapsed
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeRow(GradeLevelModel grade, GradeLevelsState state) {
    return _HoverableGradeRow(
      key: ValueKey(grade.id),
      grade: grade,
      state: state,
      onEdit: () => _showGradeDialog(grade),
      onDelete: () => _confirmDeleteGrade(grade),
      onAddClass: () => _showClassDialog(grade, state),
      onClassTap: (cls) => context.go('/classes/${cls.id}'),
      onAssignSection: () => _showAssignSectionDialog(grade, state),
      onRemoveSection: (sId) => _removeSectionFromGrade(grade.id, sId),
    );
  }

  Widget _buildFooter(GradeLevelsState state) {
    final totalStudents = state.gradeLevels.fold<int>(
      0,
      (sum, g) => sum + g.studentCount,
    );
    final totalClasses = state.gradeLevels.fold<int>(
      0,
      (sum, g) => sum + g.classCount,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.slate200)),
      ),
      child: Row(
        children: [
          Text(
            'Données académiques actuelles',
            style: TextStyle(fontSize: 12, color: AppColors.slate400),
          ),
          const Spacer(),
          Icon(Icons.groups_outlined, size: 16, color: AppColors.slate400),
          const SizedBox(width: 4),
          Text(
            '$totalStudents Élèves au total',
            style: TextStyle(fontSize: 12, color: AppColors.slate400),
          ),
          const SizedBox(width: 24),
          Icon(Icons.meeting_room_outlined, size: 16, color: AppColors.slate400),
          const SizedBox(width: 4),
          Text(
            '$totalClasses Classes actives',
            style: TextStyle(fontSize: 12, color: AppColors.slate400),
          ),
        ],
      ),
    );
  }

  // ==================== SECTIONS TAB ====================
  Widget _buildSectionsTab(BuildContext context, GradeLevelsState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF655DD5).withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: AppColors.slate200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF655DD5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.account_tree, color: Color(0xFF655DD5), size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Filières (Sections)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.slate200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${state.sections.length} FILIÈRES',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate600, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.sections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_tree_outlined, size: 56, color: AppColors.slate300),
                        const SizedBox(height: 16),
                        Text('Aucune filière', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.slate500)),
                        const SizedBox(height: 8),
                        Text('Ajoutez des filières pour structurer le secondaire.', style: TextStyle(fontSize: 13, color: AppColors.slate400)),
                        const SizedBox(height: 20),
                        InkWell(
                          onTap: () => _showSectionDialog(),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF655DD5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Ajouter une filière', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.sections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _buildSectionTile(state.sections[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTile(SectionModel section) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.slate100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF655DD5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                section.code,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF655DD5), fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B))),
                if (section.description != null) ...[
                  const SizedBox(height: 2),
                  Text(section.description!, style: TextStyle(fontSize: 12, color: AppColors.slate400), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          _gradeActionButton(Icons.edit, () => _showSectionDialog(section)),
          const SizedBox(width: 4),
          _gradeActionButton(Icons.delete_outline, () => _confirmDeleteSection(section), isDelete: true),
        ],
      ),
    );
  }

  // ==================== EXAM TYPES TAB ====================
  Widget _buildExamTypesTab(BuildContext context, GradeLevelsState state) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF655DD5).withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: AppColors.slate200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF655DD5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.description_outlined, color: Color(0xFF655DD5), size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Types d\'Examen',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.slate200,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${state.examTypes.length} TYPES',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.slate600, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.examTypes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description_outlined, size: 56, color: AppColors.slate300),
                        const SizedBox(height: 16),
                        Text('Aucun type d\'examen', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.slate500)),
                        const SizedBox(height: 8),
                        Text('Définissez les types d\'évaluations (Devoir, Composition, etc.).', style: TextStyle(fontSize: 13, color: AppColors.slate400)),
                        const SizedBox(height: 20),
                        InkWell(
                          onTap: () => _showExamTypeDialog(),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF655DD5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 18, color: Colors.white),
                                SizedBox(width: 8),
                                Text('Ajouter un type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.examTypes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _buildExamTypeCard(state.examTypes[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamTypeCard(ExamTypeModel examType) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.slate100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF655DD5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                examType.code,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF655DD5), fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(examType.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (examType.description != null)
                  Text(examType.description!, style: TextStyle(fontSize: 12, color: AppColors.slate400), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          _gradeActionButton(Icons.edit, () => _showExamTypeDialog(examType)),
          const SizedBox(width: 4),
          _gradeActionButton(Icons.delete_outline, () => _confirmDeleteExamType(examType), isDelete: true),
        ],
      ),
    );
  }

  // ==================== SHARED ACTION BUTTON ====================
  Widget _gradeActionButton(IconData icon, VoidCallback onTap, {bool isDelete = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.slate100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: isDelete ? AppColors.error : AppColors.slate600,
          ),
        ),
      ),
    );
  }

  // ==================== AUTO-CODE GENERATION ====================
  String _generateCode(String name) {
    if (name.isEmpty) return '';

    // Remove common words and extract meaningful parts
    final cleaned = name
        .replaceAll(RegExp(r'[éèê]', caseSensitive: false), 'e')
        .replaceAll(RegExp(r'[àâ]', caseSensitive: false), 'a')
        .replaceAll(RegExp(r'[ûù]', caseSensitive: false), 'u')
        .replaceAll(RegExp(r'[îï]', caseSensitive: false), 'i')
        .replaceAll(RegExp(r'[ôö]', caseSensitive: false), 'o')
        .replaceAll(RegExp(r"[']"), ' ');

    // Split into words
    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return '';

    // Check if first word is a number (like "7ème")
    final numMatch = RegExp(r'^(\d+)').firstMatch(words[0]);
    if (numMatch != null) {
      // For "7ème Année de Base" -> "7B", "1ère Année Secondaire" -> "1S"
      final number = numMatch.group(1)!;
      // Find the key word (Base, Secondaire, etc.)
      String suffix = '';
      for (final word in words) {
        final upper = word.toUpperCase();
        if (upper.startsWith('SEC') || upper.startsWith('LYC')) {
          suffix = 'S'; // Secondaire
          break;
        } else if (upper.startsWith('BAS') ||
            upper.startsWith('COL') ||
            upper.startsWith('MOY')) {
          suffix = 'B'; // Base/College
          break;
        }
      }
      if (suffix.isEmpty && words.length > 1) {
        suffix = words[1].substring(0, 1).toUpperCase();
      }
      return '$number$suffix';
    }

    // For section names like "Sciences Expérimentales" -> "SE"
    // Take first letter of each word (max 3 letters)
    final initials = words
        .where((w) => w.length > 2) // Skip small words like "de", "la"
        .take(3)
        .map((w) => w[0].toUpperCase())
        .join();

    return initials.isEmpty ? words[0].substring(0, 2).toUpperCase() : initials;
  }
  
  // Generate a unique code, appending a number if needed
  String _generateUniqueCode(String baseCode, Set<String> existingCodes, {String? excludeId}) {
    if (baseCode.isEmpty) return '';
    
    String code = baseCode.toUpperCase();
    if (!existingCodes.contains(code)) return code;
    
    // Try appending numbers
    for (int i = 2; i <= 99; i++) {
      final newCode = '$code$i';
      if (!existingCodes.contains(newCode)) return newCode;
    }
    
    return code; // Fallback
  }
  
  // Get all existing codes for validation
  Set<String> _getExistingGradeCodes({String? excludeId}) {
    final state = ref.read(gradeLevelsProvider).value;
    if (state == null) return {};
    return state.gradeLevels
        .where((g) => excludeId == null || g.id != excludeId)
        .map((g) => g.code.toUpperCase())
        .toSet();
  }
  
  Set<String> _getExistingSectionCodes({String? excludeId}) {
    final state = ref.read(gradeLevelsProvider).value;
    if (state == null) return {};
    return state.sections
        .where((s) => excludeId == null || s.id != excludeId)
        .map((s) => s.code.toUpperCase())
        .toSet();
  }
  
  Set<String> _getExistingExamTypeCodes({String? excludeId}) {
    final state = ref.read(gradeLevelsProvider).value;
    if (state == null) return {};
    return state.examTypes
        .where((e) => excludeId == null || e.id != excludeId)
        .map((e) => e.code.toUpperCase())
        .toSet();
  }

  // ==================== PREMIUM STYLED INPUT ====================
  Widget _styledField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? errorText,
    String? helperText,
    void Function(String)? onChanged,
    Color? fillColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate600),
            children: required
                ? [const TextSpan(text: ' *', style: TextStyle(color: Color(0xFF655DD5)))]
                : [],
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.slate400, fontSize: 13),
            helperText: helperText,
            helperStyle: TextStyle(color: AppColors.success, fontSize: 11),
            errorText: errorText,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: fillColor ?? AppColors.slate100.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF655DD5), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.error),
            ),
          ),
        ),
      ],
    );
  }

  Widget _styledDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.slate100.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.slate200),
          ),
          child: DropdownButtonFormField<T>(
            value: value,
            decoration: InputDecoration(
              hintText: hint ?? 'Choisir un type...',
              hintStyle: TextStyle(color: AppColors.slate400, fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            icon: Icon(Icons.expand_more, size: 20, color: AppColors.slate400),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _dialogShell({
    required String title,
    required String subtitle,
    required BuildContext ctx,
    required List<Widget> children,
    required VoidCallback onSubmit,
    required String submitLabel,
    bool isEdit = false,
  }) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 120, vertical: 40),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: AppColors.slate400)),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(ctx),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.slate100,
                    ),
                    child: Icon(Icons.close, size: 18, color: AppColors.slate500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Fields
            ...children,

            const SizedBox(height: 28),
            // Footer
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
                    child: const Text('Annuler', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    child: Text(submitLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== DIALOGS ====================
  void _showAddDialog(String type) {
    switch (type) {
      case 'grade':
        _showGradeDialog();
        break;
      case 'section':
        _showSectionDialog();
        break;
      case 'exam':
        _showExamTypeDialog();
        break;
    }
  }

  void _showGradeDialog([GradeLevelModel? grade]) {
    final nameCtrl = TextEditingController(text: grade?.name);
    final codeCtrl = TextEditingController(text: grade?.code);
    final descCtrl = TextEditingController(text: grade?.description);
    final orderCtrl = TextEditingController(text: (grade?.orderIndex ?? 1).toString());
    String levelType = grade?.levelType ?? 'college';
    String? codeError;
    
    final existingCodes = _getExistingGradeCodes(excludeId: grade?.id);

    nameCtrl.addListener(() {
      if (grade == null || codeCtrl.text.isEmpty ||
          codeCtrl.text == _generateCode(nameCtrl.text.substring(0, nameCtrl.text.length > 1 ? nameCtrl.text.length - 1 : 0))) {
        final baseCode = _generateCode(nameCtrl.text);
        codeCtrl.text = _generateUniqueCode(baseCode, existingCodes);
      }
    });

    _showBlurDialog(
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _dialogShell(
          ctx: ctx,
          title: grade == null ? 'Ajouter un Niveau' : 'Modifier le Niveau',
          subtitle: grade == null
              ? 'Configurez un nouveau cycle d\'enseignement pour votre établissement.'
              : 'Modifiez les informations du niveau scolaire.',
          isEdit: grade != null,
          submitLabel: grade == null ? 'Ajouter le niveau' : 'Enregistrer',
          onSubmit: () async {
            if (nameCtrl.text.isEmpty || codeCtrl.text.isEmpty) return;
            // Block submit if code is a duplicate
            if (existingCodes.contains(codeCtrl.text.toUpperCase())) {
              setDialogState(() => codeError = 'Ce code existe déjà');
              return;
            }
            if (codeError != null) return;
            final newGrade = GradeLevelModel(
              id: grade?.id ?? '',
              name: nameCtrl.text,
              code: codeCtrl.text,
              levelType: levelType,
              orderIndex: int.tryParse(orderCtrl.text) ?? 0,
              description: descCtrl.text.isEmpty ? null : descCtrl.text,
            );
            try {
              if (grade == null) {
                await ref.read(gradeLevelsProvider.notifier).addGradeLevel(newGrade);
              } else {
                await ref.read(gradeLevelsProvider.notifier).updateGradeLevel(grade.id, newGrade);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _showSuccess(grade == null ? 'Niveau ajouté' : 'Niveau modifié');
            } catch (e) {
              _showError('Erreur: $e');
            }
          },
          children: [
            _styledField(
              controller: nameCtrl,
              label: 'Nom',
              hint: 'Ex: Collège Enseignement de Base',
              required: true,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _styledField(
                    controller: codeCtrl,
                    label: 'Code',
                    hint: 'Ex: CEB-01',
                    required: true,
                    errorText: codeError,
                    suffixIcon: Icon(Icons.auto_awesome, size: 16, color: const Color(0xFF655DD5).withOpacity(0.5)),
                    onChanged: (v) {
                      if (existingCodes.contains(v.toUpperCase())) {
                        setDialogState(() => codeError = 'Ce code existe déjà');
                      } else {
                        setDialogState(() => codeError = null);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _styledField(
                    controller: orderCtrl,
                    label: 'Ordre d\'affichage',
                    hint: '1',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _styledDropdown<String>(
              label: 'Type d\'enseignement',
              value: levelType,
              hint: 'Choisir un type...',
              items: const [
                DropdownMenuItem(value: 'college', child: Text('Collège (Enseignement de Base)')),
                DropdownMenuItem(value: 'secondaire', child: Text('Lycée (Secondaire)')),
              ],
              onChanged: (v) => setDialogState(() => levelType = v!),
            ),
            const SizedBox(height: 18),
            _styledField(
              controller: descCtrl,
              label: 'Description',
              hint: 'Informations complémentaires sur ce niveau...',
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  void _showSectionDialog([SectionModel? section]) {
    final nameCtrl = TextEditingController(text: section?.name);
    final codeCtrl = TextEditingController(text: section?.code);
    final descCtrl = TextEditingController(text: section?.description);
    String? codeError;
    
    final existingCodes = _getExistingSectionCodes(excludeId: section?.id);

    nameCtrl.addListener(() {
      if (section == null || codeCtrl.text.isEmpty ||
          codeCtrl.text == _generateCode(nameCtrl.text.substring(0, nameCtrl.text.length > 1 ? nameCtrl.text.length - 1 : 0))) {
        final baseCode = _generateCode(nameCtrl.text);
        codeCtrl.text = _generateUniqueCode(baseCode, existingCodes);
      }
    });

    _showBlurDialog(
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _dialogShell(
          ctx: ctx,
          title: section == null ? 'Ajouter une Filière' : 'Modifier la Filière',
          subtitle: section == null
              ? 'Créez une nouvelle filière académique pour structurer le secondaire.'
              : 'Modifiez les informations de la filière.',
          isEdit: section != null,
          submitLabel: section == null ? 'Ajouter la filière' : 'Enregistrer',
          onSubmit: () async {
            if (nameCtrl.text.isEmpty || codeCtrl.text.isEmpty) return;
            // Block submit if code is a duplicate
            if (existingCodes.contains(codeCtrl.text.toUpperCase())) {
              setDialogState(() => codeError = 'Ce code existe déjà');
              return;
            }
            if (codeError != null) return;
            final newSection = SectionModel(
              id: section?.id ?? '',
              name: nameCtrl.text,
              code: codeCtrl.text,
              description: descCtrl.text.isEmpty ? null : descCtrl.text,
            );
            try {
              if (section == null) {
                await ref.read(gradeLevelsProvider.notifier).addSection(newSection);
              } else {
                await ref.read(gradeLevelsProvider.notifier).updateSection(section.id, newSection);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _showSuccess(section == null ? 'Filière ajoutée' : 'Filière modifiée');
            } catch (e) {
              _showError('Erreur: $e');
            }
          },
          children: [
            _styledField(
              controller: nameCtrl,
              label: 'Nom',
              hint: 'Ex: Sciences Expérimentales',
              required: true,
            ),
            const SizedBox(height: 18),
            _styledField(
              controller: codeCtrl,
              label: 'Code',
              hint: 'Ex: SE',
              required: true,
              errorText: codeError,
              suffixIcon: Icon(Icons.auto_awesome, size: 16, color: const Color(0xFF655DD5).withOpacity(0.5)),
              onChanged: (v) {
                if (existingCodes.contains(v.toUpperCase())) {
                  setDialogState(() => codeError = 'Ce code existe déjà');
                } else {
                  setDialogState(() => codeError = null);
                }
              },
            ),
            const SizedBox(height: 18),
            _styledField(
              controller: descCtrl,
              label: 'Description',
              hint: 'Informations complémentaires sur cette filière...',
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  void _showExamTypeDialog([ExamTypeModel? examType]) {
    final nameCtrl = TextEditingController(text: examType?.name);
    final codeCtrl = TextEditingController(text: examType?.code);
    final descCtrl = TextEditingController(text: examType?.description);
    String? codeError;
    
    final existingCodes = _getExistingExamTypeCodes(excludeId: examType?.id);

    nameCtrl.addListener(() {
      if (examType == null || codeCtrl.text.isEmpty ||
          codeCtrl.text == _generateCode(nameCtrl.text.substring(0, nameCtrl.text.length > 1 ? nameCtrl.text.length - 1 : 0))) {
        final baseCode = _generateCode(nameCtrl.text);
        codeCtrl.text = _generateUniqueCode(baseCode, existingCodes);
      }
    });

    _showBlurDialog(
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _dialogShell(
          ctx: ctx,
          title: examType == null ? 'Ajouter un Type d\'Examen' : 'Modifier le Type d\'Examen',
          subtitle: examType == null
              ? 'Définissez un nouveau type d\'évaluation pour votre établissement.'
              : 'Modifiez les informations du type d\'examen.',
          isEdit: examType != null,
          submitLabel: examType == null ? 'Ajouter le type' : 'Enregistrer',
          onSubmit: () async {
            if (nameCtrl.text.isEmpty || codeCtrl.text.isEmpty) return;
            // Block submit if code is a duplicate
            if (existingCodes.contains(codeCtrl.text.toUpperCase())) {
              setDialogState(() => codeError = 'Ce code existe déjà');
              return;
            }
            if (codeError != null) return;
            final newExamType = ExamTypeModel(
              id: examType?.id ?? '',
              name: nameCtrl.text,
              code: codeCtrl.text,
              description: descCtrl.text.isEmpty ? null : descCtrl.text,
            );
            try {
              if (examType == null) {
                await ref.read(gradeLevelsProvider.notifier).addExamType(newExamType);
              } else {
                await ref.read(gradeLevelsProvider.notifier).updateExamType(examType.id, newExamType);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _showSuccess(examType == null ? 'Type ajouté' : 'Type modifié');
            } catch (e) {
              _showError('Erreur: $e');
            }
          },
          children: [
            _styledField(
              controller: nameCtrl,
              label: 'Nom',
              hint: 'Ex: Devoir, Composition',
              required: true,
            ),
            const SizedBox(height: 18),
            _styledField(
              controller: codeCtrl,
              label: 'Code',
              hint: 'Ex: DEV, COMP',
              required: true,
              errorText: codeError,
              suffixIcon: Icon(Icons.auto_awesome, size: 16, color: const Color(0xFF655DD5).withOpacity(0.5)),
              onChanged: (v) {
                if (existingCodes.contains(v.toUpperCase())) {
                  setDialogState(() => codeError = 'Ce code existe déjà');
                } else {
                  setDialogState(() => codeError = null);
                }
              },
            ),
            const SizedBox(height: 18),
            _styledField(
              controller: descCtrl,
              label: 'Description',
              hint: 'Informations complémentaires sur ce type d\'examen...',
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignSectionDialog(GradeLevelModel grade, GradeLevelsState state) {
    final assignedIds = grade.sections.map((s) => s.id).toSet();
    final available = state.sections
        .where((s) => !assignedIds.contains(s.id))
        .toList();

    if (available.isEmpty) {
      _showError('Toutes les filières sont déjà assignées');
      return;
    }

    _showBlurDialog(
      builder: (ctx) => AlertDialog(
        title: const Text('Assigner une Filière'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: available
                .map(
                  (section) => ListTile(
                    title: Text(section.name),
                    subtitle: Text(section.code),
                    onTap: () async {
                      try {
                        await ref
                            .read(gradeLevelsProvider.notifier)
                            .assignSectionToGrade(grade.id, section.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSuccess('Filière assignée');
                      } catch (e) {
                        _showError('Erreur: $e');
                      }
                    },
                  ),
                )
                .toList(),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE8EAF0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeSectionFromGrade(String gradeId, String sectionId) async {
    try {
      await ref
          .read(gradeLevelsProvider.notifier)
          .removeSectionFromGrade(gradeId, sectionId);
      _showSuccess('Filière retirée');
    } catch (e) {
      _showError('Erreur: $e');
    }
  }

  void _confirmDeleteGrade(GradeLevelModel grade) {
    _showBlurDialog(
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer "${grade.name}" ?'),
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
                    onPressed: () async {
                      try {
                        await ref
                            .read(gradeLevelsProvider.notifier)
                            .deleteGradeLevel(grade.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSuccess('Niveau supprimé');
                      } catch (e) {
                        _showError('Erreur: \$e');
                      }
                    },
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

  void _confirmDeleteSection(SectionModel section) {
    _showBlurDialog(
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer "${section.name}" ?'),
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
                    onPressed: () async {
                      try {
                        await ref
                            .read(gradeLevelsProvider.notifier)
                            .deleteSection(section.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSuccess('Filière supprimée');
                      } catch (e) {
                        _showError('Erreur: \$e');
                      }
                    },
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

  void _confirmDeleteExamType(ExamTypeModel examType) {
    _showBlurDialog(
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer "${examType.name}" ?'),
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
                    onPressed: () async {
                      try {
                        await ref
                            .read(gradeLevelsProvider.notifier)
                            .deleteExamType(examType.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSuccess('Type supprimé');
                      } catch (e) {
                        _showError('Erreur: \$e');
                      }
                    },
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

  // ==================== BLUR DIALOG HELPER ====================
  Future<T?> _showBlurDialog<T>({required Widget Function(BuildContext) builder}) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: builder(ctx),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  // ==================== FILTER PANEL ====================
  Widget _buildFilterPanel(GradeLevelsState? state) {
    final allGrades = state?.gradeLevels ?? [];
    final sections = state?.sections ?? [];
    final examTypes = state?.examTypes ?? [];

    // Cascade: filter grades by cycle
    final filteredGrades = _filterCycle != null
        ? allGrades.where((g) => g.levelType == _filterCycle).toList()
        : allGrades;

    // Cascade: filter classes by selected grade
    final selectedGrade = _filterGradeId != null
        ? allGrades.where((g) => g.id == _filterGradeId).firstOrNull
        : null;
    final filteredClasses = selectedGrade?.classes ?? [];

    return Material(
      elevation: 16,
      shadowColor: Colors.black.withOpacity(0.15),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Column(
          children: [
            // ─── Header ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF655DD5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.tune, color: Color(0xFF655DD5), size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Filtres avancés',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => setState(() => _showFilterPanel = false),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.slate100,
                      ),
                      child: Icon(Icons.close, size: 18, color: AppColors.slate500),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Filters body ───
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CYCLE toggle
                    _filterLabel('Cycle'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _cycleChip('Collège', 'college'),
                        const SizedBox(width: 8),
                        _cycleChip('Secondaire', 'secondaire'),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // NIVEAU dropdown
                    _filterLabel('Niveau'),
                    const SizedBox(height: 8),
                    _filterDropdown<String>(
                      value: _filterGradeId,
                      hint: 'Tous les niveaux',
                      items: filteredGrades.map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(g.name, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: (v) => setState(() {
                        _filterGradeId = v;
                        // Reset class when grade changes
                      }),
                    ),

                    const SizedBox(height: 24),

                    // CLASSE dropdown (cascading from Niveau)
                    _filterLabel('Classe'),
                    const SizedBox(height: 8),
                    _filterDropdown<String>(
                      value: null,
                      hint: filteredClasses.isEmpty
                          ? 'Sélectionnez un niveau d\'abord'
                          : 'Toutes les classes',
                      items: filteredClasses.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: filteredClasses.isEmpty ? null : (v) {},
                    ),

                    const SizedBox(height: 24),

                    // FILIÈRE dropdown
                    _filterLabel('Filière'),
                    const SizedBox(height: 8),
                    _filterDropdown<String>(
                      value: _filterSectionId,
                      hint: 'Toutes les filières',
                      items: sections.map((s) => DropdownMenuItem(
                        value: s.id,
                        child: Text(s.name, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: (v) => setState(() => _filterSectionId = v),
                    ),

                    const SizedBox(height: 24),

                    // TYPE D'EXAMEN dropdown
                    _filterLabel('Type d\'examen'),
                    const SizedBox(height: 8),
                    _filterDropdown<String>(
                      value: _filterExamTypeId,
                      hint: 'Tous les types',
                      items: examTypes.map((e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(e.name, style: const TextStyle(fontSize: 13)),
                      )).toList(),
                      onChanged: (v) => setState(() => _filterExamTypeId = v),
                    ),

                    const SizedBox(height: 24),

                    // ENSEIGNANT search
                    _filterLabel('Enseignant'),
                    const SizedBox(height: 8),
                    Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: TextField(
                        controller: _teacherSearchCtrl,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un enseignant...',
                          hintStyle: TextStyle(color: AppColors.slate400, fontSize: 13),
                          prefixIcon: Icon(Icons.person_search, color: AppColors.slate400, size: 18),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          suffixIcon: _teacherSearchCtrl.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () => setState(() => _teacherSearchCtrl.clear()),
                                  icon: Icon(Icons.close, size: 16, color: AppColors.slate400),
                                  padding: EdgeInsets.zero,
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ─── Footer buttons ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                color: Color(0xFFFAFAFB),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _filterCycle = null;
                          _filterGradeId = null;
                          _filterSectionId = null;
                          _filterExamTypeId = null;
                          _teacherSearchCtrl.clear();
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Réinitialiser', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF655DD5),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF655DD5).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() => _showFilterPanel = false);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: const Center(
                            child: Text(
                              'Appliquer',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.slate500,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _cycleChip(String label, String value) {
    final isSelected = _filterCycle == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _filterCycle = isSelected ? null : value;
          _filterGradeId = null; // Reset cascading
        }),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF655DD5).withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF655DD5) : AppColors.slate200,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF655DD5) : AppColors.slate500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?)? onChanged,
  }) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: onChanged == null ? AppColors.slate100.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.slate200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: TextStyle(fontSize: 13, color: AppColors.slate400)),
          isExpanded: true,
          icon: Icon(Icons.expand_more, size: 18, color: AppColors.slate400),
          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
          borderRadius: BorderRadius.circular(12),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ==================== CLASS MANAGEMENT ====================
  void _showClassDialog(GradeLevelModel grade, GradeLevelsState state) {
    final nameCtrl = TextEditingController();
    String? selectedSectionId;
    String? nameError;

    // For secondaire, sections are required
    final availableSections = grade.levelType == 'secondaire'
        ? grade.sections
        : <SectionModel>[];

    _showBlurDialog(
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => _dialogShell(
          ctx: ctx,
          title: 'Nouvelle Classe',
          subtitle: 'Ajouter une nouvelle classe pour ${grade.name}.',
          submitLabel: 'Créer la classe',
          onSubmit: () async {
            if (nameCtrl.text.trim().isEmpty) {
              setDialogState(() => nameError = 'Le nom est requis');
              return;
            }
            if (grade.levelType == 'secondaire' &&
                availableSections.isNotEmpty &&
                selectedSectionId == null) {
              _showError('La filière est requise pour le secondaire');
              return;
            }
            try {
              await ref
                  .read(gradeLevelsProvider.notifier)
                  .addClass(
                    name: nameCtrl.text.trim(),
                    gradeLevelId: grade.id,
                    sectionId: selectedSectionId,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
              _showSuccess('Classe "${nameCtrl.text.trim()}" créée');
            } catch (e) {
              _showError('Erreur: $e');
            }
          },
          children: [
            _styledField(
              controller: nameCtrl,
              label: 'Nom de la classe',
              hint: 'Ex: ${grade.code}-A ou 7B1',
              required: true,
              errorText: nameError,
              onChanged: (_) {
                if (nameError != null) setDialogState(() => nameError = null);
              },
            ),
            if (availableSections.isNotEmpty) ...[
              const SizedBox(height: 16),
              _styledDropdown<String>(
                label: 'Filière',
                value: selectedSectionId,
                hint: 'Sélectionner une filière...',
                items: availableSections
                    .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedSectionId = v),
              ),
            ] else if (grade.levelType == 'secondaire') ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentSoft),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Aucune filière n\'est assignée à ce niveau. Veuillez d\'abord assigner des filières.',
                        style: TextStyle(color: AppColors.accent, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Les classes du collège n\'ont pas de filière.',
                        style: TextStyle(color: AppColors.primary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ==================== HOVERABLE GRADE ROW ====================
class _HoverableGradeRow extends StatefulWidget {
  final GradeLevelModel grade;
  final GradeLevelsState state;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onAddClass;
  final void Function(ClassSummary) onClassTap;
  final VoidCallback onAssignSection;
  final void Function(String sectionId) onRemoveSection;

  const _HoverableGradeRow({
    super.key,
    required this.grade,
    required this.state,
    required this.onEdit,
    required this.onDelete,
    required this.onAddClass,
    required this.onClassTap,
    required this.onAssignSection,
    required this.onRemoveSection,
  });

  @override
  State<_HoverableGradeRow> createState() => _HoverableGradeRowState();
}

class _HoverableGradeRowState extends State<_HoverableGradeRow> {
  bool _isHovered = false;
  String? _selectedSectionId;

  @override
  Widget build(BuildContext context) {
    final grade = widget.grade;
    // Filter classes by selected filière
    final displayedClasses = _selectedSectionId != null
        ? grade.classes.where((c) => c.sectionId == _selectedSectionId).toList()
        : grade.classes;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: _isHovered ? AppColors.slate200 : AppColors.slate100),
          borderRadius: BorderRadius.circular(12),
          color: _isHovered ? AppColors.slate50.withOpacity(0.5) : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + action buttons
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        grade.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '• ${grade.classCount} classes, ${grade.studentCount} élèves',
                        style: TextStyle(fontSize: 12, color: AppColors.slate400),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _actionButton(Icons.edit, widget.onEdit),
                    const SizedBox(width: 4),
                    _actionButton(Icons.delete_outline, widget.onDelete, isDelete: true),
                  ],
                ),
              ],
            ),
            // Filières (for secondaire)
            if (grade.levelType == 'secondaire') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'FILIÈRES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (grade.sections.isEmpty)
                    InkWell(
                      onTap: widget.onAssignSection,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF655DD5).withOpacity(0.3), style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '+ Assigner',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF655DD5)),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          ...grade.sections.map((section) {
                            final isSelected = _selectedSectionId == section.id;
                            return InkWell(
                              onTap: () => setState(() {
                                _selectedSectionId = isSelected ? null : section.id;
                              }),
                              borderRadius: BorderRadius.circular(4),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF655DD5).withOpacity(0.12)
                                      : AppColors.slate100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF655DD5).withOpacity(0.4)
                                        : AppColors.slate200,
                                  ),
                                ),
                                child: Text(
                                  section.name,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? const Color(0xFF655DD5) : AppColors.slate500,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            // Class pills
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...displayedClasses.map((cls) => _classPill(cls)),
                _addClassButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, VoidCallback onTap, {bool isDelete = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isDelete
              ? AppColors.slate100
              : AppColors.slate100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: isDelete ? AppColors.error : AppColors.slate600,
          ),
        ),
      ),
    );
  }

  Widget _classPill(ClassSummary cls) {
    return InkWell(
      onTap: () => widget.onClassTap(cls),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.slate200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              cls.name,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate600),
            ),
            if (cls.studentCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '(${cls.studentCount})',
                style: TextStyle(fontSize: 10, color: AppColors.slate400),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _addClassButton() {
    return InkWell(
      onTap: widget.onAddClass,
      borderRadius: BorderRadius.circular(8),
      hoverColor: const Color(0xFF655DD5).withOpacity(0.05),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF655DD5).withOpacity(0.4),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 14, color: Color(0xFF655DD5)),
            SizedBox(width: 4),
            Text(
              'Nouvelle classe',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF655DD5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
