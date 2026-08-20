import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/payments_provider.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/ios_loader.dart';
import '../../widgets/user_avatar.dart';
import '../users/user_profile_screen.dart';

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
          .select('id, name, cycle, display_order')
          .order('display_order');

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
                          child: IosLoader(color: Color(0xFF10B981)),
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

          const SizedBox(width: 8),

          // Pricing configuration button
          _buildHeaderIconButton(
            icon: Icons.price_change_outlined,
            tooltip: 'Tarification',
            onPressed: () => _showPricingConfigDialog(context),
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
      niveauId: classData?['niveau_id']?.toString(),
      sectionId: classData?['section_id']?.toString(),
    );
  }

  void _showAddPaymentPlanDialog(BuildContext screenContext) {
    _showBlurredDialog(
      context: screenContext,
      child: _SelectStudentForPaymentDialog(
        allStudents: _allStudents,
        allNiveaux: _allNiveaux,
        allSections: _allSections,
        allClasses: _allClasses,
        onStudentSelected: (student) {
          Navigator.pop(screenContext);
          _showCreatePaymentPlanForStudent(student);
        },
        onStudentProfile: (student) {
          final studentId = student['id']?.toString();
          if (studentId == null) return;
          _showBlurredDialog(
            context: screenContext,
            child: UserProfileScreen(
              userId: studentId,
              userName: student['full_name']?.toString(),
              isDialogMode: true,
              onBack: () => Navigator.pop(screenContext),
            ),
          );
        },
      ),
    );
  }

  void _showPricingConfigDialog(BuildContext context) {
    _showBlurredDialog(
      context: context,
      child: _PaymentPricingDialog(
        allNiveaux: _allNiveaux,
        allSections: _allSections,
        allClasses: _allClasses,
      ),
    );
  }

  Future<T?> _showBlurredDialog<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              color: Colors.black.withOpacity(0.3),
              width: double.infinity,
              height: double.infinity,
              child: Material(
                type: MaterialType.transparency,
                child: SafeArea(
                  child: Center(
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPaymentPlanCreationDialog({
    required String studentId,
    required String studentName,
    required String enrollmentId,
    required String className,
    String? niveauId,
    String? sectionId,
  }) {
    _showBlurredDialog(
      context: context,
      child: _CreatePaymentPlanDialog(
        studentId: studentId,
        studentName: studentName,
        enrollmentId: enrollmentId,
        className: className,
        niveauId: niveauId,
        sectionId: sectionId,
        onCreated: () {
          Navigator.pop(context);
          ref.invalidate(paymentsProvider);
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
    final referenceController = TextEditingController(
      text: 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 10)}',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Marquer comme payé'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slate50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Montant: ${payment.amount.toStringAsFixed(0)} TND',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Étudiant: ${payment.studentName ?? "-"}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Mode de paiement',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.slate200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF10B981)),
                ),
              ),
              borderRadius: BorderRadius.circular(14),
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
              decoration: InputDecoration(
                labelText: 'Référence / Reçu',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.slate200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF10B981)),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    referenceController.text =
                        'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 10)}';
                  },
                  tooltip: 'Générer nouvelle référence',
                ),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                  ? const Center(child: IosLoader())
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
  final Function(Map<String, dynamic>)? onStudentProfile;

  const _SelectStudentForPaymentDialog({
    required this.allStudents,
    required this.allNiveaux,
    required this.allSections,
    required this.allClasses,
    required this.onStudentSelected,
    this.onStudentProfile,
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
  final GlobalKey _filterIconKey = GlobalKey();

  static const Color _brand = Color(0xFF6D4CF6);
  static const Color _brandLight = Color(0xFFF3E8FF);

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

      final enrollments = s['enrollments'] as List?;

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
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToStudentProfile(Map<String, dynamic> student) {
    if (widget.onStudentProfile != null) {
      widget.onStudentProfile!(student);
    } else {
      final studentId = student['id']?.toString();
      if (studentId == null) return;
      Navigator.pop(context);
      context.push('/users/$studentId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 680,
      height: 640,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
          children: [
            // ── Header ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.slate200)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _brandLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_search_rounded, color: _brand, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sélectionner un élève',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choisissez un élève pour créer un plan de paiement',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Close button - borderless
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.close, size: 20, color: AppColors.textTertiary),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search Bar with Filter Icon ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par nom, email ou téléphone...',
                        hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                        prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textTertiary),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchController.text.isNotEmpty)
                              InkWell(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(Icons.close, size: 16, color: AppColors.textTertiary),
                                ),
                              ),
                            // Filter icon for niveau selection
                            InkWell(
                              key: _filterIconKey,
                              onTap: () => _showNiveauFilter(context),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 18,
                                      color: _selectedNiveauId != null
                                          ? _brand
                                          : AppColors.textTertiary,
                                    ),
                                    if (_selectedNiveauId != null) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: _brand,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        filled: true,
                        fillColor: AppColors.slate50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.slate200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.slate200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _brand, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Active filter chips ──
            if (_selectedNiveauId != null || _selectedClassId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Row(
                  children: [
                    if (_selectedNiveauId != null)
                      _buildFilterChip(
                        _getNiveauName(_selectedNiveauId!),
                        () => setState(() {
                          _selectedNiveauId = null;
                          _selectedSectionId = null;
                          _selectedClassId = null;
                        }),
                      ),
                    if (_selectedClassId != null) ...[
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        _getClassName(_selectedClassId!),
                        () => setState(() => _selectedClassId = null),
                      ),
                    ],
                  ],
                ),
              ),

            // ── Students List ──
            Expanded(
              child: _filteredStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 56, color: AppColors.slate200),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun élève trouvé',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Modifiez vos filtres pour voir les résultats',
                            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        final enrollments = student['enrollments'] as List?;
                        final enrollment = enrollments?.isNotEmpty == true
                            ? enrollments!.first as Map<String, dynamic>
                            : null;
                        final classData = enrollment?['classes'] as Map<String, dynamic>?;

                        return _buildStudentRow(student, classData);
                      },
                    ),
            ),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.slate200)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.slate100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_filteredStudents.length} élève(s)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Annuler button - styled like "Ajouter un niveau" button
                  SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        shadowColor: _brand.withOpacity(0.3),
                      ),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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

  void _showNiveauFilter(BuildContext context) {
    final RenderBox renderBox = _filterIconKey.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx - 280 + size.width,
        position.dy + size.height + 8,
        position.dx,
        position.dy + size.height + 400,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.15),
      constraints: const BoxConstraints(
        minWidth: 280,
        maxWidth: 280,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          padding: EdgeInsets.zero,
          child: StatefulBuilder(
            builder: (ctx, setMenuState) {
              return Container(
                width: 280,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 18, color: _brand),
                          const SizedBox(width: 8),
                          const Text(
                            'Filtrer par niveau',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Niveau options
                    _buildNiveauOption(null, 'Tous les niveaux', ctx),
                    ...widget.allNiveaux.map(
                      (n) => _buildNiveauOption(
                        n['id']?.toString(),
                        n['name']?.toString() ?? '',
                        ctx,
                      ),
                    ),
                    // Class filter (if niveau selected)
                    if (_selectedNiveauId != null && _filteredClasses.isNotEmpty) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.class_outlined, size: 16, color: AppColors.textTertiary),
                            const SizedBox(width: 8),
                            Text(
                              'Filtrer par classe',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildClassOption(null, 'Toutes les classes', ctx),
                      ..._filteredClasses.map(
                        (c) => _buildClassOption(
                          c['id']?.toString(),
                          c['name']?.toString() ?? '',
                          ctx,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNiveauOption(String? id, String label, BuildContext menuContext) {
    final isSelected = _selectedNiveauId == id;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedNiveauId = id;
          _selectedSectionId = null;
          _selectedClassId = null;
        });
        Navigator.pop(menuContext);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? _brandLight : Colors.transparent,
        child: Row(
          children: [
            Icon(
              Icons.school_outlined,
              size: 18,
              color: isSelected ? _brand : AppColors.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? _brand : const Color(0xFF374151),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 18, color: _brand),
          ],
        ),
      ),
    );
  }

  Widget _buildClassOption(String? id, String label, BuildContext menuContext) {
    final isSelected = _selectedClassId == id;
    return InkWell(
      onTap: () {
        setState(() => _selectedClassId = id);
        Navigator.pop(menuContext);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? _brandLight : Colors.transparent,
        child: Row(
          children: [
            Icon(
              Icons.class_outlined,
              size: 16,
              color: isSelected ? _brand : AppColors.textTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? _brand : const Color(0xFF374151),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 16, color: _brand),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _brandLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _brand.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _brand,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(10),
            child: const Icon(Icons.close, size: 14, color: _brand),
          ),
        ],
      ),
    );
  }

  String _getNiveauName(String id) {
    final niveau = widget.allNiveaux.firstWhere(
      (n) => n['id']?.toString() == id,
      orElse: () => {'name': 'Niveau'},
    );
    return niveau['name']?.toString() ?? 'Niveau';
  }

  String _getClassName(String id) {
    final cls = widget.allClasses.firstWhere(
      (c) => c['id']?.toString() == id,
      orElse: () => {'name': 'Classe'},
    );
    return cls['name']?.toString() ?? 'Classe';
  }

  Widget _buildStudentRow(Map<String, dynamic> student, Map<String, dynamic>? classData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            // Avatar - clickable to go to profile
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _navigateToStudentProfile(student),
                child: UserAvatar(
                  name: student['full_name'] ?? '?',
                  radius: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Info - clickable to go to profile
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _navigateToStudentProfile(student),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['full_name'] ?? 'Sans nom',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.school_outlined, size: 13, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            classData?['name'] ?? 'Pas de classe',
                            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                          ),
                          if (student['email'] != null) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.email_outlined, size: 13, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                student['email'] ?? '',
                                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Select button - clickable
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => widget.onStudentSelected(student),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _brand,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: _brand.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Sélectionner',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
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

// ═══════════════════════════════════════════════════════════════════════════
// CREATE PAYMENT PLAN DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class _CreatePaymentPlanDialog extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String enrollmentId;
  final String className;
  final String? niveauId;
  final String? sectionId;
  final VoidCallback onCreated;

  const _CreatePaymentPlanDialog({
    required this.studentId,
    required this.studentName,
    required this.enrollmentId,
    required this.className,
    this.niveauId,
    this.sectionId,
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
  bool _isLoadingPricing = true;
  DateTime _startDate = DateTime.now();

  // Dynamic plan counts from academic year
  int _monthCount = 9;
  int _semesterCount = 3;

  static const Color _brand = Color(0xFF6D4CF6);
  static const Color _brandLight = Color(0xFFF3E8FF);

  final _categories = const [
    ('scolarite', 'Scolarité', Icons.school, Color(0xFF3B82F6)),
    ('transport', 'Transport', Icons.directions_bus, Color(0xFF10B981)),
    ('cantine', 'Cantine', Icons.restaurant, Color(0xFFF59E0B)),
    ('inscription', 'Inscription', Icons.assignment, Color(0xFF8B5CF6)),
    ('uniforme', 'Uniforme', Icons.checkroom, Color(0xFFEC4899)),
    ('activites', 'Activités', Icons.sports_soccer, Color(0xFF14B8A6)),
    ('autres', 'Autres', Icons.more_horiz, Color(0xFF6B7280)),
  ];

  final _planTypes = [
    ('monthly', 'Mensuel', 9),
    ('semester', 'Trimestriel', 3),
    ('annual', 'Annuel', 1),
  ];

  @override
  void initState() {
    super.initState();
    _loadAcademicYearAndPricing();
  }

  Future<void> _loadAcademicYearAndPricing() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userData = await supabase
          .from('users')
          .select('school_id')
          .eq('id', user.id)
          .single();
      final schoolId = userData['school_id']?.toString();

      if (schoolId != null) {
        // Load current academic year, fallback to most recent
        var yearData = await supabase
            .from('academic_years')
            .select('id, start_date, end_date')
            .eq('school_id', schoolId)
            .eq('is_current', true)
            .maybeSingle();

        yearData ??= await supabase
            .from('academic_years')
            .select('id, start_date, end_date')
            .eq('school_id', schoolId)
            .order('start_date', ascending: false)
            .limit(1)
            .maybeSingle();

        if (yearData != null) {
          final start = DateTime.tryParse(yearData['start_date'].toString());
          final end = DateTime.tryParse(yearData['end_date'].toString());
          if (start != null && end != null && end.isAfter(start)) {
            _monthCount = (end.year - start.year) * 12 + (end.month - start.month) + 1;
          }

          // Count semesters directly from the academic year
          final semesterResp = await supabase
              .from('semesters')
              .select('id')
              .eq('academic_year_id', yearData['id'].toString());
          _semesterCount = semesterResp.length;
        }

        if (_semesterCount <= 0) {
          final semesterCount = await supabase.rpc(
            'get_current_academic_year_semester_count',
            params: {'p_school_id': schoolId},
          );
          if (semesterCount != null) {
            _semesterCount = (semesterCount as num).toInt();
          }
        }
        if (_semesterCount <= 0) _semesterCount = 3;
        if (_monthCount <= 0) _monthCount = 9;

        // Load pricing for scolarite if niveauId available
        if (widget.niveauId != null) {
          final pricing = await supabase.rpc(
            'get_payment_pricing_for_enrollment',
            params: {
              'p_enrollment_id': widget.enrollmentId,
              'p_category': 'scolarite',
            },
          );
          if (pricing != null && (pricing as List).isNotEmpty) {
            final amount = (pricing.first['amount'] as num?)?.toDouble();
            if (amount != null && amount > 0) {
              _amountController.text = amount.toStringAsFixed(0);
            }
          } else {
            // Fallback: try by niveau/section directly for scolarite
            final query = supabase
                .from('payment_pricing')
                .select('amount')
                .eq('school_id', schoolId)
                .eq('category', 'scolarite')
                .eq('niveau_id', widget.niveauId!);

            final pricingData = widget.sectionId == null
                ? await query.isFilter('section_id', null).limit(1)
                : await query.eq('section_id', widget.sectionId!).limit(1);

            if (pricingData.isNotEmpty) {
              final amount = (pricingData.first['amount'] as num?)?.toDouble();
              if (amount != null && amount > 0) {
                _amountController.text = amount.toStringAsFixed(0);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading academic year/pricing: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPricing = false);
    }
  }

  List<(String, String, int)> get _dynamicPlanTypes {
    return [
      ('monthly', 'Mensuel ($_monthCount paiements)', _monthCount),
      ('semester', 'Trimestriel ($_semesterCount paiements)', _semesterCount),
      ('annual', 'Annuel (1 paiement)', 1),
    ];
  }

  bool get _isScolarite => _selectedCategory == 'scolarite';

  void _onCategoryChanged(String category) {
    setState(() {
      _selectedCategory = category;
      if (!_isScolarite) {
        _selectedPlanType = 'annual';
      } else if (!['monthly', 'semester', 'annual'].contains(_selectedPlanType)) {
        _selectedPlanType = 'monthly';
      }
    });
    _loadPricingForCategory(category);
  }

  Future<void> _loadPricingForCategory(String category) async {
    if (widget.niveauId == null) return;
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userData = await supabase.from('users').select('school_id').eq('id', user.id).single();
      final schoolId = userData['school_id']?.toString();
      if (schoolId == null) return;

      final pricing = await supabase.rpc(
        'get_payment_pricing_for_enrollment',
        params: {
          'p_enrollment_id': widget.enrollmentId,
          'p_category': category,
        },
      );
      if (pricing != null && (pricing as List).isNotEmpty) {
        final amount = (pricing.first['amount'] as num?)?.toDouble();
        if (amount != null && amount > 0) {
          _amountController.text = amount.toStringAsFixed(0);
        } else {
          _amountController.clear();
        }
      } else {
        _amountController.clear();
      }
    } catch (e) {
      debugPrint('Error loading category pricing: $e');
    }
  }

  double? get _currentAmount {
    final text = _amountController.text;
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  Widget _buildAmountPreview() {
    final amount = _currentAmount;
    if (amount == null || amount <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textTertiary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tarification non définie pour cette catégorie. Veuillez la configurer dans la page Tarification.',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      );
    }

    final planType = _isScolarite ? _selectedPlanType : 'annual';
    final plan = _dynamicPlanTypes.firstWhere(
      (pt) => pt.$1 == planType,
      orElse: () => ('annual', 'Annuel (1 paiement)', 1),
    );
    final count = plan.$3;
    final installment = amount / count;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_brand.withOpacity(0.08), _brand.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _brand.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.preview_outlined, color: _brand, size: 20),
              const SizedBox(width: 8),
              Text(
                'Montant à facturer',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _brand),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_formatCurrency(amount)} TND',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            count == 1
                ? '1 paiement unique de ${_formatCurrency(installment)} TND'
                : '$count paiements de ${_formatCurrency(installment)} TND',
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
          Text(
            'Ce montant sera visible par l\'élève dans l\'application.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,###.##', 'fr_FR');
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 620,
      height: 720,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header matching select-student dialog ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.slate200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _brandLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.payment_rounded, color: _brand, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nouveau Plan de Paiement',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.studentName} • ${widget.className}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button - borderless
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.close, size: 20, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),

          // ── Form ──
          Expanded(
            child: _isLoadingPricing
                ? const Center(child: IosLoader(color: _brand))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // Category selection
                  const Text(
                    'Catégorie',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
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
                          fontWeight: FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? cat.$4 : AppColors.slate200,
                          ),
                        ),
                        backgroundColor: Colors.white,
                        onSelected: (_) => _onCategoryChanged(cat.$1),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Plan type (only for scolarité)
                  if (_isScolarite) ...[
                    const Text(
                      'Type de paiement',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Column(
                        children: _dynamicPlanTypes.map((pt) {
                          final isSelected = _selectedPlanType == pt.$1;
                          return RadioListTile<String>(
                            value: pt.$1,
                            groupValue: _selectedPlanType,
                            onChanged: (v) => setState(() => _selectedPlanType = v!),
                            title: Text(
                              pt.$2,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? _brand : AppColors.textPrimary,
                              ),
                            ),
                            activeColor: _brand,
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Amount preview from pricing
                  _buildAmountPreview(),

                  const SizedBox(height: 20),

                  // Start date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: Theme.of(context).colorScheme.copyWith(
                              primary: _brand,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _startDate = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        border: Border.all(color: AppColors.slate200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: AppColors.textTertiary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date de début',
                                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.edit_calendar_outlined, color: _brand, size: 18),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Description
                  TextField(
                    controller: _descriptionController,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Description (optionnel)',
                      labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                      prefixIcon: const Icon(Icons.notes, size: 20),
                      filled: true,
                      fillColor: AppColors.slate50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.slate200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.slate200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _brand, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Footer matching select-student dialog ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.slate200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.slate100,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _createPaymentPlan,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: IosLoader.small(color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text(
                      'Créer le plan',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      shadowColor: const Color(0xFF10B981).withOpacity(0.3),
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

  Future<void> _createPaymentPlan() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarification non définie pour cette catégorie. Veuillez la configurer dans la page Tarification.'),
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
      final numPayments = _isScolarite
          ? _dynamicPlanTypes.firstWhere((pt) => pt.$1 == _selectedPlanType).$3
          : 1;
      final paymentAmount = amount / numPayments;

      final payments = <Map<String, dynamic>>[];
      for (int i = 0; i < numPayments; i++) {
        DateTime dueDate;
        if (_selectedPlanType == 'monthly' && _isScolarite) {
          dueDate = DateTime(_startDate.year, _startDate.month + i, 1);
        } else if (_selectedPlanType == 'semester' && _isScolarite) {
          // Distribute evenly based on semester count, starting from start date
          final monthsPerSemester = _monthCount / _semesterCount;
          dueDate = DateTime(_startDate.year, _startDate.month + (i * monthsPerSemester.ceil()), 1);
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

// ═══════════════════════════════════════════════════════════════════════════
// PAYMENT PRICING CONFIGURATION DIALOG
// ═══════════════════════════════════════════════════════════════════════════

class _PaymentPricingDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allNiveaux;
  final List<Map<String, dynamic>> allSections;
  final List<Map<String, dynamic>> allClasses;

  const _PaymentPricingDialog({
    required this.allNiveaux,
    required this.allSections,
    required this.allClasses,
  });

  @override
  State<_PaymentPricingDialog> createState() => _PaymentPricingDialogState();
}

class _PaymentPricingDialogState extends State<_PaymentPricingDialog> {
  String _selectedCategory = 'scolarite';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _schoolId;
  String? _academicYearId;

  // Map: niveauId -> { sectionId (null for niveau-level) -> amount }
  final Map<String, Map<String?, double>> _pricing = {};

  static const Color _brand = Color(0xFF6D4CF6);
  static const Color _brandLight = Color(0xFFF3E8FF);

  final _categories = const [
    ('scolarite', 'Scolarité', Icons.school, Color(0xFF3B82F6)),
    ('transport', 'Transport', Icons.directions_bus, Color(0xFF10B981)),
    ('cantine', 'Cantine', Icons.restaurant, Color(0xFFF59E0B)),
    ('inscription', 'Inscription', Icons.assignment, Color(0xFF8B5CF6)),
    ('uniforme', 'Uniforme', Icons.checkroom, Color(0xFFEC4899)),
    ('activites', 'Activités', Icons.sports_soccer, Color(0xFF14B8A6)),
    ('autres', 'Autres', Icons.more_horiz, Color(0xFF6B7280)),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  List<Map<String, dynamic>> get _sortedNiveaux {
    final sorted = List<Map<String, dynamic>>.from(widget.allNiveaux);
    sorted.sort((a, b) {
      // Put base cycle (primaire + collège) before secondaire (lycée)
      final cycleA = a['cycle']?.toString() ?? '';
      final cycleB = b['cycle']?.toString() ?? '';
      final cycleCompare = cycleA.compareTo(cycleB);
      if (cycleCompare != 0) return cycleCompare;

      // Then by display order
      final orderA = (a['display_order'] as num?)?.toInt() ?? 0;
      final orderB = (b['display_order'] as num?)?.toInt() ?? 0;
      return orderA.compareTo(orderB);
    });
    return sorted;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final userData = await supabase
          .from('users')
          .select('school_id')
          .eq('id', user.id)
          .single();
      _schoolId = userData['school_id']?.toString();

      if (_schoolId != null) {
        final yearData = await supabase
            .from('academic_years')
            .select('id')
            .eq('school_id', _schoolId!)
            .eq('is_current', true)
            .maybeSingle();
        _academicYearId = yearData?['id']?.toString();
      }

      await _loadPricing();
    } catch (e) {
      debugPrint('Error loading pricing data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPricing() async {
    if (_schoolId == null) return;
    try {
      final supabase = Supabase.instance.client;
      // Load all pricing rows for this category + school, then prefer current academic year
      final response = await supabase
          .from('payment_pricing')
          .select()
          .eq('school_id', _schoolId!)
          .eq('category', _selectedCategory);

      _pricing.clear();
      // First pass: rows with matching academic_year_id
      for (final row in response) {
        final yearId = row['academic_year_id']?.toString();
        if (yearId != null && yearId == _academicYearId) {
          final niveauId = row['niveau_id']?.toString();
          final sectionId = row['section_id']?.toString();
          final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
          if (niveauId != null) {
            _pricing.putIfAbsent(niveauId, () => {});
            _pricing[niveauId]![sectionId] = amount;
          }
        }
      }
      // Second pass: fallback to null academic_year_id only if no specific year row exists
      for (final row in response) {
        final yearId = row['academic_year_id']?.toString();
        if (yearId == null) {
          final niveauId = row['niveau_id']?.toString();
          final sectionId = row['section_id']?.toString();
          final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
          if (niveauId != null) {
            _pricing.putIfAbsent(niveauId, () => {});
            if (!_pricing[niveauId]!.containsKey(sectionId)) {
              _pricing[niveauId]![sectionId] = amount;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading pricing: $e');
    }
  }

  Future<void> _savePricing() async {
    if (_schoolId == null) return;
    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;

      for (final entry in _pricing.entries) {
        final niveauId = entry.key;
        for (final sectionEntry in entry.value.entries) {
          final sectionId = sectionEntry.key;
          final amount = sectionEntry.value;

          final query = supabase
              .from('payment_pricing')
              .select('id')
              .eq('school_id', _schoolId!)
              .eq('category', _selectedCategory)
              .eq('niveau_id', niveauId);

          final existing = sectionId == null
              ? await query.isFilter('section_id', null).maybeSingle()
              : await query.eq('section_id', sectionId!).maybeSingle();

          if (existing != null) {
            await supabase
                .from('payment_pricing')
                .update({'amount': amount, 'updated_at': DateTime.now().toIso8601String()})
                .eq('id', existing['id']);
          } else {
            await supabase.from('payment_pricing').insert({
              'school_id': _schoolId,
              'academic_year_id': _academicYearId,
              'category': _selectedCategory,
              'niveau_id': niveauId,
              'section_id': sectionId,
              'amount': amount,
            });
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarification enregistrée'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<Map<String, dynamic>> _sectionsForNiveau(String niveauId) {
    return widget.allSections
        .where((s) => s['niveau_id']?.toString() == niveauId)
        .toList();
  }

  bool _niveauHasSections(String niveauId) {
    return _sectionsForNiveau(niveauId).isNotEmpty;
  }

  double? _getAmount(String niveauId, String? sectionId) {
    return _pricing[niveauId]?[sectionId];
  }

  void _setAmount(String niveauId, String? sectionId, double? amount) {
    _pricing.putIfAbsent(niveauId, () => {});
    if (amount == null || amount <= 0) {
      _pricing[niveauId]!.remove(sectionId);
    } else {
      _pricing[niveauId]![sectionId] = amount;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 720,
      height: 760,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.slate200)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _brandLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.price_change_outlined, color: _brand, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tarification des paiements',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Définissez les montants par niveau et section',
                        style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(Icons.close, size: 20, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
          ),

          // Category selector
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat.$1;
                return FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.$3, size: 16, color: isSelected ? Colors.white : cat.$4),
                      const SizedBox(width: 6),
                      Text(cat.$2),
                    ],
                  ),
                  selectedColor: cat.$4,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: isSelected ? cat.$4 : AppColors.slate200),
                  ),
                  backgroundColor: Colors.white,
                  onSelected: (_) async {
                    _selectedCategory = cat.$1;
                    await _loadPricing();
                    if (mounted) setState(() {});
                  },
                );
              }).toList(),
            ),
          ),

          // Apply to all (non-scolarité)
          if (_selectedCategory != 'scolarite') ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: _showApplyToAllDialog,
                  icon: const Icon(Icons.copy_all, size: 16),
                  label: const Text('Appliquer un montant aux niveaux'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    shadowColor: _brand.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ],

          // Pricing list
          Expanded(
            child: _isLoading
                ? const Center(child: IosLoader(color: _brand))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    itemCount: _sortedNiveaux.length,
                    itemBuilder: (context, index) {
                      final niveau = _sortedNiveaux[index];
                      final niveauId = niveau['id']?.toString() ?? '';
                      final sections = _sectionsForNiveau(niveauId);
                      return _buildNiveauPricingCard(niveau, sections);
                    },
                  ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.slate200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.slate100,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _savePricing,
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: IosLoader.small(color: Colors.white))
                        : const Icon(Icons.save, size: 18),
                    label: const Text('Enregistrer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      shadowColor: _brand.withOpacity(0.3),
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

  Widget _buildNiveauPricingCard(Map<String, dynamic> niveau, List<Map<String, dynamic>> sections) {
    final niveauId = niveau['id']?.toString() ?? '';
    final hasSections = sections.isNotEmpty;
    final niveauAmount = _getAmount(niveauId, null);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        border: Border(
          bottom: BorderSide(color: AppColors.slate100),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    niveau['name']?.toString() ?? 'Niveau',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                if (!hasSections) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 160,
                    child: _buildAmountField(
                      initialValue: niveauAmount,
                      onChanged: (v) => _setAmount(niveauId, null, v),
                    ),
                  ),
                ],
              ],
            ),
            if (hasSections) ...[
              const SizedBox(height: 12),
              ...sections.map((section) {
                final sectionId = section['id']?.toString() ?? '';
                final amount = _getAmount(niveauId, sectionId);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.arrow_right, color: AppColors.textTertiary, size: 18),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          section['name']?.toString() ?? 'Section',
                          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: _buildAmountField(
                          initialValue: amount,
                          onChanged: (v) => _setAmount(niveauId, sectionId, v),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField({
    required double? initialValue,
    required ValueChanged<double?> onChanged,
  }) {
    final controller = TextEditingController(
      text: initialValue != null && initialValue > 0 ? initialValue.toStringAsFixed(0) : '',
    );
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 14),
      textAlign: TextAlign.end,
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: TextStyle(color: AppColors.textTertiary),
        suffixText: 'TND',
        suffixStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _brand, width: 1.5),
        ),
      ),
      onChanged: (v) {
        final amount = double.tryParse(v);
        onChanged(amount);
      },
    );
  }

  void _showApplyToAllDialog() {
    final selectedNiveaux = <String>{};
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Appliquer un montant',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Montant',
                      labelStyle: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                      prefixIcon: const Icon(Icons.attach_money, size: 20),
                      suffixText: 'TND',
                      filled: true,
                      fillColor: AppColors.slate50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.slate200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.slate200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _brand, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Niveaux sélectionnés',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() => selectedNiveaux.addAll(_sortedNiveaux.map((n) => n['id']?.toString() ?? '').where((id) => id.isNotEmpty))),
                        child: const Text('Tout'),
                      ),
                      TextButton(
                        onPressed: () => setState(() => selectedNiveaux.clear()),
                        child: const Text('Aucun'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _sortedNiveaux.length,
                      itemBuilder: (context, index) {
                        final niveau = _sortedNiveaux[index];
                        final niveauId = niveau['id']?.toString() ?? '';
                        final isSelected = selectedNiveaux.contains(niveauId);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (_) {
                            setState(() {
                              if (isSelected) {
                                selectedNiveaux.remove(niveauId);
                              } else {
                                selectedNiveaux.add(niveauId);
                              }
                            });
                          },
                          title: Text(
                            niveau['name']?.toString() ?? 'Niveau',
                            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: _brand,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount != null && amount > 0 && selectedNiveaux.isNotEmpty) {
                    _applyToSelectedNiveaux(selectedNiveaux.toList(), amount);
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Appliquer'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _applyToSelectedNiveaux(List<String> niveauIds, double amount) {
    for (final niveauId in niveauIds) {
      final sections = _sectionsForNiveau(niveauId);
      if (sections.isEmpty) {
        _setAmount(niveauId, null, amount);
      } else {
        for (final section in sections) {
          _setAmount(niveauId, section['id']?.toString(), amount);
        }
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
  }
}
