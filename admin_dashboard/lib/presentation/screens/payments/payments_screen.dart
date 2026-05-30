import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/payments_provider.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/user_avatar.dart';

/// Modern Payment Management Screen
/// Full control over student payments with comprehensive filtering and actions
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen>
    with TickerProviderStateMixin {
  late TabController _viewTabController;
  final _searchController = TextEditingController();
  bool _showFilters = false;
  Set<String> _selectedPayments = {};

  // Hierarchical filter state
  List<Map<String, dynamic>> _allNiveaux = [];
  List<Map<String, dynamic>> _allSections = [];
  List<Map<String, dynamic>> _allClasses = [];
  List<Map<String, dynamic>> _allStudents = [];
  String? _selectedNiveauId;
  String? _selectedSectionId;
  String? _selectedClassId;
  bool _isLoadingHierarchy = true;

  @override
  void initState() {
    super.initState();
    _viewTabController = TabController(length: 3, vsync: this);
    _loadHierarchyData();
  }

  Future<void> _loadHierarchyData() async {
    try {
      final supabase = Supabase.instance.client;

      // Load niveaux
      final niveauxResp = await supabase
          .from('niveaux')
          .select('id, name')
          .order('name');

      // Load sections (filières) - need to get from niveau_sections to know which sections belong to which niveau
      final sectionsResp = await supabase
          .from('sections')
          .select('id, name')
          .order('name');

      // Load niveau_sections to map sections to niveaux
      final niveauSectionsResp = await supabase
          .from('niveau_sections')
          .select('niveau_id, section_id')
          .eq('is_active', true);

      // Load all classes with niveau and section info
      final classesResp = await supabase
          .from('classes')
          .select('id, name, niveau_id, section_id')
          .eq('is_active', true)
          .order('name');

      // Load all students with their enrollments
      final studentsResp = await supabase
          .from('users')
          .select('id, full_name, email, phone')
          .eq('role', 'student')
          .eq('is_active', true)
          .order('full_name');

      // Load enrollments separately
      final enrollmentsResp = await supabase
          .from('enrollments')
          .select(
            'id, user_id, class_id, classes(id, name, niveau_id, section_id)',
          )
          .eq('is_active', true);

      // Merge enrollments into students
      final studentsWithEnrollments = <Map<String, dynamic>>[];
      for (final student in studentsResp) {
        final studentEnrollments = (enrollmentsResp as List)
            .where((e) => e['user_id'] == student['id'])
            .toList();
        studentsWithEnrollments.add({
          ...student,
          'enrollments': studentEnrollments,
        });
      }

      // Build sections with niveau_id mapping
      final sectionsWithNiveau = <Map<String, dynamic>>[];
      for (final section in sectionsResp) {
        final niveauMapping = (niveauSectionsResp as List)
            .where((ns) => ns['section_id'] == section['id'])
            .toList();
        for (final mapping in niveauMapping) {
          sectionsWithNiveau.add({
            ...section,
            'niveau_id': mapping['niveau_id'],
          });
        }
      }

      setState(() {
        _allNiveaux = List<Map<String, dynamic>>.from(niveauxResp);
        _allSections = sectionsWithNiveau;
        _allClasses = List<Map<String, dynamic>>.from(classesResp);
        _allStudents = studentsWithEnrollments;
        _isLoadingHierarchy = false;
      });
    } catch (e) {
      debugPrint('Error loading hierarchy: $e');
      setState(() => _isLoadingHierarchy = false);
    }
  }

  // Get sections for selected niveau
  List<Map<String, dynamic>> get _sectionsForNiveau {
    if (_selectedNiveauId == null) return [];
    return _allSections
        .where((s) => s['niveau_id'] == _selectedNiveauId)
        .toList();
  }

  // Check if selected niveau has sections
  bool get _niveauHasSections => _sectionsForNiveau.isNotEmpty;

  // Get filtered classes based on hierarchy selection
  List<Map<String, dynamic>> get _filteredClasses {
    if (_selectedNiveauId == null) return _allClasses;

    return _allClasses.where((c) {
      if (c['niveau_id'] != _selectedNiveauId) return false;
      if (_niveauHasSections && _selectedSectionId != null) {
        return c['section_id'] == _selectedSectionId;
      }
      return true;
    }).toList();
  }

  // Get filtered students based on hierarchy and search
  List<Map<String, dynamic>> _getFilteredStudents(String query) {
    return _allStudents.where((s) {
      // Search filter
      if (query.isNotEmpty) {
        final searchLower = query.toLowerCase();
        final name = (s['full_name'] ?? '').toString().toLowerCase();
        final email = (s['email'] ?? '').toString().toLowerCase();
        final phone = (s['phone'] ?? '').toString().toLowerCase();

        if (!name.contains(searchLower) &&
            !email.contains(searchLower) &&
            !phone.contains(searchLower)) {
          return false;
        }
      }

      // Get enrollment info
      final enrollments = s['enrollments'] as List?;

      // If hierarchy filter is applied, filter by class
      if (_selectedClassId != null || _selectedNiveauId != null) {
        if (enrollments == null || enrollments.isEmpty) return false;

        final enrollment = enrollments.first as Map<String, dynamic>;
        final classData = enrollment['classes'] as Map<String, dynamic>?;

        if (_selectedClassId != null) {
          return enrollment['class_id'] == _selectedClassId ||
              classData?['id'] == _selectedClassId;
        }

        if (_selectedNiveauId != null) {
          if (classData?['niveau_id'] != _selectedNiveauId) return false;
          if (_niveauHasSections && _selectedSectionId != null) {
            return classData?['section_id'] == _selectedSectionId;
          }
        }
      }

      return true;
    }).toList();
  }

  @override
  void dispose() {
    _viewTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(paymentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F8),
      body: Stack(
        children: [
          Row(
            children: [
              const AdminSidebar(currentRoute: '/payments'),
              Expanded(
                child: Column(
                  children: [
                    _buildHeader(paymentsAsync),
                    Expanded(
                      child: paymentsAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF10B981),
                            strokeWidth: 2,
                          ),
                        ),
                        error: (e, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline_rounded, size: 56,
                                    color: AppColors.error.withOpacity(0.6)),
                                const SizedBox(height: 16),
                                Text('Erreur: $e',
                                    style: TextStyle(color: AppColors.textSecondary)),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () => ref.invalidate(paymentsProvider),
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Réessayer'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        data: (state) => _buildMainContent(context, state),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Filter overlay — slides in from right like grade_levels
          if (_showFilters) ...[
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showFilters = false),
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
              child: paymentsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (state) => _buildFilterPanel(context, state),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER — Premium grade-levels style
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(AsyncValue<PaymentsState> paymentsAsync) {
    final state = paymentsAsync.asData?.value;
    final count = state?.payments.length ?? 0;
    final studentCount = state?.studentSummaries.length ?? 0;
    final hasFilters = (state?.statusFilter != null && state?.statusFilter != 'all') ||
        state?.classFilter != null ||
        state?.categoryFilter != null ||
        state?.dateFromFilter != null ||
        state?.dateToFilter != null ||
        _selectedNiveauId != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title block
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gestion des Paiements',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count paiements • $studentCount étudiants',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),

          const Spacer(),

          // Bulk actions (when selection active)
          if (_selectedPayments.isNotEmpty) ...[
            SizedBox(
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () => _showBulkMarkPaidDialog(context),
                icon: const Icon(Icons.check_circle, size: 16),
                label: Text('Marquer ${_selectedPayments.length} payé(s)',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: TextButton(
                onPressed: () => setState(() => _selectedPayments.clear()),
                child: Text('Annuler',
                    style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
              ),
            ),
            const SizedBox(width: 16),
          ],

          // Student search (Autocomplete)
          SizedBox(
            width: 320,
            height: 40,
            child: _buildStudentSearchBar(),
          ),

          const SizedBox(width: 12),

          // Filter button
          _buildHeaderIconButton(
            icon: Icons.filter_list_rounded,
            tooltip: 'Filtres',
            isActive: _showFilters || hasFilters,
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),

          const SizedBox(width: 8),

          // Export button
          PopupMenuButton<String>(
            onSelected: _handleExport,
            offset: const Offset(0, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pdf',
                child: Row(children: [
                  Icon(Icons.picture_as_pdf, color: AppColors.error, size: 18),
                  const SizedBox(width: 12),
                  const Text('Exporter en PDF'),
                ]),
              ),
              PopupMenuItem(
                value: 'excel',
                child: Row(children: [
                  Icon(Icons.table_chart, color: const Color(0xFF10B981), size: 18),
                  const SizedBox(width: 12),
                  const Text('Exporter en Excel'),
                ]),
              ),
              PopupMenuItem(
                value: 'print',
                child: Row(children: [
                  Icon(Icons.print, color: AppColors.slate500, size: 18),
                  const SizedBox(width: 12),
                  const Text('Imprimer'),
                ]),
              ),
            ],
            tooltip: 'Exporter',
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.file_download_outlined, size: 20, color: Color(0xFF64748B)),
            ),
          ),

          const SizedBox(width: 16),

          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () => _showAddPaymentPlanDialog(context),
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
      color: isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
      style: IconButton.styleFrom(
        backgroundColor: isActive ? const Color(0xFF10B981).withOpacity(0.1) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isActive ? const Color(0xFF10B981).withOpacity(0.2) : Colors.transparent,
          ),
        ),
      ),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STUDENT SEARCH BAR WITH AUTOCOMPLETE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStudentSearchBar() {
    return Autocomplete<Map<String, dynamic>>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<Map<String, dynamic>>.empty();
          }
          return _getFilteredStudents(textEditingValue.text).take(10);
        },
        displayStringForOption: (option) =>
            option['full_name']?.toString() ?? '',
        fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher un élève...',
              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
              prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textTertiary),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () => controller.clear(),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text('⌘K', style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontFamily: 'monospace')),
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
                borderSide: BorderSide(
                    color: const Color(0xFF10B981).withOpacity(0.4), width: 1.5),
              ),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                width: 400,
                constraints: const BoxConstraints(maxHeight: 350),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final student = options.elementAt(index);
                    final enrollments = student['enrollments'] as List?;
                    final enrollment = enrollments?.isNotEmpty == true
                        ? enrollments!.first as Map<String, dynamic>
                        : null;
                    final classData =
                        enrollment?['classes'] as Map<String, dynamic>?;

                    return ListTile(
                      leading: UserAvatar(
                        name: student['full_name'] ?? '?',
                        radius: 20,
                      ),
                      title: Text(
                        student['full_name'] ?? 'Sans nom',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${classData?['name'] ?? 'Pas de classe'} • ${student['email'] ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Color(0xFF10B981),
                        ),
                        tooltip: 'Créer un plan de paiement',
                        onPressed: () =>
                            _showCreatePaymentPlanForStudent(student),
                      ),
                      onTap: () => _showCreatePaymentPlanForStudent(student),
                    );
                  },
                ),
              ),
            ),
          );
        },
        onSelected: (student) => _showCreatePaymentPlanForStudent(student),
      );
  }

  void _showCreatePaymentPlanForStudent(Map<String, dynamic> student) {
    final enrollments = student['enrollments'] as List?;
    if (enrollments == null || enrollments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cet élève n\'est inscrit dans aucune classe'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final enrollment = enrollments.first as Map<String, dynamic>;
    final enrollmentId = enrollment['id']?.toString();
    final classData = enrollment['classes'] as Map<String, dynamic>?;

    _showPaymentPlanCreationDialog(
      studentId: student['id']?.toString() ?? '',
      studentName: student['full_name']?.toString() ?? '',
      enrollmentId: enrollmentId ?? '',
      className: classData?['name']?.toString() ?? '',
    );
  }

  void _showAddPaymentPlanDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _SelectStudentForPaymentDialog(
        allStudents: _allStudents,
        allNiveaux: _allNiveaux,
        allSections: _allSections,
        allClasses: _allClasses,
        onStudentSelected: (student) {
          Navigator.pop(context);
          _showCreatePaymentPlanForStudent(student);
        },
      ),
    );
  }

  void _showPaymentPlanCreationDialog({
    required String studentId,
    required String studentName,
    required String enrollmentId,
    required String className,
  }) {
    showDialog(
      context: context,
      builder: (context) => _CreatePaymentPlanDialog(
        studentId: studentId,
        studentName: studentName,
        enrollmentId: enrollmentId,
        className: className,
        onCreated: () {
          ref.read(paymentsProvider.notifier).refresh();
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LEFT PANEL - FILTERS
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // FILTER PANEL — Overlay drawer (right-side, grade_levels pattern)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFilterPanel(BuildContext context, PaymentsState state) {
    final dateFormat = DateFormat('dd/MM/yyyy');

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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  const Text('Filtres', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _showFilters = false),
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),

            // ─── Filter body ───
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // STATUT
                    _filterLabel('Statut'),
                    const SizedBox(height: 8),
                    _buildFilterDropdown<String>(
                      value: state.statusFilter == 'all' ? null : state.statusFilter,
                      hint: 'Tous les statuts',
                      items: const [
                        DropdownMenuItem(
                          value: 'paid',
                          child: Row(children: [
                            Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Text('Payés'),
                          ]),
                        ),
                        DropdownMenuItem(
                          value: 'pending',
                          child: Row(children: [
                            Icon(Icons.access_time, size: 14, color: Color(0xFFF59E0B)),
                            SizedBox(width: 8),
                            Text('En attente'),
                          ]),
                        ),
                        DropdownMenuItem(
                          value: 'overdue',
                          child: Row(children: [
                            Icon(Icons.warning, size: 14, color: Color(0xFFEF4444)),
                            SizedBox(width: 8),
                            Text('En retard'),
                          ]),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Row(children: [
                            Icon(Icons.cancel, size: 14, color: Color(0xFF64748B)),
                            SizedBox(width: 8),
                            Text('Annulés'),
                          ]),
                        ),
                      ],
                      onChanged: (v) => ref
                          .read(paymentsProvider.notifier)
                          .setStatusFilter(v ?? 'all'),
                    ),

                    const SizedBox(height: 24),

                    // NIVEAU
                    _filterLabel('Niveau'),
                    const SizedBox(height: 8),
                    _buildFilterDropdown<String>(
                      value: _selectedNiveauId,
                      hint: 'Tous les niveaux',
                      items: _allNiveaux
                          .map((n) => DropdownMenuItem(
                                value: n['id']?.toString(),
                                child: Text(n['name']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedNiveauId = v;
                          _selectedSectionId = null;
                          _selectedClassId = null;
                        });
                        ref
                            .read(paymentsProvider.notifier)
                            .setClassFilter(null);
                      },
                    ),

                    // FILIÈRE (conditional)
                    if (_selectedNiveauId != null &&
                        _niveauHasSections) ...[
                      const SizedBox(height: 16),
                      _filterLabel('Filière'),
                      const SizedBox(height: 8),
                      _buildFilterDropdown<String>(
                        value: _selectedSectionId,
                        hint: 'Toutes les filières',
                        items: _sectionsForNiveau
                            .map((s) => DropdownMenuItem(
                                  value: s['id']?.toString(),
                                  child: Text(s['name']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedSectionId = v;
                            _selectedClassId = null;
                          });
                          ref
                              .read(paymentsProvider.notifier)
                              .setClassFilter(null);
                        },
                      ),
                    ],

                    // CLASSE (conditional)
                    if (_selectedNiveauId != null) ...[
                      const SizedBox(height: 16),
                      _filterLabel('Classe'),
                      const SizedBox(height: 8),
                      _buildFilterDropdown<String>(
                        value: _selectedClassId,
                        hint: 'Toutes les classes',
                        items: _filteredClasses
                            .map((c) => DropdownMenuItem(
                                  value: c['id']?.toString(),
                                  child: Text(c['name']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) {
                          setState(() => _selectedClassId = v);
                          ref.read(paymentsProvider.notifier).setClassFilter(v);
                        },
                      ),
                    ],

                    const SizedBox(height: 24),

                    // CATÉGORIE
                    _filterLabel('Catégorie'),
                    const SizedBox(height: 8),
                    _buildFilterDropdown<String>(
                      value: state.categoryFilter,
                      hint: 'Toutes les catégories',
                      items: [
                        ...PaymentCategory.values.map(
                          (c) => DropdownMenuItem(
                            value: c.label,
                            child: Text(
                              c.label,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) => ref
                          .read(paymentsProvider.notifier)
                          .setCategoryFilter(v),
                    ),

                    const SizedBox(height: 24),

                    // PÉRIODE
                    _filterLabel("Période d'échéance"),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                _selectDate(context, true, state),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.slate50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: AppColors.slate200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 14,
                                      color: AppColors.textTertiary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      state.dateFromFilter != null
                                          ? dateFormat
                                              .format(state.dateFromFilter!)
                                          : 'Du...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: state.dateFromFilter != null
                                            ? AppColors.textPrimary
                                            : AppColors.textTertiary,
                                      ),
                                    ),
                                  ),
                                  if (state.dateFromFilter != null)
                                    GestureDetector(
                                      onTap: () => ref
                                          .read(paymentsProvider.notifier)
                                          .setDateFromFilter(null),
                                      child: Icon(Icons.close,
                                          size: 14,
                                          color: AppColors.textTertiary),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                _selectDate(context, false, state),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.slate50,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: AppColors.slate200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 14,
                                      color: AppColors.textTertiary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      state.dateToFilter != null
                                          ? dateFormat
                                              .format(state.dateToFilter!)
                                          : 'Au...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: state.dateToFilter != null
                                            ? AppColors.textPrimary
                                            : AppColors.textTertiary,
                                      ),
                                    ),
                                  ),
                                  if (state.dateToFilter != null)
                                    GestureDetector(
                                      onTap: () => ref
                                          .read(paymentsProvider.notifier)
                                          .setDateToFilter(null),
                                      child: Icon(Icons.close,
                                          size: 14,
                                          color: AppColors.textTertiary),
                                    ),
                                ],
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

            // ─── Footer ───
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                        onPressed: _hasActiveFilters(state)
                            ? () {
                                ref.read(paymentsProvider.notifier).clearFilters();
                                setState(() {
                                  _selectedNiveauId = null;
                                  _selectedSectionId = null;
                                  _selectedClassId = null;
                                });
                              }
                            : null,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF374151),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
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
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _showFilters = false),
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
    );
  }

  Widget _filterLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.slate500,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        borderRadius: BorderRadius.circular(12),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
          isDense: true,
        ),
        hint: Text(hint, style: TextStyle(fontSize: 13, color: AppColors.slate400)),
        items: [
          DropdownMenuItem<T>(
            value: null,
            child: Text(hint, style: const TextStyle(fontSize: 13)),
          ),
          ...items,
        ],
        onChanged: (v) => onChanged(v),
        style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
        dropdownColor: Colors.white,
        icon: Icon(Icons.keyboard_arrow_down, color: AppColors.slate400, size: 18),
      ),
    );
  }






  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildClassFilter(PaymentsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Niveau dropdown
        const Text(
          'Niveau',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String?>(
            value: _selectedNiveauId,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
            hint: const Text(
              'Tous les niveaux',
              style: TextStyle(fontSize: 13),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Tous les niveaux'),
              ),
              ..._allNiveaux.map(
                (n) => DropdownMenuItem<String?>(
                  value: n['id']?.toString(),
                  child: Text(
                    n['name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
            onChanged: (v) {
              setState(() {
                _selectedNiveauId = v;
                _selectedSectionId = null;
                _selectedClassId = null;
              });
              ref.read(paymentsProvider.notifier).setClassFilter(null);
            },
          ),
        ),

        // Section (Filière) dropdown - only if niveau has sections
        if (_selectedNiveauId != null && _niveauHasSections) ...[
          const SizedBox(height: 12),
          const Text(
            'Filière',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonFormField<String?>(
              value: _selectedSectionId,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              hint: const Text(
                'Toutes les filières',
                style: TextStyle(fontSize: 13),
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Toutes les filières'),
                ),
                ..._sectionsForNiveau.map(
                  (s) => DropdownMenuItem<String?>(
                    value: s['id']?.toString(),
                    child: Text(
                      s['name']?.toString() ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedSectionId = v;
                  _selectedClassId = null;
                });
                ref.read(paymentsProvider.notifier).setClassFilter(null);
              },
            ),
          ),
        ],

        // Class dropdown - always show if niveau is selected
        if (_selectedNiveauId != null) ...[
          const SizedBox(height: 12),
          const Text(
            'Classe',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonFormField<String?>(
              value: _selectedClassId,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              hint: const Text(
                'Toutes les classes',
                style: TextStyle(fontSize: 13),
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Toutes les classes'),
                ),
                ..._filteredClasses.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c['id']?.toString(),
                    child: Text(
                      c['name']?.toString() ?? '',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
              onChanged: (v) {
                setState(() => _selectedClassId = v);
                ref.read(paymentsProvider.notifier).setClassFilter(v);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryFilter(PaymentsState state) {
    final categories = PaymentCategory.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Catégorie',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String?>(
            initialValue: state.categoryFilter,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
            hint: const Text(
              'Toutes les catégories',
              style: TextStyle(fontSize: 13),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Toutes les catégories'),
              ),
              ...categories.map(
                (c) => DropdownMenuItem<String?>(
                  value: c.label,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Color(c.colorValue),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(c.label, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
            onChanged: (v) =>
                ref.read(paymentsProvider.notifier).setCategoryFilter(v),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeFilter(PaymentsState state) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Période d\'échéance',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context, true, state),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.dateFromFilter != null
                              ? dateFormat.format(state.dateFromFilter!)
                              : 'Du...',
                          style: TextStyle(
                            fontSize: 12,
                            color: state.dateFromFilter != null
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                      if (state.dateFromFilter != null)
                        GestureDetector(
                          onTap: () => ref
                              .read(paymentsProvider.notifier)
                              .setDateFromFilter(null),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(context, false, state),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.dateToFilter != null
                              ? dateFormat.format(state.dateToFilter!)
                              : 'Au...',
                          style: TextStyle(
                            fontSize: 12,
                            color: state.dateToFilter != null
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                      if (state.dateToFilter != null)
                        GestureDetector(
                          onTap: () => ref
                              .read(paymentsProvider.notifier)
                              .setDateToFilter(null),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: AppColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _hasActiveFilters(PaymentsState state) {
    return state.statusFilter != 'all' ||
        state.classFilter != null ||
        state.categoryFilter != null ||
        state.dateFromFilter != null ||
        state.dateToFilter != null ||
        state.searchQuery.isNotEmpty;
  }

  Future<void> _selectDate(
    BuildContext context,
    bool isFrom,
    PaymentsState state,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (state.dateFromFilter ?? DateTime.now())
          : (state.dateToFilter ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      if (isFrom) {
        ref.read(paymentsProvider.notifier).setDateFromFilter(picked);
      } else {
        ref.read(paymentsProvider.notifier).setDateToFilter(picked);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAIN CONTENT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMainContent(BuildContext context, PaymentsState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          // ─── Tab bar (grade_levels style) ───
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.slate200)),
            ),
            child: Row(
              children: [
                TabBar(
                  controller: _viewTabController,
                  isScrollable: true,
                  labelColor: const Color(0xFF0F172A),
                  unselectedLabelColor: AppColors.slate500,
                  labelStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  unselectedLabelStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  indicatorColor: const Color(0xFF10B981),
                  indicatorWeight: 2,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: 'Liste'),
                    Tab(text: 'Par Étudiant'),
                    Tab(text: 'Statistiques'),
                  ],
                ),
                const Spacer(),
                // Select-all (visible in Liste tab)
                if (_viewTabController.index == 0 && state.filtered.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: Checkbox(
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            value: _selectedPayments.length ==
                                state.filtered
                                    .where(
                                        (p) => p.status != PaymentStatus.paid)
                                    .length,
                            tristate: true,
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selectedPayments = state.filtered
                                      .where(
                                          (p) => p.status != PaymentStatus.paid)
                                      .map((p) => p.id)
                                      .toSet();
                                } else {
                                  _selectedPayments.clear();
                                }
                              });
                            },
                            activeColor: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tout sélectionner',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                // Result count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${state.filtered.length} résultat(s)',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.slate600,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── Tab content ───
          Expanded(
            child: TabBarView(
              controller: _viewTabController,
              children: [
                _buildPaymentsList(context, state),
                _buildStudentsList(context, state),
                _buildStatisticsView(context, state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAYMENTS LIST VIEW
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPaymentsList(BuildContext context, PaymentsState state) {
    final payments = state.filtered;

    if (payments.isEmpty) {
      return _buildEmptyState(
        icon: Icons.payments_outlined,
        title: 'Aucun paiement trouvé',
        subtitle: 'Modifiez vos filtres ou ajoutez des paiements',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];
        return _buildPaymentCard(context, payment);
      },
    );
  }

  Widget _buildPaymentCard(BuildContext context, Payment payment) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final isOverdue = payment.isOverdue;
    final statusColor = isOverdue
        ? const Color(0xFFEF4444)
        : Color(payment.status.colorValue);
    final isSelected = _selectedPayments.contains(payment.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE9EAF2),
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent bar (status color)
              Container(width: 4, color: statusColor),

              // Card content
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showPaymentDetails(context, payment),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          // Checkbox (if not paid/cancelled)
                          if (payment.status != PaymentStatus.paid &&
                              payment.status != PaymentStatus.cancelled)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: Checkbox(
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  value: isSelected,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedPayments.add(payment.id);
                                      } else {
                                        _selectedPayments.remove(payment.id);
                                      }
                                    });
                                  },
                                  activeColor: const Color(0xFF10B981),
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 28),

                          // Status icon
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              payment.status == PaymentStatus.paid
                                  ? Icons.check_circle
                                  : (payment.status == PaymentStatus.cancelled
                                      ? Icons.cancel
                                      : (isOverdue
                                          ? Icons.warning_rounded
                                          : Icons.access_time)),
                              color: statusColor,
                              size: 22,
                            ),
                          ),

                          const SizedBox(width: 14),

                          // Payment info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        payment.studentName ?? 'Étudiant inconnu',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: Color(0xFF111827),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        isOverdue
                                            ? 'En retard'
                                            : payment.status.label,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(Icons.school_outlined,
                                        size: 13, color: AppColors.slate400),
                                    const SizedBox(width: 4),
                                    Text(
                                      payment.className ?? '-',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate500),
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      payment.category ?? '-',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate500),
                                    ),
                                    const SizedBox(width: 14),
                                    Icon(Icons.event_outlined,
                                        size: 13, color: AppColors.slate400),
                                    const SizedBox(width: 4),
                                    Text(
                                      dateFormat.format(payment.dueDate),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isOverdue
                                            ? const Color(0xFFEF4444)
                                            : AppColors.slate500,
                                        fontWeight: isOverdue
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                if (payment.paidAt != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline,
                                            size: 13,
                                            color: const Color(0xFF10B981)),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Payé le ${dateFormat.format(payment.paidAt!)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Amount
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '${payment.amount.toStringAsFixed(0)} TND',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),

                          // Actions popup
                          PopupMenuButton<String>(
                            onSelected: (value) =>
                                _handlePaymentAction(context, value, payment),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            offset: const Offset(0, 40),
                            itemBuilder: (context) => [
                              if (payment.status != PaymentStatus.paid)
                                PopupMenuItem(
                                  value: 'mark_paid',
                                  child: Row(children: [
                                    Icon(Icons.check_circle,
                                        color: const Color(0xFF10B981),
                                        size: 18),
                                    const SizedBox(width: 10),
                                    const Text('Marquer payé'),
                                  ]),
                                ),
                              PopupMenuItem(
                                value: 'view',
                                child: Row(children: [
                                  Icon(Icons.visibility,
                                      color: AppColors.slate500, size: 18),
                                  const SizedBox(width: 10),
                                  const Text('Voir les détails'),
                                ]),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit,
                                      color: const Color(0xFF3B82F6), size: 18),
                                  const SizedBox(width: 10),
                                  const Text('Modifier'),
                                ]),
                              ),
                              const PopupMenuDivider(),
                              if (payment.status != PaymentStatus.cancelled)
                                PopupMenuItem(
                                  value: 'cancel',
                                  child: Row(children: [
                                    Icon(Icons.cancel,
                                        color: const Color(0xFFF59E0B),
                                        size: 18),
                                    const SizedBox(width: 10),
                                    const Text('Annuler'),
                                  ]),
                                ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete_outline,
                                      color: const Color(0xFFEF4444), size: 18),
                                  const SizedBox(width: 10),
                                  const Text('Supprimer',
                                      style:
                                          TextStyle(color: Color(0xFFEF4444))),
                                ]),
                              ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.slate100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.more_vert,
                                  size: 18, color: AppColors.slate500),
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
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STUDENTS LIST VIEW
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStudentsList(BuildContext context, PaymentsState state) {
    final students = state.filteredStudents;

    if (students.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'Aucun étudiant trouvé',
        subtitle: 'Modifiez vos filtres pour voir les étudiants',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return _buildStudentCard(context, student);
      },
    );
  }

  Widget _buildStudentCard(
    BuildContext context,
    StudentPaymentSummary student,
  ) {
    final progress = student.progressPercent;
    final progressColor = progress >= 100
        ? const Color(0xFF10B981)
        : (progress >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9EAF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 4,
                color: progressColor,
              ),
              // Card content
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showStudentPaymentDetails(context, student),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          // Progress circle
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: progress / 100,
                                  backgroundColor:
                                      progressColor.withOpacity(0.12),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(progressColor),
                                  strokeWidth: 5,
                                ),
                                Text(
                                  '${progress.toInt()}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: progressColor,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Student info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      student.studentName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    if (student.overduePayments > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.warning_rounded,
                                                size: 11,
                                                color: Color(0xFFEF4444)),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${student.overduePayments} en retard',
                                              style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFFEF4444)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(Icons.school_outlined,
                                        size: 12, color: AppColors.slate400),
                                    const SizedBox(width: 4),
                                    Text(
                                      student.className ?? 'Classe non assignée',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.slate500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Amount chips row
                                Row(
                                  children: [
                                    _amountChip(
                                        '${student.totalAmount.toStringAsFixed(0)} TND',
                                        'Total',
                                        AppColors.slate400,
                                        AppColors.slate50),
                                    const SizedBox(width: 8),
                                    _amountChip(
                                        '${student.paidAmount.toStringAsFixed(0)} TND',
                                        'Payé',
                                        const Color(0xFF10B981),
                                        const Color(0xFF10B981)
                                            .withOpacity(0.08)),
                                    if (student.pendingAmount > 0) ...[
                                      const SizedBox(width: 8),
                                      _amountChip(
                                          '${student.pendingAmount.toStringAsFixed(0)} TND',
                                          'Reste',
                                          const Color(0xFFF59E0B),
                                          const Color(0xFFF59E0B)
                                              .withOpacity(0.08)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Paid/Total count
                          Padding(
                            padding: const EdgeInsets.only(left: 12, right: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        size: 14,
                                        color: const Color(0xFF10B981)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${student.paidPayments}/${student.totalPayments}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF10B981)),
                                    ),
                                  ],
                                ),
                                Text(
                                  'paiements',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.slate400),
                                ),
                                const SizedBox(height: 6),
                                // Quick reminder button
                                if (student.overduePayments > 0)
                                  GestureDetector(
                                    onTap: () => _sendReminder(student),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.send,
                                              size: 12,
                                              color: Color(0xFF3B82F6)),
                                          const SizedBox(width: 4),
                                          const Text('Rappel',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF3B82F6),
                                                  fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const Icon(Icons.chevron_right,
                              color: Color(0xFFCBD5E1), size: 20),
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

  Widget _amountChip(
      String value, String label, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 9, color: color.withOpacity(0.8))),
          Text(value,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STATISTICS VIEW
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStatisticsView(BuildContext context, PaymentsState state) {
    final collectionRate = state.totalDue > 0
        ? (state.totalCollected / state.totalDue * 100)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview Cards
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  'Taux de Recouvrement',
                  '${collectionRate.toStringAsFixed(1)}%',
                  Icons.trending_up,
                  const Color(0xFF10B981),
                  subtitle:
                      '${state.totalCollected.toStringAsFixed(0)} / ${state.totalDue.toStringAsFixed(0)} TND',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOverviewCard(
                  'Paiements en Retard',
                  '${state.overdueCount}',
                  Icons.warning,
                  const Color(0xFFEF4444),
                  subtitle:
                      '${state.totalOverdue.toStringAsFixed(0)} TND impayés',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOverviewCard(
                  'Étudiants à Jour',
                  '${state.studentSummaries.where((s) => s.overduePayments == 0).length}',
                  Icons.check_circle,
                  const Color(0xFF10B981),
                  subtitle: 'sur ${state.studentSummaries.length} étudiants',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOverviewCard(
                  'À Percevoir',
                  '${state.totalPending.toStringAsFixed(0)} TND',
                  Icons.schedule,
                  const Color(0xFFF59E0B),
                  subtitle: 'paiements en attente',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Charts row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment status distribution
              Expanded(
                flex: 1,
                child: _buildChartCard(
                  'Répartition par Statut',
                  _buildStatusPieChart(state),
                ),
              ),

              const SizedBox(width: 16),

              // Category breakdown
              Expanded(
                flex: 2,
                child: _buildChartCard(
                  'Paiements par Catégorie',
                  _buildCategoryBreakdown(state),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Top debtors
          _buildChartCard(
            'Étudiants avec Paiements en Retard',
            _buildDebtorsList(state),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildStatusPieChart(PaymentsState state) {
    final paid = state.payments
        .where((p) => p.status == PaymentStatus.paid)
        .length;
    final pending = state.payments
        .where((p) => p.status == PaymentStatus.pending && !p.isOverdue)
        .length;
    final overdue = state.payments.where((p) => p.isOverdue).length;
    final cancelled = state.payments
        .where((p) => p.status == PaymentStatus.cancelled)
        .length;
    final total = state.payments.length;

    if (total == 0) {
      return const Center(child: Text('Aucune donnée'));
    }

    return Row(
      children: [
        // Simple pie representation
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _SimplePieChartPainter(
              segments: [
                (paid / total, const Color(0xFF10B981)),
                (pending / total, const Color(0xFFF59E0B)),
                (overdue / total, const Color(0xFFEF4444)),
                (cancelled / total, const Color(0xFF64748B)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [
              _buildLegendItem('Payés', paid, const Color(0xFF10B981)),
              _buildLegendItem('En attente', pending, const Color(0xFFF59E0B)),
              _buildLegendItem('En retard', overdue, const Color(0xFFEF4444)),
              _buildLegendItem('Annulés', cancelled, const Color(0xFF64748B)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(PaymentsState state) {
    final categoryTotals = <String, double>{};
    for (final p in state.payments) {
      final cat = p.category ?? 'Autres';
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + p.amount;
    }

    if (categoryTotals.isEmpty) {
      return const Center(child: Text('Aucune donnée'));
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxAmount = sortedCategories.first.value;

    return Column(
      children: sortedCategories.map((entry) {
        final categoryEnum = PaymentCategory.values
            .cast<PaymentCategory?>()
            .firstWhere(
              (c) => c?.label == entry.key,
              orElse: () => PaymentCategory.autres,
            )!;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Color(categoryEnum.colorValue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(categoryEnum),
                  size: 16,
                  color: Color(categoryEnum.colorValue),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: entry.value / maxAmount,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Color(categoryEnum.colorValue),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: Text(
                  '${entry.value.toStringAsFixed(0)} TND',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getCategoryIcon(PaymentCategory category) {
    switch (category) {
      case PaymentCategory.scolarite:
        return Icons.school;
      case PaymentCategory.transport:
        return Icons.directions_bus;
      case PaymentCategory.inscription:
        return Icons.app_registration;
      case PaymentCategory.uniforme:
        return Icons.checkroom;
      case PaymentCategory.cantine:
        return Icons.restaurant;
      case PaymentCategory.activites:
        return Icons.sports_soccer;
      case PaymentCategory.autres:
        return Icons.more_horiz;
    }
  }

  Widget _buildDebtorsList(PaymentsState state) {
    final debtors =
        state.studentSummaries.where((s) => s.overduePayments > 0).toList()
          ..sort((a, b) => b.pendingAmount.compareTo(a.pendingAmount));

    if (debtors.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 24),
            const SizedBox(width: 8),
            Text(
              'Aucun paiement en retard ! 🎉',
              style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: debtors
          .take(5)
          .map(
            (student) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    name: student.studentName,
                    radius: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.studentName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          student.className ?? '-',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${student.pendingAmount.toStringAsFixed(0)} TND',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      Text(
                        '${student.overduePayments} en retard',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.email_outlined, size: 20),
                    color: const Color(0xFF64748B),
                    onPressed: () => _sendReminder(student),
                    tooltip: 'Envoyer un rappel',
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.slate200),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGS & ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  void _handlePaymentAction(
    BuildContext context,
    String action,
    Payment payment,
  ) {
    switch (action) {
      case 'mark_paid':
        _showMarkPaidDialog(context, payment);
        break;
      case 'edit':
        _showEditPaymentDialog(context, payment);
        break;
      case 'view':
        _showPaymentDetails(context, payment);
        break;
      case 'cancel':
        _confirmCancelPayment(context, payment);
        break;
      case 'delete':
        _confirmDeletePayment(context, payment);
        break;
    }
  }

  void _showMarkPaidDialog(BuildContext context, Payment payment) {
    String? selectedMethod;
    final referenceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marquer comme payé'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Montant: ${payment.amount.toStringAsFixed(0)} TND'),
            Text('Étudiant: ${payment.studentName ?? "-"}'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Mode de paiement',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Espèces')),
                DropdownMenuItem(
                  value: 'bank_transfer',
                  child: Text('Virement bancaire'),
                ),
                DropdownMenuItem(value: 'card', child: Text('Carte bancaire')),
                DropdownMenuItem(value: 'check', child: Text('Chèque')),
              ],
              onChanged: (v) => selectedMethod = v,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'Référence / Reçu (optionnel)',
                border: OutlineInputBorder(),
              ),
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
                    onPressed: () => Navigator.pop(context),
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
                      ref.read(paymentsProvider.notifier).markAsPaid(
                        payment.id,
                        method: selectedMethod,
                        reference: referenceController.text.isNotEmpty ? referenceController.text : null,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paiement marqué comme payé'), backgroundColor: Color(0xFF10B981)));
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.w700)),
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

  void _showBulkMarkPaidDialog(BuildContext context) {
    String? selectedMethod;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marquer les paiements comme payés'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_selectedPayments.length} paiements sélectionnés'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Mode de paiement',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Espèces')),
                DropdownMenuItem(
                  value: 'bank_transfer',
                  child: Text('Virement bancaire'),
                ),
                DropdownMenuItem(value: 'card', child: Text('Carte bancaire')),
                DropdownMenuItem(value: 'check', child: Text('Chèque')),
              ],
              onChanged: (v) => selectedMethod = v,
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
                    onPressed: () => Navigator.pop(context),
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
                      await ref.read(paymentsProvider.notifier).bulkMarkAsPaid(_selectedPayments.toList(), method: selectedMethod);
                      setState(() => _selectedPayments.clear());
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paiements marqués comme payés'), backgroundColor: Color(0xFF10B981)));
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.w700)),
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

  void _showEditPaymentDialog(BuildContext context, Payment payment) {
    final amountController = TextEditingController(
      text: payment.amount.toString(),
    );
    final notesController = TextEditingController(text: payment.notes ?? '');
    DateTime selectedDate = payment.dueDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier le paiement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Montant (TND)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date d\'échéance',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
                      onPressed: () => Navigator.pop(context),
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
                        ref.read(paymentsProvider.notifier).updatePayment(
                          id: payment.id,
                          amount: double.tryParse(amountController.text),
                          dueDate: selectedDate,
                          notes: notesController.text.isNotEmpty ? notesController.text : null,
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paiement modifié')));
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700)),
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
      ),
    );
  }

  void _showPaymentDetails(BuildContext context, Payment payment) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              payment.status == PaymentStatus.paid
                  ? Icons.check_circle
                  : Icons.schedule,
              color: Color(payment.status.colorValue),
            ),
            const SizedBox(width: 8),
            const Text('Détails du Paiement'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                'Montant',
                '${payment.amount.toStringAsFixed(0)} TND',
              ),
              _buildDetailRow('Statut', payment.status.label),
              _buildDetailRow('Étudiant', payment.studentName ?? '-'),
              _buildDetailRow('Classe', payment.className ?? '-'),
              _buildDetailRow('Catégorie', payment.category ?? '-'),
              _buildDetailRow(
                'Échéance',
                DateFormat('dd/MM/yyyy').format(payment.dueDate),
              ),
              if (payment.paidAt != null)
                _buildDetailRow('Payé le', dateFormat.format(payment.paidAt!)),
              if (payment.method != null)
                _buildDetailRow('Mode', payment.method!),
              if (payment.reference != null)
                _buildDetailRow('Référence', payment.reference!),
              if (payment.notes != null && payment.notes!.isNotEmpty)
                _buildDetailRow('Notes', payment.notes!),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmCancelPayment(BuildContext context, Payment payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le paiement ?'),
        content: Text(
          'Voulez-vous annuler le paiement de ${payment.amount.toStringAsFixed(0)} TND ?',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE8EAF0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Non', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(paymentsProvider.notifier).cancelPayment(payment.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paiement annulé')));
                    },
                    icon: const Icon(Icons.warning_outlined, size: 16),
                    label: const Text('Oui, annuler', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
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

  void _confirmDeletePayment(BuildContext context, Payment payment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le paiement ?'),
        content: Text(
          'Cette action est irréversible. Supprimer le paiement de ${payment.amount.toStringAsFixed(0)} TND ?',
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
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
                      ref.read(paymentsProvider.notifier).deletePayment(payment.id);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paiement supprimé'), backgroundColor: Color(0xFFEF4444)));
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

  void _showStudentPaymentDetails(
    BuildContext context,
    StudentPaymentSummary student,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          _StudentPaymentDetailDialog(student: student, ref: ref),
    );
  }

  void _sendReminder(StudentPaymentSummary student) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rappel envoyé à ${student.studentName}'),
        backgroundColor: const Color(0xFF3B82F6),
      ),
    );
  }

  void _handleExport(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export $format en cours...'),
        backgroundColor: const Color(0xFF3B82F6),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SIMPLE PIE CHART PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class _SimplePieChartPainter extends CustomPainter {
  final List<(double, Color)> segments;

  _SimplePieChartPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    double startAngle = -math.pi / 2;

    for (final segment in segments) {
      if (segment.$1 <= 0) continue;

      final sweepAngle = segment.$1 * 2 * math.pi;
      final paint = Paint()
        ..color = segment.$2
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Draw center hole for donut effect
    final holePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.5, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// MODERN STUDENT PAYMENT DETAIL DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class _StudentPaymentDetailDialog extends ConsumerStatefulWidget {
  final StudentPaymentSummary student;
  final WidgetRef ref;

  const _StudentPaymentDetailDialog({required this.student, required this.ref});

  @override
  ConsumerState<_StudentPaymentDetailDialog> createState() =>
      _StudentPaymentDetailDialogState();
}

class _StudentPaymentDetailDialogState
    extends ConsumerState<_StudentPaymentDetailDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _payments = [];
  List<Map<String, dynamic>> _paymentPlans = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStudentPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentPayments() async {
    try {
      final supabase = Supabase.instance.client;

      // Load payment plans with payments
      final plansResponse = await supabase
          .from('payment_plans')
          .select('''
            *,
            payments(*)
          ''')
          .eq('enrollment_id', widget.student.studentId)
          .order('created_at', ascending: false);

      // Load all payments for this student
      final paymentsResponse = await supabase
          .from('payments')
          .select('''
            *,
            payment_plans!inner(
              id,
              plan_type,
              category,
              enrollment_id
            )
          ''')
          .eq('payment_plans.enrollment_id', widget.student.studentId)
          .order('due_date', ascending: true);

      setState(() {
        _paymentPlans = List<Map<String, dynamic>>.from(plansResponse);
        _payments = List<Map<String, dynamic>>.from(paymentsResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading payments: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredPayments {
    if (_selectedCategory == 'all') return _payments;
    return _payments.where((p) {
      final plan = p['payment_plans'] as Map<String, dynamic>?;
      return plan?['category'] == _selectedCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 900,
        height: 700,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            _buildSummaryCards(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMonthlyTimelineView(),
                        _buildPaymentsListView(),
                        _buildPaymentPlansView(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF667EEA), const Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          UserAvatar(
            name: widget.student.studentName,
            radius: 30,
            backgroundColor: Colors.white.withOpacity(0.2),
            textColor: Colors.white,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.student.studentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        widget.student.className ?? 'Non assigné',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final isComplete = widget.student.progressPercent >= 100;
    final hasOverdue = widget.student.overduePayments > 0;

    Color bgColor;
    String text;
    IconData icon;

    if (isComplete) {
      bgColor = const Color(0xFF10B981);
      text = 'Soldé';
      icon = Icons.check_circle;
    } else if (hasOverdue) {
      bgColor = const Color(0xFFEF4444);
      text = '${widget.student.overduePayments} en retard';
      icon = Icons.warning_rounded;
    } else {
      bgColor = const Color(0xFFF59E0B);
      text = 'En cours';
      icon = Icons.access_time;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: AppColors.slate50,
      child: Row(
        children: [
          _buildSummaryCard(
            'Total',
            '${widget.student.totalAmount.toStringAsFixed(0)} TND',
            Icons.account_balance_wallet,
            const Color(0xFF3B82F6),
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Payé',
            '${widget.student.paidAmount.toStringAsFixed(0)} TND',
            Icons.check_circle,
            const Color(0xFF10B981),
          ),
          const SizedBox(width: 12),
          _buildSummaryCard(
            'Reste',
            '${widget.student.pendingAmount.toStringAsFixed(0)} TND',
            Icons.pending,
            const Color(0xFFF59E0B),
          ),
          const SizedBox(width: 12),
          _buildProgressCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: widget.student.progressPercent / 100,
                    strokeWidth: 4,
                    backgroundColor: AppColors.slate200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getProgressColor(widget.student.progressPercent),
                    ),
                  ),
                  Text(
                    '${widget.student.progressPercent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progression',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
                Text(
                  '${widget.student.paidPayments}/${widget.student.totalPayments} paiements',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 100) return const Color(0xFF10B981);
    if (progress >= 75) return const Color(0xFF3B82F6);
    if (progress >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.slate200)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF667EEA),
        unselectedLabelColor: AppColors.textTertiary,
        indicatorColor: const Color(0xFF667EEA),
        indicatorWeight: 3,
        tabs: const [
          Tab(
            icon: Icon(Icons.calendar_month, size: 20),
            text: 'Échéancier Mensuel',
          ),
          Tab(icon: Icon(Icons.list_alt, size: 20), text: 'Tous les Paiements'),
          Tab(icon: Icon(Icons.category, size: 20), text: 'Plans de Paiement'),
        ],
      ),
    );
  }

  Widget _buildMonthlyTimelineView() {
    // Group payments by month
    final Map<String, List<Map<String, dynamic>>> paymentsByMonth = {};

    for (final payment in _payments) {
      final dueDate = DateTime.tryParse(payment['due_date'] ?? '');
      if (dueDate != null) {
        final monthKey =
            '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}';
        paymentsByMonth.putIfAbsent(monthKey, () => []);
        paymentsByMonth[monthKey]!.add(payment);
      }
    }

    // Sort months
    final sortedMonths = paymentsByMonth.keys.toList()..sort();

    if (sortedMonths.isEmpty) {
      return _buildEmptyState('Aucun paiement programmé', Icons.calendar_today);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category filter
          _buildCategoryFilter(),
          const SizedBox(height: 20),
          // Monthly timeline
          ...sortedMonths.map((month) {
            final payments = paymentsByMonth[month]!;
            final date = DateTime.parse('$month-01');
            return _buildMonthSection(date, payments);
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = [
      ('all', 'Toutes', Icons.apps),
      ('scolarite', 'Scolarité', Icons.school),
      ('transport', 'Transport', Icons.directions_bus),
      ('cantine', 'Cantine', Icons.restaurant),
      ('activites', 'Activités', Icons.sports_soccer),
      ('autres', 'Autres', Icons.more_horiz),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.$3, size: 16),
                  const SizedBox(width: 6),
                  Text(cat.$2),
                ],
              ),
              selectedColor: const Color(0xFF667EEA).withOpacity(0.2),
              checkmarkColor: const Color(0xFF667EEA),
              onSelected: (_) => setState(() => _selectedCategory = cat.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthSection(
    DateTime date,
    List<Map<String, dynamic>> payments,
  ) {
    final monthNames = [
      '',
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];

    // Filter by category
    final filteredPayments = _selectedCategory == 'all'
        ? payments
        : payments.where((p) {
            final plan = p['payment_plans'] as Map<String, dynamic>?;
            return plan?['category'] == _selectedCategory;
          }).toList();

    if (filteredPayments.isEmpty) return const SizedBox.shrink();

    final totalMonth = filteredPayments.fold<double>(
      0,
      (sum, p) => sum + (p['amount'] as num? ?? 0).toDouble(),
    );
    final paidMonth = filteredPayments
        .where((p) => p['status'] == 'paid')
        .fold<double>(
          0,
          (sum, p) => sum + (p['amount'] as num? ?? 0).toDouble(),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667EEA).withOpacity(0.1),
                  Colors.white,
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: const Color(0xFF667EEA).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF667EEA),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Center(
                    child: Text(
                      date.month.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${monthNames[date.month]} ${date.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${filteredPayments.length} paiement(s) • $paidMonth / $totalMonth TND',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Progress indicator for month
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: paidMonth >= totalMonth
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    paidMonth >= totalMonth
                        ? 'Complet'
                        : '${((paidMonth / totalMonth) * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Payment cards
          ...filteredPayments.map(
            (payment) => _buildPaymentTimelineCard(payment),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTimelineCard(Map<String, dynamic> payment) {
    final status = payment['status'] ?? 'pending';
    final amount = (payment['amount'] as num? ?? 0).toDouble();
    final dueDate = DateTime.tryParse(payment['due_date'] ?? '');
    final paidAt = payment['paid_at'] != null
        ? DateTime.tryParse(payment['paid_at'])
        : null;
    final plan = payment['payment_plans'] as Map<String, dynamic>?;
    final category = plan?['category'] ?? 'scolarite';

    final isOverdue =
        status == 'pending' &&
        dueDate != null &&
        dueDate.isBefore(DateTime.now());
    final isPaid = status == 'paid';

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isPaid) {
      statusColor = const Color(0xFF10B981);
      statusIcon = Icons.check_circle;
      statusText = 'Payé';
    } else if (isOverdue) {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.warning_rounded;
      statusText = 'En retard';
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.access_time;
      statusText = 'En attente';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isPaid ? AppColors.slate200 : statusColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getCategoryColor(category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getCategoryIcon(category),
              color: _getCategoryColor(category),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getCategoryName(category),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dueDate != null
                      ? 'Échéance: ${dueDate.day}/${dueDate.month}/${dueDate.year}'
                      : 'Date non définie',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
                if (paidAt != null)
                  Text(
                    'Payé le: ${paidAt.day}/${paidAt.month}/${paidAt.year}',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${amount.toStringAsFixed(0)} TND',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isPaid ? AppColors.textTertiary : AppColors.textPrimary,
                  decoration: isPaid ? TextDecoration.lineThrough : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Actions
          if (!isPaid)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.textTertiary),
              onSelected: (action) => _handlePaymentAction(action, payment),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mark_paid',
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Color(0xFF10B981),
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text('Marquer payé'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Color(0xFF3B82F6), size: 18),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel, color: Color(0xFFEF4444), size: 18),
                      SizedBox(width: 8),
                      Text('Annuler'),
                    ],
                  ),
                ),
              ],
            ),
          if (isPaid)
            IconButton(
              onPressed: () => _showPaymentReceipt(payment),
              icon: Icon(Icons.receipt_long, color: AppColors.textTertiary),
              tooltip: 'Voir le reçu',
            ),
        ],
      ),
    );
  }

  void _handlePaymentAction(String action, Map<String, dynamic> payment) async {
    final paymentId = payment['id'];

    switch (action) {
      case 'mark_paid':
        await _markPaymentAsPaid(paymentId);
        break;
      case 'edit':
        await _showEditPaymentDialog(payment);
        break;
      case 'cancel':
        await _cancelPayment(paymentId);
        break;
    }
  }

  Future<void> _markPaymentAsPaid(String paymentId) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('payments')
          .update({
            'status': 'paid',
            'paid_at': DateTime.now().toIso8601String(),
          })
          .eq('id', paymentId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paiement marqué comme payé'),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      await _loadStudentPayments();
      ref.read(paymentsProvider.notifier).refresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _cancelPayment(String paymentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer l\'annulation'),
        content: const Text('Voulez-vous vraiment annuler ce paiement ?'),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE8EAF0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Non', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.warning_outlined, size: 16),
                    label: const Text('Oui, annuler', style: TextStyle(fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
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

    if (confirm != true) return;

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('payments')
          .update({'status': 'cancelled'})
          .eq('id', paymentId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paiement annulé'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );

      await _loadStudentPayments();
      ref.read(paymentsProvider.notifier).refresh();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showEditPaymentDialog(Map<String, dynamic> payment) async {
    final amountController = TextEditingController(
      text: (payment['amount'] as num? ?? 0).toString(),
    );
    final dueDate = DateTime.tryParse(payment['due_date'] ?? '');
    DateTime? selectedDate = dueDate;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier le paiement'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Montant (TND)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.textTertiary),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppColors.textTertiary),
                        const SizedBox(width: 12),
                        Text(
                          selectedDate != null
                              ? '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'
                              : 'Sélectionner une date',
                          style: TextStyle(
                            color: selectedDate != null
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
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
                        Navigator.pop(context, {
                          'amount': double.tryParse(amountController.text) ?? 0,
                          'due_date': selectedDate?.toIso8601String(),
                        });
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w700)),
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
      ),
    );

    if (result != null) {
      try {
        final supabase = Supabase.instance.client;
        await supabase
            .from('payments')
            .update({
              'amount': result['amount'],
              'due_date': result['due_date'],
            })
            .eq('id', payment['id']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement modifié'),
            backgroundColor: Color(0xFF3B82F6),
          ),
        );

        await _loadStudentPayments();
        ref.read(paymentsProvider.notifier).refresh();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showPaymentReceipt(Map<String, dynamic> payment) {
    final amount = (payment['amount'] as num? ?? 0).toDouble();
    final paidAt = payment['paid_at'] != null
        ? DateTime.tryParse(payment['paid_at'])
        : null;
    final reference = payment['reference'] ?? 'N/A';
    final method = payment['method'] ?? 'cash';
    final plan = payment['payment_plans'] as Map<String, dynamic>?;
    final category = plan?['category'] ?? 'scolarite';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            const Text('Reçu de Paiement'),
          ],
        ),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF10B981),
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Paiement Effectué',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '${amount.toStringAsFixed(0)} TND',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 28,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildReceiptRow('Étudiant', widget.student.studentName),
              _buildReceiptRow('Catégorie', _getCategoryName(category)),
              _buildReceiptRow('Méthode', _getPaymentMethodName(method)),
              _buildReceiptRow('Référence', reference),
              if (paidAt != null)
                _buildReceiptRow(
                  'Date',
                  '${paidAt.day}/${paidAt.month}/${paidAt.year}',
                ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE8EAF0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Impression en cours...')),
                      );
                    },
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Imprimer', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _buildReceiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textTertiary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash':
        return 'Espèces';
      case 'bank_transfer':
        return 'Virement bancaire';
      case 'check':
        return 'Chèque';
      case 'card':
        return 'Carte bancaire';
      default:
        return method;
    }
  }

  Widget _buildPaymentsListView() {
    if (_filteredPayments.isEmpty) {
      return _buildEmptyState('Aucun paiement trouvé', Icons.payments);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredPayments.length,
      itemBuilder: (context, index) =>
          _buildPaymentTimelineCard(_filteredPayments[index]),
    );
  }

  Widget _buildPaymentPlansView() {
    if (_paymentPlans.isEmpty) {
      return _buildEmptyState(
        'Aucun plan de paiement',
        Icons.account_balance_wallet,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _paymentPlans.length,
      itemBuilder: (context, index) =>
          _buildPaymentPlanCard(_paymentPlans[index]),
    );
  }

  Widget _buildPaymentPlanCard(Map<String, dynamic> plan) {
    final planType = plan['plan_type'] ?? 'monthly';
    final category = plan['category'] ?? 'scolarite';
    final totalAmount = (plan['amount_total'] as num? ?? 0).toDouble();
    final payments = List<Map<String, dynamic>>.from(plan['payments'] ?? []);
    final paidAmount = payments
        .where((p) => p['status'] == 'paid')
        .fold<double>(
          0,
          (sum, p) => sum + (p['amount'] as num? ?? 0).toDouble(),
        );
    final progress = totalAmount > 0 ? (paidAmount / totalAmount * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getCategoryColor(category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  _getCategoryIcon(category),
                  color: _getCategoryColor(category),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getCategoryName(category),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _getPlanTypeName(planType),
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${totalAmount.toStringAsFixed(0)} TND',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${payments.length} échéances',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${paidAmount.toStringAsFixed(0)} / ${totalAmount.toStringAsFixed(0)} TND',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                  ),
                  Text(
                    '${progress.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: _getProgressColor(progress),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 8,
                  backgroundColor: AppColors.slate200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getProgressColor(progress),
                  ),
                ),
              ),
            ],
          ),
          // Payment status badges
          if (payments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: payments.take(12).map((p) {
                final status = p['status'] ?? 'pending';
                final isPaid = status == 'paid';
                final isOverdue =
                    status == 'pending' &&
                    DateTime.tryParse(
                          p['due_date'] ?? '',
                        )?.isBefore(DateTime.now()) ==
                        true;

                return Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isPaid
                        ? const Color(0xFF10B981)
                        : (isOverdue
                              ? const Color(0xFFEF4444)
                              : AppColors.slate200),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaid
                        ? Icons.check
                        : (isOverdue ? Icons.priority_high : Icons.access_time),
                    color: Colors.white,
                    size: 16,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _getPlanTypeName(String planType) {
    switch (planType) {
      case 'monthly':
        return 'Paiement mensuel (9x)';
      case 'semester':
        return 'Paiement trimestriel (3x)';
      case 'annual':
        return 'Paiement annuel (1x)';
      default:
        return planType;
    }
  }

  Color _getCategoryColor(String category) {
    return const Color(0xFF64748B);
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'scolarite':
        return Icons.school;
      case 'transport':
        return Icons.directions_bus;
      case 'cantine':
        return Icons.restaurant;
      case 'inscription':
        return Icons.assignment;
      case 'uniforme':
        return Icons.checkroom;
      case 'activites':
        return Icons.sports_soccer;
      default:
        return Icons.more_horiz;
    }
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'scolarite':
        return 'Scolarité';
      case 'transport':
        return 'Transport';
      case 'cantine':
        return 'Cantine';
      case 'inscription':
        return 'Inscription';
      case 'uniforme':
        return 'Uniforme';
      case 'activites':
        return 'Activités';
      default:
        return 'Autres';
    }
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.slate200),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SELECT STUDENT DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class _SelectStudentForPaymentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allStudents;
  final List<Map<String, dynamic>> allNiveaux;
  final List<Map<String, dynamic>> allSections;
  final List<Map<String, dynamic>> allClasses;
  final Function(Map<String, dynamic>) onStudentSelected;

  const _SelectStudentForPaymentDialog({
    required this.allStudents,
    required this.allNiveaux,
    required this.allSections,
    required this.allClasses,
    required this.onStudentSelected,
  });

  @override
  State<_SelectStudentForPaymentDialog> createState() =>
      _SelectStudentForPaymentDialogState();
}

class _SelectStudentForPaymentDialogState
    extends State<_SelectStudentForPaymentDialog> {
  final _searchController = TextEditingController();
  String? _selectedNiveauId;
  String? _selectedSectionId;
  String? _selectedClassId;

  List<Map<String, dynamic>> get _sectionsForNiveau {
    if (_selectedNiveauId == null) return [];
    return widget.allSections
        .where((s) => s['niveau_id'] == _selectedNiveauId)
        .toList();
  }

  bool get _niveauHasSections => _sectionsForNiveau.isNotEmpty;

  List<Map<String, dynamic>> get _filteredClasses {
    if (_selectedNiveauId == null) return widget.allClasses;
    return widget.allClasses.where((c) {
      if (c['niveau_id'] != _selectedNiveauId) return false;
      if (_niveauHasSections && _selectedSectionId != null) {
        return c['section_id'] == _selectedSectionId;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredStudents {
    final query = _searchController.text.toLowerCase();

    return widget.allStudents.where((s) {
      // Search filter
      if (query.isNotEmpty) {
        final name = (s['full_name'] ?? '').toString().toLowerCase();
        final email = (s['email'] ?? '').toString().toLowerCase();
        final phone = (s['phone'] ?? '').toString().toLowerCase();
        if (!name.contains(query) &&
            !email.contains(query) &&
            !phone.contains(query)) {
          return false;
        }
      }

      // Get enrollment info
      final enrollments = s['enrollments'] as List?;

      // If hierarchy filter is applied, filter by class
      if (_selectedClassId != null || _selectedNiveauId != null) {
        if (enrollments == null || enrollments.isEmpty) return false;

        final enrollment = enrollments.first as Map<String, dynamic>;
        final classData = enrollment['classes'] as Map<String, dynamic>?;

        if (_selectedClassId != null) {
          return enrollment['class_id'] == _selectedClassId ||
              classData?['id'] == _selectedClassId;
        }

        if (_selectedNiveauId != null) {
          if (classData?['niveau_id'] != _selectedNiveauId) return false;
          if (_niveauHasSections && _selectedSectionId != null) {
            return classData?['section_id'] == _selectedSectionId;
          }
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 700,
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sélectionner un élève',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Choisissez un élève pour créer un plan de paiement',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.slate50,
              child: Column(
                children: [
                  // Search bar
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par nom, email, téléphone...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide(color: AppColors.slate200),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Hierarchical dropdowns
                  Row(
                    children: [
                      // Niveau
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _selectedNiveauId,
                          decoration: InputDecoration(
                            labelText: 'Niveau',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Tous'),
                            ),
                            ...widget.allNiveaux.map(
                              (n) => DropdownMenuItem(
                                value: n['id']?.toString(),
                                child: Text(
                                  n['name']?.toString() ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            _selectedNiveauId = v;
                            _selectedSectionId = null;
                            _selectedClassId = null;
                          }),
                        ),
                      ),

                      // Section (if applicable)
                      if (_selectedNiveauId != null && _niveauHasSections) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _selectedSectionId,
                            decoration: InputDecoration(
                              labelText: 'Filière',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Toutes'),
                              ),
                              ..._sectionsForNiveau.map(
                                (s) => DropdownMenuItem(
                                  value: s['id']?.toString(),
                                  child: Text(
                                    s['name']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() {
                              _selectedSectionId = v;
                              _selectedClassId = null;
                            }),
                          ),
                        ),
                      ],

                      // Class
                      if (_selectedNiveauId != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _selectedClassId,
                            decoration: InputDecoration(
                              labelText: 'Classe',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Toutes'),
                              ),
                              ..._filteredClasses.map(
                                (c) => DropdownMenuItem(
                                  value: c['id']?.toString(),
                                  child: Text(
                                    c['name']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedClassId = v),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Students list
            Expanded(
              child: _filteredStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: AppColors.slate200,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun élève trouvé',
                            style: TextStyle(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        final enrollments = student['enrollments'] as List?;
                        final enrollment = enrollments?.isNotEmpty == true
                            ? enrollments!.first as Map<String, dynamic>
                            : null;
                        final classData =
                            enrollment?['classes'] as Map<String, dynamic>?;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: UserAvatar(
                              name: student['full_name'] ?? '?',
                              radius: 20,
                            ),
                            title: Text(
                              student['full_name'] ?? 'Sans nom',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${classData?['name'] ?? 'Pas de classe'} • ${student['email'] ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                            trailing: FilledButton.icon(
                              onPressed: () =>
                                  widget.onStudentSelected(student),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Sélectionner'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                            ),
                            onTap: () => widget.onStudentSelected(student),
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                border: Border(top: BorderSide(color: AppColors.slate200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredStudents.length} élève(s) trouvé(s)',
                    style: TextStyle(color: AppColors.textTertiary),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CREATE PAYMENT PLAN DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class _CreatePaymentPlanDialog extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String enrollmentId;
  final String className;
  final VoidCallback onCreated;

  const _CreatePaymentPlanDialog({
    required this.studentId,
    required this.studentName,
    required this.enrollmentId,
    required this.className,
    required this.onCreated,
  });

  @override
  State<_CreatePaymentPlanDialog> createState() =>
      _CreatePaymentPlanDialogState();
}

class _CreatePaymentPlanDialogState extends State<_CreatePaymentPlanDialog> {
  String _selectedCategory = 'scolarite';
  String _selectedPlanType = 'monthly';
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  DateTime _startDate = DateTime.now();

  final _categories = [
    ('scolarite', 'Scolarité', Icons.school, const Color(0xFF3B82F6)),
    ('transport', 'Transport', Icons.directions_bus, const Color(0xFF10B981)),
    ('cantine', 'Cantine', Icons.restaurant, const Color(0xFFF59E0B)),
    ('inscription', 'Inscription', Icons.assignment, const Color(0xFF8B5CF6)),
    ('uniforme', 'Uniforme', Icons.checkroom, const Color(0xFFEC4899)),
    ('activites', 'Activités', Icons.sports_soccer, const Color(0xFF14B8A6)),
    ('autres', 'Autres', Icons.more_horiz, const Color(0xFF6B7280)),
  ];

  final _planTypes = [
    ('monthly', 'Mensuel (9 paiements)', 9),
    ('semester', 'Trimestriel (3 paiements)', 3),
    ('annual', 'Annuel (1 paiement)', 1),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 550,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.92),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  UserAvatar(
                    name: widget.studentName,
                    radius: 25,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    textColor: Colors.white,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nouveau Plan de Paiement',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${widget.studentName} • ${widget.className}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form - wrapped in Expanded + SingleChildScrollView
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category selection
                    const Text(
                      'Catégorie',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _selectedCategory == cat.$1;
                        return FilterChip(
                          selected: isSelected,
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat.$3,
                                size: 16,
                                color: isSelected ? Colors.white : cat.$4,
                              ),
                              const SizedBox(width: 6),
                              Text(cat.$2),
                            ],
                          ),
                          selectedColor: cat.$4,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                          onSelected: (_) =>
                              setState(() => _selectedCategory = cat.$1),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // Plan type
                    const Text(
                      'Type de paiement',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...(_planTypes.map(
                      (pt) => RadioListTile<String>(
                        value: pt.$1,
                        groupValue: _selectedPlanType,
                        onChanged: (v) => setState(() => _selectedPlanType = v!),
                        title: Text(pt.$2),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )),

                    const SizedBox(height: 16),

                    // Amount
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Montant total (TND)',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        helperText: _selectedPlanType == 'monthly'
                            ? 'Sera divisé en 9 paiements mensuels'
                            : _selectedPlanType == 'semester'
                            ? 'Sera divisé en 3 paiements trimestriels'
                            : 'Un seul paiement',
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Start date
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() => _startDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.textTertiary),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: AppColors.textTertiary),
                            const SizedBox(width: 12),
                            Text(
                              'Date de début: ${_startDate.day}/${_startDate.month}/${_startDate.year}',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Description
                    TextField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description (optionnel)',
                        prefixIcon: const Icon(Icons.notes),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _createPaymentPlan,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Créer le plan'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
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

  Future<void> _createPaymentPlan() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer un montant valide'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // Create payment plan
      final planResult = await supabase
          .from('payment_plans')
          .insert({
            'enrollment_id': widget.enrollmentId,
            'plan_type': _selectedPlanType,
            'amount_total': amount,
            'currency': 'TND',
            'description': _descriptionController.text.isNotEmpty
                ? _descriptionController.text
                : _getCategoryLabel(_selectedCategory),
            'category': _selectedCategory,
          })
          .select()
          .single();

      final planId = planResult['id'];

      // Create individual payments based on plan type
      final numPayments = _planTypes
          .firstWhere((pt) => pt.$1 == _selectedPlanType)
          .$3;
      final paymentAmount = amount / numPayments;

      final payments = <Map<String, dynamic>>[];
      for (int i = 0; i < numPayments; i++) {
        DateTime dueDate;
        if (_selectedPlanType == 'monthly') {
          dueDate = DateTime(_startDate.year, _startDate.month + i, 1);
        } else if (_selectedPlanType == 'semester') {
          dueDate = DateTime(_startDate.year, _startDate.month + (i * 3), 1);
        } else {
          dueDate = _startDate;
        }

        payments.add({
          'payment_plan_id': planId,
          'amount': paymentAmount,
          'due_date': dueDate.toIso8601String(),
          'status': 'pending',
        });
      }

      await supabase.from('payments').insert(payments);

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan de paiement créé pour ${widget.studentName}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getCategoryLabel(String category) {
    return _categories
        .firstWhere(
          (c) => c.$1 == category,
          orElse: () => ('', 'Autres', Icons.more_horiz, AppColors.textTertiary),
        )
        .$2;
  }
}
