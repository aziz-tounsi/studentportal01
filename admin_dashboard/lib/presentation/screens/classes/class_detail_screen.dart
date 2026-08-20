import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../providers/classes_provider.dart';
import '../../providers/subjects_management_provider.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/user_avatar.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/ios_loader.dart';

const _brand = Color(0xFF655DD5);
const _brandLight = Color(0xFFEEECFB);
const _brandDark = Color(0xFF4A42B0);

Color _subjectColor(String? code) {
  if (code == null || code.isEmpty) return _brand;
  switch (code.toUpperCase()) {
    case 'MATH':
    case 'MATHS':
      return const Color(0xFF2563EB);
    case 'PHYS':
    case 'PHY':
      return const Color(0xFFDC2626);
    case 'SVT':
      return const Color(0xFF059669);
    case 'AR':
      return const Color(0xFF0891B2);
    case 'FR':
      return const Color(0xFF7C3AED);
    case 'EN':
      return const Color(0xFFDB2777);
    case 'HG':
    case 'HIST':
      return const Color(0xFFCA8A04);
    case 'PHILO':
      return const Color(0xFF4F46E5);
    case 'INFO':
      return const Color(0xFF0284C7);
    case 'EPS':
      return const Color(0xFF059669);
    case 'ESP':
      return const Color(0xFFE11D48);
    case 'TECH':
      return const Color(0xFF6D28D9);
    case 'SYS':
      return const Color(0xFF0369A1);
    case 'RESEAUX':
      return const Color(0xFF0E7490);
    case 'PROG':
      return const Color(0xFF7C3AED);
    case 'MUS':
      return const Color(0xFFBE185D);
    case 'LV3':
      return const Color(0xFF059669);
    case 'PENS_IS':
      return const Color(0xFF7E22CE);
    default:
      final hue = (code.hashCode % 360).abs().toDouble();
      return HSLColor.fromAHSL(1.0, hue, 0.60, 0.50).toColor();
  }
}

/// Provider for loading students in a specific class
final classStudentsProvider = FutureProvider.family<ClassDetailData, String>((ref, classId) async {
  final supabase = SupabaseConfig.adminClient;
  
  debugPrint('ClassDetail: Loading class with ID: $classId');
  
  // Get class info
  final classResp = await supabase
      .from('classes')
      .select('id, name, room, capacity, niveau_id, section_id, niveaux(code, name), sections(name)')
      .eq('id', classId)
      .single();
  
  debugPrint('ClassDetail: Class found: ${classResp['name']} (ID: ${classResp['id']})');
  
  // DEBUG: Check all enrollments to see if they exist
  final allEnrollments = await supabase
      .from('enrollments')
      .select('id, user_id, class_id, is_active')
      .limit(50);
  debugPrint('ClassDetail: Total enrollments in DB: ${(allEnrollments as List).length}');
  for (final e in allEnrollments.take(10)) {
    debugPrint('  - enrollment: class_id=${e['class_id']}, user_id=${e['user_id']}, active=${e['is_active']}');
  }
  
  // Get students enrolled in this class - using simple query then join manually
  final enrollmentsResp = await supabase
      .from('enrollments')
      .select('id, student_code, user_id, is_active, class_id')
      .eq('class_id', classId);
  
  debugPrint('ClassDetail: Enrollments with class_id=$classId: ${(enrollmentsResp as List).length}');
  
  // Also try without is_active filter
  final activeEnrollments = enrollmentsResp.where((e) => e['is_active'] == true).toList();
  debugPrint('ClassDetail: Active enrollments: ${activeEnrollments.length}');
  
  final students = <StudentInClass>[];
  
  // Get user details for each enrollment
  for (final e in enrollmentsResp) {
    final userId = e['user_id'] as String?;
    if (userId == null) continue;
    
    try {
      final userResp = await supabase
          .from('users')
          .select('id, full_name, email, phone, photo_url, date_of_birth, gender, is_active, student_code')
          .eq('id', userId)
          .single();
      
      students.add(StudentInClass(
        id: userResp['id'] ?? '',
        fullName: userResp['full_name'] ?? 'N/A',
        email: userResp['email'] ?? '',
        phone: userResp['phone'],
        avatarUrl: userResp['photo_url'],
        studentCode: e['student_code'] ?? userResp['student_code'],
        dateOfBirth: userResp['date_of_birth'],
        gender: userResp['gender'],
        status: (userResp['is_active'] == true) ? 'active' : 'inactive',
        enrollmentId: e['id'],
      ));
    } catch (err) {
      debugPrint('ClassDetail: Error fetching user $userId: $err');
    }
  }
  
  // Sort by name
  students.sort((a, b) => a.fullName.compareTo(b.fullName));
  
  debugPrint('ClassDetail: Loaded ${students.length} students');
  
  final niveauInfo = classResp['niveaux'] as Map<String, dynamic>?;
  final sectionInfo = classResp['sections'] as Map<String, dynamic>?;
  
  return ClassDetailData(
    classId: classResp['id'],
    className: classResp['name'] ?? 'Classe',
    room: classResp['room'],
    capacity: classResp['capacity'],
    niveauCode: niveauInfo?['code'],
    niveauName: niveauInfo?['name'],
    sectionName: sectionInfo?['name'],
    students: students,
  );
});

class ClassDetailData {
  final String classId;
  final String className;
  final String? room;
  final int? capacity;
  final String? niveauCode;
  final String? niveauName;
  final String? sectionName;
  final List<StudentInClass> students;

  ClassDetailData({
    required this.classId,
    required this.className,
    this.room,
    this.capacity,
    this.niveauCode,
    this.niveauName,
    this.sectionName,
    required this.students,
  });
}

class StudentInClass {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? studentCode;
  final String? dateOfBirth;
  final String? gender;
  final String status;
  final String enrollmentId;

  StudentInClass({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.studentCode,
    this.dateOfBirth,
    this.gender,
    required this.status,
    required this.enrollmentId,
  });
}

class ClassDetailScreen extends ConsumerStatefulWidget {
  final String classId;

