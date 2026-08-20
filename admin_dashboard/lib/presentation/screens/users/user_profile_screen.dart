import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/ios_loader.dart';
import '../../../core/config/supabase_config.dart';
import '../../../data/models/user_model.dart';
import '../../providers/users_provider.dart';
import 'user_form_dialog.dart';

// ==================== USER PROFILE DATA MODEL ====================
class UserProfileData {
  final Map<String, dynamic> user;
  final Map<String, dynamic>? enrollment;
  final String? className;
  final String? groupName;
  final int yearsAtSchool;
  final List<Map<String, dynamic>> suggestions;
  final List<Map<String, dynamic>> monthlyAbsences;
  final int totalAbsences;
  final int justifiedAbsences;
  final List<Map<String, dynamic>> payments;
  final double paymentAccuracy;
  final int onTimePayments;
  final int latePayments;
  final double totalPaid;
  final double totalDue;
  final List<Map<String, dynamic>> grades;
  final List<Map<String, dynamic>> timetable;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> activityLog;

  UserProfileData({
    required this.user,
    this.enrollment,
    this.className,
    this.groupName,
    this.yearsAtSchool = 0,
    this.suggestions = const [],
    this.monthlyAbsences = const [],
    this.totalAbsences = 0,
    this.justifiedAbsences = 0,
    this.payments = const [],
    this.paymentAccuracy = 0,
    this.onTimePayments = 0,
    this.latePayments = 0,
    this.totalPaid = 0,
    this.totalDue = 0,
    this.grades = const [],
    this.timetable = const [],
    this.messages = const [],
    this.activityLog = const [],
  });
}

