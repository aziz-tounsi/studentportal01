import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/user_avatar.dart';

const _brand = Color(0xFF655DD5);
const _brandLight = Color(0xFFEEECFB);

class TeacherProfileScreen extends ConsumerStatefulWidget {
  final String teacherId;
  const TeacherProfileScreen({super.key, required this.teacherId});

  @override
  ConsumerState<TeacherProfileScreen> createState() => _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _classDetails = [];
  List<Map<String, dynamic>> _timetableToday = [];
  Set<String> _subjects = {};
  Set<String> _niveaux = {};
  Map<String, String> _niveauFilieres = {};
  String _mainSubject = '';
  String _hireDate = '-';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final supabase = SupabaseConfig.adminClient;
    try {
      _user = await supabase
          .from('users')
          .select('id, full_name, email, phone, photo_url, role, is_active, created_at, gender, nationality')
          .eq('id', widget.teacherId)
          .maybeSingle();

      final raw = await supabase
          .from('teacher_assignments')
          .select('id, subject_id, class_id, niveau_id, subjects(name, code), niveaux(id, name, code), classes(id, name, room, capacity, niveau_id, section_id, niveaux(name, code), sections:section_id(name, code))')
          .eq('teacher_id', widget.teacherId)
          .eq('is_active', true);
      _assignments = List<Map<String, dynamic>>.from(raw as List);

      // Student counts per class
      final classIds = _assignments.map((a) => a['class_id']?.toString()).where((id) => id != null).toSet().toList();
      for (final cId in classIds) {
        try {
          final countResp = await supabase.from('enrollments').select('id').eq('class_id', cId!);
          final classRow = _assignments.firstWhere((a) => a['class_id'] == cId, orElse: () => {});
          final cls = classRow['classes'] as Map<String, dynamic>?;
          final assignmentNiveau = classRow['niveaux'] as Map<String, dynamic>?;
          final classNiveau = cls?['niveaux'] as Map<String, dynamic>?;
          final niveauName = assignmentNiveau?['name'] ?? classNiveau?['name'] ?? '';
          _classDetails.add({
            'class_id': cId,
            'name': cls?['name'] ?? '',
            'room': cls?['room'],
            'niveau_name': niveauName,
            'student_count': (countResp as List).length,
          });
        } catch (_) {}
      }

      // Today's timetable
      final now = DateTime.now();
      const dayNames = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final dayName = dayNames[now.weekday - 1];
      try {
        final offerings = await supabase
            .from('subject_offerings')
            .select('id, class_id')
            .eq('teacher_id', widget.teacherId);
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
          _timetableToday = List<Map<String, dynamic>>.from(slots);
        }
      } catch (e) {
        debugPrint('Teacher timetable load error: $e');
      }

      // Derive subjects & niveaux from assignments
      for (final a in _assignments) {
        final sName = (a['subjects'] as Map?)?['name']?.toString();
        if (sName != null) _subjects.add(sName);
        // Get niveau from assignment OR class→niveaux
        final aN = (a['niveaux'] as Map?)?['name']?.toString();
        final cN = ((a['classes'] as Map?)?['niveaux'] as Map?)?['name']?.toString();
        // Get filière/section from class
        final sectionName = ((a['classes'] as Map?)?['sections'] as Map?)?['name']?.toString();
        if (aN != null) {
          _niveaux.add(aN);
          if (sectionName != null) _niveauFilieres[aN] = sectionName;
        } else if (cN != null) {
          _niveaux.add(cN);
          if (sectionName != null) _niveauFilieres[cN] = sectionName;
        }
      }
      _mainSubject = _subjects.isNotEmpty ? _subjects.first : 'N/A';

