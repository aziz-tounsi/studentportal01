import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/arabic_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/document_model.dart';
import '../../widgets/animated_search_header.dart';
import '../../widgets/bouncing_wrapper.dart';
import '../../widgets/detail_modal_sheet.dart';
import '../../widgets/documents_skeleton.dart';
import '../../widgets/semester_navigator.dart';
import '../../providers/nav_bar_provider.dart';

// Semester state provider for this screen
final docsSemesterProvider = StateProvider<int>((ref) => 1);

// Demo documents dataset with distinct documents for each semester
final List<DocumentModel> _demoDocuments = [
  // --- SEMESTRE 1 DOCUMENTS ---
    DocumentModel(
      id: 's1-1',
      schoolId: 'school1',
      title: 'Attestation de scolarité',
      description: 'Attestation officielle d\'inscription pour l\'année universitaire 2024-2025',
      category: 'attestation',
      semester: 1,
      fileUrl: 'https://example.com/attestation.pdf',
      fileName: 'attestation_scolarite_2024_2025.pdf',
      fileSize: 256000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2024, 9, 15),
    ),
    DocumentModel(
      id: 's1-2',
      schoolId: 'school1',
      title: 'Certificat d\'inscription',
      description: 'Certificat d\'inscription administrative au titre du premier semestre',
      category: 'certificat',
      semester: 1,
      fileUrl: 'https://example.com/certificat.pdf',
      fileName: 'certificat_inscription_s1.pdf',
      fileSize: 145000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2024, 9, 5),
    ),
    DocumentModel(
      id: 's1-3',
      schoolId: 'school1',
      title: 'Règlement intérieur & Charte',
      description: 'Règlement intérieur, devoirs et droits de l\'étudiant sur le campus',
      category: 'reglement',
      semester: 1,
      fileUrl: 'https://example.com/reglement.pdf',
      fileName: 'reglement_interieur_2024.pdf',
      fileSize: 420000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2024, 9, 1),
    ),
    DocumentModel(
      id: 's1-4',
      schoolId: 'school1',
      title: 'Carte d\'étudiant numérique',
      description: 'Badge d\'accès sécurisé aux laboratoires et à la bibliothèque',
      category: 'carte_etudiant',
      semester: 1,
      fileUrl: 'https://example.com/carte.pdf',
      fileName: 'carte_etudiant_2024_2025.pdf',
      fileSize: 95000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2024, 10, 1),
    ),
    DocumentModel(
      id: 's1-5',
      schoolId: 'school1',
      title: 'Emploi du temps - Semestre 1',
      description: 'Planning des séances de cours magistraux, TD et TP',
      category: 'planning',
      semester: 1,
      fileUrl: 'https://example.com/planning_s1.pdf',
      fileName: 'emploi_du_temps_semestre_1.pdf',
      fileSize: 310000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2024, 9, 8),
    ),
    DocumentModel(
      id: 's1-6',
      schoolId: 'school1',
      title: 'Calendrier des examens S1',
      description: 'Planning des sessions principales et des rattrapages S1',
      category: 'exams',
      semester: 1,
      fileUrl: 'https://example.com/calendrier_s1.pdf',
      fileName: 'calendrier_examens_s1.pdf',
      fileSize: 128000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2024, 11, 20),
    ),
    DocumentModel(
      id: 's1-7',
      schoolId: 'school1',
      title: 'Relevé de notes - S1',
      description: 'Relevé de notes et crédits ECTS validés du premier semestre',
      category: 'releve_notes',
      semester: 1,
      fileUrl: 'https://example.com/releve_s1.pdf',
      fileName: 'releve_notes_s1_2024_2025.pdf',
      fileSize: 180000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2025, 1, 25),
    ),

    // --- SEMESTRE 2 DOCUMENTS ---
    DocumentModel(
      id: 's2-1',
      schoolId: 'school1',
      title: 'Emploi du temps - Semestre 2',
      description: 'Planning des cours et des créneaux de projets du semestre 2',
      category: 'planning',
      semester: 2,
      fileUrl: 'https://example.com/planning_s2.pdf',
      fileName: 'emploi_du_temps_semestre_2.pdf',
      fileSize: 295000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2025, 2, 3),
    ),
    DocumentModel(
      id: 's2-2',
      schoolId: 'school1',
      title: 'Convention de stage & Guide PFE',
      description: 'Modèle de convention tripartite obligatoire et guide de rédaction',
      category: 'stage_pfe',
      semester: 2,
      fileUrl: 'https://example.com/convention_stage.pdf',
      fileName: 'convention_stage_et_guide_pfe.pdf',
      fileSize: 520000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2025, 3, 10),
    ),
    DocumentModel(
      id: 's2-3',
      schoolId: 'school1',
      title: 'Calendrier des examens S2',
      description: 'Planning des épreuves terminales du second semestre',
      category: 'exams',
      semester: 2,
      fileUrl: 'https://example.com/calendrier_s2.pdf',
      fileName: 'calendrier_examens_s2.pdf',
      fileSize: 135000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2025, 5, 15),
    ),
    DocumentModel(
      id: 's2-4',
      schoolId: 'school1',
      title: 'Relevé de notes - S2',
      description: 'Relevé de notes officiel du second semestre et moyennes annuelles',
      category: 'releve_notes',
      semester: 2,
      fileUrl: 'https://example.com/releve_s2.pdf',
      fileName: 'releve_notes_s2_2024_2025.pdf',
      fileSize: 195000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2025, 6, 20),
    ),
    DocumentModel(
      id: 's2-5',
      schoolId: 'school1',
      title: 'Attestation de réussite S2',
      description: 'Attestation de validation de l\'année et passage en année supérieure',
      category: 'attestation',
      semester: 2,
      fileUrl: 'https://example.com/reussite_s2.pdf',
      fileName: 'attestation_reussite_s2.pdf',
      fileSize: 210000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2025, 6, 28),
    ),

    // --- SEMESTRE 3 DOCUMENTS ---
    DocumentModel(
      id: 's3-1',
      schoolId: 'school1',
      title: 'Emploi du temps - Semestre 3',
      description: 'Planning des cours avancés et ateliers de spécialité',
      category: 'planning',
      semester: 3,
      fileUrl: 'https://example.com/planning_s3.pdf',
      fileName: 'emploi_du_temps_semestre_3.pdf',
      fileSize: 310000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2025, 9, 10),
    ),
    DocumentModel(
      id: 's3-2',
      schoolId: 'school1',
      title: 'Guide des options de spécialité',
      description: 'Descriptif des parcours et choix de modules optionnels',
      category: 'administrative',
      semester: 3,
      fileUrl: 'https://example.com/guide_s3.pdf',
      fileName: 'guide_specialites_s3.pdf',
      fileSize: 450000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2025, 9, 12),
    ),
    DocumentModel(
      id: 's3-3',
      schoolId: 'school1',
      title: 'Planning des examens S3',
      description: 'Calendrier des évaluations partielles et projets S3',
      category: 'exams',
      semester: 3,
      fileUrl: 'https://example.com/examens_s3.pdf',
      fileName: 'planning_examens_s3.pdf',
      fileSize: 140000,
      mimeType: 'application/pdf',
      createdAt: DateTime(2025, 11, 15),
    ),
  ];

