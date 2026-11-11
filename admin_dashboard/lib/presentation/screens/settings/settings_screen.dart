// ignore_for_file: avoid_web_libraries_in_flutter, unused_element, deprecated_member_use

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../../core/utils/error_messages.dart';
import '../../widgets/admin_sidebar.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/user_avatar.dart';
import 'password_reset_requests_screen.dart';

// ═══════════════════════════════════════════════════════════════════
// ░░░  ULTIMATE REDESIGN — Settings Screen  ░░░
// ═══════════════════════════════════════════════════════════════════

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Local settings toggles state
  bool _twoFactorEnabled = false;
  bool _strongPasswordPolicy = true;
  bool _sessionTimeoutEnabled = true;

  bool _emailSecurityAlerts = true;
  bool _emailNewRequests = true;
  bool _emailWeeklyReports = false;

  bool _pushLiveAlerts = true;
  bool _pushSoundAlerts = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return;

    // Smart tab navigation based on search keywords
    if (query.contains('sécurité') ||
        query.contains('mot de passe') ||
        query.contains('2fa') ||
        query.contains('authentif') ||
        query.contains('accès')) {
      if (_tabController.index != 1) _tabController.animateTo(1);
    } else if (query.contains('notif') ||
        query.contains('email') ||
        query.contains('alerte') ||
        query.contains('son')) {
      if (_tabController.index != 2) _tabController.animateTo(2);
    } else if (query.contains('danger') ||
        query.contains('déconnexion') ||
        query.contains('cache') ||
        query.contains('système')) {
      if (_tabController.index != 3) _tabController.animateTo(3);
    } else if (query.contains('école') ||
        query.contains('profil') ||
        query.contains('contact') ||
        query.contains('année') ||
        query.contains('général')) {
      if (_tabController.index != 0) _tabController.animateTo(0);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/settings'),
          Expanded(
            child: Column(
              children: [
                _buildHeader(context),
                _buildTabsBar(),
                Expanded(
                  child: authState.isLoading
                      ? const SettingsSkeletonLoader()
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildGeneralTab(context, authState),
                            _buildSecurityTab(context, authState),
                            _buildNotificationsTab(context),
                            _buildDangerZoneTab(context, authState),
                          ],
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
  // HEADER BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paramètres',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Configuration générale, sécurité, notifications et préférences de l\'établissement',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const Spacer(),

          // Search Field (250px)
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
                      hintText: 'Rechercher un paramètre...',
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
          const SizedBox(width: 12),

          // Refresh Button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Actualiser',
            onPressed: () {
              ref.invalidate(authProvider);
              ref.invalidate(pendingPasswordResetCountProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Paramètres actualisés'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            color: const Color(0xFF655DD5),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF8FAFC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SUBPAGE TABS
  // ─────────────────────────────────────────────────────────────
  Widget _buildTabsBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorColor: const Color(0xFF6D4CF6),
        indicatorWeight: 2.5,
        labelColor: const Color(0xFF6D4CF6),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: const [
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.business_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Général & École'),
                ],
              ),
            ),
          ),
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 16),
                  SizedBox(width: 8),
                  Text('Sécurité & Accès'),
                ],
              ),
            ),
          ),
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Notifications'),
                ],
              ),
            ),
          ),
          Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16),
                  SizedBox(width: 8),
                  Text('Zone de danger & Système'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 0: GÉNÉRAL & ÉCOLE
  // ─────────────────────────────────────────────────────────────
  Widget _buildGeneralTab(BuildContext context, AdminAuthState authState) {
    final user = authState.user;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Profil Administrateur Card
          _buildCardContainer(
            title: 'Profil Administrateur',
            subtitle: 'Vos coordonnées personnelles et vos identifiants d\'accès',
            icon: Icons.person_outline_rounded,
            badgeColor: const Color(0xFF6D4CF6),
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    UserAvatar(
                      name: user?.fullName ?? 'Admin',
                      photoUrl: user?.photoUrl,
                      radius: 30,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                user?.fullName ?? 'Administrateur',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6D4CF6).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  (user?.role ?? 'ADMIN').toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6D4CF6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          if (user?.phone != null && user!.phone!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              user.phone!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditProfileDialog(context, authState),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Modifier le profil'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6D4CF6),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 2: Établissement Card
          _buildCardContainer(
            title: 'Établissement & Scolarité',
            subtitle: 'Gestion des coordonnées scolaires et de l\'organisation académique',
            icon: Icons.school_outlined,
            badgeColor: const Color(0xFF059669),
            children: [
              _buildActionTile(
                icon: Icons.business_outlined,
                iconColor: const Color(0xFF6D4CF6),
                title: 'Informations de l\'école',
                subtitle: 'Nom officiel, code établissement, adresse et logo',
                onTap: () => context.push('/settings/school-info'),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildActionTile(
                icon: Icons.contact_phone_outlined,
                iconColor: const Color(0xFF059669),
                title: 'Informations de contact',
                subtitle: 'Numéros de téléphone officiels, email support et réseaux sociaux',
                onTap: () => context.push('/settings/contact-info'),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildActionTile(
                icon: Icons.calendar_month_outlined,
                iconColor: const Color(0xFFD97706),
                title: 'Années académiques & Périodes',
                subtitle: 'Périodes scolaires, semestres et trimestres de l\'établissement',
                onTap: () => context.push('/semesters'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: SÉCURITÉ & ACCÈS
  // ─────────────────────────────────────────────────────────────
  Widget _buildSecurityTab(BuildContext context, AdminAuthState authState) {
    final pendingRequestsAsync = ref.watch(pendingPasswordResetCountProvider);
    final pendingCount = pendingRequestsAsync.value ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Demandes Banner
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6D4CF6).withOpacity(0.08),
                  const Color(0xFF8B5CF6).withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6D4CF6).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6D4CF6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_reset_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Demandes de réinitialisation de mot de passe',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (pendingCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                      const SizedBox(height: 4),
                      const Text(
                        'Consultez et validez les demandes soumises par les élèves et les enseignants',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/password-resets'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Gérer les demandes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6D4CF6),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Section: Authentification & Mots de passe
          _buildCardContainer(
            title: 'Politique des mots de passe & Accès',
            subtitle: 'Paramètres de sécurité de votre compte administrateur et des utilisateurs',
            icon: Icons.shield_outlined,
            badgeColor: const Color(0xFF6D4CF6),
            children: [
              _buildActionTile(
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFF6D4CF6),
                title: 'Changer mon mot de passe',
                subtitle: 'Mettre à jour le mot de passe de votre compte administrateur',
                onTap: () => _showChangePasswordDialog(context),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildSwitchTile(
                icon: Icons.fingerprint_rounded,
                iconColor: const Color(0xFF059669),
                title: 'Authentification à deux facteurs (2FA)',
                subtitle: 'Exiger une vérification de sécurité supplémentaire à la connexion',
                value: _twoFactorEnabled,
                onChanged: (v) => setState(() => _twoFactorEnabled = v),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildSwitchTile(
                icon: Icons.password_rounded,
                iconColor: const Color(0xFFD97706),
                title: 'Politique de mot de passe renforcée',
                subtitle: 'Exiger au moins 8 caractères, un chiffre et un caractère spécial',
                value: _strongPasswordPolicy,
                onChanged: (v) => setState(() => _strongPasswordPolicy = v),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildSwitchTile(
                icon: Icons.timer_outlined,
                iconColor: const Color(0xFF64748B),
                title: 'Expiration de session après inactivité',
                subtitle: 'Déconnexion automatique au bout de 30 minutes d\'inactivité',
                value: _sessionTimeoutEnabled,
                onChanged: (v) => setState(() => _sessionTimeoutEnabled = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────
  Widget _buildNotificationsTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Notifications Email
          _buildCardContainer(
            title: 'Notifications par Email',
            subtitle: 'Contrôlez les messages envoyés à votre adresse administrateur',
            icon: Icons.mail_outline_rounded,
            badgeColor: const Color(0xFF6D4CF6),
            children: [
              _buildSwitchTile(
                icon: Icons.security_rounded,
                iconColor: const Color(0xFF6D4CF6),
                title: 'Alertes de sécurité et connexions',
                subtitle: 'Recevoir un email lors de tentatives inhabituelles ou de réinitialisations',
                value: _emailSecurityAlerts,
                onChanged: (v) => setState(() => _emailSecurityAlerts = v),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildSwitchTile(
                icon: Icons.person_add_outlined,
                iconColor: const Color(0xFF059669),
                title: 'Demandes de réinitialisation et nouveaux comptes',
                subtitle: 'Recevoir un email dès qu\'une nouvelle demande requiert validation',
                value: _emailNewRequests,
                onChanged: (v) => setState(() => _emailNewRequests = v),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildSwitchTile(
                icon: Icons.assessment_outlined,
                iconColor: const Color(0xFFD97706),
                title: 'Rapport d\'activité hebdomadaire',
                subtitle: 'Synthèse des présences, notes et annonces chaque lundi matin',
                value: _emailWeeklyReports,
                onChanged: (v) => setState(() => _emailWeeklyReports = v),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 2: Notifications Push & Bureau
          _buildCardContainer(
            title: 'Notifications en direct & Sons',
            subtitle: 'Alertes visuelles et sonores au sein du tableau de bord',
            icon: Icons.notifications_active_outlined,
            badgeColor: const Color(0xFF059669),
            children: [
              _buildSwitchTile(
                icon: Icons.desktop_windows_outlined,
                iconColor: const Color(0xFF6D4CF6),
                title: 'Bannières d\'alerte sur le tableau de bord',
                subtitle: 'Afficher des notifications immédiates lors de nouveaux événements',
                value: _pushLiveAlerts,
                onChanged: (v) => setState(() => _pushLiveAlerts = v),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildSwitchTile(
                icon: Icons.volume_up_outlined,
                iconColor: const Color(0xFF059669),
                title: 'Signaux sonores',
                subtitle: 'Émettre un son discret pour les annonces importantes et alertes urgentes',
                value: _pushSoundAlerts,
                onChanged: (v) => setState(() => _pushSoundAlerts = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3: ZONE DE DANGER & SYSTÈME
  // ─────────────────────────────────────────────────────────────
  Widget _buildDangerZoneTab(BuildContext context, AdminAuthState authState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Cache & Performances
          _buildCardContainer(
            title: 'Cache & Synchronisation Système',
            subtitle: 'Opérations de maintenance des données locales de l\'application',
            icon: Icons.storage_rounded,
            badgeColor: const Color(0xFF64748B),
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
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vider le cache local',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Supprime les données temporaires stockées et recharge l\'état serveur',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        onPressed: () {
                          ref.invalidate(authProvider);
                          ref.invalidate(pendingPasswordResetCountProvider);
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
                        child: const Text('Vider le cache', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section 2: Danger Zone Card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2).withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zone de danger',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Actions sensibles ayant un impact direct sur votre session',
                            style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFFCA5A5)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                              style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          onPressed: () => _showSignOutDialog(context),
                          icon: const Icon(Icons.logout_rounded, size: 16),
                          label: const Text('Se déconnecter'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
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
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // REUSABLE CARD & TILE BUILDERS
  // ─────────────────────────────────────────────────────────────
  Widget _buildCardContainer({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color badgeColor,
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: badgeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF6D4CF6),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MODALS & DIALOGS (WITH BACKGROUND BLUR)
  // ─────────────────────────────────────────────────────────────

  /// Redesigned Change Password Modal with Strength indicator & eye toggle
  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: const _ChangePasswordModal(),
      ),
    );
  }

  /// Redesigned Edit Profile Modal
  void _showEditProfileDialog(BuildContext context, AdminAuthState authState) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: _EditProfileModal(authState: authState),
      ),
    );
  }

  /// Redesigned Sign Out Confirmation Dialog
  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.08),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Confirmer la déconnexion',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          content: const Text(
            'Êtes-vous sûr de vouloir vous déconnecter du portail administrateur ?',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
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
                      foregroundColor: const Color(0xFF64748B),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ref.read(authProvider.notifier).signOut();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Standalone Change Password Dialog with Strength Meter
class _ChangePasswordModal extends ConsumerStatefulWidget {
  const _ChangePasswordModal();

  @override
  ConsumerState<_ChangePasswordModal> createState() => _ChangePasswordModalState();
}

class _ChangePasswordModalState extends ConsumerState<_ChangePasswordModal> {
  final TextEditingController _newPwd = TextEditingController();
  final TextEditingController _confirmPwd = TextEditingController();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
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
    final newP = _newPwd.text.trim();
    final confP = _confirmPwd.text.trim();

    if (newP.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le nouveau mot de passe doit comporter au moins 6 caractères'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (newP != confP) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les nouveaux mots de passe ne correspondent pas'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.updateUser(
        UserAttributes(password: newP),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe administrateur modifié avec succès'),
            backgroundColor: Color(0xFF059669),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D4CF6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF6D4CF6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Changer le mot de passe',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Sécurisez l\'accès à votre compte administrateur',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Nouveau mot de passe
              const Text(
                'NOUVEAU MOT DE PASSE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _newPwd,
                obscureText: _obscureNew,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Entrez au moins 6 caractères...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: const Color(0xFF94A3B8),
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
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
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      strengthLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: strengthColor,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Confirmer le mot de passe
              const Text(
                'CONFIRMER LE MOT DE PASSE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPwd,
                obscureText: _obscureConfirm,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Répétez le nouveau mot de passe...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 18,
                      color: const Color(0xFF94A3B8),
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 40,
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        _isLoading ? 'Mise à jour...' : 'Mettre à jour',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D4CF6),
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
      ),
    );
  }
}

/// Standalone Edit Profile Dialog
class _EditProfileModal extends ConsumerStatefulWidget {
  final AdminAuthState authState;
  const _EditProfileModal({required this.authState});

  @override
  ConsumerState<_EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends ConsumerState<_EditProfileModal> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.authState.user?.fullName ?? '');
    _phoneCtrl = TextEditingController(text: widget.authState.user?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
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
        'phone': _phoneCtrl.text.trim(),
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
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UserFriendlyError.format(e)), backgroundColor: const Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6D4CF6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF6D4CF6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modifier mon profil',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Mettez à jour vos informations personnelles',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Nom complet
              const Text(
                'NOM COMPLET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                ),
              ),
              const SizedBox(height: 16),

              // Téléphone
              const Text(
                'NUMÉRO DE TÉLÉPHONE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: '+216 ...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 40,
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Annuler', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 16),
                      label: Text(
                        _isLoading ? 'Enregistrement...' : 'Enregistrer',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6D4CF6),
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
      ),
    );
  }
}