      // Format hire date
      if (_user?['created_at'] != null) {
        try {
          final dt = DateTime.parse(_user!['created_at'].toString());
          const months = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
          _hireDate = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Teacher profile load error: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Row(children: [
        const AdminSidebar(currentRoute: '/users'),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _brand))
              : _user == null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.person_off_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('Enseignant introuvable', style: TextStyle(fontSize: 14, color: AppColors.textTertiary)),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () => context.go('/classes'),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('Retour'),
                        ),
                      ]),
                    )
                  : Column(children: [
                      _buildHeader(),
                      Expanded(child: _buildBody()),
                    ]),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    final isActive = _user?['is_active'] == true;
    final fullName = _user?['full_name']?.toString() ?? 'Enseignant';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(children: [
        // Back button
        InkWell(
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/classes');
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.transparent,
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 16),
        // Name & subtitle
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.3)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isActive ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA)),
                ),
                child: Text(
                  isActive ? 'Actif' : 'Inactif',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isActive ? const Color(0xFF15803D) : const Color(0xFFDC2626)),
                ),
              ),
            ]),
            const SizedBox(height: 2),
            Text(
              'Profil Enseignant • ID: TEA-${widget.teacherId.substring(0, 8).toUpperCase()}',
              style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
            ),
          ]),
        ),
        // Modifier le profil button
        Material(
          color: _brand,
          borderRadius: BorderRadius.circular(8),
          elevation: 2,
          shadowColor: _brand.withOpacity(0.3),
          child: InkWell(
            onTap: () => _showEditTeacherDialog(),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, color: Colors.white, size: 15),
                  SizedBox(width: 6),
                  Text('Modifier le profil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  BODY – 2-column layout
  // ══════════════════════════════════════════════════════════════
  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── LEFT: Profile card ──
          SizedBox(width: 340, child: _buildProfileCard()),
          const SizedBox(width: 32),
          // ── RIGHT: Specialty, Classes, Timetable ──
          Expanded(child: _buildRightColumn()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  LEFT PROFILE CARD
  // ══════════════════════════════════════════════════════════════
  Widget _buildProfileCard() {
    final fullName = _user?['full_name']?.toString() ?? 'Enseignant';
    final email = _user?['email']?.toString() ?? '-';
    final phone = _user?['phone']?.toString() ?? '-';
    final photoUrl = _user?['photo_url']?.toString();
    final gender = _user?['gender']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Gradient banner
        Container(
          height: 96,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_brand.withOpacity(0.10), const Color(0xFFEDE9FE)],
            ),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
        ),
        // Avatar + info – overlaps the banner
        Transform.translate(
          offset: const Offset(0, -48),
          child: Column(children: [
            // Avatar
            Stack(
              children: [
                UserAvatar(
                  name: fullName,
                  photoUrl: photoUrl,
                  gender: gender,
                  radius: 64,
                  borderColor: Colors.white,
                  borderWidth: 4,
                ),
                // Camera edit button
                Positioned(
                  top: 0, right: 0,
                  child: InkWell(
                    onTap: _pickAndUploadPhoto,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)],
                      ),
                      child: const Icon(Icons.camera_alt_rounded, size: 15, color: _brand),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Name
            Text(fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            // Subject title
            Text(
              'Professeur ${_subjects.isNotEmpty ? "d\'${_subjects.first}" : ""}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _brand),
            ),
            const SizedBox(height: 24),
            // Contact info blocks
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                _contactBlock(Icons.mail_outlined, 'Email Professionnel', email),
                const SizedBox(height: 10),
                _contactBlock(Icons.phone_outlined, 'Téléphone', phone.isNotEmpty ? phone : '-'),
                const SizedBox(height: 10),
                _contactBlock(Icons.calendar_month_outlined, 'Date d\'embauche', _hireDate),
              ]),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ]),
    );
  }

  Widget _avatarFallback(String name, double size) {
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: _brandLight),
      child: Center(
        child: Text(_initials(name), style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w700, color: _brand)),
      ),
    );
  }

  Widget _contactBlock(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
          ),
          child: Icon(icon, size: 18, color: AppColors.textTertiary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade400)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  RIGHT COLUMN
  // ══════════════════════════════════════════════════════════════
  Widget _buildRightColumn() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSpecialitySection(),
      const SizedBox(height: 24),
      _buildClassesSection(),
      const SizedBox(height: 24),
      _buildTimetableSection(),
    ]);
  }

  // ── Spécialité & Niveaux ──
  Widget _buildSpecialitySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('SPÉCIALITÉ & NIVEAUX',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade400, letterSpacing: 1.2)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          // Main subject badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _brand,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: _brand.withOpacity(0.3), blurRadius: 12)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.terminal_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              Text(_mainSubject.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
          if (_niveaux.isNotEmpty) ...[
            Container(width: 1, height: 32, color: Colors.grey.shade200, margin: const EdgeInsets.symmetric(horizontal: 4)),
            ..._niveaux.map((n) {
            final filiere = _niveauFilieres[n];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(n, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
                if (filiere != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(filiere, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED))),
                  ),
                ],
              ]),
            );
          }),
          ],
        ]),
      ]),
    );
  }

  // ── Classes Assignées ──
  Widget _buildClassesSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Classes Assignées', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
          child: Text('Total: ${_classDetails.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
        ),
      ]),
      const SizedBox(height: 16),
      if (_classDetails.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Center(child: Column(children: [
            Icon(Icons.class_rounded, size: 36, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            const Text('Aucune classe assignée', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          ])),
        )
      else
        LayoutBuilder(builder: (context, constraints) {
          final crossCount = constraints.maxWidth > 700 ? 2 : 1;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _classDetails.map((c) {
              final cardWidth = (constraints.maxWidth - (crossCount - 1) * 16) / crossCount;
              return SizedBox(
                width: cardWidth,
                child: _buildClassCard(c),
              );
            }).toList(),
          );
        }),
    ]);
  }

  Widget _buildClassCard(Map<String, dynamic> c) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c['name']?.toString() ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(c['niveau_name']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          ])),
          InkWell(
            onTap: () {
              final classId = c['class_id']?.toString();
              if (classId != null) context.push('/classes/$classId');
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _brand.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_outward_rounded, size: 18, color: _brand),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Container(height: 1, color: Colors.grey.shade100),
        const SizedBox(height: 14),
        Row(children: [
          Icon(Icons.groups_rounded, size: 15, color: Colors.grey.shade400),
          const SizedBox(width: 6),
          Text('${c['student_count']} Étudiants', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
          if (c['room'] != null) ...[
            const SizedBox(width: 20),
            Icon(Icons.room_rounded, size: 15, color: Colors.grey.shade400),
            const SizedBox(width: 6),
            Text(c['room'].toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
          ],
        ]),
      ]),
    );
  }

  // ── Emploi du temps ──
  Widget _buildTimetableSection() {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 18, color: _brand),
          const SizedBox(width: 10),
          const Text('Emploi du temps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const Spacer(),
          // Toggle buttons
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                ),
                child: const Text('Aujourd\'hui', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text('Semaine', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 24),
        // Slots
        if (_timetableToday.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Icon(Icons.event_busy_rounded, size: 40, color: Colors.grey.shade300),
              const SizedBox(height: 10),
              const Text('Aucun cours aujourd\'hui', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
            ]),
          )
        else
          ..._buildTimetableSlots(nowMin),
      ]),
    );
  }

  List<Widget> _buildTimetableSlots(int nowMin) {
    final widgets = <Widget>[];
    for (int i = 0; i < _timetableToday.length; i++) {
      final slot = _timetableToday[i];
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

      // Check for gap → Pause / Préparation
      if (i > 0) {
        final prevSlot = _timetableToday[i - 1];
        final prevEnd = prevSlot['end_time']?.toString().substring(0, 5) ?? '00:00';
        if (prevEnd != startTime) {
          widgets.add(_buildPauseSlot(prevEnd, startTime));
        }
      }

      widgets.add(_buildSlotRow(
        startTime: startTime,
        endTime: endTime,
        subject: subjectName,
        className: className,
        room: room,
        isCurrent: isCurrent,
        isPast: isPast,
      ));
    }
    return widgets;
  }

  Widget _buildPauseSlot(String startTime, String endTime) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        // Time column
        SizedBox(
          width: 56,
          child: Column(children: [
            Text(startTime, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
            Text(endTime, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ]),
        ),
        // Separator line
        Container(width: 1, height: 40, color: Colors.grey.shade200),
        const SizedBox(width: 16),
        // Break card
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
            ),
            child: Center(
              child: Text('Pause / Préparation', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildSlotRow({
    required String startTime,
    required String endTime,
    required String subject,
    required String className,
    String? room,
    required bool isCurrent,
    required bool isPast,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: isPast ? 0.5 : 1.0,
        child: Row(children: [
          // Time column
          SizedBox(
            width: 56,
            child: Column(children: [
              Text(startTime, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isCurrent ? AppColors.textPrimary : Colors.grey.shade700)),
              Text(endTime, style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            ]),
          ),
          // Separator line
          Container(width: 1, height: 48, color: Colors.grey.shade200),
          const SizedBox(width: 16),
          // Course card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFFEDE9FE) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: isCurrent
                    ? const Border(left: BorderSide(color: _brand, width: 4))
                    : Border.all(color: Colors.grey.shade200),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(subject, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isCurrent ? AppColors.textPrimary : AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    '$className${room != null ? ' • $room' : ''}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isCurrent ? _brand : AppColors.textTertiary),
                  ),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCurrent ? _brand.withOpacity(0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCurrent ? 'EN COURS' : (isPast ? 'TERMINÉ' : 'À VENIR'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isCurrent ? _brand : Colors.grey.shade500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  PICK & UPLOAD PHOTO
  // ══════════════════════════════════════════════════════════════
  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 85);
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final path = 'avatars/${widget.teacherId}.$ext';

      await SupabaseConfig.adminClient.storage.from('avatars').uploadBinary(
        path, bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      final url = SupabaseConfig.adminClient.storage.from('avatars').getPublicUrl(path);

      await SupabaseConfig.adminClient.from('users').update({'photo_url': url}).eq('id', widget.teacherId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Photo mise à jour'), backgroundColor: const Color(0xFF16A34A), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
        setState(() => _loading = true);
        _classDetails = [];
        _subjects = {};
        _niveaux = {};
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur photo: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        );
      }
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  EDIT TEACHER DIALOG
  // ══════════════════════════════════════════════════════════════
  void _showEditTeacherDialog() async {
    final nameCtrl = TextEditingController(text: _user?['full_name']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: _user?['email']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: _user?['phone']?.toString() ?? '');
    bool saving = false;

    // Load all niveaux, classes, and subjects for the school
    List<Map<String, dynamic>> allNiveaux = [];
    List<Map<String, dynamic>> allClasses = [];
    List<Map<String, dynamic>> allSubjects = [];
    String? schoolId;
    try {
      final schoolResp = await SupabaseConfig.adminClient
          .from('users').select('school_id').eq('id', widget.teacherId).maybeSingle();
      schoolId = schoolResp?['school_id']?.toString();
      if (schoolId != null) {
        // niveaux is a global reference table — no school_id column
        final nResp = await SupabaseConfig.adminClient
            .from('niveaux').select('id, name, code, has_sections').order('name');
        allNiveaux = List<Map<String, dynamic>>.from(nResp as List);
        final cResp = await SupabaseConfig.adminClient
            .from('classes')
            .select('id, name, niveau_id, section_id, sections(id, name, code)')
            .eq('school_id', schoolId)
            .order('name');
        allClasses = List<Map<String, dynamic>>.from(cResp as List);
        final sResp = await SupabaseConfig.adminClient
            .from('subjects').select('id, name, code').eq('school_id', schoolId).order('name');
        allSubjects = List<Map<String, dynamic>>.from(sResp as List);
      }
    } catch (_) {}

    // Build currently assigned subject + niveaux + classes from _assignments
    String? selectedSubjectId;
    final Set<String> selectedNiveauIds = {};
    final Map<String, Set<String>> selectedClassIdsByNiveau = {};
    final Map<String, Set<String>> selectedSectionIdsByNiveau = {};

    // Track original assignments for diffing on save
    final List<Map<String, dynamic>> originalAssignments = List.from(_assignments);

    for (final a in _assignments) {
      // Get subject
      if (selectedSubjectId == null && a['subject_id'] != null) {
        selectedSubjectId = a['subject_id']?.toString();
      }
      final niveauId = a['niveau_id']?.toString() ?? (a['niveaux'] as Map?)?['id']?.toString();
      final classId = a['class_id']?.toString();
      if (niveauId != null) {
        selectedNiveauIds.add(niveauId);
        selectedClassIdsByNiveau.putIfAbsent(niveauId, () => {});
        selectedSectionIdsByNiveau.putIfAbsent(niveauId, () => {});
        if (classId != null) {
          selectedClassIdsByNiveau[niveauId]!.add(classId);
          // Pre-select section if class belongs to one
          final cls = allClasses.where((c) => c['id'] == classId).toList();
          if (cls.isNotEmpty) {
            final sectionId = cls.first['section_id']?.toString();
            if (sectionId != null) selectedSectionIdsByNiveau[niveauId]!.add(sectionId);
          }
        }
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Stack(
            children: [
              // Blurred backdrop
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(color: Colors.black.withOpacity(0.3)),
                  ),
                ),
              ),
              // Dialog
              Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 580,
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 8))],
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.edit_rounded, size: 20, color: _brand),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Modifier l\'enseignant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                              SizedBox(height: 2),
                              Text('Mettez à jour les informations du profil et les affectations', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                            ]),
                          ),
                          InkWell(
                            onTap: () => Navigator.of(ctx).pop(),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textTertiary),
                            ),
                          ),
                        ]),
                      ),
                      Divider(height: 1, color: Colors.grey.shade200),
                      // Scrollable content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            // ── Personal Info Section ──
                            _sectionHeader('Informations Personnelles'),
                            const SizedBox(height: 12),
                            _fieldLabel('Nom complet'),
                            const SizedBox(height: 6),
                            _textField(nameCtrl, 'Nom complet', Icons.person_outlined),
                            const SizedBox(height: 16),
                            Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _fieldLabel('Email'),
                                const SizedBox(height: 6),
                                _textField(emailCtrl, 'Adresse email', Icons.mail_outlined),
                              ])),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                _fieldLabel('Téléphone'),
                                const SizedBox(height: 6),
                                _textField(phoneCtrl, 'Numéro de téléphone', Icons.phone_outlined),
                              ])),
                            ]),

                            const SizedBox(height: 24),
                            Divider(color: Colors.grey.shade100),
                            const SizedBox(height: 20),

                            // ── Subject/Matière Section ──
                            _sectionHeader('Matière Enseignée'),
                            const SizedBox(height: 12),
                            _fieldLabel('Matière'),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedSubjectId,
                                  isExpanded: true,
                                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade400, size: 20),
                                  hint: Row(children: [
                                    Icon(Icons.menu_book_rounded, size: 18, color: Colors.grey.shade400),
                                    const SizedBox(width: 10),
                                    Text('Sélectionner une matière', style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
                                  ]),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                                  borderRadius: BorderRadius.circular(12),
                                  items: allSubjects.map((s) => DropdownMenuItem(
                                    value: s['id'] as String,
                                    child: Text(s['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                                  )).toList(),
                                  onChanged: (v) => setDialogState(() => selectedSubjectId = v),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),
                            Divider(color: Colors.grey.shade100),
                            const SizedBox(height: 20),

                            // ── Niveaux Section ──
                            _sectionHeader('Niveaux & Classes'),
                            const SizedBox(height: 12),
                            _fieldLabel('Niveaux assignés'),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                // Selected niveaux pills
                                if (selectedNiveauIds.isNotEmpty)
                                  Wrap(
                                    spacing: 8, runSpacing: 8,
                                    children: selectedNiveauIds.map((nId) {
                                      final nv = allNiveaux.firstWhere((n) => n['id'] == nId, orElse: () => {'name': nId});
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(8)),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Text(nv['name']?.toString() ?? nId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brand)),
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap: () => setDialogState(() {
                                              selectedNiveauIds.remove(nId);
                                              selectedClassIdsByNiveau.remove(nId);
                                              selectedSectionIdsByNiveau.remove(nId);
                                            }),
                                            child: const Icon(Icons.close_rounded, size: 14, color: _brand),
                                          ),
                                        ]),
                                      );
                                    }).toList(),
                                  ),
                                if (selectedNiveauIds.isNotEmpty) const SizedBox(height: 8),
                                // Add niveau dropdown
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: null,
                                      isExpanded: true,
                                      hint: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 12),
                                        child: Text('+ Ajouter un niveau', style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      borderRadius: BorderRadius.circular(12),
                                      items: allNiveaux
                                          .where((n) => !selectedNiveauIds.contains(n['id']))
                                          .map((n) => DropdownMenuItem(
                                            value: n['id'] as String,
                                            child: Text(n['name']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                                          )).toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setDialogState(() {
                                            selectedNiveauIds.add(v);
                                            selectedClassIdsByNiveau.putIfAbsent(v, () => {});
                                            selectedSectionIdsByNiveau.putIfAbsent(v, () => {});
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                            const SizedBox(height: 20),
                            // ── Classes per niveau ──
                            if (selectedNiveauIds.isNotEmpty) ...[
                              _fieldLabel('Classes par niveau'),
                              const SizedBox(height: 8),
                              ...selectedNiveauIds.map((nId) {
                                final nv = allNiveaux.firstWhere((n) => n['id'] == nId, orElse: () => {'name': nId});
                                final niveauClasses = allClasses.where((c) => c['niveau_id'] == nId).toList();
                                final selectedIds = selectedClassIdsByNiveau[nId] ?? {};

                                // Auto-detect sections: collect unique non-null section_ids from classes
                                final sectionsMap = <String, Map<String, dynamic>>{};
                                for (final c in niveauClasses) {
                                  final sectionId = c['section_id']?.toString();
                                  final sectionData = c['sections'];
                                  if (sectionId != null && sectionId.isNotEmpty && sectionData != null) {
                                    sectionsMap[sectionId] = Map<String, dynamic>.from(sectionData as Map);
                                  }
                                }

                                // If this niveau has sections, show section-based UI
                                if (sectionsMap.isNotEmpty) {
                                  final sectionsList = sectionsMap.values.toList()
                                    ..sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
                                  final selectedSectionIds = selectedSectionIdsByNiveau.putIfAbsent(nId, () => {});

                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      // Niveau label + count
                                      Row(children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(6)),
                                          child: Text(nv['name']?.toString() ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _brand)),
                                        ),
                                        const Spacer(),
                                        Text('${selectedIds.length}/${niveauClasses.length}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                                      ]),
                                      const SizedBox(height: 12),
                                      // Section chips row
                                      Text('Sections', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8, runSpacing: 8,
                                        children: sectionsList.map((sec) {
                                          final sId = sec['id']?.toString() ?? '';
                                          final isSecSelected = selectedSectionIds.contains(sId);
                                          final sectionClasses = niveauClasses.where((c) => c['section_id']?.toString() == sId).toList();
                                          return InkWell(
                                            onTap: () => setDialogState(() {
                                              if (isSecSelected) {
                                                selectedSectionIds.remove(sId);
                                                for (final c in sectionClasses) {
                                                  selectedClassIdsByNiveau[nId]?.remove(c['id']?.toString());
                                                }
                                              } else {
                                                selectedSectionIds.add(sId);
                                              }
                                            }),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                              decoration: BoxDecoration(
                                                color: isSecSelected ? _brandLight : const Color(0xFFF3F4F6),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: isSecSelected ? _brand.withOpacity(0.4) : Colors.grey.shade200),
                                              ),
                                              child: Text(
                                                sec['name']?.toString() ?? '',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isSecSelected ? _brand : AppColors.textSecondary),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      // Classes per selected section
                                      if (selectedSectionIds.isNotEmpty) ...[
                                        const SizedBox(height: 14),
                                        ...selectedSectionIds.map((sId) {
                                          final secData = sectionsMap[sId];
                                          if (secData == null) return const SizedBox.shrink();
                                          final sectionClasses = niveauClasses.where((c) => c['section_id']?.toString() == sId).toList();
                                          final allSelected = sectionClasses.isNotEmpty && sectionClasses.every((c) => selectedIds.contains(c['id']?.toString()));
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF9FAFB),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: _brand.withOpacity(0.15)),
                                            ),
                                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Row(children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(5)),
                                                  child: Text(secData['code']?.toString() ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(secData['name']?.toString() ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                                const Spacer(),
                                                GestureDetector(
                                                  onTap: () => setDialogState(() {
                                                    for (final c in sectionClasses) {
                                                      final cId = c['id']?.toString() ?? '';
                                                      if (allSelected) {
                                                        selectedClassIdsByNiveau[nId]?.remove(cId);
                                                      } else {
                                                        selectedClassIdsByNiveau[nId]?.add(cId);
                                                      }
                                                    }
                                                  }),
                                                  child: Text(
                                                    allSelected ? 'Tout désélectionner' : 'Tout sélectionner',
                                                    style: const TextStyle(fontSize: 11, color: _brand, fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                              ]),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 6, runSpacing: 6,
                                                children: sectionClasses.map((c) {
                                                  final cId = c['id']?.toString() ?? '';
                                                  final isSelected = selectedIds.contains(cId);
                                                  return InkWell(
                                                    onTap: () => setDialogState(() {
                                                      if (isSelected) {
                                                        selectedClassIdsByNiveau[nId]!.remove(cId);
                                                      } else {
                                                        selectedClassIdsByNiveau[nId]!.add(cId);
                                                      }
                                                    }),
                                                    borderRadius: BorderRadius.circular(7),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                      decoration: BoxDecoration(
                                                        color: isSelected ? _brand : Colors.white,
                                                        borderRadius: BorderRadius.circular(7),
                                                        border: Border.all(color: isSelected ? _brand : Colors.grey.shade300),
                                                      ),
                                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                        if (isSelected) ...[
                                                          const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                                                          const SizedBox(width: 3),
                                                        ],
                                                        Text(c['name']?.toString() ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isSelected ? Colors.white : AppColors.textPrimary)),
                                                      ]),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ]),
                                          );
                                        }),
                                      ],
                                    ]),
                                  );
                                }

                                // No sections — flat class list
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: _brandLight, borderRadius: BorderRadius.circular(6)),
                                        child: Text(nv['name']?.toString() ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _brand)),
                                      ),
                                      const Spacer(),
                                      Text('${selectedIds.length}/${niveauClasses.length}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                                    ]),
                                    const SizedBox(height: 8),
                                    if (niveauClasses.isEmpty)
                                      Text('Aucune classe dans ce niveau', style: TextStyle(fontSize: 12, color: Colors.grey.shade400))
                                    else
                                      Wrap(
                                        spacing: 8, runSpacing: 8,
                                        children: niveauClasses.map((c) {
                                          final cId = c['id']?.toString() ?? '';
                                          final isSelected = selectedIds.contains(cId);
                                          return InkWell(
                                            onTap: () => setDialogState(() {
                                              if (isSelected) {
                                                selectedClassIdsByNiveau[nId]!.remove(cId);
                                              } else {
                                                selectedClassIdsByNiveau[nId]!.add(cId);
                                              }
                                            }),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isSelected ? _brand : const Color(0xFFF9FAFB),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: isSelected ? _brand : Colors.grey.shade200),
                                              ),
                                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                if (isSelected) ...[
                                                  const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                                                  const SizedBox(width: 4),
                                                ],
                                                Text(c['name']?.toString() ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isSelected ? Colors.white : AppColors.textPrimary)),
                                              ]),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                  ]),
                                );
                              }),
                              const SizedBox(height: 4),
                            ],
                          ]),
                        ),
                      ),
                      // Bottom buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                        child: Column(children: [
                          Divider(height: 1, color: Colors.grey.shade200),
                          const SizedBox(height: 14),
                          Row(children: [
                            const Spacer(),
                            SizedBox(
                              height: 40,
                              child: TextButton(
                                onPressed: () => Navigator.of(ctx).pop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF6B7280),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                ),
                                child: const Text('Annuler', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 40,
                              child: ElevatedButton.icon(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        setDialogState(() => saving = true);
                                        try {
                                          final supabase = SupabaseConfig.adminClient;

                                          // 1. Update user profile fields
                                          final updates = <String, dynamic>{};
                                          final newName = nameCtrl.text.trim();
                                          final newEmail = emailCtrl.text.trim();
                                          final newPhone = phoneCtrl.text.trim();
                                          if (newName.isNotEmpty && newName != _user?['full_name']) updates['full_name'] = newName;
                                          if (newEmail.isNotEmpty && newEmail != _user?['email']) updates['email'] = newEmail;
                                          if (newPhone != (_user?['phone'] ?? '')) updates['phone'] = newPhone;

                                          if (updates.isNotEmpty) {
                                            await supabase.from('users').update(updates).eq('id', widget.teacherId);
                                          }

                                          // 2. Sync teacher_assignments: delete removed, add new
                                          // Deactivate all current assignments
                                          for (final a in originalAssignments) {
                                            final aId = a['id']?.toString();
                                            if (aId != null && aId.isNotEmpty) {
                                              await supabase.from('teacher_assignments').update({'is_active': false}).eq('id', aId);
                                            }
                                          }

                                          // Build new assignment set from selected niveaux + classes
                                          for (final nId in selectedNiveauIds) {
                                            final classIds = selectedClassIdsByNiveau[nId] ?? {};
                                            if (classIds.isEmpty) {
                                              // Assigned to niveau but no specific class
                                              await supabase.from('teacher_assignments').insert({
                                                'teacher_id': widget.teacherId,
                                                'subject_id': selectedSubjectId,
                                                'niveau_id': nId,
                                                'class_id': null,
                                                'school_id': schoolId,
                                                'is_active': true,
                                              });
                                            } else {
                                              // One assignment per class
                                              for (final cId in classIds) {
                                                await supabase.from('teacher_assignments').insert({
                                                  'teacher_id': widget.teacherId,
                                                  'subject_id': selectedSubjectId,
                                                  'niveau_id': nId,
                                                  'class_id': cId,
                                                  'school_id': schoolId,
                                                  'is_active': true,
                                                });
                                              }
                                            }
                                          }

                                          if (ctx.mounted) Navigator.of(ctx).pop();
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: const Text('Profil et affectations mis à jour'), backgroundColor: const Color(0xFF16A34A), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                            );
                                            setState(() => _loading = true);
                                            _classDetails = [];
                                            _subjects = {};
                                            _niveaux = {};
                                            _loadData();
                                          }
                                        } catch (e) {
                                          setDialogState(() => saving = false);
                                          if (ctx.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                            );
                                          }
                                        }
                                      },
                                icon: saving
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.check_rounded, size: 17),
                                label: const Text('Enregistrer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6D4CF6),
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  disabledBackgroundColor: Colors.grey.shade300,
                                ),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(children: [
      Container(width: 3, height: 16, decoration: BoxDecoration(color: const Color(0xFF6D4CF6), borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: 0.8)),
    ]);
  }

  Widget _fieldLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400),
        prefixIcon: Icon(icon, size: 18, color: AppColors.textTertiary),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