// Demo documents provider family with distinct documents for each semester & authentic loading delay
final documentsProvider = FutureProvider.family<List<DocumentModel>, int>((ref, semester) async {
  await Future.delayed(const Duration(milliseconds: 260));
  return _demoDocuments.where((doc) {
    if (doc.category == 'courses') return false;
    return doc.effectiveSemester == semester;
  }).toList();
});

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen>
    with TickerProviderStateMixin {
  late AnimationController _searchAnimController;
  String? _selectedCategory;
  bool _isFilterDropdownOpen = false;
  
  // Search state
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // iOS 26 gradient colors
  static const _gradientColors = [
    Color(0xFFF8F0FC),
    Color(0xFFF0E6F8),
    Color(0xFFEAF0FA),
    Color(0xFFF4F8FC),
    Color(0xFFFAFCFD),
  ];

  @override
  void initState() {
    super.initState();
    _searchAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
      }
    });
  }

  @override
  void deactivate() {
    dismissAllOverlaysAndPopups();
    super.deactivate();
  }

  @override
  void dispose() {
    if (_isSearching) {
      ref.read(backSwipeInterceptorProvider.notifier).state = null;
    }
    _searchAnimController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _searchAnimController.forward();
        ref.read(backSwipeInterceptorProvider.notifier).state = () {
          _toggleSearch();
          return true;
        };
        Future.delayed(const Duration(milliseconds: 150), () {
          _searchFocusNode.requestFocus();
        });
      } else {
        ref.read(backSwipeInterceptorProvider.notifier).state = null;
        _searchAnimController.reverse();
        _searchController.clear();
        _searchQuery = '';
        _searchFocusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedSemester = ref.watch(docsSemesterProvider);
    final documentsAsync = ref.watch(documentsProvider(selectedSemester));

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradientColors,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildHeader(l10n),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DynamicSemesterNav(
                  selectedSemesterNumber: selectedSemester,
                  accentColor: const Color(0xFF6B5CE7),
                  secondaryColor: const Color(0xFF8B5CF6),
                  onChanged: (v) {
                    ref.read(docsSemesterProvider.notifier).state = v;
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: documentsAsync.when(
                  data: (documents) => _buildContent(documents, l10n, selectedSemester),
                  loading: () => _buildLoadingState(l10n),
                  error: (error, stack) => _buildErrorState(l10n),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: AnimatedSearchHeader(
        animationController: _searchAnimController,
        searchController: _searchController,
        searchFocusNode: _searchFocusNode,
        onToggleSearch: _toggleSearch,
        title: l10n.documents,
        subtitle: l10n.homeSubtitleDocuments,
        icon: Icons.folder_rounded,
        gradientColors: const [Color(0xFF6B5CE7), Color(0xFF8B5CF6)],
        isSearching: _isSearching,
      ),
    );
  }

  Widget _buildContent(List<DocumentModel> documents, AppLocalizations l10n, int selectedSemester) {
    // 1. Strictly filter documents for the selected semester
    // Courses are excluded as they belong to the Dedicated Courses Screen
    final semesterDocs = documents.where((doc) {
      if (doc.category == 'courses') return false;
      return doc.effectiveSemester == selectedSemester;
    }).toList();

    // 2. Sort documents by post date descending (most recent first)
    semesterDocs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // 3. Extract unique categories present in this semester
    final availableCategories = semesterDocs.map((d) => d.category).toSet().toList();

    // 4. Apply category filter if one is selected
    var filteredDocs = semesterDocs;
    if (_selectedCategory != null) {
      filteredDocs = filteredDocs.where((doc) => doc.category == _selectedCategory).toList();
    }

    // 5. Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredDocs = filteredDocs.where((doc) {
        return doc.title.toLowerCase().contains(query) ||
            (doc.description?.toLowerCase().contains(query) ?? false) ||
            doc.fileName.toLowerCase().contains(query) ||
            doc.displayCategory(l10n).toLowerCase().contains(query);
      }).toList();
    }

    if (semesterDocs.isEmpty) {
      return _buildEmptySemesterState(selectedSemester, l10n);
    }

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_isSearching) _toggleSearch();
      },
      onHorizontalDragUpdate: (details) {
        if (_isSearching) {
          if (isRtl) {
            if ((details.primaryDelta ?? 0) > 8) _toggleSearch();
          } else {
            if ((details.primaryDelta ?? 0) < -8) _toggleSearch();
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Trier par" label and dropdown button aligned to max right - fixed at top
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSortAndFilterBar(availableCategories, l10n),
          ),
          const SizedBox(height: 10),

          // Scrollable document cards that pass cleanly under the "Trier par" row
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(documentsProvider(selectedSemester));
                await ref.read(documentsProvider(selectedSemester).future);
              },
              color: const Color(0xFF6B5CE7),
              backgroundColor: Colors.white,
              child: filteredDocs.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      child: _buildEmptyFilterState(l10n),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 140),
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) => _DocumentCard(document: filteredDocs[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortAndFilterBar(List<String> availableCategories, AppLocalizations l10n) {
    const allCategoriesKey = '__ALL__';
    final currentLabel = DocumentTypeHelper.getLabel(_selectedCategory, l10n);

    final sortOptions = <MapEntry<String, String>>[
      MapEntry(allCategoriesKey, l10n.allTypes),
      ...availableCategories.map((cat) => MapEntry(cat, DocumentTypeHelper.getLabel(cat, l10n))),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          // "Trier par" label on left
          Text(
            l10n.sortBy,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(), // Pushes the pill to the maximum right

          // Dropdown button styled exactly like Suggestion Type list
          Theme(
            data: Theme.of(context).copyWith(
              popupMenuTheme: PopupMenuThemeData(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 8,
              ),
            ),
            child: PopupMenuButton<String>(
              color: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              offset: const Offset(0, 48),
              onOpened: () => setState(() => _isFilterDropdownOpen = true),
              onCanceled: () => setState(() => _isFilterDropdownOpen = false),
              onSelected: (String categoryKey) {
                setState(() {
                  _selectedCategory = (categoryKey == allCategoriesKey) ? null : categoryKey;
                  _isFilterDropdownOpen = false;
                });
              },
              itemBuilder: (BuildContext context) => sortOptions.map((entry) {
                final catKey = entry.key;
                final isAll = catKey == allCategoriesKey;
                final typeColor = isAll
                    ? const Color(0xFF6B5CE7)
                    : getCategoryColor(catKey);
                final typeIcon = isAll
                    ? Icons.dashboard_rounded
                    : getCategoryIcon(catKey);
                final isSelected = (_selectedCategory == null && isAll) || _selectedCategory == catKey;

                return PopupMenuItem<String>(
                  value: catKey,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(typeIcon, color: typeColor, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? typeColor : Colors.grey[800],
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle, color: typeColor, size: 20),
                      ],
                    ),
                  ),
                );
              }).toList(),
              child: AnimatedScale(
                scale: _isFilterDropdownOpen ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutBack,
                child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B5CE7).withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      currentLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _selectedCategory != null
                            ? const Color(0xFF6B5CE7)
                            : const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _isFilterDropdownOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: _selectedCategory != null
                            ? const Color(0xFF6B5CE7)
                            : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'releve_notes':
        return Icons.grade_rounded;
      case 'exams':
        return Icons.quiz_rounded;
      case 'carte_etudiant':
        return Icons.badge_rounded;
      case 'attestation':
        return Icons.verified_rounded;
      case 'planning':
        return Icons.calendar_month_rounded;
      case 'certificat':
        return Icons.assignment_turned_in_rounded;
      case 'stage_pfe':
        return Icons.work_rounded;
      case 'reglement':
        return Icons.gavel_rounded;
      case 'administrative':
        return Icons.description_rounded;
      case 'courses':
        return Icons.menu_book_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  static Color getCategoryColor(String category) {
    switch (category) {
      case 'releve_notes':
        return const Color(0xFF8B5CF6);
      case 'exams':
        return const Color(0xFFF43F5E);
      case 'carte_etudiant':
        return const Color(0xFF3B82F6);
      case 'attestation':
        return const Color(0xFF6B5CE7);
      case 'planning':
        return const Color(0xFF10B981);
      case 'certificat':
        return const Color(0xFF06B6D4);
      case 'stage_pfe':
        return const Color(0xFFF59E0B);
      case 'reglement':
        return const Color(0xFF64748B);
      case 'administrative':
        return const Color(0xFF6366F1);
      case 'courses':
        return const Color(0xFF4ECDC4);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  Widget _buildEmptySemesterState(int semester, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF6B5CE7).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.folder_open_rounded,
              size: 40,
              color: const Color(0xFF6B5CE7).withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.noData,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.noDocsForSemester(semester),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFilterState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.filter_list_off_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              l10n.noMatchingDocuments,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.trySelectAnotherType,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(AppLocalizations l10n) {
    final currentLabel = _selectedCategory != null
        ? DocumentTypeHelper.getLabel(_selectedCategory, l10n)
        : null;
    return DocumentsCardsSkeleton(selectedCategoryLabel: currentLabel);
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    final selectedSemester = ref.watch(docsSemesterProvider);
    return Center(
      child: Container(
        margin: const EdgeInsets.all(40),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 28,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.error,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3142),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => ref.refresh(documentsProvider(selectedSemester)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B5CE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.retry,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Document card widget - iOS 26 premium style without entry hover animation
class _DocumentCard extends StatelessWidget {
  final DocumentModel document;

  const _DocumentCard({
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat('dd MMM yyyy', lang);
    final categoryColor = _DocumentsScreenState.getCategoryColor(document.category);
    final categoryIcon = _DocumentsScreenState.getCategoryIcon(document.category);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BouncingWrapper(
        shrinkScale: 0.93,
        overshootScale: 1.055,
        delayNavigation: false,
        onTap: () => _showDocumentDetails(context, document),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
              children: [
                // Category icon with soft gradient matching document type
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [categoryColor, categoryColor.withValues(alpha: 0.75)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: categoryColor.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    categoryIcon,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: ArabicTypography.subtitleStyle(
                          context,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1F2937),
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (document.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          document.description!,
                          style: ArabicTypography.bodyStyle(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      // Meta row without overflowing category pill
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ArabicTypography.toLatinDigits(dateFormat.format(document.createdAt)),
                            style: ArabicTypography.bodyStyle(
                              context,
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (document.fileSize != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              document.displayFileSize,
                              style: ArabicTypography.bodyStyle(
                                context,
                                fontSize: 11,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                // Normal grey arrow pointing left in Arabic, right in Latin
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Icon(
                    ArabicTypography.isArabic(context)
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  void _showDocumentDetails(BuildContext context, DocumentModel document) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final dateFormat = DateFormat('dd MMMM yyyy', lang);
    final categoryColor = _DocumentsScreenState.getCategoryColor(document.category);
    final categoryIcon = _DocumentsScreenState.getCategoryIcon(document.category);

    DetailModalSheet.show(
      context: context,
      initialChildSize: 0.58,
      bottomAction: BouncingWrapper(
        behavior: HitTestBehavior.opaque,
        shrinkScale: 0.94,
        overshootScale: 1.05,
        delayNavigation: true,
        onTap: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.translate('downloading_status')),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: categoryColor,
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [categoryColor, categoryColor.withValues(alpha: 0.85)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: categoryColor.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.download_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                l10n.translate('download'),
                style: ArabicTypography.buttonStyle(
                  context,
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and category badge
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [categoryColor, categoryColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: categoryColor.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  categoryIcon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      style: ArabicTypography.headerStyle(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        document.displayCategory(l10n),
                        style: ArabicTypography.subtitleStyle(
                          context,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: categoryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (document.description != null && document.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              document.description!,
              style: ArabicTypography.bodyStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Info rows (Date, Size, File name) with ROUND circular icons
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: l10n.dateLabel,
            value: ArabicTypography.toLatinDigits(dateFormat.format(document.createdAt)),
          ),
          if (document.fileSize != null)
            _DetailRow(
              icon: Icons.storage_outlined,
              label: l10n.translate('size_label'),
              value: document.displayFileSize,
            ),
          _DetailRow(
            icon: Icons.insert_drive_file_outlined,
            label: l10n.translate('file_label'),
            value: document.fileName,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: Colors.grey[600]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: ArabicTypography.bodyStyle(
                    context,
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: ArabicTypography.bodyStyle(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