  const ClassDetailScreen({super.key, required this.classId});

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _sortAsc = true;
  int _currentPage = 0;
  static const int _perPage = 10;

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(classStudentsProvider(widget.classId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/classes'),
          Expanded(
            child: dataAsync.when(
              loading: () => const Center(child: IosLoader(color: _brand)),
              error: (e, _) => _buildErrorState(e),
              data: (data) => _buildContent(context, data),
            ),
          ),
        ],
      ),
    );
  }

  // ── ERROR ──
  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
        const SizedBox(height: 16),
        Text('Erreur: $error', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        Material(
          color: _brand, borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => ref.invalidate(classStudentsProvider(widget.classId)),
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text('Réessayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── MAIN CONTENT ──
  Widget _buildContent(BuildContext context, ClassDetailData data) {
    var filtered = data.students.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.fullName.toLowerCase().contains(q) ||
          (s.studentCode?.toLowerCase().contains(q) ?? false) ||
          s.email.toLowerCase().contains(q);
    }).toList();

    filtered.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'code': cmp = (a.studentCode ?? '').compareTo(b.studentCode ?? ''); break;
        case 'status': cmp = a.status.compareTo(b.status); break;
        default: cmp = a.fullName.compareTo(b.fullName);
      }
      return _sortAsc ? cmp : -cmp;
    });

    final totalPages = (filtered.length / _perPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) _currentPage = totalPages - 1;
    final pageStudents = filtered.skip(_currentPage * _perPage).take(_perPage).toList();

    return Column(
      children: [
        _buildHeader(context, data),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: stats + table ──
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildStatsRow(data),
                    const SizedBox(height: 24),
                    _buildStudentTable(context, filtered, pageStudents, data, totalPages),
                    const SizedBox(height: 24),
                    _buildTeachersSection(data),
                  ]),
                ),
              ),
              // ── Right sidebar ──
              Container(
                width: 320,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(left: BorderSide(color: AppColors.border.withOpacity(0.5))),
                ),
                child: _buildRightSidebar(data),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, ClassDetailData data) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border.withOpacity(0.5)),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textSecondary),
              onPressed: () => context.go('/classes'),
              tooltip: 'Retour aux classes',
              splashRadius: 20,
            ),
          ),
          const SizedBox(width: 16),

          // Class icon
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.class_rounded, color: _brand, size: 24),
          ),
          const SizedBox(width: 14),

          // Name + badges
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(data.className, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              if (data.niveauName != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(8)),
                  child: Text(data.niveauName!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brand)),
                ),
              ],
            ]),
            if (data.sectionName != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(data.sectionName!, style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
              ),
          ]),

          const Spacer(),

          // Search
          SizedBox(
            width: 260, height: 40,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un étudiant...', hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary),
                filled: true, fillColor: AppColors.slate50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border.withOpacity(0.5))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _brand, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              ),
              onChanged: (v) => setState(() { _searchQuery = v; _currentPage = 0; }),
            ),
          ),
          const SizedBox(width: 10),

          // Refresh
          Container(
            decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border.withOpacity(0.5))),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSecondary),
              onPressed: () => ref.invalidate(classStudentsProvider(widget.classId)),
              tooltip: 'Rafraîchir', splashRadius: 20,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  STAT CARDS
  // ══════════════════════════════════════════════════════════════
  Widget _buildStatsRow(ClassDetailData data) {
    final count = data.students.length;
    final cap = data.capacity ?? 0;
    final fill = cap > 0 ? (count / cap * 100).toStringAsFixed(0) : '-';

    // Dynamic salle: show current room from timetable if available
    final timetableForSalle = ref.watch(classTimetableTodayProvider(data.classId));
    String currentRoom = data.room ?? '-';
    if (timetableForSalle.value != null) {
      final now = DateTime.now();
      final nowMin = now.hour * 60 + now.minute;
      for (final slot in timetableForSalle.value!) {
        final sp = slot.startTime.split(':');
        final ep = slot.endTime.split(':');
        final sMin = int.parse(sp[0]) * 60 + int.parse(sp[1]);
        final eMin = int.parse(ep[0]) * 60 + int.parse(ep[1]);
        if (nowMin >= sMin && nowMin < eMin && slot.room != null) {
          currentRoom = slot.room!;
          break;
        }
      }
    }

    return Row(children: [
      _statCard(Icons.people_rounded, 'Étudiants', '$count${cap > 0 ? '/$cap' : ''}', const Color(0xFF3B82F6)),
      const SizedBox(width: 16),
      _statCard(Icons.pie_chart_rounded, 'Taux de remplissage', '$fill%', const Color(0xFF10B981)),
      const SizedBox(width: 16),
      _statCard(Icons.meeting_room_rounded, 'Salle', currentRoom, const Color(0xFFF59E0B)),
    ]);
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
          ]),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  STUDENT TABLE
  // ══════════════════════════════════════════════════════════════
  Widget _buildStudentTable(BuildContext ctx, List<StudentInClass> all, List<StudentInClass> page, ClassDetailData data, int totalPages) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Table header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.people_rounded, color: _brand, size: 16),
            ),
            const SizedBox(width: 12),
            const Text('Liste des étudiants', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(8)),
              child: Text('${all.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _brand)),
            ),
          ]),
        ),

        // Column headers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          color: const Color(0xFFF9FAFB),
          child: const Row(children: [
            SizedBox(width: 50),
            Expanded(flex: 3, child: Text('NOM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5))),
            Expanded(flex: 2, child: Text('CODE ÉTUDIANT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5))),
            Expanded(flex: 3, child: Text('EMAIL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5))),
            Expanded(flex: 2, child: Text('TÉLÉPHONE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5))),
            SizedBox(width: 50, child: Text('ACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textTertiary, letterSpacing: 0.5))),
          ]),
        ),

        // Rows or empty
        if (page.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people_outline_rounded, size: 56, color: AppColors.slate300),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty ? 'Aucun résultat pour "$_searchQuery"' : 'Aucun étudiant inscrit',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
              ),
            ]),
          )
        else
          ...page.asMap().entries.map((e) => _studentRow(ctx, e.value, (_currentPage * _perPage) + e.key, data)),

        // Pagination footer
        if (all.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
            child: Row(children: [
              Text(
                'Affichage de ${_currentPage * _perPage + 1} à ${(_currentPage * _perPage + page.length).clamp(0, all.length)} sur ${all.length} étudiants',
                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              const Spacer(),
              _pageBtn(Icons.chevron_left_rounded, _currentPage > 0, () => setState(() => _currentPage--)),
              const SizedBox(width: 4),
              ...List.generate(totalPages.clamp(0, 7), (i) {
                final isActive = i == _currentPage;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => setState(() => _currentPage = i),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: isActive ? _brand : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isActive ? null : Border.all(color: AppColors.border.withOpacity(0.4)),
                      ),
                      alignment: Alignment.center,
                      child: Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? Colors.white : AppColors.textSecondary)),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),
              _pageBtn(Icons.chevron_right_rounded, _currentPage < totalPages - 1, () => setState(() => _currentPage++)),
            ]),
          ),
      ]),
    );
  }

  Widget _pageBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border.withOpacity(0.4))),
        child: Icon(icon, size: 18, color: enabled ? AppColors.textSecondary : AppColors.slate300),
      ),
    );
  }

  Widget _studentRow(BuildContext ctx, StudentInClass s, int index, ClassDetailData data) {
    return InkWell(
      onTap: () => ctx.push('/users/${s.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: index.isEven ? Colors.white : const Color(0xFFFAFAFC),
          border: const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
        ),
        child: Row(children: [
          // Avatar
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: UserAvatar(name: s.fullName, photoUrl: s.avatarUrl, radius: 18, gender: s.gender == 'male' ? 'M' : s.gender == 'female' ? 'F' : null),
          ),

          // Name
          Expanded(
            flex: 3,
            child: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
          ),

          // Code
          Expanded(flex: 2, child: Text(s.studentCode ?? '-', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'monospace'))),

          // Email
          Expanded(flex: 3, child: Text(s.email, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),

          // Phone
          Expanded(flex: 2, child: Text(s.phone ?? '-', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),

          // Action
          SizedBox(
            width: 50,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textTertiary),
              splashRadius: 18,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              offset: const Offset(0, 36),
              onSelected: (action) {
                switch (action) {
                  case 'profile': ctx.push('/users/${s.id}'); break;
                  case 'transfer': _showTransferStudentDialog(ctx, s, data); break;
                  case 'remove': _confirmRemoveStudent(ctx, s, data); break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'profile', child: Row(children: [
                  Icon(Icons.person_rounded, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 10),
                  Text('Voir le profil', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ])),
                const PopupMenuItem(value: 'transfer', child: Row(children: [
                  Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF2563EB)),
                  SizedBox(width: 10),
                  Text('Transférer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                ])),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'remove', child: Row(children: [
                  Icon(Icons.person_remove_rounded, size: 16, color: Color(0xFFDC2626)),
                  SizedBox(width: 10),
                  Text('Retirer de la classe', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFFDC2626))),
                ])),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  STUDENT ACTIONS: REMOVE & TRANSFER
  // ══════════════════════════════════════════════════════════════

  void _confirmRemoveStudent(BuildContext ctx, StudentInClass s, ClassDetailData data) {
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.person_remove_rounded, color: Color(0xFFDC2626), size: 18),
          ),
          const SizedBox(width: 12),
          const Text('Retirer l\'étudiant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: RichText(text: TextSpan(
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          children: [
            const TextSpan(text: 'Voulez-vous retirer '),
            TextSpan(text: s.fullName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            TextSpan(text: ' de la classe ${data.className} ?'),
          ],
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              try {
                await SupabaseConfig.adminClient
                    .from('enrollments')
                    .delete()
                    .eq('id', s.enrollmentId);
                ref.invalidate(classStudentsProvider(data.classId));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${s.fullName} retiré(e) de la classe'),
                    backgroundColor: _brand,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                }
              } catch (e) {
                debugPrint('Remove student error: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Erreur: $e'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Retirer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showTransferStudentDialog(BuildContext ctx, StudentInClass s, ClassDetailData data) async {
    // Fetch all classes from the same school
    List<Map<String, dynamic>> allClasses = [];
    try {
      final classResp = await SupabaseConfig.adminClient
          .from('classes')
          .select('school_id')
          .eq('id', data.classId)
          .single();
      final schoolId = classResp['school_id'] as String;
      final resp = await SupabaseConfig.adminClient
          .from('classes')
          .select('id, name, room, capacity, niveaux(code, name)')
          .eq('school_id', schoolId)
          .neq('id', data.classId)
          .order('name');
      allClasses = List<Map<String, dynamic>>.from(resp as List);
    } catch (e) {
      debugPrint('Load classes for transfer error: $e');
    }

    if (!mounted) return;

    showDialog(
      context: ctx,
      barrierColor: Colors.black54,
      builder: (dCtx) {
        String search = '';
        String? selectedClassId;
        return StatefulBuilder(builder: (dCtx, setInner) {
          final filtered = allClasses.where((c) {
            if (search.isEmpty) return true;
            final q = search.toLowerCase();
            final name = c['name']?.toString().toLowerCase() ?? '';
            final nv = (c['niveaux'] as Map?)?['name']?.toString().toLowerCase() ?? '';
            return name.contains(q) || nv.contains(q);
          }).toList();

          // Group by niveau
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final c in filtered) {
            final nvName = (c['niveaux'] as Map?)?['name']?.toString() ?? 'Autre';
            grouped.putIfAbsent(nvName, () => []).add(c);
          }

          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 480,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(dCtx).size.height * 0.8),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 8))],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F1F5)))),
                    child: Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Transférer l\'étudiant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(s.fullName, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                      ])),
                      IconButton(onPressed: () => Navigator.pop(dCtx), icon: const Icon(Icons.close_rounded, size: 20)),
                    ]),
                  ),
                  // Search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: TextField(
                      onChanged: (v) => setInner(() => search = v),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Rechercher une classe ou un niveau...',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E4EA))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E4EA))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _brand)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                    ),
                  ),
                  // From badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(8)),
                        child: Text('De: ${data.className}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                      ),
                      if (selectedClassId != null) ...[
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textTertiary)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(8)),
                          child: Text('Vers: ${allClasses.firstWhere((c) => c['id'] == selectedClassId)['name']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                        ),
                      ],
                    ]),
                  ),
                  // Class list
                  Flexible(
                    child: filtered.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade300),
                              const SizedBox(height: 10),
                              const Text('Aucune classe trouvée', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                            ]),
                          )
                        : ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                            children: grouped.entries.map((group) {
                              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                                  child: Text(group.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.5)),
                                ),
                                ...group.value.map((c) {
                                  final isSelected = selectedClassId == c['id'];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: InkWell(
                                      onTap: () => setInner(() => selectedClassId = c['id']),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isSelected ? _brandLight : const Color(0xFFF9F9FC),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: isSelected ? _brand.withOpacity(0.3) : const Color(0xFFEAEAF0)),
                                        ),
                                        child: Row(children: [
                                          Container(
                                            width: 32, height: 32,
                                            decoration: BoxDecoration(color: isSelected ? _brand.withOpacity(0.12) : const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(8)),
                                            child: Icon(Icons.class_rounded, size: 16, color: isSelected ? _brand : AppColors.textTertiary),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(c['name']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isSelected ? _brand : AppColors.textPrimary)),
                                            if (c['room'] != null)
                                              Text('Salle ${c['room']}', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                          ])),
                                          if (isSelected)
                                            const Icon(Icons.check_circle_rounded, size: 20, color: _brand),
                                        ]),
                                      ),
                                    ),
                                  );
                                }),
                              ]);
                            }).toList(),
                          ),
                  ),
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF1F1F5)))),
                    child: Row(children: [
                      Expanded(child: OutlinedButton(
                        onPressed: () => Navigator.pop(dCtx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E4EA)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(
                        onPressed: selectedClassId == null ? null : () async {
                          Navigator.pop(dCtx);
                          try {
                            await SupabaseConfig.adminClient
                                .from('enrollments')
                                .update({'class_id': selectedClassId})
                                .eq('id', s.enrollmentId);
                            ref.invalidate(classStudentsProvider(data.classId));
                            final targetName = allClasses.firstWhere((c) => c['id'] == selectedClassId)['name'];
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('${s.fullName} transféré(e) vers $targetName'),
                                backgroundColor: _brand,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ));
                            }
                          } catch (e) {
                            debugPrint('Transfer student error: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Erreur: $e'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _brand.withOpacity(0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                        ),
                        child: const Text('Transférer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      )),
                    ]),
                  ),
                ]),
              ),
            ),
          );
        });
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TEACHERS SECTION — Horizontal Compact Cards
  // ══════════════════════════════════════════════════════════════

  Widget _buildTeachersSection(ClassDetailData data) {
    final teachersAsync = ref.watch(classAllTeachersProvider(data.classId));

    return teachersAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAEAF0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 2))],
        ),
        child: Row(children: const [
          IosLoader.small(color: _brand),
          SizedBox(width: 12),
          Text('Chargement des enseignants...', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ]),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEAEAF0)),
        ),
        child: Text('Erreur enseignants: $e', style: const TextStyle(color: AppColors.error, fontSize: 12)),
      ),
      data: (teachers) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEAEAF0)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.school_rounded, color: _brand, size: 16),
                ),
                const SizedBox(width: 12),
                const Text('Enseignants assignés', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const Spacer(),
                _buildGererButton(data),
              ]),
            ),
            // ── Divider ──
            Container(height: 1, color: const Color(0xFFF1F1F5)),
            // ── Cards ──
            if (teachers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_off_rounded, size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('Aucun enseignant assigné', style: TextStyle(fontSize: 13, color: AppColors.textTertiary, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    const Text('Cliquez sur "Gérer" pour assigner des enseignants', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                  ]),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final cols = w > 900 ? 5 : (w > 700 ? 4 : (w > 450 ? 3 : 2));
                  final gap = 8.0;
                  final cardW = (w - (cols - 1) * gap) / cols;
                  return Wrap(
                    spacing: gap, runSpacing: gap,
                    children: teachers.map((t) => SizedBox(width: cardW, child: _teacherCard(t, data))).toList(),
                  );
                }),
              ),
          ]),
        );
      },
    );
  }

  Widget _buildGererButton(ClassDetailData data) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _showManageTeachersDialog(data),
        borderRadius: BorderRadius.circular(10),
        hoverColor: _brand.withOpacity(0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _brand.withOpacity(0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.edit_rounded, size: 13, color: _brand),
            SizedBox(width: 6),
            Text('Gérer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brand)),
          ]),
        ),
      ),
    );
  }

  Widget _teacherCard(ClassTeacherWithSubject t, ClassDetailData data) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.push('/teachers/${t.id}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEAEAF0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(children: [
            // Avatar
            UserAvatar(name: t.fullName, photoUrl: t.photoUrl, radius: 15),
            const SizedBox(width: 6),
            // Name + subject
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.fullName, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF1A1A2E)), overflow: TextOverflow.ellipsis),
                if (t.subjectName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: _subjectColor(t.subjectCode).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        t.subjectName!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: _subjectColor(t.subjectCode), letterSpacing: 0.3),
                      ),
                    ),
                  ),
              ]),
            ),
            // Chevron
            Icon(Icons.chevron_right_rounded, size: 14, color: Colors.grey.shade400),
          ]),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  TEACHER PROFILE DIALOG — Full profile matching design spec
  // ══════════════════════════════════════════════════════════════
  void _showTeacherProfileDialog(ClassTeacherWithSubject teacher, ClassDetailData classData) async {
    final supabase = SupabaseConfig.adminClient;

    Map<String, dynamic>? userDetails;
    List<Map<String, dynamic>> assignments = [];
    List<Map<String, dynamic>> classDetails = []; // class info for each assignment
    List<Map<String, dynamic>> timetableToday = [];

    try {
      userDetails = await supabase
          .from('users')
          .select('id, full_name, email, phone, photo_url, role, is_active, created_at, gender, nationality')
          .eq('id', teacher.id)
          .maybeSingle();

      final raw = await supabase
          .from('teacher_assignments')
          .select('id, subject_id, class_id, subjects(name, code), niveaux(name, code), classes(name, room, capacity)')
          .eq('teacher_id', teacher.id)
          .eq('is_active', true);
      assignments = List<Map<String, dynamic>>.from(raw as List);

      // Get student counts for assigned classes
      final classIds = assignments.map((a) => a['class_id']?.toString()).where((id) => id != null).toSet().toList();
      for (final cId in classIds) {
        try {
          final countResp = await supabase.from('enrollments').select('id').eq('class_id', cId!);
          final classRow = assignments.firstWhere((a) => a['class_id'] == cId, orElse: () => {});
          final cls = classRow['classes'] as Map<String, dynamic>?;
          final nv = classRow['niveaux'] as Map<String, dynamic>?;
          classDetails.add({
            'class_id': cId,
            'name': cls?['name'] ?? '',
            'room': cls?['room'],
            'niveau_name': nv?['name'] ?? '',
            'student_count': (countResp as List).length,
          });
        } catch (_) {}
      }

      // Get today's timetable for this teacher
      final now = DateTime.now();
      const dayNames = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];
      final dayName = dayNames[now.weekday - 1];
      try {
        final offerings = await supabase
            .from('subject_offerings')
            .select('id, class_id')
            .eq('teacher_id', teacher.id);
        final offeringIds = (offerings as List).map((e) => e['id'] as String).toList();
        if (offeringIds.isNotEmpty) {
          List<dynamic> slots;
          try {
            slots = await supabase
                .from('timetable_slots')
                .select('*, subject_offerings(subject_id, class_id, subjects(name, code), classes(name))')
                .inFilter('subject_offering_id', offeringIds)
                .eq('day_of_week', dayName)
                .order('start_time');
          } catch (_) {
            slots = await supabase
                .from('timetable_slots')
                .select('*, subject_offerings(subject_id, class_id, subjects(name, code), classes(name))')
                .inFilter('subject_offering_id', offeringIds)
                .eq('day_of_week', now.weekday)
                .order('start_time');
          }
          timetableToday = List<Map<String, dynamic>>.from(slots);
        }
      } catch (e) {
        debugPrint('Teacher timetable load error: $e');
      }
    } catch (e) {
      debugPrint('Teacher profile load error: $e');
    }

    if (!mounted) return;

    // Derive unique subjects and niveaux from assignments
    final subjects = <String>{};
    final niveaux = <String>{};
    for (final a in assignments) {
      final sName = (a['subjects'] as Map?)?['name']?.toString();
      final nName = (a['niveaux'] as Map?)?['name']?.toString();
      if (sName != null) subjects.add(sName);
      if (nName != null) niveaux.add(nName);
    }
    final mainSubject = subjects.isNotEmpty ? subjects.first : teacher.subjectName ?? 'N/A';

    // Format hire date
    String hireDate = '-';
    if (userDetails?['created_at'] != null) {
      try {
        final dt = DateTime.parse(userDetails!['created_at'].toString());
        const months = ['Janvier','Février','Mars','Avril','Mai','Juin','Juillet','Août','Septembre','Octobre','Novembre','Décembre'];
        hireDate = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
      } catch (_) {}
    }

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final now = DateTime.now();
        final nowMin = now.hour * 60 + now.minute;

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 960,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 40, offset: const Offset(0, 12))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // ── Top header bar ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(children: [
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textSecondary),
                      splashRadius: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(teacher.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (userDetails?['is_active'] == true) ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: (userDetails?['is_active'] == true) ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                          ),
                          child: Text(
                            (userDetails?['is_active'] == true) ? 'Actif' : 'Inactif',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: (userDetails?['is_active'] == true) ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
                          ),
                        ),
                      ]),
                      Text('Profil Enseignant • ID: ${teacher.id.substring(0, 8).toUpperCase()}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    ])),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        context.push('/users/${teacher.id}');
                      },
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: const Text('Modifier le profil'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        elevation: 0,
                        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
                // ── Body: 2-column layout ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // ── LEFT COLUMN: Profile card ──
                      SizedBox(
                        width: 280,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
                          ),
                          child: Column(children: [
                            // Gradient header
                            Container(
                              height: 80,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [Color(0xFFF5F4FF), Color(0xFFEDE9FE)]),
                                borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, -40),
                              child: Column(children: [
                                // Photo
                                UserAvatar(
                                  name: teacher.fullName,
                                  photoUrl: teacher.photoUrl,
                                  radius: 44,
                                  borderColor: Colors.white,
                                  borderWidth: 3,
                                ),
                                const SizedBox(height: 8),
                                Text(teacher.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text('Professeur ${subjects.isNotEmpty ? "d'${subjects.first}" : ""}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _brand)),
                                const SizedBox(height: 16),
                                // Contact info
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Column(children: [
                                    _contactRow(Icons.mail_outlined, 'Email Professionnel', teacher.email ?? '-'),
                                    _contactRow(Icons.phone_outlined, 'Téléphone', userDetails?['phone']?.toString() ?? '-'),
                                    _contactRow(Icons.calendar_month_outlined, 'Date d\'embauche', hireDate),
                                  ]),
                                ),
                                const SizedBox(height: 8),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // ── RIGHT COLUMN ──
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Speciality & Niveaux
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('SPÉCIALITÉ & NIVEAUX', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 1)),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              // Main subject badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: _brand.withOpacity(0.3), blurRadius: 8)]),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.terminal_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(mainSubject.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                                ]),
                              ),
                              if (niveaux.isNotEmpty) ...[
                                Container(width: 1, height: 28, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 4)),
                                ...niveaux.map((n) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                                  child: Text(n, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                                )),
                              ],
                            ]),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        // ── Classes Assignées ──
                        Row(children: [
                          const Text('Classes Assignées', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
                            child: Text('Total: ${classDetails.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        if (classDetails.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                            child: const Center(child: Text('Aucune classe assignée', style: TextStyle(fontSize: 12, color: AppColors.textTertiary))),
                          )
                        else
                          Wrap(spacing: 12, runSpacing: 12, children: classDetails.map((c) {
                            return Container(
                              width: 260,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white, borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(c['name']?.toString() ?? '', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                    Text(c['niveau_name']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                                  ])),
                                  Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(color: _brand.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.arrow_outward_rounded, size: 16, color: _brand),
                                  ),
                                ]),
                                const SizedBox(height: 10),
                                Container(height: 1, color: Colors.grey.shade100),
                                const SizedBox(height: 10),
                                Row(children: [
                                  Icon(Icons.groups_rounded, size: 14, color: Colors.grey.shade400),
                                  const SizedBox(width: 4),
                                  Text('${c['student_count']} Étudiants', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
                                  if (c['room'] != null) ...[
                                    const SizedBox(width: 16),
                                    Icon(Icons.room_rounded, size: 14, color: Colors.grey.shade400),
                                    const SizedBox(width: 4),
                                    Text(c['room'].toString(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
                                  ],
                                ]),
                              ]),
                            );
                          }).toList()),
                        const SizedBox(height: 20),
                        // ── Emploi du temps ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2))],
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              const Icon(Icons.calendar_today_rounded, size: 16, color: _brand),
                              const SizedBox(width: 8),
                              const Text('Emploi du temps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
                                child: const Text('Aujourd\'hui', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            if (timetableToday.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(10)),
                                child: Column(children: [
                                  Icon(Icons.event_busy_rounded, size: 32, color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  const Text('Aucun cours aujourd\'hui', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                                ]),
                              )
                            else
                              ...timetableToday.asMap().entries.map((entry) {
                                final slot = entry.value;
                                final so = slot['subject_offerings'] as Map<String, dynamic>?;
                                final subjectName = so?['subjects']?['name']?.toString() ?? 'Cours';
                                final className = so?['classes']?['name']?.toString() ?? '';
                                final startTime = slot['start_time']?.toString().substring(0, 5) ?? '??:??';
                                final endTime = slot['end_time']?.toString().substring(0, 5) ?? '??:??';
                                final room = slot['room']?.toString();
                                final sp = startTime.split(':');
                                final ep = endTime.split(':');
                                final sMin = (int.tryParse(sp[0]) ?? 0) * 60 + (int.tryParse(sp.length > 1 ? sp[1] : '0') ?? 0);
                                final eMin = (int.tryParse(ep[0]) ?? 0) * 60 + (int.tryParse(ep.length > 1 ? ep[1] : '0') ?? 0);
                                final isCurrent = nowMin >= sMin && nowMin < eMin;
                                final isPast = nowMin >= eMin;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(children: [
                                    // Time column
                                    SizedBox(
                                      width: 50,
                                      child: Column(children: [
                                        Text(startTime, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isCurrent ? _brand : AppColors.textPrimary)),
                                        Text(endTime, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                                      ]),
                                    ),
                                    const SizedBox(width: 12),
                                    // Dot + line
                                    Container(
                                      width: 10, height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isCurrent ? _brand : (isPast ? Colors.grey.shade300 : Colors.grey.shade200),
                                        border: Border.all(color: isCurrent ? _brand : Colors.grey.shade300, width: 2),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Card
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isCurrent ? const Color(0xFFF0EDFF) : const Color(0xFFF9FAFB),
                                          borderRadius: BorderRadius.circular(10),
                                          border: isCurrent ? Border(left: BorderSide(color: _brand, width: 3)) : null,
                                        ),
                                        child: Row(children: [
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(subjectName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isCurrent ? _brand : AppColors.textPrimary)),
                                            const SizedBox(height: 2),
                                            Text('$className${room != null ? ' • $room' : ''}',
                                                style: TextStyle(fontSize: 11, color: isCurrent ? _brand.withOpacity(0.7) : AppColors.textTertiary)),
                                          ])),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isCurrent ? _brand.withOpacity(0.1) : Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isCurrent ? 'EN COURS' : (isPast ? 'TERMINÉ' : 'À VENIR'),
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isCurrent ? _brand : Colors.grey.shade500, letterSpacing: 0.3),
                                            ),
                                          ),
                                        ]),
                                      ),
                                    ),
                                  ]),
                                );
                              }),
                          ]),
                        ),
                      ])),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _contactRow(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
          child: Icon(icon, size: 16, color: AppColors.textTertiary),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade400)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  Widget _profileChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  MANAGE TEACHERS DIALOG
  // ══════════════════════════════════════════════════════════════
  void _showManageTeachersDialog(ClassDetailData data) async {
    final supabase = SupabaseConfig.adminClient;

    // Load all school teachers + existing assignments for this class
    List<Map<String, dynamic>> allTeachers = [];
    List<Map<String, dynamic>> currentAssignments = [];
    List<Map<String, dynamic>> allSubjects = [];

    try {
      final schoolResp = await supabase.from('classes').select('school_id').eq('id', data.classId).single();
      final schoolId = schoolResp['school_id'] as String;

      final tResp = await supabase
          .from('users')
          .select('id, full_name, email, photo_url')
          .eq('school_id', schoolId)
          .eq('role', 'teacher')
          .eq('is_active', true)
          .order('full_name');
      allTeachers = List<Map<String, dynamic>>.from(tResp as List);

      final sResp = await supabase
          .from('subjects')
          .select('id, name, code')
          .eq('school_id', schoolId)
          .eq('is_active', true)
          .order('name');
      allSubjects = List<Map<String, dynamic>>.from(sResp as List);

      final aResp = await supabase
          .from('teacher_assignments')
          .select('id, teacher_id, subject_id, subjects(name, code)')
          .eq('class_id', data.classId)
          .eq('is_active', true);
      currentAssignments = List<Map<String, dynamic>>.from(aResp as List);
    } catch (e) {
      debugPrint('Manage teachers load error: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(color: Colors.black.withOpacity(0.3)),
                ),
              ),
            ),
            _ManageTeachersDialog(
              classId: data.classId,
              className: data.className,
              allTeachers: allTeachers,
              allSubjects: allSubjects,
              initialAssignments: currentAssignments,
              onDone: () {
                ref.invalidate(classAllTeachersProvider(data.classId));
              },
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  RIGHT SIDEBAR
  // ══════════════════════════════════════════════════════════════
  Widget _buildRightSidebar(ClassDetailData data) {
    final timetableAsync = ref.watch(classTimetableTodayProvider(data.classId));
    final now = DateTime.now();
    const daysFr = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const monthsFr = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    final dateStr = '${daysFr[now.weekday - 1]} ${now.day} ${monthsFr[now.month - 1]}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Agenda header ──
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.calendar_today_rounded, color: _brand, size: 16),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Agenda de la classe', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
        ]),
        const SizedBox(height: 4),
        Text('Aujourd\'hui, $dateStr', style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
        const SizedBox(height: 20),

        // ── Timeline ──
        timetableAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: IosLoader(color: _brand))),
          error: (_, __) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.errorSoft, borderRadius: BorderRadius.circular(10)),
            child: const Text('Erreur de chargement', style: TextStyle(color: AppColors.error, fontSize: 12)),
          ),
          data: (slots) {
            if (slots.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border.withOpacity(0.3))),
                child: Column(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: const BoxDecoration(color: Color(0xFFE5E7EB), shape: BoxShape.circle),
                    child: const Icon(Icons.event_busy_rounded, size: 24, color: AppColors.textTertiary),
                  ),
                  const SizedBox(height: 12),
                  const Text('Aucun cours aujourd\'hui', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  const Text('Profitez de la journée !', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ]),
              );
            }

            final nowMin = now.hour * 60 + now.minute;

            // Sort: current first, then upcoming, then past – limit to 4
            int _toMin(String t) { final p = t.split(':'); return int.parse(p[0]) * 60 + int.parse(p[1]); }
            final sortedSlots = List<ClassTimetableSlot>.from(slots)..sort((a, b) {
              final aS = _toMin(a.startTime), aE = _toMin(a.endTime);
              final bS = _toMin(b.startTime), bE = _toMin(b.endTime);
              final aCur = nowMin >= aS && nowMin < aE;
              final bCur = nowMin >= bS && nowMin < bE;
              final aPast = nowMin >= aE;
              final bPast = nowMin >= bE;
              if (aCur && !bCur) return -1;
              if (!aCur && bCur) return 1;
              if (!aPast && bPast) return -1;
              if (aPast && !bPast) return 1;
              return aS.compareTo(bS);
            });
            final displaySlots = sortedSlots.take(6).toList();

            return Column(children: [
              ...displaySlots.asMap().entries.map((entry) {
              final slot = entry.value;
              final sp = slot.startTime.split(':');
              final ep = slot.endTime.split(':');
              final sMin = int.parse(sp[0]) * 60 + int.parse(sp[1]);
              final eMin = int.parse(ep[0]) * 60 + int.parse(ep[1]);
              final isCurrent = nowMin >= sMin && nowMin < eMin;
              final isPast = nowMin >= eMin;

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Timeline dots
                  SizedBox(
                    width: 24,
                    child: Column(children: [
                      const SizedBox(height: 14),
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent ? _brand : (isPast ? AppColors.slate300 : AppColors.slate200),
                          border: Border.all(color: isCurrent ? _brand : AppColors.slate300, width: 2),
                          boxShadow: isCurrent ? [BoxShadow(color: _brand.withOpacity(0.3), blurRadius: 6)] : null,
                        ),
                      ),
                      if (entry.key < displaySlots.length - 1) Container(width: 2, height: 56, color: AppColors.slate200),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  // Course card
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCurrent ? _brandLight : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isCurrent ? _brand.withOpacity(0.3) : AppColors.border.withOpacity(0.3)),
                        boxShadow: isCurrent
                            ? [BoxShadow(color: _brand.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))]
                            : [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: const Offset(0, 1))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(
                            slot.subjectName ?? 'Cours',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isCurrent ? _brand : AppColors.textPrimary),
                          )),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(6)),
                              child: const Text('En Cours', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                            ),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          Icon(Icons.access_time_rounded, size: 13, color: isPast ? AppColors.textTertiary : AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('${slot.startTime.substring(0, 5)} - ${slot.endTime.substring(0, 5)}',
                              style: TextStyle(fontSize: 12, color: isPast ? AppColors.textTertiary : AppColors.textSecondary)),
                        ]),
                        if (slot.teacherName != null) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            UserAvatar(name: slot.teacherName!, radius: 10),
                            const SizedBox(width: 6),
                            Expanded(child: Text(slot.teacherName!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                          ]),
                        ],
                        if (slot.room != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textTertiary),
                            const SizedBox(width: 4),
                            Text('Salle ${slot.room}', style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                          ]),
                        ],
                      ]),
                    ),
                  ),
                ]),
              );
            }).toList(),
              if (slots.length > 6) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '+ ${slots.length - 6} autres cours',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brand),
                  ),
                ),
              ],
            ]);
          },
        ),
      ]),
    );
  }

  // ── HELPERS ──
  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ══════════════════════════════════════════════════════════════
