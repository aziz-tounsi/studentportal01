// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart' show AppColors;
import '../../../core/utils/error_messages.dart';
import '../../../data/services/user_management_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/user_avatar.dart';
import 'password_reset_requests_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Admin team accounts in this school
  List<Map<String, dynamic>> _schoolAdmins = [];
  bool _loadingAdmins = false;
  String? _loadedSchoolId;

  // Preferences state
  bool _twoFactorEnabled = false;
  bool _strongPasswordPolicy = true;
  bool _sessionTimeoutEnabled = true;

  bool _emailSecurityAlerts = true;
  bool _emailNewRequests = true;
  bool _emailWeeklyReports = false;

  bool _pushLiveAlerts = true;
  bool _pushSoundAlerts = true;

  static const Color _brand = Color(0xFF6D4CF6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSchoolAdmins(String schoolId, {bool force = false}) async {
    if (_loadingAdmins) return;
    if (!force && _loadedSchoolId == schoolId) return;
    setState(() => _loadingAdmins = true);
    try {
      final resp = await Supabase.instance.client
          .from('users')
          .select('id, full_name, email, role, created_at')
          .eq('school_id', schoolId)
          .inFilter('role', ['owner', 'admin', 'staff', 'manager'])
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _schoolAdmins = List<Map<String, dynamic>>.from(resp as List);
          _loadedSchoolId = schoolId;
          _loadingAdmins = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading school admins: $e');
      if (mounted) {
        setState(() {
          _loadedSchoolId = schoolId;
          _loadingAdmins = false;
        });
      }
    }
  }

  bool _matchesSearch(List<String> keywords) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return keywords.any((k) => k.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final schoolId = authState.user?.schoolId;
    if (schoolId != null && _loadedSchoolId != schoolId && !_loadingAdmins) {
      Future.microtask(() => _loadSchoolAdmins(schoolId));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/settings'),
          Expanded(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: authState.isLoading
                      ? const SettingsSkeletonLoader()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32, 20, 32, 36),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1060),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // High-positioned Profil Administrateur (no icon, no admin pill, no phone)
                                  if (_matchesSearch([
                                    'profil',
                                    'administrateur',
                                    'nom',
                                    'email',
                                    'compte',
                                    'mot de passe',
                                    authState.user?.fullName ?? '',
                                    authState.user?.email ?? '',
                                  ])) ...[
                                    _buildAdminProfileHeroCard(
                                        context, authState),
                                    const SizedBox(height: 20),
                                  ],

                                  // Search mode shows all matching sections unified
                                  if (_searchQuery.isNotEmpty)
                                    _buildSearchResultsView(context, authState)
                                  else ...[
                                    _buildTabsBar(),
                                    const SizedBox(height: 20),
                                    AnimatedBuilder(
                                      animation: _tabController,
                                      builder: (context, _) {
                                        switch (_tabController.index) {
                                          case 0:
                                            return _buildTeamAndSchoolTab(
                                                context, authState);
                                          case 1:
                                            return _buildSecurityTab(
                                                context, authState);
                                          case 2:
                                            return _buildNotificationsTab(
                                                context);
                                          case 3:
                                          default:
                                            return _buildSystemTab(
                                                context, authState);
                                        }
                                      },
                                    ),
                                  ],
                                ],
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
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HEADER BAR (Exact search bar from Documents page, NO Actualiser button)
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EAF2))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Paramètres',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Profil administrateur, accès équipe, établissement et sécurité',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Exact Documents page Search Bar
          SizedBox(
            width: 320,
            height: 40,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() {
                _searchQuery = v.trim();
              }),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Rechercher un paramètre...',
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.slate50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            '⌘K',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                filled: true,
                fillColor: AppColors.slate50,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: const Color(0xFF655DD5).withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HIGH-POSITIONED PROFIL ADMINISTRATEUR CARD (no title icon, no admin pill, no phone)
  // ─────────────────────────────────────────────────────────────
  Widget _buildAdminProfileHeroCard(
    BuildContext context,
    AdminAuthState authState,
  ) {
    final user = authState.user;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profil Administrateur',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Informations personnelles et sécurité de connexion',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          Row(
            children: [
              UserAvatar(
                name: user?.fullName ?? 'Administrateur',
                photoUrl: user?.photoUrl,
                radius: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? 'Administrateur',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showEditProfileDialog(context, authState),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Modifier le profil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF334155),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _showChangePasswordDialog(context, authState),
                      icon: const Icon(Icons.lock_outline_rounded, size: 15),
                      label: const Text('Mot de passe'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SEGMENTED SETTINGS TABS
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabsBar() {
    const items = [
      (icon: Icons.admin_panel_settings_outlined, label: 'Équipe & Établissement'),
      (icon: Icons.shield_outlined, label: 'Sécurité & Accès'),
      (icon: Icons.notifications_none_rounded, label: 'Notifications'),
      (icon: Icons.settings_suggest_outlined, label: 'Système'),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(items.length, (i) {
            final isActive = _tabController.index == i;
            return GestureDetector(
              onTap: () => setState(() => _tabController.index = i),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFF5F3FF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].icon,
                        size: 16,
                        color: isActive ? _brand : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w500,
                          color: isActive ? _brand : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // UNIFIED SEARCH RESULTS ACROSS ALL SETTINGS
  // ─────────────────────────────────────────────────────────────
  Widget _buildSearchResultsView(
    BuildContext context,
    AdminAuthState authState,
  ) {
    final blocks = <Widget>[];

    if (_matchesSearch([
      'administrateur',
      'équipe',
      'ajouter',
      'login',
      'compte',
      'staff',
      'accès',
    ])) {
      blocks.add(_buildAdminsManagementCard(context, authState));
      blocks.add(const SizedBox(height: 20));
    }

    if (_matchesSearch([
      'école',
      'établissement',
      'logo',
      'adresse',
      'contact',
      'année',
      'semestre',
      'période',
    ])) {
      blocks.add(_buildSchoolCard(context));
      blocks.add(const SizedBox(height: 20));
    }

    if (_matchesSearch([
      'sécurité',
      'mot de passe',
      'réinitialisation',
      'demande',
      '2fa',
      'session',
      'authentification',
    ])) {
      blocks.add(_buildSecurityTab(context, authState));
      blocks.add(const SizedBox(height: 20));
    }

    if (_matchesSearch([
      'notification',
      'email',
      'alerte',
      'rapport',
      'son',
      'bannière',
    ])) {
      blocks.add(_buildNotificationsTab(context));
      blocks.add(const SizedBox(height: 20));
    }

    if (_matchesSearch([
      'cache',
      'déconnexion',
      'système',
      'session',
      'maintenance',
    ])) {
      blocks.add(_buildSystemTab(context, authState));
    }

    if (blocks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text(
              'Aucun paramètre trouvé pour "$_searchQuery"',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 0: ÉQUIPE ADMIN & ÉTABLISSEMENT
  // ─────────────────────────────────────────────────────────────
  Widget _buildTeamAndSchoolTab(
    BuildContext context,
    AdminAuthState authState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAdminsManagementCard(context, authState),
        const SizedBox(height: 20),
        _buildSchoolCard(context),
      ],
    );
  }

  Widget _buildAdminsManagementCard(
    BuildContext context,
    AdminAuthState authState,
  ) {
    final currentUserId = authState.user?.id;
    final schoolId = authState.user?.schoolId;

    return _buildCardContainer(
      title: 'Administrateurs de l\'établissement',
      subtitle:
          'Ajoutez ou gérez les comptes d\'accès au tableau de bord de votre école',
      trailing: SizedBox(
        height: 36,
        child: ElevatedButton.icon(
          onPressed: schoolId == null
              ? null
              : () => _showAddAdminDialog(context, schoolId),
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
          label: const Text('Ajouter un admin'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _brand,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      children: [
        if (_loadingAdmins && _schoolAdmins.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_schoolAdmins.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Aucun autre administrateur configuré pour cet établissement.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          )
        else
          ...List.generate(_schoolAdmins.length, (idx) {
            final adm = _schoolAdmins[idx];
            final id = adm['id']?.toString() ?? '';
            final name = adm['full_name']?.toString() ?? 'Administrateur';
            final email = adm['email']?.toString() ?? '';
            final role = adm['role']?.toString() ?? 'admin';
            final isSelf = id == currentUserId;
            final isOwner = role == 'owner';

            return Column(
              children: [
                if (idx > 0)
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      UserAvatar(name: name, radius: 18),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                if (isSelf) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Vous',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOwner
                              ? _brand.withOpacity(0.08)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOwner
                                ? _brand.withOpacity(0.25)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Text(
                          isOwner
                              ? 'Propriétaire'
                              : (role == 'staff' ? 'Staff' : 'Administrateur'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOwner ? _brand : const Color(0xFF475569),
                          ),
                        ),
                      ),
                      if (!isSelf && !isOwner) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Supprimer cet accès',
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Color(0xFFEF4444),
                          ),
                          onPressed: () =>
                              _confirmDeleteAdmin(context, id, name, schoolId!),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildSchoolCard(BuildContext context) {
    return _buildCardContainer(
      title: 'Établissement & Scolarité',
      subtitle:
          'Informations officielles, coordonnées et calendrier académique',
      children: [
        _buildActionTile(
          icon: Icons.business_outlined,
          iconColor: _brand,
          title: 'Informations de l\'école',
          subtitle: 'Nom officiel, code établissement, adresse et logo',
          onTap: () => context.push('/settings/school-info'),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        _buildActionTile(
          icon: Icons.contact_phone_outlined,
          iconColor: const Color(0xFF059669),
          title: 'Informations de contact',
          subtitle:
              'Numéros de téléphone officiels, email support et réseaux sociaux',
          onTap: () => context.push('/settings/contact-info'),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        _buildActionTile(
          icon: Icons.calendar_month_outlined,
          iconColor: const Color(0xFFD97706),
          title: 'Années académiques & Périodes',
          subtitle:
              'Périodes scolaires, semestres et trimestres de l\'établissement',
          onTap: () => context.push('/semesters'),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: SÉCURITÉ & ACCÈS
  // ─────────────────────────────────────────────────────────────
  Widget _buildSecurityTab(BuildContext context, AdminAuthState authState) {
    final pendingRequestsAsync = ref.watch(pendingPasswordResetCountProvider);
    final pendingCount = pendingRequestsAsync.value ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _brand.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _brand.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: _brand,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Demandes de réinitialisation de mot de passe',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (pendingCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pendingCount en attente',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Approuvez ou refusez les demandes envoyées par les élèves',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/password-resets'),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                  label: const Text('Gérer les demandes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildCardContainer(
          title: 'Politique de sécurité',
          subtitle:
              'Contrôlez l\'authentification de votre compte et de vos sessions',
          children: [
            _buildActionTile(
              icon: Icons.lock_outline_rounded,
              iconColor: _brand,
              title: 'Changer mon mot de passe',
              subtitle:
                  'Vérification de l\'ancien mot de passe requise avant modification',
              onTap: () => _showChangePasswordDialog(context, authState),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _buildSwitchTile(
              icon: Icons.fingerprint_rounded,
              iconColor: const Color(0xFF059669),
              title: 'Authentification à deux facteurs (2FA)',
              subtitle:
                  'Exiger une vérification supplémentaire lors de la connexion',
              value: _twoFactorEnabled,
              onChanged: (v) => setState(() => _twoFactorEnabled = v),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _buildSwitchTile(
              icon: Icons.password_rounded,
              iconColor: const Color(0xFFD97706),
              title: 'Politique de mot de passe renforcée',
              subtitle:
                  'Exiger au moins 8 caractères, un chiffre et un caractère spécial',
              value: _strongPasswordPolicy,
              onChanged: (v) => setState(() => _strongPasswordPolicy = v),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _buildSwitchTile(
              icon: Icons.timer_outlined,
              iconColor: const Color(0xFF64748B),
              title: 'Expiration après inactivité',
              subtitle:
                  'Déconnexion automatique après 30 minutes d\'inactivité',
              value: _sessionTimeoutEnabled,
              onChanged: (v) => setState(() => _sessionTimeoutEnabled = v),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────
  Widget _buildNotificationsTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardContainer(
          title: 'Notifications par Email',
          subtitle: 'Alertes envoyées à votre adresse administrateur',
          children: [
            _buildSwitchTile(
              icon: Icons.security_rounded,
              iconColor: _brand,
              title: 'Alertes de sécurité et connexions',
              subtitle:
                  'Recevoir un email lors de tentatives inhabituelles ou réinitialisations',
              value: _emailSecurityAlerts,
              onChanged: (v) => setState(() => _emailSecurityAlerts = v),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _buildSwitchTile(
              icon: Icons.person_add_outlined,
              iconColor: const Color(0xFF059669),
              title: 'Demandes de réinitialisation et nouveaux comptes',
              subtitle: 'Recevoir un email lorsqu\'une action requiert validation',
              value: _emailNewRequests,
              onChanged: (v) => setState(() => _emailNewRequests = v),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _buildSwitchTile(
              icon: Icons.assessment_outlined,
              iconColor: const Color(0xFFD97706),
              title: 'Rapport hebdomadaire',
              subtitle: 'Synthèse des présences et notes chaque lundi matin',
              value: _emailWeeklyReports,
              onChanged: (v) => setState(() => _emailWeeklyReports = v),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildCardContainer(
          title: 'Notifications en direct & Sons',
          subtitle: 'Comportement des alertes au sein du tableau de bord',
          children: [
            _buildSwitchTile(
              icon: Icons.desktop_windows_outlined,
              iconColor: _brand,
              title: 'Bannières d\'alerte sur le tableau de bord',
              subtitle: 'Afficher les notifications en direct lors d\'événements',
              value: _pushLiveAlerts,
              onChanged: (v) => setState(() => _pushLiveAlerts = v),
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _buildSwitchTile(
              icon: Icons.volume_up_outlined,
              iconColor: const Color(0xFF059669),
              title: 'Signaux sonores',
              subtitle: 'Émettre un son discret pour les alertes urgentes',
              value: _pushSoundAlerts,
              onChanged: (v) => setState(() => _pushSoundAlerts = v),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3: SYSTÈME & SESSION
  // ─────────────────────────────────────────────────────────────
  Widget _buildSystemTab(BuildContext context, AdminAuthState authState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardContainer(
          title: 'Synchronisation & Cache',
          subtitle: 'Maintenance locale des données de session',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cleaning_services_rounded,
                      color: Color(0xFF64748B),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vider le cache local',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Recharge la session et les compteurs depuis le serveur',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: () {
                        ref.invalidate(authProvider);
                        ref.invalidate(pendingPasswordResetCountProvider);
                        if (authState.user?.schoolId != null) {
                          _loadSchoolAdmins(authState.user!.schoolId!,
                              force: true);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cache local vidé avec succès'),
                            backgroundColor: Color(0xFF059669),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E293B),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Vider le cache',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2).withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Déconnexion du compte administrateur',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Termine votre session actuelle et retourne à la page de connexion',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 38,
                child: ElevatedButton.icon(
                  onPressed: () => _showSignOutDialog(context),
                  icon: const Icon(Icons.logout_rounded, size: 15),
                  label: const Text('Se déconnecter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // REUSABLE CARD & TILE BUILDERS
  // ─────────────────────────────────────────────────────────────
  Widget _buildCardContainer({
    required String title,
    required String subtitle,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      hoverColor: const Color(0xFFF8FAFC),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: _brand,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DIALOG LAUNCHERS
  // ─────────────────────────────────────────────────────────────
  void _showChangePasswordDialog(
    BuildContext context,
    AdminAuthState authState,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: _ChangePasswordModal(
          userEmail: authState.user?.email ??
              Supabase.instance.client.auth.currentUser?.email ??
              '',
          userId: authState.user?.id,
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AdminAuthState authState) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: _EditProfileModal(
          authState: authState,
          onOpenPasswordModal: () =>
              _showChangePasswordDialog(context, authState),
        ),
      ),
    );
  }

  Future<void> _showAddAdminDialog(
    BuildContext context,
    String schoolId,
  ) async {
    final created = await showDialog<Map<String, String>?>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: _AddAdminModal(schoolId: schoolId),
      ),
    );

    if (created != null && mounted) {
      await _loadSchoolAdmins(schoolId, force: true);
      if (!mounted) return;
      _showAdminCredentialsDialog(
        context,
        name: created['full_name'] ?? '',
        email: created['email'] ?? '',
        password: created['password'] ?? '',
      );
    }
  }

  void _showAdminCredentialsDialog(
    BuildContext context, {
    required String name,
    required String email,
    required String password,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Compte administrateur créé',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transmettez ces identifiants à $name (changement obligatoire à la première connexion) :',
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email : $email',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Mot de passe temporaire : $password',
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          color: _brand,
                        )),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(text: 'Email: $email\nMot de passe: $password'),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Identifiants copiés')),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copier'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAdmin(
    BuildContext context,
    String adminId,
    String adminName,
    String schoolId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Supprimer l\'accès administrateur',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text(
            'Voulez-vous vraiment supprimer le compte administrateur de $adminName ?',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      final success = await UserManagementService.deleteUser(adminId);
      if (mounted) {
        if (success) {
          await _loadSchoolAdmins(schoolId, force: true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Accès administrateur supprimé'),
                backgroundColor: Color(0xFF059669),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de supprimer cet administrateur'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Confirmer la déconnexion',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: const Text(
            'Êtes-vous sûr de vouloir vous déconnecter du portail administrateur ?',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(authProvider.notifier).signOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Déconnexion'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CHANGE PASSWORD MODAL (Verifies old password FIRST)
// ═══════════════════════════════════════════════════════════════════
class _ChangePasswordModal extends ConsumerStatefulWidget {
  final String userEmail;
  final String? userId;
  const _ChangePasswordModal({required this.userEmail, this.userId});

  @override
  ConsumerState<_ChangePasswordModal> createState() =>
      _ChangePasswordModalState();
}

class _ChangePasswordModalState extends ConsumerState<_ChangePasswordModal> {
  final TextEditingController _oldPwd = TextEditingController();
  final TextEditingController _newPwd = TextEditingController();
  final TextEditingController _confirmPwd = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _inlineError;

  @override
  void dispose() {
    _oldPwd.dispose();
    _newPwd.dispose();
    _confirmPwd.dispose();
    super.dispose();
  }

  double _calculateStrength(String pwd) {
    if (pwd.isEmpty) return 0.0;
    double score = 0.2;
    if (pwd.length >= 8) score += 0.3;
    if (RegExp(r'[0-9]').hasMatch(pwd)) score += 0.25;
    if (RegExp(r'[!@#\$&*~_=+%-]').hasMatch(pwd)) score += 0.25;
    return score.clamp(0.0, 1.0);
  }

  Future<void> _submit() async {
    final oldP = _oldPwd.text.trim();
    final newP = _newPwd.text.trim();
    final confP = _confirmPwd.text.trim();

    if (oldP.isEmpty) {
      setState(() => _inlineError = 'Veuillez saisir votre ancien mot de passe.');
      return;
    }
    if (newP.length < 6) {
      setState(() =>
          _inlineError = 'Le nouveau mot de passe doit contenir au moins 6 caractères.');
      return;
    }
    if (newP != confP) {
      setState(() =>
          _inlineError = 'Les nouveaux mots de passe ne correspondent pas.');
      return;
    }

    setState(() {
      _isLoading = true;
      _inlineError = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final email = widget.userEmail.isNotEmpty
          ? widget.userEmail
          : (supabase.auth.currentUser?.email ?? '');
      if (email.isEmpty) {
        throw Exception('Adresse e-mail introuvable pour vérifier le compte.');
      }

      // 1. Verify old password FIRST
      try {
        await supabase.auth.signInWithPassword(
          email: email,
          password: oldP,
        );
      } on AuthException {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _inlineError = 'L\'ancien mot de passe est incorrect.';
          });
        }
        return;
      }

      // 2. Update password in Supabase Auth
      await supabase.auth.updateUser(UserAttributes(password: newP));

      // 3. Clear force_password_change & initial_password if present
      if (widget.userId != null) {
        try {
          await supabase.from('users').update({
            'force_password_change': false,
            'initial_password': null,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', widget.userId!);
        } catch (_) {}
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe modifié avec succès'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _inlineError = UserFriendlyError.format(e);
        });
      }
    }
  }

  InputDecoration _pwdDecoration(
    String hint,
    bool obscure,
    VoidCallback toggle,
  ) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 18,
          color: const Color(0xFF64748B),
        ),
        onPressed: toggle,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF6D4CF6), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strength = _calculateStrength(_newPwd.text);
    Color strengthColor = const Color(0xFFDC2626);
    String strengthLabel = 'Faible';
    if (strength >= 0.75) {
      strengthColor = const Color(0xFF059669);
      strengthLabel = 'Fort';
    } else if (strength >= 0.5) {
      strengthColor = const Color(0xFFD97706);
      strengthLabel = 'Moyen';
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Modifier le mot de passe',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Confirmez votre ancien mot de passe pour définir le nouveau',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),

              if (_inlineError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    _inlineError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              const Text(
                'ANCIEN MOT DE PASSE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _oldPwd,
                obscureText: _obscureOld,
                style: const TextStyle(fontSize: 13),
                decoration: _pwdDecoration(
                  'Entrez votre mot de passe actuel...',
                  _obscureOld,
                  () => setState(() => _obscureOld = !_obscureOld),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'NOUVEAU MOT DE PASSE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _newPwd,
                obscureText: _obscureNew,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13),
                decoration: _pwdDecoration(
                  'Minimum 6 caractères...',
                  _obscureNew,
                  () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              if (_newPwd.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: strength,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation(strengthColor),
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      strengthLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: strengthColor,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              const Text(
                'CONFIRMER LE NOUVEAU MOT DE PASSE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmPwd,
                obscureText: _obscureConfirm,
                style: const TextStyle(fontSize: 13),
                decoration: _pwdDecoration(
                  'Répétez le nouveau mot de passe...',
                  _obscureConfirm,
                  () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(_isLoading ? 'Vérification...' : 'Mettre à jour'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// EDIT PROFILE MODAL (NO phone field; includes password action)
// ═══════════════════════════════════════════════════════════════════
class _EditProfileModal extends ConsumerStatefulWidget {
  final AdminAuthState authState;
  final VoidCallback onOpenPasswordModal;
  const _EditProfileModal({
    required this.authState,
    required this.onOpenPasswordModal,
  });

  @override
  ConsumerState<_EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends ConsumerState<_EditProfileModal> {
  late TextEditingController _nameCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl =
        TextEditingController(text: widget.authState.user?.fullName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom complet est obligatoire')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = widget.authState.user?.id;
      if (userId == null) return;

      await supabase.from('users').update({
        'full_name': newName,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      ref.invalidate(authProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(UserFriendlyError.format(e)),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.authState.user?.email ?? '';

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Modifier le profil',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Mettez à jour votre nom ou accédez à la modification du mot de passe',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),

              const Text(
                'NOM COMPLET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFF6D4CF6), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'ADRESSE E-MAIL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Direct button to change password (verifies old password first)
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  widget.onOpenPasswordModal();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF6D4CF6).withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_reset_rounded,
                          size: 18, color: Color(0xFF6D4CF6)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Modifier / Réinitialiser mon mot de passe',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6D4CF6),
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18, color: Color(0xFF6D4CF6)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child:
                        Text(_isLoading ? 'Enregistrement...' : 'Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// ADD SCHOOL ADMIN LOGIN MODAL
// ═══════════════════════════════════════════════════════════════════
class _AddAdminModal extends StatefulWidget {
  final String schoolId;
  const _AddAdminModal({required this.schoolId});

  @override
  State<_AddAdminModal> createState() => _AddAdminModalState();
}

class _AddAdminModalState extends State<_AddAdminModal> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  late final TextEditingController _passwordCtrl;
  String _selectedRole = 'admin';
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _passwordCtrl = TextEditingController(text: _generateTempPassword());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _generateTempPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789@#!';
    final rng = math.Random.secure();
    return List.generate(10, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final pwd = _passwordCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Veuillez saisir un nom complet et un email valide.');
      return;
    }
    if (pwd.length < 6) {
      setState(
          () => _error = 'Le mot de passe temporaire doit contenir au moins 6 caractères.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await UserManagementService.createUser(
        email: email,
        password: pwd,
        fullName: name,
        role: _selectedRole,
        schoolId: widget.schoolId,
        forcePasswordChange: true,
      );

      if (result['success'] == true && mounted) {
        Navigator.pop(context, {
          'full_name': name,
          'email': email,
          'password': pwd,
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = result['error']?.toString() ?? 'Échec de création';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = UserFriendlyError.format(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ajouter un administrateur',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Créez un accès supplémentaire pour le tableau de bord de votre école',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),

              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB91C1C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],

              const Text(
                'NOM COMPLET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ex: Sami Ben Ali',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'ADRESSE E-MAIL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'admin2@ecole.tn',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'RÔLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Administrateur')),
                  DropdownMenuItem(value: 'staff', child: Text('Staff / Secrétariat')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedRole = v);
                },
              ),
              const SizedBox(height: 12),

              const Text(
                'MOT DE PASSE TEMPORAIRE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordCtrl,
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    tooltip: 'Générer',
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    onPressed: () {
                      setState(() {
                        _passwordCtrl.text = _generateTempPassword();
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(_isLoading ? 'Création...' : 'Créer le compte'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}