// ==================== PROFILE PROVIDER ====================
final userProfileDataProvider = FutureProvider.family<UserProfileData?, String>((
  ref,
  userId,
) async {
  final supabase = Supabase.instance.client;

  try {
    // Get user basic info
    final userResponse = await supabase
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (userResponse == null) return null;

    // Get enrollment info with class and niveau
    Map<String, dynamic>? enrollment;
    String? className;
    String? groupName;
    String? niveauCodeFromEnrollment;

    try {
      enrollment = await supabase
          .from('enrollments')
          .select(
            '*, classes(id, name, niveau_id, niveaux(code, name)), groups(name)',
          )
          .eq('user_id', userId)
          .maybeSingle();

      debugPrint('Profile: Enrollment for $userId: $enrollment');
      if (enrollment != null) {
        final classInfo = enrollment['classes'] as Map<String, dynamic>?;
        className = classInfo?['name'];
        final niveauInfo = classInfo?['niveaux'] as Map<String, dynamic>?;
        niveauCodeFromEnrollment = niveauInfo?['code'];
        groupName = enrollment['groups']?['name'];
        debugPrint(
          'Profile: className=$className, niveau=$niveauCodeFromEnrollment, groupName=$groupName',
        );
      }
    } catch (e) {
      debugPrint('Profile: Error loading enrollment: $e');
    }

    // Update user data with niveau from enrollment if not set
    final userData = Map<String, dynamic>.from(userResponse);
    if (userData['niveau_code'] == null && niveauCodeFromEnrollment != null) {
      userData['niveau_code'] = niveauCodeFromEnrollment;
    }

    // Calculate years at school
    int yearsAtSchool = 0;
    if (userResponse['created_at'] != null) {
      final createdAt = DateTime.tryParse(userResponse['created_at']);
      if (createdAt != null) {
        yearsAtSchool = DateTime.now().difference(createdAt).inDays ~/ 365;
        if (yearsAtSchool == 0) yearsAtSchool = 1;
      }
    }

    // Get suggestions
    List<Map<String, dynamic>> suggestions = [];
    try {
      final resp = await supabase
          .from('suggestions')
          .select('id, subject, status, suggestion_type, created_at')
          .eq('student_id', userId)
          .order('created_at', ascending: false)
          .limit(10);
      suggestions = (resp as List).cast<Map<String, dynamic>>();
    } catch (_) {}

    // Get all absences (for calendar display across months)
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    List<Map<String, dynamic>> monthlyAbsences = [];
    int totalAbsences = 0;
    int justifiedAbsences = 0;

    try {
      final resp = await supabase
          .from('absence_records')
          .select('date, hours_absent, justified, enrollment_id')
          .order('date');
      monthlyAbsences = (resp as List).cast<Map<String, dynamic>>();
      // Count current month absences for stats
      final currentMonthAbsences = monthlyAbsences.where((a) {
        final d = DateTime.tryParse(a['date'] as String? ?? '');
        return d != null && d.year == now.year && d.month == now.month;
      }).toList();
      totalAbsences = currentMonthAbsences.length;
      justifiedAbsences = currentMonthAbsences
          .where((a) => a['justified'] == true)
          .length;
    } catch (_) {}

    // Get payments and calculate accuracy
    List<Map<String, dynamic>> payments = [];
    double paymentAccuracy = 0;
    int onTimePayments = 0;
    int latePayments = 0;
    double totalPaid = 0;
    double totalDue = 0;

    try {
      final resp = await supabase
          .from('payments')
          .select('amount, status, due_date, paid_at, description, created_at')
          .order('created_at', ascending: false);
      payments = (resp as List).cast<Map<String, dynamic>>();

      for (final p in payments) {
        final amount = (p['amount'] as num?)?.toDouble() ?? 0;

        if (p['status'] == 'paid') {
          totalPaid += amount;
          if (p['due_date'] != null && p['paid_at'] != null) {
            final dueDate = DateTime.parse(p['due_date']);
            final paidAt = DateTime.parse(p['paid_at']);
            if (paidAt.isBefore(dueDate) || paidAt.isAtSameMomentAs(dueDate)) {
              onTimePayments++;
            } else {
              latePayments++;
            }
          } else {
            onTimePayments++;
          }
        } else {
          totalDue += amount;
          if (p['status'] == 'overdue') latePayments++;
        }
      }

      final total = onTimePayments + latePayments;
      if (total > 0) paymentAccuracy = (onTimePayments / total) * 100;
    } catch (_) {}

    // Get grades
    List<Map<String, dynamic>> grades = [];
    try {
      final resp = await supabase
          .from('grades')
          .select('grade_value, status, subjects(name)')
          .order('created_at', ascending: false)
          .limit(10);
      grades = (resp as List).cast<Map<String, dynamic>>();
    } catch (_) {}

    // Get timetable
    List<Map<String, dynamic>> timetable = [];
    try {
      final resp = await supabase
          .from('timetable_slots')
          .select('*, subjects(name)')
          .order('day_of_week')
          .order('start_time');
      timetable = (resp as List).cast<Map<String, dynamic>>();
    } catch (_) {}

    // Get class messages
    List<Map<String, dynamic>> messages = [];
    try {
      if (enrollment != null && enrollment['class_id'] != null) {
        final resp = await supabase
            .from('announcements')
            .select('id, title, body, published_at')
            .order('published_at', ascending: false)
            .limit(5);
        messages = (resp as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    // Build activity log from real data
    List<Map<String, dynamic>> activityLog = [];
    for (final a in monthlyAbsences) {
      activityLog.add({
        'action': 'Absence',
        'details': a['justified'] == true
            ? 'Absence justifiée (${a['hours_absent'] ?? 1}h)'
            : 'Absence non justifiée (${a['hours_absent'] ?? 1}h)',
        'date': a['date'],
        'type': a['justified'] == true ? 'warning' : 'error',
      });
    }
    for (final p in payments) {
      activityLog.add({
        'action': 'Paiement',
        'details': '${p['description'] ?? 'Paiement'} - ${((p['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} DT (${p['status'] ?? 'en attente'})',
        'date': p['paid_at'] ?? p['created_at'],
        'type': p['status'] == 'paid' ? 'success' : 'info',
      });
    }
    for (final s in suggestions) {
      activityLog.add({
        'action': 'Suggestion',
        'details': s['subject'] ?? 'Suggestion envoyée',
        'date': s['created_at'],
        'type': 'purple',
      });
    }
    for (final m in messages) {
      activityLog.add({
        'action': 'Annonce',
        'details': m['title'] ?? 'Annonce de classe',
        'date': m['published_at'],
        'type': 'info',
      });
    }
    activityLog.sort((a, b) {
      final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return UserProfileData(
      user: userData,
      enrollment: enrollment,
      className: className,
      groupName: groupName,
      yearsAtSchool: yearsAtSchool,
      suggestions: suggestions,
      monthlyAbsences: monthlyAbsences,
      totalAbsences: totalAbsences,
      justifiedAbsences: justifiedAbsences,
      payments: payments,
      paymentAccuracy: paymentAccuracy,
      onTimePayments: onTimePayments,
      latePayments: latePayments,
      totalPaid: totalPaid,
      totalDue: totalDue,
      grades: grades,
      timetable: timetable,
      messages: messages,
      activityLog: activityLog,
    );
  } catch (e) {
    debugPrint('Error loading profile: $e');
    return null;
  }
});

// ==================== MAIN PROFILE SCREEN ====================
class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String? userName;
  final bool isDialogMode;
  final VoidCallback? onBack;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.userName,
    this.isDialogMode = false,
    this.onBack,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  bool _isUploadingPhoto = false;
  bool _showPassword = false;
  bool _isResettingPassword = false;
  int _selectedMonthOffset = 0;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileDataProvider(widget.userId));

    final content = profileAsync.when(
      loading: () => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.card,
          ),
          child: const IosLoader(color: AppColors.primary),
        ),
      ),
      error: (e, _) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.error.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Erreur: $e', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ),
      data: (data) {
        if (data == null) return _buildNotFound();
        // Redirect teachers to their dedicated profile page
        if (data.user['role'] == 'teacher') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/teachers/${widget.userId}');
          });
          return const Center(child: IosLoader(color: AppColors.primary));
        }
        return _buildProfile(context, data);
      },
    );

    if (widget.isDialogMode) {
      return Dialog.fullscreen(
        backgroundColor: AppColors.background,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: content,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/users'),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.slate300, AppColors.slate400]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_off_rounded, size: 48, color: AppColors.textOnPrimary),
            ),
            const SizedBox(height: 24),
            Text('Utilisateur non trouvé',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.slate700)),
            const SizedBox(height: 8),
            Text("L'utilisateur demandé n'existe pas ou a été supprimé.",
                style: TextStyle(color: AppColors.slate500)),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded, color: AppColors.textOnPrimary),
                        SizedBox(width: 8),
                        Text('Retour', style: TextStyle(color: AppColors.textOnPrimary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== MAIN PROFILE LAYOUT ====================
  Widget _buildProfile(BuildContext context, UserProfileData data) {
    final user = data.user;
    final fullName = user['full_name'] as String? ?? 'Nom inconnu';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(fullName, user),
          const SizedBox(height: 32),
          // 2-col grid: Left sidebar + Right content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column (profile card + security)
              SizedBox(
                width: 360,
                child: Column(
                  children: [
                    _buildProfileCard(data),
                    const SizedBox(height: 24),
                    _buildSecurityCard(data),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // Right Column (stats + calendar/payments + activity)
              Expanded(
                child: Column(
                  children: [
                    _buildStatsGrid(data),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildPresenceCalendar(data)),
                        const SizedBox(width: 32),
                        Expanded(child: _buildPaymentsCard(data)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildActivityLog(data),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== HEADER ====================
  Widget _buildHeader(String fullName, Map<String, dynamic> user) {
    final isStudent = user['role'] == 'student';
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.slate100)),
      ),
      child: Row(
        children: [
          _iconButton(icon: Icons.arrow_back_rounded, onTap: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/users');
            }
          }),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3)),
                Text(
                  isStudent ? 'Profil étudiant' : 'Profil utilisateur',
                  style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _outlineButton(icon: Icons.edit_outlined, label: 'Modifier', onTap: () => _showEditDialog(user)),
              _brandOutlineButton(label: 'Réinitialiser mot de passe', onTap: _isResettingPassword ? null : () => _resetPassword(user), isLoading: _isResettingPassword),
              if (isStudent) ...[
                _brandOutlineButton(label: 'Envoyer message élève', onTap: () => _sendMessageToStudent(user)),
                _successButton(icon: Icons.login_rounded, label: 'Se connecter en tant que', onTap: () => _loginAsStudent(user)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> user) {
    // Convert map to UserModel for editing
    final userModel = UserModel(
      id: user['id'] ?? widget.userId,
      schoolId: user['school_id'],
      role: user['role'] ?? 'student',
      fullName: user['full_name'] ?? '',
      email: user['email'] ?? '',
      phone: user['phone'],
      photoUrl: user['photo_url'],
      studentCode: user['student_code'],
      dateOfBirth: user['date_of_birth'] != null
          ? DateTime.tryParse(user['date_of_birth'].toString())
          : null,
      address: user['address'],
      gender: user['gender'],
      nationality: user['nationality'],
      niveau: user['niveau'],
      niveauCode: user['niveau_code'],
      sectionCode: user['section_code'],
      initialPassword: user['initial_password'],
      createdAt: user['created_at'] != null
          ? DateTime.parse(user['created_at'])
          : DateTime.now(),
      updatedAt: user['updated_at'] != null
          ? DateTime.parse(user['updated_at'])
          : DateTime.now(),
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => UserFormDialog(user: userModel),
    ).then((_) {
      // Refresh profile after dialog closes
      ref.invalidate(userProfileDataProvider(widget.userId));
    });
  }

  void _sendMessageToStudent(Map<String, dynamic> user) {
    // Navigate to announcements screen with student scope pre-selected
    context.go(
      '/announcements',
      extra: {'initialScope': 'student', 'preSelectedStudentId': user['id']},
    );
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          title: const Text('Réinitialiser le mot de passe'),
          content: Text(
            'Voulez-vous générer un nouveau mot de passe pour ${user['full_name']} ?',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 40,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 2,
                    ),
                    child: const Text('Confirmer', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    setState(() => _isResettingPassword = true);

    try {
      final newPassword = await ref
          .read(usersProvider.notifier)
          .resetUserPassword(widget.userId);

      if (newPassword != null && mounted) {
        ref.invalidate(userProfileDataProvider(widget.userId));
        showDialog(
          context: context,
          barrierColor: Colors.black.withOpacity(0.08),
          builder: (ctx) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: 12),
                const Text('Mot de passe réinitialisé'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nouveau mot de passe :'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          newPassword,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: newPassword));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mot de passe copié !'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D4CF6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Fermer'),
              ),
            ],
          ),
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
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  Future<void> _setPasswordManually(Map<String, dynamic> user) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;

    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
          title: const Text('Définir le mot de passe'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entrez le mot de passe actuel de ${user['full_name']} pour le sauvegarder.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setDialogState(
                        () => obscurePassword = !obscurePassword,
                      ),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Requis' : null,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    final generated = _generateRandomPassword();
                    passwordController.text = generated;
                  },
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  label: const Text('Générer automatiquement'),
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
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, passwordController.text);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6D4CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      // Save the password to initial_password field
      await Supabase.instance.client
          .from('users')
          .update({
            'initial_password': result,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.userId);

      // Refresh the profile
      ref.invalidate(userProfileDataProvider(widget.userId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe sauvegardé avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _generateRandomPassword() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(
      10,
      (i) => chars[(random + i * 7) % chars.length],
    ).join();
  }

  Future<void> _loginAsStudent(Map<String, dynamic> user) async {
    final email = user['email'] as String?;
    final initialPassword = user['initial_password'] as String?;
    final fullName = user['full_name'] as String? ?? 'cet étudiant';

    if (email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cet utilisateur n\'a pas d\'email'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // If we have the password saved, show credentials directly
    if (initialPassword != null) {
      _showLoginCredentialsDialog(email, initialPassword, fullName);
      return;
    }

    // Otherwise, ask if they want to reset the password
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          title: const Text('Mot de passe non enregistré'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Le mot de passe de $fullName n\'est pas enregistré.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Voulez-vous réinitialiser son mot de passe pour pouvoir vous connecter ?',
              style: TextStyle(fontSize: 14),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Réinitialiser et connecter'),
          ),
        ],
        ),
      ),
    );

    if (confirm != true) return;

    // Reset password
    setState(() => _isResettingPassword = true);
    try {
      final newPassword = await ref
          .read(usersProvider.notifier)
          .resetUserPassword(widget.userId);

      if (newPassword != null && mounted) {
        ref.invalidate(userProfileDataProvider(widget.userId));
        _showLoginCredentialsDialog(email, newPassword, fullName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isResettingPassword = false);
    }
  }

  void _showLoginCredentialsDialog(
    String email,
    String password,
    String fullName,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.login, color: AppColors.success),
            const SizedBox(width: 12),
            const Text('Connexion en tant qu\'étudiant'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Utilisez ces identifiants pour vous connecter à l\'application étudiant en tant que $fullName :',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildCredentialRow('Email', email),
            const SizedBox(height: 8),
            _buildCredentialRow('Mot de passe', password),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFF6D4CF6),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ouvrez l\'application mobile PythaOne et connectez-vous avec ces identifiants.',
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF6D4CF6),
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
                child: TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: 'Email: $email\nMot de passe: $password'),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Identifiants copiés !'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  icon: const Icon(Icons.copy_all, size: 16),
                  label: const Text('Copier tout', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D4CF6),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Widget _buildCredentialRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.slate100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.slate700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$label copié !'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copié !'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ==================== PROFILE CARD (LEFT SIDEBAR) ====================
  Widget _buildProfileCard(UserProfileData data) {
    final user = data.user;
    final photoUrl = user['photo_url'] as String?;
    final role = user['role'] as String? ?? 'student';
    final isStudent = role == 'student';
    final fullName = user['full_name'] as String? ?? 'Nom inconnu';
    final studentCode = user['student_code'] as String?;
    final niveauCode = user['niveau_code'] as String?;
    final sectionCode = user['section_code'] as String?;
    final legacyNiveau = user['niveau'] as String?;
    final gender = user['gender'] as String?;
    final nationality = user['nationality'] as String?;
    final dateOfBirth = user['date_of_birth'] as String?;

    int? age;
    if (dateOfBirth != null) {
      final dob = DateTime.tryParse(dateOfBirth);
      if (dob != null) {
        age = DateTime.now().difference(dob).inDays ~/ 365;
      }
    }

    final niveauDisplay = niveauCode ?? legacyNiveau ?? '-';
    final classeDisplay = (data.className != null && data.className!.isNotEmpty) ? data.className! : (sectionCode ?? '-');

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              UserAvatar(
                name: fullName,
                photoUrl: photoUrl,
                radius: 50,
                gender: data.user['gender'] as String?,
              ),
              GestureDetector(
                onTap: _pickAndUploadPhoto,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 2),
                    boxShadow: AppShadows.sm,
                  ),
                  child: _isUploadingPhoto
                      ? const IosLoader.small()
                      : Icon(Icons.camera_alt_rounded, size: 14, color: AppColors.slate500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Name
          Text(fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.slate800), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getRoleColor(role).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getRoleColor(role).withOpacity(0.3)),
            ),
            child: Text(_getRoleLabel(role), style: TextStyle(color: _getRoleColor(role), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          if (studentCode != null) ...[
            const SizedBox(height: 6),
            Text(studentCode, style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: 24),
          // Info Rows
          if (isStudent) ...[
            _profileInfoRow('Niveau', niveauDisplay),
            _profileInfoRow('Classe', classeDisplay),
            if (data.groupName != null && data.groupName!.isNotEmpty) _profileInfoRow('Groupe', data.groupName!),
            _profileInfoRow('Genre', gender ?? '-'),
            if (age != null) _profileInfoRow('Âge', '$age ans'),
            _profileInfoRow('Nationalité', nationality ?? '-'),
          ] else ...[
            _profileInfoRow('Rôle', _getRoleLabel(role)),
            _profileInfoRow('Email', user['email'] ?? '-'),
            if (user['phone'] != null) _profileInfoRow('Téléphone', user['phone']),
            _profileInfoRow('Créé le', _formatDate(user['created_at'])),
          ],
          const SizedBox(height: 20),
          // Separator
          Divider(color: AppColors.border, thickness: 1),
          const SizedBox(height: 16),
          // Contact Rapide
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Contact Rapide', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.slate500)),
          ),
          const SizedBox(height: 12),
          _contactRow(Icons.email_outlined, user['email'] ?? '-'),
          const SizedBox(height: 8),
          _contactRow(Icons.phone_outlined, user['phone'] ?? '-'),
          if (user['address'] != null) ...[
            const SizedBox(height: 8),
            _contactRow(Icons.location_on_outlined, user['address']),
          ],
        ],
      ),
    );
  }

  Widget _profileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: AppColors.slate400, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.slate700, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: AppColors.slate600, fontSize: 13), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  // ==================== SECURITY CARD ====================
  Widget _buildSecurityCard(UserProfileData data) {
    final user = data.user;
    final initialPassword = user['initial_password'] as String?;

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: AppColors.slate500),
              const SizedBox(width: 8),
              const Text('Sécurité', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.slate800)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Mot de passe initial', style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    initialPassword != null
                        ? (_showPassword ? initialPassword : '•' * initialPassword.length)
                        : 'Non défini',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: initialPassword != null ? 'monospace' : null,
                      color: initialPassword != null ? AppColors.slate700 : AppColors.slate400,
                    ),
                  ),
                ),
                if (initialPassword != null) ...[
                  _miniIconBtn(
                    icon: _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    onTap: () => setState(() => _showPassword = !_showPassword),
                  ),
                  const SizedBox(width: 4),
                  _miniIconBtn(
                    icon: Icons.copy_outlined,
                    onTap: () => _copyToClipboard(initialPassword, 'Mot de passe'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== STATS GRID ====================
  Widget _buildStatsGrid(UserProfileData data) {
    return Row(
      children: [
        Expanded(child: _statCard('Absences ce mois', '${data.monthlyAbsences.length}', Icons.event_busy_outlined, AppColors.error, AppColors.errorSoft)),
        const SizedBox(width: 16),
        Expanded(child: _statCard('Justifiées', '${data.justifiedAbsences}', Icons.verified_outlined, AppColors.success, AppColors.successSoft)),
        const SizedBox(width: 16),
        Expanded(child: _statCard('Suggestions', '${data.suggestions.length}', Icons.lightbulb_outline, AppColors.warning, AppColors.warningSoft)),
        const SizedBox(width: 16),
        Expanded(child: _statCard('Notes récentes', '${data.grades.length}', Icons.grade_outlined, AppColors.primary, AppColors.primarySoft)),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, Color bgColor) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: AppColors.slate400, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== PRESENCE CALENDAR ====================
  Widget _buildPresenceCalendar(UserProfileData data) {
    final now = DateTime.now();
    final targetMonth = now.month + _selectedMonthOffset;
    final targetDate = DateTime(now.year, targetMonth, 1);
    const frenchMonths = ['Janvier','Février','Mars','Avril','Mai','Juin','Juillet','Août','Septembre','Octobre','Novembre','Décembre'];
    final monthLabel = '${frenchMonths[targetDate.month - 1]} ${targetDate.year}';

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Présence ce mois', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.slate800)),
              const Spacer(),
              _miniIconBtn(icon: Icons.chevron_left_rounded, onTap: () => setState(() => _selectedMonthOffset--)),
              const SizedBox(width: 4),
              Text(monthLabel, style: TextStyle(color: AppColors.slate500, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              _miniIconBtn(icon: Icons.chevron_right_rounded, onTap: _selectedMonthOffset < 0 ? () => setState(() => _selectedMonthOffset++) : null),
            ],
          ),
          const SizedBox(height: 16),
          _buildCalendarGrid(data, targetDate),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(AppColors.success, 'Présent'),
              const SizedBox(width: 16),
              _legendDot(AppColors.error, 'Absent'),
              const SizedBox(width: 16),
              _legendDot(AppColors.warning, 'Justifié'),
              const SizedBox(width: 16),
              _legendDot(AppColors.slate200, 'Pas de cours'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(UserProfileData data, DateTime targetDate) {
    final year = targetDate.year;
    final month = targetDate.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday; // 1=Mon

    // Build absence map for the month
    final Map<int, String> absenceMap = {};
    for (final abs in data.monthlyAbsences) {
      final dateStr = abs['date'] as String?;
      if (dateStr == null) continue;
      final d = DateTime.tryParse(dateStr);
      if (d != null && d.year == year && d.month == month) {
        final justified = abs['justified'] == true;
        absenceMap[d.day] = justified ? 'justified' : 'absent';
      }
    }

    final dayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Column(
      children: [
        // Header row
        Row(
          children: dayLabels.map((d) => Expanded(
            child: Center(child: Text(d, style: TextStyle(color: AppColors.slate400, fontSize: 11, fontWeight: FontWeight.w600))),
          )).toList(),
        ),
        const SizedBox(height: 8),
        // Calendar cells
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [
            // Empty cells before first day
            for (int i = 1; i < firstWeekday; i++)
              const SizedBox(),
            // Day cells
            for (int day = 1; day <= daysInMonth; day++)
              _buildDayCell(day, absenceMap[day], DateTime(year, month, day)),
          ],
        ),
      ],
    );
  }

  Widget _buildDayCell(int day, String? absenceStatus, DateTime date) {
    final isWeekend = date.weekday == 6 || date.weekday == 7;
    final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;

    Color bgColor;
    Color textColor;

    if (absenceStatus == 'absent') {
      bgColor = AppColors.error;
      textColor = Colors.white;
    } else if (absenceStatus == 'justified' || absenceStatus == 'justifié') {
      bgColor = AppColors.warning;
      textColor = Colors.white;
    } else if (absenceStatus != null) {
      // present or other status
      bgColor = AppColors.success;
      textColor = Colors.white;
    } else if (isWeekend) {
      bgColor = AppColors.slate100;
      textColor = AppColors.slate400;
    } else if (date.isAfter(DateTime.now())) {
      bgColor = AppColors.slate50;
      textColor = AppColors.slate300;
    } else {
      // Past day with no record = present (was at school)
      bgColor = AppColors.success.withOpacity(0.15);
      textColor = AppColors.success;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isToday ? Border.all(color: AppColors.primary, width: 2) : null,
      ),
      child: Center(
        child: Text('$day', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: AppColors.slate500, fontSize: 11)),
      ],
    );
  }

  // ==================== PAYMENTS CARD ====================
  Widget _buildPaymentsCard(UserProfileData data) {
    final totalDue = data.totalDue;
    final totalPaid = data.totalPaid;
    final pct = totalDue > 0 ? (totalPaid / totalDue * 100).clamp(0.0, 100.0) : 0.0;

    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Paiements', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.slate800)),
          const SizedBox(height: 24),
          // Donut chart
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: CustomPaint(
                painter: _DonutPainter(percentage: pct, color: pct >= 75 ? AppColors.success : (pct >= 50 ? AppColors.warning : AppColors.error)),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.slate800)),
                      Text('Payé', style: TextStyle(color: AppColors.slate400, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _paymentItem('Total dû', '${totalDue.toStringAsFixed(0)} DH', AppColors.slate500),
          const SizedBox(height: 8),
          _paymentItem('Total payé', '${totalPaid.toStringAsFixed(0)} DH', AppColors.success),
          const SizedBox(height: 8),
          _paymentItem('Reste', '${(totalDue - totalPaid).toStringAsFixed(0)} DH', AppColors.error),
          const SizedBox(height: 8),
          _paymentItem('À temps', '${data.onTimePayments}', AppColors.primary),
          const SizedBox(height: 8),
          _paymentItem('En retard', '${data.latePayments}', AppColors.warning),
        ],
      ),
    );
  }

  Widget _paymentItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: AppColors.slate500, fontSize: 13)),
        const Spacer(),
        Text(value, style: TextStyle(color: AppColors.slate700, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ==================== ACTIVITY LOG ====================
  Widget _buildActivityLog(UserProfileData data) {
    final activities = data.activityLog;
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activité Récente', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.slate800)),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.history_rounded, size: 40, color: AppColors.slate300),
                    const SizedBox(height: 12),
                    Text('Aucune activité récente', style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            // Table
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(4),
                  2: FlexColumnWidth(2),
                },
                children: [
                  // Header
                  TableRow(
                    decoration: BoxDecoration(color: AppColors.slate50),
                    children: [
                      _tableHeader('Action'),
                      _tableHeader('Détails'),
                      _tableHeader('Date'),
                    ],
                  ),
                  // Rows
                  ...activities.take(10).map((a) {
                    final type = a['type'] as String? ?? '';
                    final detail = a['detail'] as String? ?? '';
                    final date = a['date'] as String? ?? '';
                    return TableRow(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: _activityBadge(type),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Text(detail, style: TextStyle(color: AppColors.slate600, fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Text(_formatActivityDate(date), style: TextStyle(color: AppColors.slate400, fontSize: 12)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(text, style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _activityBadge(String type) {
    Color color;
    String label;
    switch (type) {
      case 'absence':
        color = AppColors.error;
        label = 'Absence';
        break;
      case 'grade':
        color = AppColors.primary;
        label = 'Note';
        break;
      case 'payment':
        color = AppColors.success;
        label = 'Paiement';
        break;
      case 'suggestion':
        color = AppColors.warning;
        label = 'Suggestion';
        break;
      case 'message':
        color = const Color(0xFF8B5CF6);
        label = 'Message';
        break;
      default:
        color = AppColors.slate400;
        label = type;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  String _formatActivityDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // ==================== REUSABLE HELPERS ====================
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: AppShadows.card,
    );
  }

  Widget _iconButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 20, color: AppColors.slate600),
          ),
        ),
      ),
    );
  }

  Widget _outlineButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.slate500),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: AppColors.slate500, fontWeight: FontWeight.w500, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandOutlineButton({required String label, VoidCallback? onTap, bool isLoading = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLoading)
                  const IosLoader.small(color: AppColors.slate500)
                else
                  const Icon(Icons.lock_reset_rounded, size: 16, color: AppColors.slate500),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: AppColors.slate500, fontWeight: FontWeight.w500, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _successButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6D4CF6),
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          shadowColor: const Color(0xFF6D4CF6).withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _miniIconBtn({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16, color: onTap != null ? AppColors.slate500 : AppColors.slate300),
      ),
    );
  }

  // ==================== PHOTO UPLOAD ====================
  Future<void> _pickAndUploadPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final file = result.files.first;
      if (file.bytes == null) return;

      final ext = file.extension ?? 'jpg';
      final path = 'avatars/${widget.userId}.$ext';

      final supabase = Supabase.instance.client;

      await supabase.storage.from('avatars').uploadBinary(
        path,
        file.bytes!,
        fileOptions: const FileOptions(upsert: true),
      );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);

      await supabase
          .from('users')
          .update({'photo_url': publicUrl}).eq('id', widget.userId);

      ref.invalidate(userProfileDataProvider(widget.userId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo mise à jour !'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ==================== KEPT HELPERS ====================
  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return AppColors.error;
      case 'staff':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  LinearGradient _getRoleGradient(String role) {
    switch (role) {
      case 'admin':
        return AppColors.errorGradient;
      case 'staff':
        return AppColors.warningGradient;
      default:
        return AppColors.primaryGradient;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'staff':
        return 'Manager';
      default:
        return 'Étudiant';
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    return DateFormat('dd/MM/yyyy').format(date);
  }
}

// ==================== DONUT PAINTER ====================
class _DonutPainter extends CustomPainter {
  final double percentage;
  final Color color;

  _DonutPainter({required this.percentage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    const strokeWidth = 14.0;

    // Background arc
    final bgPaint = Paint()
      ..color = AppColors.slate100
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // Foreground arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final sweepAngle = 2 * pi * (percentage / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.percentage != percentage || old.color != color;
}
