// ignore_for_file: avoid_web_libraries_in_flutter, unused_element, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/class_model.dart';
import '../../../data/models/user_model.dart';
import '../../providers/classes_provider.dart';
import '../../providers/documents_provider.dart';
import '../../providers/semesters_provider.dart';
import '../../providers/users_provider.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/ios_loader.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/user_avatar.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  // Search & Debounce
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;

  // Selected subtab index (0: Tous, 1: Académiques, 2: Administratifs, 3+: Semestres)
  int _selectedTabIndex = 0;

  // Selected quick category pill ('all', 'administrative', 'courses', 'exams', 'other')
  String _selectedCategoryPill = 'all';

  // Selection state for multi-action
  final Set<String> _selectedIds = {};

  // Pagination
  int _currentPage = 1;
  int _rowsPerPage = 10;

  // Drawers
  bool _showFilterDrawer = false;
  Document? _selectedDocForDetail;

  // Advanced Filters
  String? _filterType;
  String? _filterCategory;
  int? _filterSemester;
  String? _filterClassId;
  String? _filterFileType;
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim();
          _currentPage = 1;
        });
      }
    });
  }

  bool get _hasActiveFilters =>
      _filterType != null ||
      _filterCategory != null ||
      _filterSemester != null ||
      _filterClassId != null ||
      _filterFileType != null ||
      _filterDateFrom != null ||
      _filterDateTo != null;

  void _resetFilters() {
    setState(() {
      _filterType = null;
      _filterCategory = null;
      _filterSemester = null;
      _filterClassId = null;
      _filterFileType = null;
      _filterDateFrom = null;
      _filterDateTo = null;
      _currentPage = 1;
    });
  }

  List<Document> _applyFiltering(
    List<Document> docs,
    List<SemesterModel> semesters,
  ) {
    return docs.where((d) {
      // 1. Text Search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = d.title.toLowerCase().contains(q);
        final matchDesc = d.cleanDescription.toLowerCase().contains(q);
        final matchClass = (d.className ?? '').toLowerCase().contains(q);
        final matchStudent = (d.studentName ?? '').toLowerCase().contains(q) ||
            (d.studentCode ?? '').toLowerCase().contains(q);
        final matchType =
            AcademicDocumentType.getLabel(d.category).toLowerCase().contains(q);
        if (!matchTitle &&
            !matchDesc &&
            !matchClass &&
            !matchStudent &&
            !matchType) {
          return false;
        }
      }

      // 2. Subpage Tab filter
      // 0: Tous
      // 1: Académiques (courses, exams)
      // 2: Administratifs (administrative)
      // 3+: Dynamically maps to semester number
      if (_selectedTabIndex == 1) {
        if (d.category == 'administrative') return false;
      } else if (_selectedTabIndex == 2) {
        if (d.category != 'administrative') return false;
      } else if (_selectedTabIndex >= 3) {
        final semIndex = _selectedTabIndex - 3;
        if (semIndex < semesters.length) {
          final targetSem = semesters[semIndex];
          if (d.semester != targetSem.number) return false;
        }
      }

      // 3. Category quick pill
      if (_selectedCategoryPill != 'all') {
        if (d.category != _selectedCategoryPill) return false;
      }

      // 4. Advanced filters
      if (_filterType != null && d.category != _filterType) return false;
      if (_filterCategory != null) {
        if (_filterCategory == 'administrative' &&
            d.category != 'administrative') {
          return false;
        }
        if (_filterCategory == 'academic' && d.category == 'administrative') {
          return false;
        }
      }
      if (_filterSemester != null && d.semester != _filterSemester) return false;
      if (_filterClassId != null && d.classId != _filterClassId) return false;
      if (_filterFileType != null) {
        final ext = (d.fileType ?? '').toUpperCase();
        if (_filterFileType == 'PDF' && !ext.contains('PDF')) return false;
        if (_filterFileType == 'Word' &&
            !ext.contains('DOC') &&
            !ext.contains('DOCX')) {
          return false;
        }
        if (_filterFileType == 'Excel' &&
            !ext.contains('XLS') &&
            !ext.contains('XLSX') &&
            !ext.contains('CSV')) {
          return false;
        }
        if (_filterFileType == 'Image' &&
            !ext.contains('PNG') &&
            !ext.contains('JPG') &&
            !ext.contains('JPEG')) {
          return false;
        }
      }
      if (_filterDateFrom != null && d.createdAt.isBefore(_filterDateFrom!)) {
        return false;
      }
      if (_filterDateTo != null &&
          d.createdAt.isAfter(
            _filterDateTo!.add(const Duration(days: 1)),
          )) {
        return false;
      }

      return true;
    }).toList();
  }

  void _exportCsv(List<Document> docs) {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun document à exporter')),
      );
      return;
    }
    final rows = <List<dynamic>>[];
    rows.add([
      'ID',
      'Titre',
      'Catégorie',
      'Semestre',
      'Classe',
      'Étudiant dédié',
      'Format',
      'Date de création',
      'Lien fichier',
    ]);
    final df = DateFormat('dd/MM/yyyy HH:mm');
    for (final d in docs) {
      rows.add([
        d.id,
        d.title,
        AcademicDocumentType.getLabel(d.category),
        'Semestre ${d.semester}',
        d.className ?? 'Général',
        d.isStudentDedicated ? '${d.studentName} (${d.studentCode})' : 'Tous',
        d.fileType ?? 'PDF',
        df.format(d.createdAt),
        d.fileUrl,
      ]);
    }
    final csvData = const ListToCsvConverter().convert(rows);
    final bytes = html.Blob([csvData], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(bytes);
    html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'documents_export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv',
      )
      ..click();
    html.Url.revokeObjectUrl(url);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${docs.length} documents exportés en CSV avec succès'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _openFile(String url) {
    if (url.isEmpty) return;
    try {
      html.window.open(url, '_blank');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'ouvrir le lien : $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _confirmDeleteSingle(Document d) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Supprimer document ?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Voulez-vous vraiment supprimer "${d.title}" ?'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ID: ${d.id}',
                        style: const TextStyle(
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
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref.read(documentsProvider.notifier).delete(d.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Document supprimé avec succès'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text(
                      'Supprimer',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSelected() {
    if (_selectedIds.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.errorSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Supprimer la sélection ?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Voulez-vous supprimer les ${_selectedIds.length} documents sélectionnés ? Cette action est irréversible.',
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total sélectionné: ${_selectedIds.length} éléments',
                        style: const TextStyle(
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
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final count = _selectedIds.length;
                      await ref
                          .read(documentsProvider.notifier)
                          .bulkDelete(_selectedIds.toList());
                      setState(() => _selectedIds.clear());
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '$count documents supprimés avec succès',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text(
                      'Supprimer',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddOrEditModal({Document? editDoc}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: _DocumentFormDialog(editDoc: editDoc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);
    final semestersAsync = ref.watch(semestersProvider);

    // Extract dynamic semesters list from database
    final semesters = semestersAsync.value?.filteredSemesters.isNotEmpty == true
        ? semestersAsync.value!.filteredSemesters
        : (semestersAsync.value?.semesters ?? <SemesterModel>[]);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/documents'),
          Expanded(
            child: Stack(
              children: [
                Column(
                  children: [
                    // Header Bar
                    _buildHeader(docsAsync),

                    // Multi-selection Action Bar (visible when items selected)
                    if (_selectedIds.isNotEmpty) _buildMultiActionBar(),

                    // Main Content
                    Expanded(
                      child: docsAsync.when(
                        loading: () => const DocumentsSkeletonLoader(),
                        error: (err, _) => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: AppColors.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Erreur de chargement: $err',
                                style: const TextStyle(color: AppColors.error),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () => ref
                                    .read(documentsProvider.notifier)
                                    .refresh(),
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        ),
                        data: (state) =>
                            _buildBody(state.documents, semesters),
                      ),
                    ),
                  ],
                ),

                // Right Filter Drawer with Background Blur
                if (_showFilterDrawer)
                  _buildRightFilterDrawer(semesters),

                // Right Document Detail Drawer with Background Blur
                if (_selectedDocForDetail != null)
                  _buildRightDetailDrawer(_selectedDocForDetail!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HEADER BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader(AsyncValue<DocumentsState> docsAsync) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title + Subtitle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Documents',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Gérez et organisez tous les documents pédagogiques et administratifs',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),

          const Spacer(),

          // Search Field
          Container(
            width: 250,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un document...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Filter Button
          _buildHeaderIconButton(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filtres',
            isActive: _showFilterDrawer || _hasActiveFilters,
            onPressed: () {
              setState(() {
                _showFilterDrawer = !_showFilterDrawer;
                if (_showFilterDrawer) _selectedDocForDetail = null;
              });
            },
          ),
          const SizedBox(width: 8),

          // Export CSV Button
          docsAsync.maybeWhen(
            data: (st) => _buildHeaderIconButton(
              icon: Icons.download_rounded,
              tooltip: 'Exporter CSV',
              onPressed: () => _exportCsv(st.documents),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),

          // Print Button
          _buildHeaderIconButton(
            icon: Icons.print_outlined,
            tooltip: 'Imprimer',
            onPressed: () => html.window.print(),
          ),
          const SizedBox(width: 8),

          // Refresh Button
          _buildHeaderIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Actualiser',
            onPressed: () =>
                ref.read(documentsProvider.notifier).refresh(),
          ),
          const SizedBox(width: 16),

          // Primary Add Button
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () => _showAddOrEditModal(),
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

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
    bool isActive = false,
  }) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      color: isActive ? const Color(0xFF655DD5) : AppColors.textTertiary,
      style: IconButton.styleFrom(
        backgroundColor:
            isActive ? const Color(0xFFF5F3FF) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isActive
                ? const Color(0xFF655DD5).withOpacity(0.2)
                : Colors.transparent,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MULTI-ACTION BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildMultiActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6D4CF6).withOpacity(0.08),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF6D4CF6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_selectedIds.length} sélectionné${_selectedIds.length > 1 ? 's' : ''}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: () {
              setState(() => _selectedIds.clear());
            },
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Désélectionner'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _confirmDeleteSelected,
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Supprimer la sélection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MAIN BODY
  // ─────────────────────────────────────────────────────────────
  Widget _buildBody(List<Document> allDocs, List<SemesterModel> semesters) {
    final filtered = _applyFiltering(allDocs, semesters);

    // Compute counts
    final totalCount = allDocs.length;
    final academicCount =
        allDocs.where((d) => d.category != 'administrative').length;
    final adminCount =
        allDocs.where((d) => d.category == 'administrative').length;

    // Subtabs list: Tous, Académiques, Administratifs, + each DB semester
    final tabs = <_TabItem>[
      _TabItem(
        label: 'Tous',
        count: totalCount,
        icon: Icons.folder_outlined,
      ),
      _TabItem(
        label: 'Académiques',
        count: academicCount,
        icon: Icons.school_outlined,
      ),
      _TabItem(
        label: 'Administratifs',
        count: adminCount,
        icon: Icons.description_outlined,
      ),
      ...semesters.map(
        (s) => _TabItem(
          label: s.name,
          count: allDocs.where((d) => d.semester == s.number).length,
          icon: Icons.calendar_month_outlined,
        ),
      ),
    ];

    // Pagination slice
    final totalFiltered = filtered.length;
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalFiltered);
    final paginatedDocs = (startIndex < totalFiltered)
        ? filtered.sublist(startIndex, endIndex)
        : <Document>[];

    return Column(
      children: [
        // Subpage Tabs (Tous, Académiques, Administratifs, Semestres)
        _buildSubTabs(tabs),

        // Quick Category Pills & Table Summary Controls
        _buildControlsRow(totalFiltered, allDocs.length),

        // Document Table / List
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: [
                    // Table Header Row
                    _buildTableHeaderRow(filtered),

                    // Table Body / Empty State
                    Expanded(
                      child: paginatedDocs.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              itemCount: paginatedDocs.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              itemBuilder: (context, index) {
                                final d = paginatedDocs[index];
                                final isSelected =
                                    _selectedIds.contains(d.id);
                                return _buildDocumentRow(d, isSelected);
                              },
                            ),
                    ),

                    // Pagination Footer
                    _buildPaginationFooter(
                      totalFiltered,
                      startIndex,
                      endIndex,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SUBPAGE TABS
  // ─────────────────────────────────────────────────────────────
  Widget _buildSubTabs(List<_TabItem> tabs) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(tabs.length, (index) {
            final t = tabs[index];
            final isSelected = _selectedTabIndex == index;
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                  _currentPage = 1;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? const Color(0xFF6D4CF6)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      t.icon,
                      size: 16,
                      color: isSelected
                          ? const Color(0xFF6D4CF6)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? const Color(0xFF6D4CF6)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6D4CF6).withOpacity(0.12)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${t.count}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFF6D4CF6)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CONTROLS ROW
  // ─────────────────────────────────────────────────────────────
  Widget _buildControlsRow(int filteredCount, int totalCount) {
    const categories = [
      {'key': 'all', 'label': 'Tous'},
      {'key': 'courses', 'label': 'Cours'},
      {'key': 'exams', 'label': 'Examens'},
      {'key': 'administrative', 'label': 'Administratif'},
      {'key': 'other', 'label': 'Autre'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          // Quick category pills
          ...categories.map((c) {
            final isSelected = _selectedCategoryPill == c['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategoryPill = c['key']!;
                    _currentPage = 1;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6D4CF6)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6D4CF6)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    c['label']!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          // Item count label
          Text(
            filteredCount == totalCount
                ? '$totalCount documents'
                : '$filteredCount sur $totalCount documents',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TABLE HEADER ROW
  // ─────────────────────────────────────────────────────────────
  Widget _buildTableHeaderRow(List<Document> currentDocs) {
    final allSelected = currentDocs.isNotEmpty &&
        currentDocs.every((d) => _selectedIds.contains(d.id));

    return Container(
      height: 44,
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Select All Checkbox
          SizedBox(
            width: 32,
            child: Checkbox(
              value: allSelected,
              tristate:
                  !allSelected && currentDocs.any((d) => _selectedIds.contains(d.id)),
              activeColor: const Color(0xFF6D4CF6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selectedIds.addAll(currentDocs.map((d) => d.id));
                  } else {
                    _selectedIds.clear();
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 12),

          // Title / Document Header
          const Expanded(
            flex: 4,
            child: Text(
              'DOCUMENT / TITRE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Type Header
          const Expanded(
            flex: 2,
            child: Text(
              'TYPE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Target (Class or Dedicated Student)
          const Expanded(
            flex: 2,
            child: Text(
              'DESTINATAIRE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Date Header
          const Expanded(
            flex: 2,
            child: Text(
              'DATE D\'AJOUT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Actions Header
          const SizedBox(
            width: 48,
            child: Text(
              'ACTIONS',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TABLE ROW
  // ─────────────────────────────────────────────────────────────
  Widget _buildDocumentRow(Document d, bool isSelected) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = df.format(d.createdAt);
    final ext = (d.fileType ?? 'PDF').toUpperCase();

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDocForDetail = d;
          _showFilterDrawer = false;
        });
      },
      hoverColor: const Color(0xFFF8FAFC),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        color: isSelected
            ? const Color(0xFF6D4CF6).withOpacity(0.04)
            : Colors.transparent,
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 32,
              child: Checkbox(
                value: isSelected,
                activeColor: const Color(0xFF6D4CF6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _selectedIds.add(d.id);
                    } else {
                      _selectedIds.remove(d.id);
                    }
                  });
                },
              ),
            ),
            const SizedBox(width: 12),

            // File Icon + Title + Description preview
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  _buildFileTypeIcon(ext),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          d.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (d.cleanDescription.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            d.cleanDescription,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Type Badge
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _getTypeColor(d.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    AcademicDocumentType.getLabel(d.category),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getTypeColor(d.category),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),

            // Destinataire (Dedicated Student OR Class OR General)
            Expanded(
              flex: 2,
              child: d.isStudentDedicated
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6D4CF6).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 12,
                            color: Color(0xFF6D4CF6),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                d.studentName ?? 'Étudiant',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6D4CF6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (d.studentCode != null &&
                                  d.studentCode!.isNotEmpty)
                                Text(
                                  d.studentCode!,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : (d.className != null && d.className!.isNotEmpty)
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            d.className!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      : const Text(
                          'Tous (Général)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
            ),

            // Date
            Expanded(
              flex: 2,
              child: Text(
                formattedDate,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            // Actions - Three Dots PopupMenuButton (like User page!)
            SizedBox(
              width: 48,
              child: Center(
                child: PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  tooltip: 'Actions',
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 8,
                  offset: const Offset(-140, 36),
                  onSelected: (action) => _handleRowAction(action, d),
                  itemBuilder: (ctx) => [
                    _buildPopupItem(
                      'open',
                      Icons.open_in_new_rounded,
                      'Ouvrir / Télécharger',
                      const Color(0xFF6D4CF6),
                    ),
                    _buildPopupItem(
                      'view',
                      Icons.visibility_outlined,
                      'Détails',
                      AppColors.success,
                    ),
                    _buildPopupItem(
                      'edit',
                      Icons.edit_outlined,
                      'Modifier',
                      const Color(0xFF655DD5),
                    ),
                    const PopupMenuDivider(),
                    _buildPopupItem(
                      'delete',
                      Icons.delete_outline_rounded,
                      'Supprimer',
                      AppColors.error,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: value == 'delete' ? AppColors.error : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _handleRowAction(String action, Document d) {
    switch (action) {
      case 'open':
        _openFile(d.fileUrl);
        break;
      case 'view':
        setState(() {
          _selectedDocForDetail = d;
          _showFilterDrawer = false;
        });
        break;
      case 'edit':
        _showAddOrEditModal(editDoc: d);
        break;
      case 'delete':
        _confirmDeleteSingle(d);
        break;
    }
  }

  Widget _buildFileTypeIcon(String ext) {
    Color bg;
    IconData icon;
    if (ext.contains('PDF')) {
      bg = const Color(0xFFEF4444);
      icon = Icons.picture_as_pdf_rounded;
    } else if (ext.contains('DOC')) {
      bg = const Color(0xFF3B82F6);
      icon = Icons.description_rounded;
    } else if (ext.contains('XLS') || ext.contains('CSV')) {
      bg = const Color(0xFF10B981);
      icon = Icons.table_chart_rounded;
    } else if (ext.contains('PPT')) {
      bg = const Color(0xFFF59E0B);
      icon = Icons.slideshow_rounded;
    } else if (ext.contains('PNG') || ext.contains('JPG')) {
      bg = const Color(0xFF8B5CF6);
      icon = Icons.image_rounded;
    } else {
      bg = const Color(0xFF64748B);
      icon = Icons.insert_drive_file_rounded;
    }

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: bg, size: 20),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'courses':
        return const Color(0xFF3B82F6);
      case 'exams':
        return const Color(0xFFEF4444);
      case 'administrative':
        return const Color(0xFF10B981);
      case 'attestation':
      case 'certificat':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 32,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun document trouvé',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Essayez de modifier votre recherche ou vos filtres.',
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            if (_hasActiveFilters || _searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _resetFilters();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Réinitialiser les filtres'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6D4CF6),
                  side: const BorderSide(color: Color(0xFF6D4CF6)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PAGINATION FOOTER
  // ─────────────────────────────────────────────────────────────
  Widget _buildPaginationFooter(int totalItems, int start, int end) {
    final totalPages = (totalItems / _rowsPerPage).ceil().clamp(1, 9999);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFB),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Text(
            totalItems == 0
                ? '0 document'
                : 'Affichage de ${start + 1} à $end sur $totalItems documents',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Spacer(),
          const Text(
            'Lignes par page:',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _rowsPerPage,
              items: const [
                DropdownMenuItem(value: 5, child: Text('5')),
                DropdownMenuItem(value: 10, child: Text('10')),
                DropdownMenuItem(value: 20, child: Text('20')),
                DropdownMenuItem(value: 50, child: Text('50')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _rowsPerPage = val;
                    _currentPage = 1;
                  });
                }
              },
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$_currentPage / $totalPages',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
            color: const Color(0xFF64748B),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            onPressed: _currentPage < totalPages
                ? () => setState(() => _currentPage++)
                : null,
            color: const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FILTER DRAWER (EXACT CLONE OF USER PAGE FILTER DRAWER)
  // ─────────────────────────────────────────────────────────────
  Widget _buildRightFilterDrawer(List<SemesterModel> semesters) {
    final classesState = ref.watch(classesProvider);
    final List<ClassModel> classes = classesState.value?.classes ?? <ClassModel>[];

    return Positioned.fill(
      child: Stack(
        children: [
          // Blurred Backdrop
          GestureDetector(
            onTap: () => setState(() => _showFilterDrawer = false),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
          ),

          // Slide-over Drawer Panel
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 380,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 24,
                    offset: Offset(-4, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.border.withOpacity(0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Filtres',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () =>
                              setState(() => _showFilterDrawer = false),
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),

                  // Filter Fields
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type de document
                          _buildFilterLabel('TYPE DE DOCUMENT'),
                          const SizedBox(height: 8),
                          _buildFilterDropdown<String?>(
                            value: _filterType,
                            hint: 'Tous les types',
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Tous les types'),
                              ),
                              ...AcademicDocumentType.types.entries.map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _filterType = v;
                              _currentPage = 1;
                            }),
                          ),
                          const SizedBox(height: 20),

                          // Catégorie
                          _buildFilterLabel('CATÉGORIE'),
                          const SizedBox(height: 8),
                          _buildFilterDropdown<String?>(
                            value: _filterCategory,
                            hint: 'Toutes les catégories',
                            items: const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('Toutes les catégories'),
                              ),
                              DropdownMenuItem(
                                value: 'academic',
                                child: Text('Académique'),
                              ),
                              DropdownMenuItem(
                                value: 'administrative',
                                child: Text('Administratif'),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _filterCategory = v;
                              _currentPage = 1;
                            }),
                          ),
                          const SizedBox(height: 20),

                          // Semestre (Dynamic from DB!)
                          _buildFilterLabel('SEMESTRE'),
                          const SizedBox(height: 8),
                          _buildFilterDropdown<int?>(
                            value: _filterSemester,
                            hint: 'Tous les semestres',
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Tous les semestres'),
                              ),
                              ...semesters.map(
                                (s) => DropdownMenuItem(
                                  value: s.number,
                                  child: Text(s.name),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _filterSemester = v;
                              _currentPage = 1;
                            }),
                          ),
                          const SizedBox(height: 20),

                          // Classe concernée
                          _buildFilterLabel('CLASSE CONCERNÉE'),
                          const SizedBox(height: 8),
                          _buildFilterDropdown<String?>(
                            value: _filterClassId,
                            hint: 'Toutes les classes',
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Toutes les classes'),
                              ),
                              ...classes.map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _filterClassId = v;
                              _currentPage = 1;
                            }),
                          ),
                          const SizedBox(height: 20),

                          // Format de fichier
                          _buildFilterLabel('FORMAT DE FICHIER'),
                          const SizedBox(height: 8),
                          _buildFilterDropdown<String?>(
                            value: _filterFileType,
                            hint: 'Tous les formats',
                            items: const [
                              DropdownMenuItem(
                                value: null,
                                child: Text('Tous les formats'),
                              ),
                              DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                              DropdownMenuItem(
                                value: 'Word',
                                child: Text('Word (.docx)'),
                              ),
                              DropdownMenuItem(
                                value: 'Excel',
                                child: Text('Excel / CSV'),
                              ),
                              DropdownMenuItem(
                                value: 'Image',
                                child: Text('Image'),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _filterFileType = v;
                              _currentPage = 1;
                            }),
                          ),
                          const SizedBox(height: 20),

                          // Période (Date début / Date fin)
                          _buildFilterLabel('PÉRIODE (DATE)'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDatePickerField(
                                  value: _filterDateFrom,
                                  hint: 'Date début',
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _filterDateFrom ??
                                          DateTime.now().subtract(
                                            const Duration(days: 90),
                                          ),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (date != null) {
                                      setState(() => _filterDateFrom = date);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildDatePickerField(
                                  value: _filterDateTo,
                                  hint: 'Date fin',
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _filterDateTo ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (date != null) {
                                      setState(() => _filterDateTo = date);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Buttons Container (Matching Image 5)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFAFB),
                      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _resetFilters,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF374151),
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFFD1D5DB)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Réinitialiser',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6D4CF6),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF6D4CF6).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() => _showFilterDrawer = false);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: const Center(
                                  child: Text(
                                    'Appliquer',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textTertiary,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required T value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: items,
          onChanged: onChanged,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          borderRadius: BorderRadius.circular(8),
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: AppColors.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickerField({
    DateTime? value,
    required String hint,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value != null
                    ? DateFormat('dd/MM/yyyy').format(value)
                    : hint,
                style: TextStyle(
                  fontSize: 13,
                  color: value != null
                      ? AppColors.textPrimary
                      : AppColors.textTertiary,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DETAIL DRAWER
  // ─────────────────────────────────────────────────────────────
  Widget _buildRightDetailDrawer(Document d) {
    final df = DateFormat('dd MMMM yyyy à HH:mm', 'fr');
    final ext = (d.fileType ?? 'PDF').toUpperCase();

    return Positioned.fill(
      child: Stack(
        children: [
          // Blurred Backdrop
          GestureDetector(
            onTap: () => setState(() => _selectedDocForDetail = null),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
          ),

          // Drawer Panel
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 420,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 24,
                    offset: Offset(-4, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.border.withOpacity(0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Détails du document',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () =>
                              setState(() => _selectedDocForDetail = null),
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),

                  // Detail Body
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                _buildFileTypeIcon(ext),
                                const SizedBox(height: 12),
                                Text(
                                  d.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getTypeColor(d.category)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    AcademicDocumentType.getLabel(d.category),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _getTypeColor(d.category),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 16),

                          // Description
                          if (d.cleanDescription.isNotEmpty) ...[
                            const Text(
                              'DESCRIPTION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textTertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              d.cleanDescription,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF334155),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Dedicated Student Card (if applicable)
                          if (d.isStudentDedicated) ...[
                            const Text(
                              'ÉTUDIANT CONCERNÉ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textTertiary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      const Color(0xFF6D4CF6).withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF6D4CF6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.studentName ?? 'Étudiant',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                        if (d.studentCode != null &&
                                            d.studentCode!.isNotEmpty)
                                          Text(
                                            'Matricule: ${d.studentCode}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Metadata Grid
                          _buildDetailRow(
                            'Semestre',
                            'Semestre ${d.semester}',
                            Icons.calendar_month_outlined,
                          ),
                          _buildDetailRow(
                            'Classe',
                            d.className ?? 'Toutes les classes (Général)',
                            Icons.groups_outlined,
                          ),
                          _buildDetailRow(
                            'Format',
                            ext,
                            Icons.extension_outlined,
                          ),
                          _buildDetailRow(
                            'Date d\'ajout',
                            df.format(d.createdAt),
                            Icons.access_time_rounded,
                          ),
                          _buildDetailRow(
                            'Identifiant',
                            d.id,
                            Icons.fingerprint_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Buttons
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFAFB),
                      border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _selectedDocForDetail = null);
                                _showAddOrEditModal(editDoc: d);
                              },
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Modifier'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF374151),
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFFD1D5DB)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () => _openFile(d.fileUrl),
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 16,
                              ),
                              label: const Text('Ouvrir'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6D4CF6),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem {
  final String label;
  final int count;
  final IconData icon;
  const _TabItem({
    required this.label,
    required this.count,
    required this.icon,
  });
}

// ─────────────────────────────────────────────────────────────
// ADD / EDIT DOCUMENT MODAL DIALOG
// ─────────────────────────────────────────────────────────────
class _DocumentFormDialog extends ConsumerStatefulWidget {
  final Document? editDoc;
  const _DocumentFormDialog({this.editDoc});

  @override
  ConsumerState<_DocumentFormDialog> createState() =>
      _DocumentFormDialogState();
}

class _DocumentFormDialogState extends ConsumerState<_DocumentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _fileUrlController;
  late TextEditingController _studentSearchController;

  String _selectedCategory = 'administrative';
  int _selectedSemester = 1;
  String? _selectedClassId;

  // Target mode: 'all' | 'class' | 'student'
  String _targetMode = 'all';

  // Selected Student
  UserModel? _selectedStudent;
  bool _isUploading = false;
  bool _isSaving = false;
  String? _uploadedFileName;
  int? _uploadedFileSize;
  String? _uploadedMimeType;

  bool get isEditing => widget.editDoc != null;

  @override
  void initState() {
    super.initState();
    final d = widget.editDoc;
    _titleController = TextEditingController(text: d?.title ?? '');
    _descController = TextEditingController(text: d?.cleanDescription ?? '');
    _fileUrlController = TextEditingController(text: d?.fileUrl ?? '');
    _studentSearchController = TextEditingController();

    if (d != null) {
      _selectedCategory = d.category;
      _selectedSemester = d.semester;
      _selectedClassId = d.classId;
      _uploadedFileName = d.fileName;
      _uploadedFileSize = d.fileSize;
      _uploadedMimeType = d.mimeType;

      if (d.isStudentDedicated) {
        _targetMode = 'student';
      } else if (d.classId != null && d.classId!.isNotEmpty) {
        _targetMode = 'class';
      } else {
        _targetMode = 'all';
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _fileUrlController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible de lire le fichier sélectionné')),
          );
        }
        return;
      }

      setState(() => _isUploading = true);

      final extension = file.extension ?? 'pdf';
      final fileName = 'doc_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final storagePath = 'uploads/$fileName';

      final supabase = SupabaseConfig.client;
      await supabase.storage.from('documents').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _getMimeType(extension),
              upsert: true,
            ),
          );

      final publicUrl =
          supabase.storage.from('documents').getPublicUrl(storagePath);

      if (mounted) {
        setState(() {
          _fileUrlController.text = publicUrl;
          _uploadedFileName = file.name;
          _uploadedFileSize = file.size;
          _uploadedMimeType = _getMimeType(extension);
          _isUploading = false;
          if (_titleController.text.trim().isEmpty) {
            _titleController.text =
                file.name.replaceAll('.$extension', '').replaceAll('_', ' ');
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fichier téléversé avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de téléversement: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.ms-powerpoint';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    final fileUrl = _fileUrlController.text.trim();

    if (fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez fournir un fichier ou un lien'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(documentsProvider.notifier);

      String? targetClassId;
      String? targetStudentId;
      String? targetStudentName;
      String? targetStudentCode;

      if (_targetMode == 'class') {
        targetClassId = _selectedClassId;
      } else if (_targetMode == 'student') {
        if (_selectedStudent != null) {
          targetStudentId = _selectedStudent!.id;
          targetStudentName = _selectedStudent!.fullName;
          targetStudentCode = _selectedStudent!.studentCode;
        } else if (widget.editDoc != null && widget.editDoc!.isStudentDedicated) {
          targetStudentId = widget.editDoc!.studentId;
          targetStudentName = widget.editDoc!.studentName;
          targetStudentCode = widget.editDoc!.studentCode;
        }
      }

      if (isEditing) {
        await notifier.updateDocument(
          id: widget.editDoc!.id,
          title: title,
          description: description,
          fileUrl: fileUrl,
          fileName: _uploadedFileName,
          fileSize: _uploadedFileSize,
          mimeType: _uploadedMimeType,
          classId: targetClassId,
          category: _selectedCategory,
          semester: _selectedSemester,
          studentId: targetStudentId,
          studentName: targetStudentName,
          studentCode: targetStudentCode,
        );
      } else {
        await notifier.create(
          title: title,
          description: description,
          fileUrl: fileUrl,
          fileName: _uploadedFileName,
          fileSize: _uploadedFileSize,
          mimeType: _uploadedMimeType,
          classId: targetClassId,
          category: _selectedCategory,
          semester: _selectedSemester,
          studentId: targetStudentId,
          studentName: targetStudentName,
          studentCode: targetStudentCode,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Document mis à jour avec succès'
                  : 'Document ajouté avec succès',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesState = ref.watch(classesProvider);
    final List<ClassModel> classes = classesState.value?.classes ?? <ClassModel>[];

    final semestersState = ref.watch(semestersProvider);
    final semesters = semestersState.value?.filteredSemesters.isNotEmpty == true
        ? semestersState.value!.filteredSemesters
        : (semestersState.value?.semesters ?? <SemesterModel>[]);

    // Students from usersProvider
    final usersState = ref.watch(usersProvider);
    final allStudents = (usersState.value?.users ?? [])
        .where((u) => u.role == 'student')
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 780),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Modal Header (matching UserFormDialog)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D4CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.post_add_rounded,
                      color: Color(0xFF6D4CF6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Modifier le document' : 'Ajouter un document',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),

            // Modal Body Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre du document
                      _buildFieldLabel('TITRE DU DOCUMENT *'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        style: const TextStyle(fontSize: 14),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Le titre est obligatoire' : null,
                        decoration: _inputDecoration('Ex: Attestation de scolarité 2026/2027'),
                      ),
                      const SizedBox(height: 18),

                      // Type de document (Styled with radius and no harsh border!)
                      _buildFieldLabel('TYPE DE DOCUMENT'),
                      const SizedBox(height: 8),
                      _buildStyledDropdown<String>(
                        value: _selectedCategory,
                        items: AcademicDocumentType.types.entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                      const SizedBox(height: 18),

                      // Semestre (Selected via dropdown with radius!)
                      _buildFieldLabel('SEMESTRE'),
                      const SizedBox(height: 8),
                      _buildStyledDropdown<int>(
                        value: _selectedSemester,
                        items: semesters.isNotEmpty
                            ? semesters
                                .map((s) => DropdownMenuItem(
                                      value: s.number,
                                      child: Text(s.name),
                                    ))
                                .toList()
                            : const [
                                DropdownMenuItem(value: 1, child: Text('Semestre 1')),
                                DropdownMenuItem(value: 2, child: Text('Semestre 2')),
                                DropdownMenuItem(value: 3, child: Text('Semestre 3')),
                              ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSemester = val);
                        },
                      ),
                      const SizedBox(height: 18),

                      // Cible du document (School-wide / Class / Single Student)
                      _buildFieldLabel('DESTINATAIRE DU DOCUMENT'),
                      const SizedBox(height: 8),
                      _buildStyledDropdown<String>(
                        value: _targetMode,
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('Général (Toutes les classes)'),
                          ),
                          DropdownMenuItem(
                            value: 'class',
                            child: Text('Une classe spécifique'),
                          ),
                          DropdownMenuItem(
                            value: 'student',
                            child: Text('Un étudiant spécifique'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _targetMode = val;
                              if (val != 'class') _selectedClassId = null;
                              if (val != 'student') _selectedStudent = null;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // When target is Class: show class dropdown
                      if (_targetMode == 'class') ...[
                        _buildFieldLabel('CHOISIR LA CLASSE'),
                        const SizedBox(height: 8),
                        _buildStyledDropdown<String?>(
                          value: _selectedClassId,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Sélectionner une classe')),
                            ...classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (val) => setState(() => _selectedClassId = val),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // When target is Single Student: Search & Select Student by Name / Code / Email
                      if (_targetMode == 'student') ...[
                        _buildFieldLabel('RECHERCHER L\'ÉTUDIANT (NOM, MATRICULE OU EMAIL)'),
                        const SizedBox(height: 8),
                        if (_selectedStudent != null ||
                            (widget.editDoc != null && widget.editDoc!.isStudentDedicated && _selectedStudent == null)) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF6D4CF6).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF6D4CF6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person, color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedStudent?.fullName ?? widget.editDoc?.studentName ?? 'Étudiant',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        _selectedStudent?.studentCode ?? widget.editDoc?.studentCode ?? '',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
                                  onPressed: () {
                                    setState(() {
                                      _selectedStudent = null;
                                      _studentSearchController.clear();
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ] else ...[
                          TextFormField(
                            controller: _studentSearchController,
                            style: const TextStyle(fontSize: 14),
                            onChanged: (_) => setState(() {}),
                            decoration: _inputDecoration('Taper pour rechercher un étudiant...').copyWith(
                              prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                            ),
                          ),
                          if (_studentSearchController.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 180),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.borderLight),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListView(
                                shrinkWrap: true,
                                children: allStudents.where((u) {
                                  final q = _studentSearchController.text.trim().toLowerCase();
                                  return u.fullName.toLowerCase().contains(q) ||
                                      u.email.toLowerCase().contains(q) ||
                                      (u.studentCode?.toLowerCase().contains(q) ?? false);
                                }).take(6).map((student) {
                                  return ListTile(
                                    dense: true,
                                    leading: UserAvatar(
                                      name: student.fullName,
                                      photoUrl: student.photoUrl,
                                      radius: 14,
                                    ),
                                    title: Text(student.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    subtitle: Text(
                                      '${student.studentCode ?? student.email} • ${student.className ?? ''}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _selectedStudent = student;
                                        _studentSearchController.clear();
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                        ],
                      ],

                      // Fichier ou Lien
                      _buildFieldLabel('FICHIER OU LIEN *'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _fileUrlController,
                              style: const TextStyle(fontSize: 14),
                              decoration: _inputDecoration('https://... ou téléversez un fichier'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: _isUploading ? null : _pickAndUploadFile,
                              icon: _isUploading
                                  ? const IosLoader.small(color: Colors.white)
                                  : const Icon(Icons.upload_file_rounded, size: 16),
                              label: const Text(
                                'Téléverser',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6D4CF6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Description
                      _buildFieldLabel('DESCRIPTION (OPTIONNEL)'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 14),
                        decoration: _inputDecoration('Précisions supplémentaires sur le document...'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Modal Footer Buttons (matching UserFormDialog exactly!)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFB),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 40,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: (_isSaving || _isUploading) ? null : _submit,
                      icon: _isSaving
                          ? const IosLoader.small(color: Colors.white)
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        isEditing ? 'Enregistrer' : 'Ajouter le document',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D4CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
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

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      filled: true,
      fillColor: AppColors.slate50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5),
      ),
    );
  }

  Widget _buildStyledDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          dropdownColor: Colors.white,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
