import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../providers/users_provider.dart';
import '../../providers/curriculum_provider.dart';
import '../../widgets/admin_sidebar.dart';
import 'user_form_dialog.dart';
import 'user_profile_screen.dart';
import 'bulk_photo_upload_screen.dart';
import 'simple_bulk_import_screen.dart';
import '../../widgets/ios_loader.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});
  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _showFilterDrawer = false;
  String _sortBy = 'name';
  bool _sortAscending = true;
  String? _classFilter;
  String? _levelFilter;
  String? _genderFilter;
  DateTime? _dateFromFilter;
  DateTime? _dateToFilter;
  String? _statusFilter; // null = tous, 'active', 'archived'

  // Bulk selection state
  final Set<String> _selectedUserIds = {};
  bool _isImporting = false;

  // Pagination state
  int _currentPage = 1;
  int _itemsPerPage = 20; // default
  static const List<int> _perPageOptions = [10, 20, 50, 100, -1]; // -1 = All

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedUserIds.clear();
          _currentPage = 1;
        });
      }
    });
  }

  void _resetFilters() {
    setState(() {
      _sortBy = 'name';
      _sortAscending = true;
      _classFilter = null;
      _levelFilter = null;
      _genderFilter = null;
      _dateFromFilter = null;
      _dateToFilter = null;
      _statusFilter = null;
      _currentPage = 1;
    });
  }

  bool get _hasActiveFilters =>
      _levelFilter != null ||
      _classFilter != null ||
      _genderFilter != null ||
      _dateFromFilter != null ||
      _dateToFilter != null;

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/users'),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, usersAsync),
                // Selection action bar
                if (_isSelectionMode) _buildSelectionBar(context, usersAsync),
                _buildTabBar(context, usersAsync),
                if (_showFilters) _buildFilterBar(context),
                Expanded(
                  child: usersAsync.when(
                    loading: () => Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          boxShadow: AppShadows.card,
                          border: Border.all(color: AppColors.border.withOpacity(0.5)),
                        ),
                        child: const SizedBox(
                          width: 36, height: 36,
                          child: IosLoader(color: AppColors.primary),
                        ),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Container(
                        padding: const EdgeInsets.all(36),
                        margin: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.errorSoft,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.error.withOpacity(0.2)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.md)),
                              child: const Icon(Icons.error_outline_rounded, size: 28, color: AppColors.error),
                            ),
                            const SizedBox(height: 16),
                            Text('Erreur: $e', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            const SizedBox(height: 20),
                            Container(
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => ref.invalidate(usersProvider),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                                        SizedBox(width: 8),
                                        Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (state) => TabBarView(
                      controller: _tabController,
                      children: [
                        _buildStudentsList(context, state),
                        _buildStaffList(context, state),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, AsyncValue<UsersState> usersAsync) {
    final studentCount =
        usersAsync.whenOrNull(
          data: (s) => s.users.where((u) => u.role == 'student').length,
        ) ??
        0;
    final staffCount =
        usersAsync.whenOrNull(
          data: (s) => s.users.where((u) => u.role != 'student').length,
        ) ??
        0;

    return Container(
      color: Colors.white.withOpacity(0.92),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textTertiary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('Étudiants'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.warningGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$studentCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_rounded, size: 20),
                const SizedBox(width: 8),
                const Text('Staff & Managers'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$staffCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AsyncValue<UsersState> usersAsync) {
    final userCount = usersAsync.whenOrNull(data: (s) => s.users.length) ?? 0;
    final studentCount =
        usersAsync.whenOrNull(
          data: (s) => s.users.where((u) => u.role == 'student').length,
        ) ??
        0;
    final staffCount =
        usersAsync.whenOrNull(
          data: (s) => s.users.where((u) => u.role != 'student').length,
        ) ??
        0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.35))),
      ),
      child: Row(
        children: [
          // Title with icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.people_alt_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Gestion des Utilisateurs',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                '$userCount utilisateurs • $studentCount étudiants • $staffCount staff',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(width: 32),
          // Search bar
          SizedBox(
            width: 350,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Rechercher nom, classe, niveau, tél, nationalité...',
                hintStyle: TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w400, fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textTertiary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.slate50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: AppColors.border.withOpacity(0.5)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Filter toggle
          Badge(
            isLabelVisible: _showFilters || _levelFilter != null || _classFilter != null || _genderFilter != null || _dateFromFilter != null || _dateToFilter != null,
            backgroundColor: AppColors.warning,
            child: IconButton(
              icon: Icon(
                _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              ),
              tooltip: _showFilters ? 'Fermer et réinitialiser les filtres' : 'Filtres',
              onPressed: _toggleFilters,
              color: _showFilters ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          // Selection mode toggle
          IconButton(
            onPressed: () => setState(() {
              _isSelectionMode = !_isSelectionMode;
              if (!_isSelectionMode) _selectedUserIds.clear();
            }),
            icon: Icon(
              _isSelectionMode
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: _isSelectionMode ? AppColors.primary : AppColors.textSecondary,
            ),
            tooltip: _isSelectionMode ? 'Quitter sélection' : 'Mode sélection',
          ),
          const SizedBox(width: 8),
          // Import Excel button - Navigate to bulk import page
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SimpleBulkImportScreen()),
            ),
            icon: const Icon(Icons.upload_file_outlined, color: AppColors.success),
            tooltip: 'Import en masse (Excel/CSV)',
          ),
          // Bulk photo upload button
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BulkPhotoUploadScreen()),
            ),
            icon: const Icon(Icons.photo_library_outlined, color: AppColors.secondary),
            tooltip: 'Photos en masse',
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(usersProvider),
          ),
          // Add button
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showUserDialog(context),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_outlined, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text('Ajouter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final usersState = ref.watch(usersProvider);
    final allClasses = usersState.whenOrNull(data: (s) => s.classes) ?? [];
    
    // Get unique niveaux from classes
    final niveauxFromClasses = <String, String>{};
    for (final c in allClasses) {
      if (c.gradeLevelId != null && c.gradeLevelName != null) {
        niveauxFromClasses[c.gradeLevelId!] = c.gradeLevelName!;
      }
    }

    // Filter classes based on selected niveau ID
    final filteredClasses = _levelFilter != null
        ? allClasses.where((c) => c.gradeLevelId == _levelFilter).toList()
        : allClasses;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.35))),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Sort dropdown
          _buildFilterChip(
            icon: Icons.sort,
            label: 'Trier: $_sortBy',
            isActive: _sortBy != 'name',
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                isDense: true,
                items: const [
                  DropdownMenuItem(value: 'name', child: Text('Nom')),
                  DropdownMenuItem(value: 'email', child: Text('Email')),
                  DropdownMenuItem(value: 'id', child: Text('ID')),
                  DropdownMenuItem(value: 'date', child: Text('Date création')),
                ],
                onChanged: (v) => setState(() => _sortBy = v!),
              ),
            ),
          ),
          // Sort direction
          IconButton(
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 20,
            ),
            tooltip: _sortAscending ? 'Croissant' : 'Décroissant',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.slate50,
            ),
            onPressed: () => setState(() => _sortAscending = !_sortAscending),
          ),
          Container(width: 1, height: 30, color: AppColors.border),
          // Niveau filter - from actual classes data
          _buildFilterChip(
            icon: Icons.school,
            label: _levelFilter != null 
                ? niveauxFromClasses[_levelFilter] ?? 'Niveau'
                : 'Niveau',
            isActive: _levelFilter != null,
            activeColor: AppColors.primary,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _levelFilter,
                isDense: true,
                hint: const Text('Tous les niveaux'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Tous les niveaux'),
                  ),
                  ...niveauxFromClasses.entries.map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _levelFilter = v;
                  _classFilter = null; // Reset class when niveau changes
                }),
              ),
            ),
          ),
          // Class filter - filtered by selected niveau
          _buildFilterChip(
            icon: Icons.class_,
            label: _classFilter ?? (_levelFilter != null ? 'Classe du niveau' : 'Classe'),
            isActive: _classFilter != null,
            activeColor: AppColors.success,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _classFilter,
                isDense: true,
                hint: Text(
                  _levelFilter != null
                      ? 'Classes (${filteredClasses.length})'
                      : 'Toutes les classes',
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(
                      _levelFilter != null
                          ? 'Toutes (${filteredClasses.length})'
                          : 'Toutes les classes',
                    ),
                  ),
                  ...filteredClasses.map(
                    (c) => DropdownMenuItem(value: c.name, child: Text(c.name)),
                  ),
                ],
                onChanged: filteredClasses.isEmpty && _levelFilter != null
                    ? null
                    : (v) => setState(() => _classFilter = v),
              ),
            ),
          ),
          // Gender filter
          _buildFilterChip(
            icon: Icons.wc,
            label: _genderFilter == 'male' ? 'Garçons' : _genderFilter == 'female' ? 'Filles' : 'Genre',
            isActive: _genderFilter != null,
            activeColor: _genderFilter == 'male' ? AppColors.primary : AppColors.chart4,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _genderFilter,
                isDense: true,
                hint: const Text('Genre'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tous')),
                  DropdownMenuItem(value: 'male', child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.male, size: 16, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('Garçons'),
                    ],
                  )),
                  DropdownMenuItem(value: 'female', child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.female, size: 16, color: AppColors.chart4),
                      SizedBox(width: 4),
                      Text('Filles'),
                    ],
                  )),
                ],
                onChanged: (v) => setState(() => _genderFilter = v),
              ),
            ),
          ),
          // Date from filter
          _buildFilterChip(
            icon: Icons.calendar_today,
            label: _dateFromFilter != null
                ? 'Du ${DateFormat('dd/MM').format(_dateFromFilter!)}'
                : 'Date début',
            isActive: _dateFromFilter != null,
            activeColor: AppColors.warning,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _dateFromFilter ?? DateTime.now().subtract(const Duration(days: 365)),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _dateFromFilter = date);
            },
          ),
          // Date to filter
          _buildFilterChip(
            icon: Icons.calendar_today,
            label: _dateToFilter != null
                ? 'Au ${DateFormat('dd/MM').format(_dateToFilter!)}'
                : 'Date fin',
            isActive: _dateToFilter != null,
            activeColor: AppColors.warning,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _dateToFilter ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _dateToFilter = date);
            },
          ),
          // Clear filters
          TextButton.icon(
            icon: const Icon(Icons.clear_all, size: 18),
            label: const Text('Réinitialiser'),
            style: TextButton.styleFrom(foregroundColor: AppColors.textTertiary),
            onPressed: _resetFilters,
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required bool isActive,
    Color? activeColor,
    Widget? child,
    VoidCallback? onTap,
  }) {
    final color = isActive ? (activeColor ?? AppColors.primary) : AppColors.textTertiary;
    return Material(
      color: isActive ? color.withOpacity(0.08) : AppColors.slate50,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
              color: isActive ? color.withOpacity(0.3) : AppColors.border.withOpacity(0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: isActive ? color : AppColors.textTertiary),
              const SizedBox(width: 6),
              if (child != null) 
                child
              else
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isActive ? color : AppColors.textSecondary,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Selection action bar - shows when in selection mode
  Widget _buildSelectionBar(
    BuildContext context,
    AsyncValue<UsersState> usersAsync,
  ) {
    final count = _selectedUserIds.length;
    final allUsers = usersAsync.whenOrNull(data: (s) => s.users) ?? [];
    final currentTabUsers = _tabController.index == 0
        ? allUsers.where((u) => u.role == 'student').toList()
        : allUsers.where((u) => u.role != 'student').toList();
    final filteredUsers = _filterAndSort(currentTabUsers);
    final allSelected =
        filteredUsers.isNotEmpty &&
        filteredUsers.every((u) => _selectedUserIds.contains(u.id));

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        border: Border(bottom: BorderSide(color: AppColors.primary.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          // Select all checkbox
          Checkbox(
            value: allSelected,
            tristate: true,
            onChanged: (v) {
              setState(() {
                if (allSelected) {
                  _selectedUserIds.clear();
                } else {
                  for (final u in filteredUsers) {
                    _selectedUserIds.add(u.id);
                  }
                }
              });
            },
          ),
          Text(
            count == 0
                ? 'Sélectionner des utilisateurs'
                : '$count sélectionné(s)',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 24),
          // Bulk actions
          if (count > 0) ...[
            OutlinedButton.icon(
              onPressed: () => _bulkDelete(context),
              icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
              label: const Text(
                'Supprimer',
                style: TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => _bulkExport(),
              icon: Icon(
                Icons.download,
                size: 18,
                color: AppColors.success,
              ),
              label: Text(
                'Exporter',
                style: TextStyle(color: AppColors.success),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.success),
              ),
            ),
          ],
          const Spacer(),
          TextButton.icon(
            onPressed: () => setState(() {
              _selectedUserIds.clear();
              _isSelectionMode = false;
            }),
            icon: const Icon(Icons.close),
            label: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsList(BuildContext context, UsersState state) {
    var users = state.users.where((u) => u.role == 'student').toList();
    users = _filterAndSort(users);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
            border: Border.all(color: AppColors.border.withOpacity(0.35)),
          ),
          child: _buildStudentTable(users),
        ),
      ),
    );
  }

  Widget _buildStaffList(BuildContext context, UsersState state) {
    var users = state.users.where((u) => u.role != 'student').toList();
    users = _filterAndSort(users);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
            border: Border.all(color: AppColors.border.withOpacity(0.35)),
          ),
          child: _buildStaffTable(users),
        ),
      ),
    );
  }

  List<UserModel> _filterAndSort(List<UserModel> users) {
    // Apply smart search filter - search across all user fields including age
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      
      // Check if searching for age (e.g., "15 ans", "age:15", "15")
      final ageMatch = RegExp(r'^(\d+)\s*(ans?)?$').firstMatch(query);
      final ageQueryMatch = RegExp(r'^age[:\s]*(\d+)$').firstMatch(query);
      int? searchAge;
      if (ageMatch != null) {
        searchAge = int.tryParse(ageMatch.group(1)!);
      } else if (ageQueryMatch != null) {
        searchAge = int.tryParse(ageQueryMatch.group(1)!);
      }
      
      users = users.where((u) {
        // If searching by age
        if (searchAge != null && u.dateOfBirth != null) {
          final age = DateTime.now().difference(u.dateOfBirth!).inDays ~/ 365;
          if (age == searchAge) return true;
        }
        
        // Text search across all fields
        return u.fullName.toLowerCase().contains(query) ||
            u.email.toLowerCase().contains(query) ||
            u.id.toLowerCase().contains(query) ||
            (u.studentCode?.toLowerCase().contains(query) ?? false) ||
            (u.phone?.toLowerCase().contains(query) ?? false) ||
            (u.niveau?.toLowerCase().contains(query) ?? false) ||
            (u.niveauCode?.toLowerCase().contains(query) ?? false) ||
            (u.className?.toLowerCase().contains(query) ?? false) ||
            (u.nationality?.toLowerCase().contains(query) ?? false) ||
            (u.address?.toLowerCase().contains(query) ?? false) ||
            (u.sectionCode?.toLowerCase().contains(query) ?? false) ||
            (u.gender?.toLowerCase().contains(query) ?? false) ||
            // Search by age text like "14 ans"
            (u.dateOfBirth != null && '${DateTime.now().difference(u.dateOfBirth!).inDays ~/ 365} ans'.contains(query));
      }).toList();
    }

    // Apply class filter
    if (_classFilter != null) {
      users = users.where((u) => u.className == _classFilter).toList();
    }

    // Apply niveau filter (now uses gradeLevelId)
    if (_levelFilter != null) {
      users = users.where((u) {
        // Match by niveau ID, name or code
        return u.niveau == _levelFilter || 
               u.niveauCode == _levelFilter ||
               // Also check if user's class belongs to this niveau
               true; // Will be handled by class filter cascade
      }).toList();
    }
    
    // Apply gender filter
    if (_genderFilter != null) {
      users = users.where((u) => u.gender == _genderFilter).toList();
    }

    // Apply date from filter
    if (_dateFromFilter != null) {
      users = users
          .where((u) => u.createdAt.isAfter(_dateFromFilter!))
          .toList();
    }

    // Apply date to filter
    if (_dateToFilter != null) {
      users = users
          .where(
            (u) => u.createdAt.isBefore(
              _dateToFilter!.add(const Duration(days: 1)),
            ),
          )
          .toList();
    }

    // Apply sorting
    users.sort((a, b) {
      int result;
      switch (_sortBy) {
        case 'email':
          result = a.email.compareTo(b.email);
          break;
        case 'id':
          result = a.id.compareTo(b.id);
          break;
        case 'date':
          result = a.createdAt.compareTo(b.createdAt);
          break;
        default:
          result = a.fullName.compareTo(b.fullName);
      }
      return _sortAscending ? result : -result;
    });

    return users;
  }

  Widget _buildStudentTable(List<UserModel> users) {
    if (users.isEmpty) {
      return _buildEmptyState('Aucun étudiant trouvé');
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 16,
          horizontalMargin: 16,
          headingRowColor: WidgetStateProperty.all(AppColors.slate50),
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
          dataTextStyle: TextStyle(fontSize: 12, color: AppColors.textPrimary),
          showCheckboxColumn: false,
          columns: [
            // Selection checkbox
            if (_isSelectionMode)
              DataColumn(
                label: Checkbox(
                  value:
                      users.isNotEmpty &&
                      users.every((u) => _selectedUserIds.contains(u.id)),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        for (final u in users) {
                          _selectedUserIds.add(u.id);
                        }
                      } else {
                        _selectedUserIds.clear();
                      }
                    });
                  },
                ),
              ),
            const DataColumn(label: Text('Photo')),
            const DataColumn(label: Text('Nom Complet')),
            const DataColumn(label: Text('Email')),
            const DataColumn(label: Text('Genre')),
            const DataColumn(label: Text('Âge')),
            const DataColumn(label: Text('Nationalité')),
            const DataColumn(label: Text('Niveau')),
            const DataColumn(label: Text('Classe')),
            const DataColumn(label: Text('Code Étudiant')),
            const DataColumn(label: Text('Téléphone')),
            const DataColumn(label: Text('Créé le')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: users.map((u) {
            final isSelected = _selectedUserIds.contains(u.id);
            return DataRow(
              selected: isSelected,
              color: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primarySoft;
                }
                if (states.contains(WidgetState.hovered)) {
                  return AppColors.slate50;
                }
                return null;
              }),
              onSelectChanged: (selected) {
                if (_isSelectionMode) {
                  setState(() {
                    if (selected == true) {
                      _selectedUserIds.add(u.id);
                    } else {
                      _selectedUserIds.remove(u.id);
                    }
                  });
                } else {
                  // Navigate to profile when row is clicked
                  _navigateToProfile(context, u);
                }
              },
              cells: [
                // Selection checkbox
                if (_isSelectionMode)
                  DataCell(
                    Checkbox(
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedUserIds.add(u.id);
                          } else {
                            _selectedUserIds.remove(u.id);
                          }
                        });
                      },
                    ),
                  ),
                // Photo
                DataCell(
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.accentSoft,
                    backgroundImage: u.photoUrl != null
                        ? NetworkImage(u.photoUrl!)
                        : null,
                    child: u.photoUrl == null
                        ? Text(
                            u.fullName.isNotEmpty
                                ? u.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent,
                            ),
                          )
                        : null,
                  ),
                ),
                // Nom Complet
                DataCell(
                  InkWell(
                    onTap: () => _navigateToProfile(context, u),
                    child: Text(
                      u.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                // Email
                DataCell(
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: u.email));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Email copié!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(u.email),
                        const SizedBox(width: 4),
                        Icon(Icons.copy, size: 12, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
                // Genre
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: u.gender == 'M'
                          ? AppColors.primarySoft
                          : u.gender == 'F'
                          ? const Color(0xFFFCE7F3)
                          : AppColors.slate100,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      u.genderDisplay,
                      style: TextStyle(
                        fontSize: 11,
                        color: u.gender == 'M'
                            ? AppColors.primary
                            : u.gender == 'F'
                            ? AppColors.chart4
                            : AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Âge
                DataCell(
                  Text(
                    u.age != null ? '${u.age} ans' : '-',
                    style: TextStyle(
                      color: u.age != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                // Nationalité
                DataCell(
                  Text(
                    u.nationality ?? '-',
                    style: TextStyle(
                      color: u.nationality != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                // Niveau
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      _formatNiveauDisplay(u),
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                // Classe
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      u.className ?? '-',
                      style: TextStyle(
                        color: u.className != null
                            ? AppColors.success
                            : AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                // Code Étudiant
                DataCell(
                  InkWell(
                    onTap: u.studentCode != null
                        ? () {
                            Clipboard.setData(
                              ClipboardData(text: u.studentCode!),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Code étudiant copié!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            u.studentCode ?? '-',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                          if (u.studentCode != null) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.copy,
                              size: 10,
                              color: AppColors.primary.withOpacity(0.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Téléphone
                DataCell(Text(u.phone ?? '-')),
                // Créé le
                DataCell(Text(DateFormat('dd/MM/yy').format(u.createdAt))),
                // Actions
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.success,
                        ),
                        tooltip: 'Voir profil',
                        onPressed: () => _navigateToProfile(context, u),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Modifier',
                        onPressed: () => _showUserDialog(context, user: u),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        tooltip: 'Supprimer',
                        onPressed: () => _confirmDelete(context, u),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatNiveauDisplay(UserModel user) {
    // First, try to derive niveau from class name if available
    if (user.className != null && user.className!.isNotEmpty) {
      final className = user.className!;
      if (className.contains('1ère')) return '1ère';
      if (className.contains('2ème')) return '2ème';
      if (className.contains('3ème')) return '3ème';
      if (className.contains('4ème') ||
          className.toLowerCase().contains('bac')) {
        return 'Bac';
      }
    }

    // Try niveau_code
    final niveauShort = getNiveauShortName(user.niveauCode);
    if (niveauShort.isNotEmpty && niveauShort != user.niveauCode) {
      if (user.sectionCode != null) {
        final sectionShort = getSectionShortName(user.sectionCode);
        return '$niveauShort $sectionShort';
      }
      return niveauShort;
    }

    // Fallback to legacy niveau
    if (user.niveau != null) {
      return _shortenNiveau(user.niveau!);
    }

    return '-';
  }

  String _shortenNiveau(String niveau) {
    if (niveau.contains('7ème')) return '7ème';
    if (niveau.contains('8ème')) return '8ème';
    if (niveau.contains('9ème')) return '9ème';
    if (niveau.contains('1ère')) return '1ère S';
    if (niveau.contains('2ème')) return '2ème S';
    if (niveau.contains('3ème')) return '3ème S';
    if (niveau.contains('4ème') || niveau.contains('Bac')) return 'Bac';
    return niveau.length > 5 ? niveau.substring(0, 5) : niveau;
  }

  Widget _buildStaffTable(List<UserModel> users) {
    if (users.isEmpty) {
      return _buildEmptyState('Aucun staff trouvé');
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 16,
          horizontalMargin: 16,
          headingRowColor: WidgetStateProperty.all(AppColors.slate50),
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
          dataTextStyle: TextStyle(fontSize: 12, color: AppColors.textPrimary),
          showCheckboxColumn: false,
          columns: [
            // Selection checkbox
            if (_isSelectionMode)
              DataColumn(
                label: Checkbox(
                  value:
                      users.isNotEmpty &&
                      users.every((u) => _selectedUserIds.contains(u.id)),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        for (final u in users) {
                          _selectedUserIds.add(u.id);
                        }
                      } else {
                        _selectedUserIds.clear();
                      }
                    });
                  },
                ),
              ),
            const DataColumn(label: Text('Photo')),
            const DataColumn(label: Text('Nom Complet')),
            const DataColumn(label: Text('Email')),
            const DataColumn(label: Text('Rôle')),
            const DataColumn(label: Text('Téléphone')),
            const DataColumn(label: Text('Créé le')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: users.map((u) {
            final isSelected = _selectedUserIds.contains(u.id);
            return DataRow(
              selected: isSelected,
              color: WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primarySoft;
                }
                if (states.contains(WidgetState.hovered)) {
                  return AppColors.slate50;
                }
                return null;
              }),
              onSelectChanged: (selected) {
                if (_isSelectionMode) {
                  setState(() {
                    if (selected == true) {
                      _selectedUserIds.add(u.id);
                    } else {
                      _selectedUserIds.remove(u.id);
                    }
                  });
                } else {
                  // Navigate to profile when row is clicked
                  _navigateToProfile(context, u);
                }
              },
              cells: [
                // Selection checkbox
                if (_isSelectionMode)
                  DataCell(
                    Checkbox(
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedUserIds.add(u.id);
                          } else {
                            _selectedUserIds.remove(u.id);
                          }
                        });
                      },
                    ),
                  ),
                // Photo
                DataCell(
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primarySoft,
                    backgroundImage: u.photoUrl != null
                        ? NetworkImage(u.photoUrl!)
                        : null,
                    child: u.photoUrl == null
                        ? Text(
                            u.fullName.isNotEmpty
                                ? u.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                ),
                // Nom Complet
                DataCell(
                  InkWell(
                    onTap: () => _navigateToProfile(context, u),
                    child: Text(
                      u.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                // Email
                DataCell(
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: u.email));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Email copié!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(u.email),
                        const SizedBox(width: 4),
                        Icon(Icons.copy, size: 12, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
                // Rôle
                DataCell(_RoleChip(role: u.role)),
                // Téléphone
                DataCell(Text(u.phone ?? '-')),
                // Créé le
                DataCell(Text(DateFormat('dd/MM/yy').format(u.createdAt))),
                // Actions
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.visibility_outlined,
                          size: 18,
                          color: AppColors.success,
                        ),
                        tooltip: 'Voir profil',
                        onPressed: () => _navigateToProfile(context, u),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Modifier',
                        onPressed: () => _showUserDialog(context, user: u),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        tooltip: 'Supprimer',
                        onPressed: () => _confirmDelete(context, u),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.slate100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.people_outline, size: 36, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Essayez une autre recherche',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToProfile(BuildContext context, UserModel u) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            UserProfileScreen(userId: u.id, userName: u.fullName),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return AppColors.secondary;
      case 'staff':
        return AppColors.primary;
      default:
        return AppColors.warning;
    }
  }

  void _showUserDialog(BuildContext context, {UserModel? user}) {
    showDialog(
      context: context,
      builder: (ctx) => UserFormDialog(user: user),
    );
  }

  void _confirmDelete(BuildContext context, UserModel u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.errorSoft, borderRadius: BorderRadius.circular(AppRadius.xs)),
              child: Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Supprimer utilisateur ?', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voulez-vous vraiment supprimer "${u.fullName}" ?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ID: ${u.id}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
            child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.errorGradient,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              boxShadow: [BoxShadow(color: AppColors.error.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ref.read(usersProvider.notifier).deleteUser(u.id);
                  Navigator.pop(ctx);
                },
                borderRadius: BorderRadius.circular(AppRadius.xs),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  child: Text('Supprimer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== BULK ACTIONS ====================

  void _bulkDelete(BuildContext context) {
    final count = _selectedUserIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.errorSoft, borderRadius: BorderRadius.circular(AppRadius.xs)),
              child: Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Supprimer en masse ?', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voulez-vous vraiment supprimer $count utilisateur(s) ?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.errorSoft,
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(color: AppColors.error.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cette action est irréversible !',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);

              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: IosLoader.small(color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text('Suppression de $count utilisateurs en cours...'),
                    ],
                  ),
                  duration: const Duration(seconds: 60),
                  backgroundColor: AppColors.primary,
                ),
              );

              // Use bulk delete method - much faster!
              final notifier = ref.read(usersProvider.notifier);
              final result = await notifier.bulkDeleteUsers(
                _selectedUserIds.toList(),
              );
              final deleted = result['deleted'] ?? 0;
              final failed = result['failed'] ?? 0;

              setState(() {
                _selectedUserIds.clear();
                _isSelectionMode = false;
              });

              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$deleted supprimé(s), $failed échec(s)'),
                    backgroundColor: failed == 0 ? AppColors.success : AppColors.warning,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(
              'Supprimer $count',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkExport() async {
    final usersState = ref.read(usersProvider);
    final allUsers = usersState.whenOrNull(data: (s) => s.users) ?? [];
    final selectedUsers = allUsers
        .where((u) => _selectedUserIds.contains(u.id))
        .toList();

    if (selectedUsers.isEmpty) return;

    final excel = Excel.createExcel();
    final sheet = excel['Utilisateurs'];

    // Headers
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('ID');
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue(
      'Nom complet',
    );
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue('Email');
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue(
      'Téléphone',
    );
    sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue('Rôle');
    sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue(
      'Code étudiant',
    );

    // Data rows
    for (var i = 0; i < selectedUsers.length; i++) {
      final u = selectedUsers[i];
      final row = i + 2;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(u.id);
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        u.fullName,
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
        u.email,
      );
      sheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(
        u.phone ?? '',
      );
      sheet.cell(CellIndex.indexByString('E$row')).value = TextCellValue(
        u.role,
      );
      sheet.cell(CellIndex.indexByString('F$row')).value = TextCellValue(
        u.studentCode ?? '',
      );
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null && mounted) {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Exporter les utilisateurs',
        fileName:
            'utilisateurs_export_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedUsers.length} utilisateur(s) exporté(s)'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  // ==================== EXCEL IMPORT METHODS ====================

  void _showImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.upload_file, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('Importer des Utilisateurs'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Importez des utilisateurs à partir d\'un fichier Excel (.xlsx) ou CSV (.csv)',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Format requis:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildFormatRow('Colonne A', 'Nom complet *'),
                    _buildFormatRow('Colonne B', 'Email *'),
                    _buildFormatRow('Colonne C', 'Téléphone'),
                    _buildFormatRow('Colonne D', 'Rôle (student/staff/admin)'),
                    _buildFormatRow(
                      'Colonne E',
                      'Date de naissance (JJ/MM/AAAA)',
                    ),
                    _buildFormatRow('Colonne F', 'Adresse'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_fix_high,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Le mot de passe et le code étudiant sont générés automatiquement !',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'La première ligne doit contenir les en-têtes et sera ignorée.',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadTemplate();
            },
            icon: const Icon(Icons.download),
            label: const Text('Télécharger modèle'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _pickAndImportExcel();
            },
            icon: const Icon(Icons.file_upload),
            label: const Text('Choisir fichier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatRow(String column, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              column,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text('→ $description', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _downloadTemplate() async {
    final excel = Excel.createExcel();
    final sheet = excel['Utilisateurs'];

    // Headers - NO PASSWORD COLUMN (auto-generated)
    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Nom complet *',
    );
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Email *');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue(
      'Téléphone',
    );
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue('Rôle');
    sheet.cell(CellIndex.indexByString('E1')).value = TextCellValue(
      'Date naissance',
    );
    sheet.cell(CellIndex.indexByString('F1')).value = TextCellValue('Adresse');

    // Example rows
    sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue(
      'Ahmed Ben Ali',
    );
    sheet.cell(CellIndex.indexByString('B2')).value = TextCellValue(
      'ahmed.benali@example.com',
    );
    sheet.cell(CellIndex.indexByString('C2')).value = TextCellValue(
      '+216 55 123 456',
    );
    sheet.cell(CellIndex.indexByString('D2')).value = TextCellValue('student');
    sheet.cell(CellIndex.indexByString('E2')).value = TextCellValue(
      '15/03/2008',
    );
    sheet.cell(CellIndex.indexByString('F2')).value = TextCellValue(
      'Tunis, Tunisie',
    );

    sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
      'Fatma Trabelsi',
    );
    sheet.cell(CellIndex.indexByString('B3')).value = TextCellValue(
      'fatma.trabelsi@example.com',
    );
    sheet.cell(CellIndex.indexByString('C3')).value = TextCellValue(
      '+216 22 987 654',
    );
    sheet.cell(CellIndex.indexByString('D3')).value = TextCellValue('student');
    sheet.cell(CellIndex.indexByString('E3')).value = TextCellValue(
      '22/07/2009',
    );
    sheet.cell(CellIndex.indexByString('F3')).value = TextCellValue(
      'Sfax, Tunisie',
    );

    sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue(
      'Mohamed Karim',
    );
    sheet.cell(CellIndex.indexByString('B4')).value = TextCellValue(
      'mohamed.karim@example.com',
    );
    sheet.cell(CellIndex.indexByString('C4')).value = TextCellValue('');
    sheet.cell(CellIndex.indexByString('D4')).value = TextCellValue('staff');
    sheet.cell(CellIndex.indexByString('E4')).value = TextCellValue('');
    sheet.cell(CellIndex.indexByString('F4')).value = TextCellValue('');

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null && mounted) {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer le modèle',
        fileName: 'modele_import_utilisateurs.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modèle prêt à télécharger'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _pickAndImportExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isImporting = true);

        final bytes = result.files.single.bytes!;
        final fileName = result.files.single.name.toLowerCase();
        final users = <Map<String, String>>[];

        if (fileName.endsWith('.csv')) {
          // Parse CSV - NEW FORMAT (no password)
          final content = String.fromCharCodes(bytes);
          final lines = content.split('\n');

          for (var i = 1; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.isEmpty) continue;

            final parts = line.split(',');
            if (parts.length < 2) continue;

            final fullName = parts[0].trim();
            final email = parts[1].trim();
            final phone = parts.length > 2 ? parts[2].trim() : '';
            final role = parts.length > 3
                ? parts[3].trim().toLowerCase()
                : 'student';
            final dateOfBirth = parts.length > 4 ? parts[4].trim() : '';
            final address = parts.length > 5 ? parts[5].trim() : '';

            if (fullName.isNotEmpty && email.isNotEmpty) {
              users.add({
                'fullName': fullName,
                'email': email,
                'phone': phone,
                'role': role.isEmpty ? 'student' : role,
                'dateOfBirth': dateOfBirth,
                'address': address,
              });
            }
          }
        } else {
          // Parse Excel - NEW FORMAT (no password)
          final excel = Excel.decodeBytes(bytes);

          for (final table in excel.tables.keys) {
            final sheet = excel.tables[table]!;

            for (var i = 1; i < sheet.maxRows; i++) {
              final row = sheet.rows[i];
              if (row.isEmpty || row[0]?.value == null) continue;

              final fullName = row[0]?.value?.toString() ?? '';
              final email = row[1]?.value?.toString() ?? '';
              final phone = row.length > 2 ? row[2]?.value?.toString() : null;
              final role = row.length > 3
                  ? row[3]?.value?.toString() ?? 'student'
                  : 'student';
              final dateOfBirth = row.length > 4
                  ? row[4]?.value?.toString()
                  : null;
              final address = row.length > 5 ? row[5]?.value?.toString() : null;

              if (fullName.isNotEmpty && email.isNotEmpty) {
                users.add({
                  'fullName': fullName,
                  'email': email,
                  'phone': phone ?? '',
                  'role': role.toLowerCase().isEmpty
                      ? 'student'
                      : role.toLowerCase(),
                  'dateOfBirth': dateOfBirth ?? '',
                  'address': address ?? '',
                });
              }
            }
            break;
          }
        }

        if (users.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Aucun utilisateur valide trouvé'),
                backgroundColor: AppColors.warning,
              ),
            );
          }
          setState(() => _isImporting = false);
          return;
        }

        if (mounted) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Confirmer l\'import'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${users.length} utilisateur(s) trouvé(s):'),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: users.length > 5 ? 5 : users.length,
                      itemBuilder: (ctx, i) => Text(
                        '• ${users[i]['fullName']} (${users[i]['email']})',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  if (users.length > 5)
                    Text(
                      '... et ${users.length - 5} autres',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text(
                    'Importer',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );

          if (confirm == true) {
            await _importUsers(users);
          }
        }

        setState(() => _isImporting = false);
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'import: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _importUsers(List<Map<String, String>> users) async {
    int success = 0;
    int failed = 0;
    final errors = <String>[];
    final createdUsers =
        <Map<String, String>>[]; // Track created users for display

    for (final user in users) {
      try {
        // Auto-generate password for each user
        final password = ref.read(usersProvider.notifier).generatePassword();

        final result = await ref
            .read(usersProvider.notifier)
            .createUser(
              email: user['email']!,
              password: password, // Auto-generated password
              fullName: user['fullName']!,
              role: user['role'] ?? 'student',
              phone: user['phone']?.isNotEmpty == true ? user['phone'] : null,
              dateOfBirth: user['dateOfBirth']?.isNotEmpty == true
                  ? user['dateOfBirth']
                  : null,
              address: user['address']?.isNotEmpty == true
                  ? user['address']
                  : null,
            );

        if (result) {
          success++;
          createdUsers.add({
            'email': user['email']!,
            'fullName': user['fullName']!,
            'password': password,
          });
        } else {
          failed++;
          errors.add(user['email']!);
        }
      } catch (e) {
        failed++;
        errors.add('${user['email']}: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import terminé: $success réussi(s), $failed échec(s)'),
          backgroundColor: failed == 0 ? AppColors.success : AppColors.warning,
          duration: const Duration(seconds: 5),
        ),
      );

      // Show generated credentials dialog if users were created successfully
      if (createdUsers.isNotEmpty) {
        _showGeneratedCredentials(createdUsers);
      }

      if (errors.isNotEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: AppColors.warning),
                const SizedBox(width: 8),
                const Text('Erreurs d\'import'),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${errors.length} utilisateur(s) n\'ont pas pu être importés:',
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: errors.length,
                      itemBuilder: (ctx, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${errors[i]}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Show dialog with generated credentials after bulk import
  void _showGeneratedCredentials(List<Map<String, String>> createdUsers) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 8),
            const Text('Identifiants générés'),
          ],
        ),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Veuillez télécharger ou copier ces identifiants. Les mots de passe ne seront plus accessibles après fermeture.',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.slate200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowColor: WidgetStateProperty.all(
                      AppColors.slate100,
                    ),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Nom',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Email',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Mot de passe',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: createdUsers
                        .map(
                          (u) => DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  u['fullName'] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  u['email'] ?? '',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                SelectableText(
                                  u['password'] ?? '',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () => _exportCredentials(createdUsers),
            icon: const Icon(Icons.download),
            label: const Text('Télécharger Excel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Export generated credentials to Excel file
  Future<void> _exportCredentials(List<Map<String, String>> users) async {
    final excel = Excel.createExcel();
    final sheet = excel['Identifiants'];

    sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Nom complet',
    );
    sheet.cell(CellIndex.indexByString('B1')).value = TextCellValue('Email');
    sheet.cell(CellIndex.indexByString('C1')).value = TextCellValue(
      'Mot de passe',
    );
    sheet.cell(CellIndex.indexByString('D1')).value = TextCellValue(
      'Code étudiant',
    );

    for (var i = 0; i < users.length; i++) {
      final row = i + 2;
      sheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
        users[i]['fullName'] ?? '',
      );
      sheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
        users[i]['email'] ?? '',
      );
      sheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
        users[i]['password'] ?? '',
      );
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.encode();
    if (bytes != null && mounted) {
      final timestamp = DateTime.now()
          .toString()
          .split('.')
          .first
          .replaceAll(':', '-');
      await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer les identifiants',
        fileName: 'identifiants_generes_$timestamp.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: Uint8List.fromList(bytes),
      );
    }
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (role) {
      case 'admin':
        bg = const Color(0xFFF5F3FF);
        fg = AppColors.secondary;
        label = 'Admin';
        icon = Icons.admin_panel_settings_outlined;
        break;
      case 'staff':
        bg = AppColors.primarySoft;
        fg = AppColors.primary;
        label = 'Manager';
        icon = Icons.badge_outlined;
        break;
      default:
        bg = AppColors.accentSoft;
        fg = AppColors.accent;
        label = 'Étudiant';
        icon = Icons.person_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// New ListView-based user tile to replace DataTable2
class _UserListTile extends StatelessWidget {
  final UserModel user;
  final bool isStudent;
  final bool isSelectionMode;
  final bool isSelected;
  final Function(bool)? onSelect;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopyId;

  const _UserListTile({
    required this.user,
    required this.isStudent,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelect,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onCopyId,
  });

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copié !'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 0,
      color: isSelected ? AppColors.primarySoft : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primary.withOpacity(0.4) : AppColors.slate200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox in selection mode
              if (isSelectionMode) ...[
                Checkbox(
                  value: isSelected,
                  onChanged: (v) => onSelect?.call(v ?? false),
                ),
                const SizedBox(width: 8),
              ],
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: isStudent
                    ? AppColors.accentSoft
                    : AppColors.primarySoft,
                backgroundImage: user.photoUrl != null
                    ? NetworkImage(user.photoUrl!)
                    : null,
                child: user.photoUrl == null
                    ? Text(
                        user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isStudent
                              ? AppColors.warning
                              : AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              // Name & Email - Copyable
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _copy(context, user.fullName, 'Nom'),
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              user.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy,
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () => _copy(context, user.email, 'Email'),
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              user.email,
                              style: TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy,
                            size: 10,
                            color: AppColors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ID Badge - Copyable
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onCopyId,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.id.length > 8
                              ? '${user.id.substring(0, 8)}...'
                              : user.id,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.copy, size: 12, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Niveau badge (for students)
              if (isStudent && (user.niveauCode != null || user.niveau != null))
                Tooltip(
                  message: _getNiveauTooltip(user),
                  child: Container(
                    width: 75,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatNiveauDisplay(user),
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              if (isStudent && (user.niveauCode != null || user.niveau != null))
                const SizedBox(width: 8),
              // Student Code or Role - Copyable
              if (isStudent)
                InkWell(
                  onTap: user.studentCode != null
                      ? () => _copy(context, user.studentCode!, 'Code étudiant')
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 100,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            user.studentCode ?? '-',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.studentCode != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy,
                            size: 10,
                            color: AppColors.primary.withOpacity(0.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                _RoleChip(role: user.role),
              const SizedBox(width: 12),
              // Phone - Copyable
              InkWell(
                onTap: user.phone != null
                    ? () => _copy(context, user.phone!, 'Téléphone')
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 110,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          user.phone ?? '-',
                          style: TextStyle(
                            fontSize: 12,
                            color: user.phone == null
                                ? AppColors.textTertiary
                                : AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.phone != null) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.copy, size: 10, color: AppColors.textTertiary),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Date
              SizedBox(
                width: 80,
                child: Text(
                  DateFormat('dd/MM/yy').format(user.createdAt),
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    tooltip: 'Modifier',
                    onPressed: onEdit,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.error,
                    ),
                    tooltip: 'Supprimer',
                    onPressed: onDelete,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortenNiveau(String niveau) {
    if (niveau.contains('7ème')) return '7ème';
    if (niveau.contains('8ème')) return '8ème';
    if (niveau.contains('9ème')) return '9ème';
    if (niveau.contains('1ère')) return '1ère S';
    if (niveau.contains('2ème')) return '2ème S';
    if (niveau.contains('3ème')) return '3ème S';
    if (niveau.contains('4ème') || niveau.contains('Bac')) return 'Bac';
    return niveau.substring(0, 5);
  }

  String _formatNiveauDisplay(UserModel user) {
    // First, try to derive niveau from class name if available
    if (user.className != null && user.className!.isNotEmpty) {
      final className = user.className!;
      if (className.contains('1ère')) return '1ère';
      if (className.contains('2ème')) return '2ème';
      if (className.contains('3ème')) return '3ème';
      if (className.contains('4ème') ||
          className.toLowerCase().contains('bac')) {
        return 'Bac';
      }
    }

    // Try niveau_code
    final niveauShort = getNiveauShortName(user.niveauCode);
    if (niveauShort.isNotEmpty && niveauShort != user.niveauCode) {
      if (user.sectionCode != null) {
        final sectionShort = getSectionShortName(user.sectionCode);
        return '$niveauShort $sectionShort';
      }
      return niveauShort;
    }

    // Fallback to legacy niveau
    if (user.niveau != null) {
      return _shortenNiveau(user.niveau!);
    }

    return '-';
  }

  String _getNiveauTooltip(UserModel user) {
    final niveauFull = getNiveauFullName(user.niveauCode);
    if (user.sectionCode != null) {
      final sectionFull = getSectionFullName(user.sectionCode);
      return '$niveauFull - $sectionFull';
    }
    // Fallback to legacy niveau
    if (niveauFull.isEmpty && user.niveau != null) {
      return user.niveau!;
    }
    return niveauFull;
  }
}