//  MANAGE TEACHERS DIALOG (Add/Remove teachers from class)
// ══════════════════════════════════════════════════════════════
class _ManageTeachersDialog extends StatefulWidget {
  final String classId;
  final String className;
  final List<Map<String, dynamic>> allTeachers;
  final List<Map<String, dynamic>> allSubjects;
  final List<Map<String, dynamic>> initialAssignments;
  final VoidCallback onDone;

  const _ManageTeachersDialog({
    required this.classId,
    required this.className,
    required this.allTeachers,
    required this.allSubjects,
    required this.initialAssignments,
    required this.onDone,
  });

  @override
  State<_ManageTeachersDialog> createState() => _ManageTeachersDialogState();
}

class _ManageTeachersDialogState extends State<_ManageTeachersDialog> {
  late List<Map<String, dynamic>> _assignments;
  String _search = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _assignments = List.from(widget.initialAssignments);
  }

  // Look up teacher name/email/photo from widget.allTeachers using teacher_id
  Map<String, dynamic>? _lookupTeacher(String teacherId) {
    try { return widget.allTeachers.firstWhere((t) => t['id'] == teacherId); }
    catch (_) { return null; }
  }

  Future<void> _removeAssignment(String assignmentId) async {
    // Show confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(ctx).pop(false),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(color: Colors.black.withOpacity(0.2)),
              ),
            ),
          ),
          Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 380,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24)],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                  ),
                  const SizedBox(height: 16),
                  const Text('Retirer l\'enseignant ?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Cette action va retirer l\'enseignant de cette classe.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text('Retirer', style: TextStyle(fontWeight: FontWeight.w700)),
                    )),
                  ]),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      await SupabaseConfig.adminClient.from('teacher_assignments').delete().eq('id', assignmentId);
      setState(() => _assignments.removeWhere((a) => a['id'] == assignmentId));
      widget.onDone();
    } catch (e) {
      debugPrint('Remove assignment error: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _reloadAssignments() async {
    try {
      final aResp = await SupabaseConfig.adminClient
          .from('teacher_assignments')
          .select('id, teacher_id, subject_id, subjects(name, code)')
          .eq('class_id', widget.classId)
          .eq('is_active', true);
      setState(() => _assignments = List<Map<String, dynamic>>.from(aResp as List));
    } catch (e) {
      debugPrint('Reload assignments error: $e');
    }
  }

  // ── CREATE TEACHER FROM SCRATCH ──────────────────────────────
  void _showCreateTeacherSheet() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+216 ');
    String? selectedSubjectId;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setInner) {
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 440,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24)],
                ),
                child: Form(
                  key: formKey,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Dialog header
                    Row(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.person_add_rounded, color: _brand, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Nouveau professeur', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        Text('Créer et assigner à cette classe', style: TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                      ])),
                      IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close_rounded, size: 20)),
                    ]),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFF1F1F5)),
                    const SizedBox(height: 20),

                    // Full name
                    _fieldLabel('NOM COMPLET'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameCtrl,
                      style: const TextStyle(fontSize: 13),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                      decoration: _inputDeco(hint: 'Ex: Ahmed Ben Salah', icon: Icons.person_outline_rounded),
                    ),
                    const SizedBox(height: 14),

                    // Email
                    _fieldLabel('EMAIL'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: emailCtrl,
                      style: const TextStyle(fontSize: 13),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Champ requis';
                        if (!v.contains('@')) return 'Email invalide';
                        return null;
                      },
                      decoration: _inputDeco(hint: 'prof@ecole.tn', icon: Icons.email_outlined),
                    ),
                    const SizedBox(height: 14),

                    // Phone (optional)
                    _fieldLabel('TÉLÉPHONE (OPTIONNEL)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: phoneCtrl,
                      style: const TextStyle(fontSize: 13),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[+\d ]')),
                        _PhoneFormatter216(),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty || v.trim() == '+216') return null;
                        if (!v.startsWith('+216')) return 'Doit commencer par +216';
                        final digits = v.replaceAll(RegExp(r'[^\d]'), '');
                        final localDigits = digits.length - 3;
                        if (localDigits != 8) return 'Numéro tunisien = 8 chiffres après +216';
                        return null;
                      },
                      decoration: _inputDeco(hint: '+216 XX XXX XXX', icon: Icons.phone_outlined),
                    ),
                    const SizedBox(height: 14),

                    // Subject dropdown
                    _fieldLabel('MATIÈRE À ENSEIGNER'),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E4EA)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedSubjectId,
                          isExpanded: true,
                          hint: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Sélectionner une matière', style: TextStyle(fontSize: 13, color: AppColors.textTertiary))),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          borderRadius: BorderRadius.circular(12),
                          items: widget.allSubjects.map((s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['name'] ?? '', style: const TextStyle(fontSize: 13)),
                          )).toList(),
                          onChanged: (v) => setInner(() => selectedSubjectId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 40,
                          child: TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF6B7280),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          height: 40,
                          child: ElevatedButton(
                            onPressed: selectedSubjectId == null ? null : () async {
                          if (!formKey.currentState!.validate()) return;
                          Navigator.of(ctx).pop();
                          setState(() => _loading = true);
                          try {
                            // Get school_id from class
                            final classResp = await SupabaseConfig.adminClient
                                .from('classes').select('school_id').eq('id', widget.classId).single();
                            final schoolId = classResp['school_id'] as String;

                            // Create teacher as auth user + users record
                            final autoEmail = emailCtrl.text.trim();
                            final autoPass = 'Teacher@${DateTime.now().millisecondsSinceEpoch}';

                            // Try to create auth user first
                            String newTeacherId;
                            try {
                              final authResp = await SupabaseConfig.adminClient.auth.admin.createUser(
                                AdminUserAttributes(
                                  email: autoEmail,
                                  password: autoPass,
                                  emailConfirm: true,
                                  userMetadata: {
                                    'full_name': nameCtrl.text.trim(),
                                    'role': 'teacher',
                                    'school_id': schoolId,
                                  },
                                ),
                              );
                              newTeacherId = authResp.user!.id;
                              // Upsert into users table
                              await SupabaseConfig.adminClient.from('users').upsert({
                                'id': newTeacherId,
                                'full_name': nameCtrl.text.trim(),
                                'email': autoEmail,
                                'phone': (phoneCtrl.text.trim().isEmpty || phoneCtrl.text.trim() == '+216') ? null : phoneCtrl.text.trim(),
                                'role': 'teacher',
                                'school_id': schoolId,
                                'is_active': true,
                              });
                            } catch (_) {
                              // Fallback: just insert into users table
                              final inserted = await SupabaseConfig.adminClient.from('users').insert({
                                'full_name': nameCtrl.text.trim(),
                                'email': autoEmail,
                                'phone': (phoneCtrl.text.trim().isEmpty || phoneCtrl.text.trim() == '+216') ? null : phoneCtrl.text.trim(),
                                'role': 'teacher',
                                'school_id': schoolId,
                                'is_active': true,
                              }).select('id').single();
                              newTeacherId = inserted['id'] as String;
                            }

                            // Create assignment for this class
                            await SupabaseConfig.adminClient.from('teacher_assignments').insert({
                              'school_id': schoolId,
                              'teacher_id': newTeacherId,
                              'subject_id': selectedSubjectId,
                              'class_id': widget.classId,
                              'is_active': true,
                            });

                            await _reloadAssignments();
                            widget.onDone();
                          } catch (e) {
                            debugPrint('Create teacher error: $e');
                          }
                          setState(() => _loading = false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brand,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _brand.withOpacity(0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          elevation: 2,
                        ),
                        child: const Text('Créer le professeur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
                  ]),
                ),
              ),
            ),
          );
        });
      },
    );
  }

  static Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 1),
  );

  static InputDecoration _inputDeco({required String hint, required IconData icon}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
    prefixIcon: Icon(icon, size: 16, color: AppColors.textTertiary),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E4EA))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _brand, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.error.withOpacity(0.6))),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.error)),
    isDense: true,
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 560,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 8))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F1F5)))),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.school_rounded, color: _brand, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Gérer les enseignants', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(widget.className, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ])),
                IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, size: 20)),
              ]),
            ),
            // Search + add
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E4EA)),
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher par nom ou matière...',
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textTertiary),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _showCreateTeacherSheet,
                  icon: const Icon(Icons.person_add_rounded, size: 15),
                  label: const Text('Nouveau'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    elevation: 0,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ]),
            ),
            // List
            Flexible(
              child: _loading
                  ? const Center(child: Padding(padding: EdgeInsets.all(32), child: IosLoader(color: _brand)))
                  : _search.isNotEmpty
                      ? _buildSearchResults()
                      : (_assignments.isEmpty)
                          ? Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.person_off_rounded, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                const Text('Aucun enseignant assigné', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _showCreateTeacherSheet,
                                  icon: const Icon(Icons.person_add_rounded, size: 16),
                                  label: const Text('Créer un professeur'),
                                  style: TextButton.styleFrom(foregroundColor: _brand),
                                ),
                              ]),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                              itemCount: _assignments.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final a = _assignments[i];
                                final teacherId = a['teacher_id']?.toString() ?? '';
                                final s = a['subjects'] as Map<String, dynamic>?;
                                final teacherData = _lookupTeacher(teacherId);
                                final name = teacherData?['full_name']?.toString() ?? 'Professeur';
                                final email = teacherData?['email']?.toString();
                                final photoUrl = teacherData?['photo_url']?.toString();
                                final subjectName = s?['name']?.toString() ?? '';
                                final subjectCode = s?['code']?.toString();

                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9F9FC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFEAEAF0)),
                                  ),
                                  child: Row(children: [
                                    UserAvatar(name: name, photoUrl: photoUrl, radius: 19),
                                    const SizedBox(width: 12),
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      if (email != null)
                                        Text(email, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary), overflow: TextOverflow.ellipsis),
                                    ])),
                                    if (subjectName.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: _subjectColor(subjectCode).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                        child: Text(subjectName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _subjectColor(subjectCode))),
                                      ),
                                    Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () => _removeAssignment(a['id'].toString()),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: 32, height: 32,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFFFE4E6)),
                                            color: const Color(0xFFFFF1F2),
                                          ),
                                          child: const Icon(Icons.close_rounded, size: 15, color: Color(0xFFBE123C)),
                                        ),
                                      ),
                                    ),
                                  ]),
                                );
                              },
                            ),
            ),
          ]),
        ),
      ),
    );
  }

  // Search all school teachers (not just assigned)
  List<Map<String, dynamic>> get _filteredTeachers {
    if (_search.isEmpty) return [];
    final q = _search.toLowerCase();
    return widget.allTeachers.where((t) {
      final name = t['full_name']?.toString().toLowerCase() ?? '';
      final email = t['email']?.toString().toLowerCase() ?? '';
      return name.contains(q) || email.contains(q);
    }).toList();
  }

  bool _isAlreadyAssigned(String teacherId) =>
      _assignments.any((a) => a['teacher_id'] == teacherId);

  // Build the search-mode list from all school teachers
  Widget _buildSearchResults() {
    final results = _filteredTeachers;
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text('Aucun professeur trouvé pour "$_search"', style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ]),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final t = results[i];
        final name = t['full_name']?.toString() ?? '';
        final email = t['email']?.toString();
        final photoUrl = t['photo_url']?.toString();
        final alreadyAssigned = _isAlreadyAssigned(t['id'].toString());
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: alreadyAssigned ? const Color(0xFFF5F4FF) : const Color(0xFFF9F9FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: alreadyAssigned ? _brand.withOpacity(0.2) : const Color(0xFFEAEAF0)),
          ),
          child: Row(children: [
            UserAvatar(name: name, photoUrl: photoUrl, radius: 19),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              if (email != null)
                Text(email, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary), overflow: TextOverflow.ellipsis),
            ])),
            const SizedBox(width: 8),
            if (alreadyAssigned)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(8)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_rounded, size: 12, color: _brand),
                  SizedBox(width: 4),
                  Text('Assigné', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _brand)),
                ]),
              )
            else
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _showAssignTeacherSheet(t),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: _brandLight,
                    ),
                    child: const Icon(Icons.add_rounded, size: 18, color: _brand),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }

  // Assign an existing school teacher to this class by picking a subject
  void _showAssignTeacherSheet(Map<String, dynamic> teacher) {
    String? selectedSubjectId;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setInner) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 380,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.person_add_rounded, color: _brand, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Assigner une matière', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(teacher['full_name']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                  ])),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 18)),
                ]),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'MATIÈRE À ENSEIGNER',
                    labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textTertiary, letterSpacing: 0.8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E4EA))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E4EA))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _brand)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  value: selectedSubjectId,
                  borderRadius: BorderRadius.circular(12),
                  hint: const Text('Choisir une matière', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                  items: widget.allSubjects.map((s) => DropdownMenuItem(
                    value: s['id'].toString(),
                    child: Text(s['name'].toString(), style: const TextStyle(fontSize: 13)),
                  )).toList(),
                  onChanged: (v) => setInner(() => selectedSubjectId = v),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E4EA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary, fontSize: 13)),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: ElevatedButton(
                    onPressed: selectedSubjectId == null ? null : () async {
                      Navigator.pop(ctx);
                      setState(() => _loading = true);
                      try {
                        final classResp = await SupabaseConfig.adminClient
                            .from('classes').select('school_id').eq('id', widget.classId).single();
                        final schoolId = classResp['school_id'] as String;
                        await SupabaseConfig.adminClient.from('teacher_assignments').insert({
                          'school_id': schoolId,
                          'teacher_id': teacher['id'],
                          'subject_id': selectedSubjectId,
                          'class_id': widget.classId,
                          'is_active': true,
                        });
                        await _reloadAssignments();
                        widget.onDone();
                        setState(() => _search = '');
                      } catch (e) {
                        debugPrint('Assign teacher error: $e');
                      }
                      setState(() => _loading = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _brand.withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                    child: const Text('Assigner', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  )),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
  }

}

class _PhoneFormatter216 extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.text.startsWith('+216')) {
      return oldValue;
    }
    return newValue;
  }
}

