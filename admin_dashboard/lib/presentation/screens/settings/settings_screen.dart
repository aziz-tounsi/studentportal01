import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/admin_sidebar.dart';
import '../../providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// ░░░  AURORA GLASS — Settings Screen  ░░░
// ═══════════════════════════════════════════════════════════════════

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const AdminSidebar(currentRoute: '/settings'),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context),
                Expanded(child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(context, 'Profil', Icons.person_outline_rounded, AppColors.primary, [
                        _buildCard(context, [
                          ListTile(
                            leading: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Center(
                                child: Text(
                                  authState.user?.fullName.substring(0, 1).toUpperCase() ?? 'A',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
                                ),
                              ),
                            ),
                            title: Text(authState.user?.fullName ?? 'Admin', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            subtitle: Text(authState.user?.email ?? '', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(AppRadius.full),
                                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                              ),
                              child: TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                ),
                                child: const Text('Modifier'),
                              ),
                            ),
                          ),
                        ]),
                      ]),
                      const SizedBox(height: 24),
                      _buildSection(context, 'Sécurité', Icons.shield_outlined, AppColors.secondary, [
                        _buildCard(context, [
                          ListTile(
                            leading: Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary),
                            title: const Text('Changer mot de passe', style: TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                            onTap: () => _showChangePasswordDialog(context, ref),
                          ),
                          Divider(color: AppColors.border.withOpacity(0.5), height: 1),
                          ListTile(
                            leading: Icon(Icons.fingerprint_rounded, color: AppColors.textSecondary),
                            title: const Text('Authentification à deux facteurs', style: TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Switch(
                              value: false,
                              onChanged: (v) {},
                              activeColor: AppColors.primary,
                            ),
                          ),
                        ]),
                      ]),
                      const SizedBox(height: 24),
                      _buildSection(context, 'Notifications', Icons.notifications_none_rounded, AppColors.accent, [
                        _buildCard(context, [
                          ListTile(
                            leading: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                            title: const Text('Notifications email', style: TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Switch(
                              value: true,
                              onChanged: (v) {},
                              activeColor: AppColors.primary,
                            ),
                          ),
                          Divider(color: AppColors.border.withOpacity(0.5), height: 1),
                          ListTile(
                            leading: Icon(Icons.notifications_active_outlined, color: AppColors.textSecondary),
                            title: const Text('Notifications push', style: TextStyle(fontWeight: FontWeight.w600)),
                            trailing: Switch(
                              value: true,
                              onChanged: (v) {},
                              activeColor: AppColors.primary,
                            ),
                          ),
                        ]),
                      ]),
                      const SizedBox(height: 24),
                      _buildSection(context, 'École', Icons.school_outlined, AppColors.success, [
                        _buildCard(context, [
                          ListTile(
                            leading: Icon(Icons.business_outlined, color: AppColors.textSecondary),
                            title: const Text('Informations de l\'école', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Nom, adresse, logo...', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                            trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                            onTap: () => context.push('/settings/school-info'),
                          ),
                          Divider(color: AppColors.border.withOpacity(0.5), height: 1),
                          ListTile(
                            leading: Icon(Icons.contact_phone_outlined, color: AppColors.primary),
                            title: const Text('Informations de contact', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Téléphone, email, réseaux sociaux...', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                            trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                            onTap: () => context.push('/settings/contact-info'),
                          ),
                          Divider(color: AppColors.border.withOpacity(0.5), height: 1),
                          ListTile(
                            leading: Icon(Icons.calendar_month_outlined, color: AppColors.textSecondary),
                            title: const Text('Années académiques', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text('Gérer les périodes scolaires', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                            trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                            onTap: () {},
                          ),
                        ]),
                      ]),
                      const SizedBox(height: 24),
                      _buildSection(context, 'Zone de danger', Icons.warning_amber_rounded, AppColors.error, [
                        _buildCard(context, [
                          ListTile(
                            leading: Icon(Icons.logout_rounded, color: AppColors.error),
                            title: Text('Déconnexion', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                            onTap: () => ref.read(authProvider.notifier).signOut(),
                          ),
                        ], borderColor: AppColors.error.withOpacity(0.15)),
                      ]),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.35))),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Paramètres', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
                  Text('Configuration de votre espace', style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildCard(BuildContext context, List<Widget> children, {Color? borderColor}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.card,
        border: Border.all(color: borderColor ?? AppColors.border.withOpacity(0.4)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Column(children: children),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentPwd = TextEditingController();
    final newPwd = TextEditingController();
    final confirmPwd = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Changer mot de passe', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPwd,
              decoration: InputDecoration(
                labelText: 'Mot de passe actuel',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPwd,
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPwd,
              decoration: InputDecoration(
                labelText: 'Confirmer',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              obscureText: true,
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
                    onPressed: () => Navigator.pop(ctx),
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
                      if (newPwd.text != confirmPwd.text) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Les mots de passe ne correspondent pas'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
                        ));
                        return;
                      }
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Mot de passe modifié'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
                      ));
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.w700)),
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
}