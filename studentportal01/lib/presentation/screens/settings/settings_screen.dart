import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/arabic_typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/nav_bar_provider.dart';
import '../../widgets/bouncing_wrapper.dart';
import '../../widgets/ios_edge_swipe_back.dart';

const Color _navPink = Color(0xFFFF2D78);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Functional Settings state
  bool _notifGrades = true;
  bool _notifSchedule = true;
  bool _notifAbsences = true;
  bool _notifAnnouncements = true;

  bool _biometricLock = false;
  bool _autoDownloadWifi = true;
  bool _cacheCleared = false;

  void _clearAppCache() {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _cacheCleared = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cleaning_services_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.translate('cache_cleared_success'))),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final l10n = AppLocalizations.of(context);
    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool isSaving = false;
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final isAr = Localizations.localeOf(context).languageCode == 'ar';
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Text(
                l10n.translate('change_password'),
                style: isAr
                    ? ArabicTypography.sectionHeader(fontSize: 18, color: const Color(0xFF1E293B))
                    : const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1E293B)),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: oldPasswordCtrl,
                      obscureText: obscureOld,
                      style: isAr
                          ? ArabicTypography.body(color: const Color(0xFF1E293B))
                          : const TextStyle(color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        labelText: l10n.translate('current_password'),
                        labelStyle: isAr
                            ? ArabicTypography.formLabel(color: Colors.grey.shade600)
                            : TextStyle(color: Colors.grey.shade600),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF64748B)),
                        suffixIcon: IconButton(
                          icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility, size: 18, color: const Color(0xFF64748B)),
                          onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _navPink, width: 1.5),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: newPasswordCtrl,
                      obscureText: obscureNew,
                      style: isAr
                          ? ArabicTypography.body(color: const Color(0xFF1E293B))
                          : const TextStyle(color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        labelText: l10n.translate('new_password'),
                        labelStyle: isAr
                            ? ArabicTypography.formLabel(color: Colors.grey.shade600)
                            : TextStyle(color: Colors.grey.shade600),
                        prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20, color: Color(0xFF64748B)),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18, color: const Color(0xFF64748B)),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _navPink, width: 1.5),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmPasswordCtrl,
                      obscureText: obscureConfirm,
                      style: isAr
                          ? ArabicTypography.body(color: const Color(0xFF1E293B))
                          : const TextStyle(color: Color(0xFF1E293B)),
                      decoration: InputDecoration(
                        labelText: l10n.translate('confirm_new_password'),
                        labelStyle: isAr
                            ? ArabicTypography.formLabel(color: Colors.grey.shade600)
                            : TextStyle(color: Colors.grey.shade600),
                        prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 20, color: Color(0xFF64748B)),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18, color: const Color(0xFF64748B)),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _navPink, width: 1.5),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                  child: Text(
                    l10n.cancel,
                    style: isAr
                        ? ArabicTypography.actionText(color: const Color(0xFF64748B))
                        : const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final oldPassword = oldPasswordCtrl.text.trim();
                          final newPassword = newPasswordCtrl.text;
                          final confirmPassword = confirmPasswordCtrl.text;

                          // 1. Current password empty check
                          if (oldPassword.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.translate('current_password_required'),
                                  style: isAr ? ArabicTypography.alert(color: Colors.white) : null,
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            return;
                          }

                          // 2. Minimum length check
                          if (newPassword.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.translate('password_too_short'),
                                  style: isAr ? ArabicTypography.alert(color: Colors.white) : null,
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            return;
                          }

                          // 3. Mismatch check
                          if (newPassword != confirmPassword) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.translate('passwords_mismatch'),
                                  style: isAr ? ArabicTypography.alert(color: Colors.white) : null,
                                ),
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          try {
                            await ref.read(authProvider.notifier).changePassword(
                                  currentPassword: oldPassword,
                                  newPassword: newPassword,
                                );
                            if (context.mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.translate('password_updated_success'),
                                    style: isAr ? ArabicTypography.alert(color: Colors.white) : null,
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          } catch (errorKey) {
                            setDialogState(() => isSaving = false);
                            if (context.mounted) {
                              final errorKeyStr = errorKey.toString();
                              final message = l10n.translate(errorKeyStr).isNotEmpty && l10n.translate(errorKeyStr) != errorKeyStr
                                  ? l10n.translate(errorKeyStr)
                                  : l10n.translate('password_update_failed');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    message,
                                    style: isAr ? ArabicTypography.alert(color: Colors.white) : null,
                                  ),
                                  backgroundColor: const Color(0xFFEF4444),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navPink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  ),
                  child: Text(
                    isSaving ? l10n.translate('saving') : l10n.translate('save'),
                    style: isAr
                        ? ArabicTypography.button(color: Colors.white)
                        : const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8D5F2),
              Color(0xFFD4C4E8),
              Color(0xFFC9D6F0),
              Color(0xFFE0EAF5),
              Color(0xFFF0F5FA),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // Custom Header with Circular Back Button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Builder(
                    builder: (ctx) {
                      final isRtl = Directionality.of(ctx) == TextDirection.rtl;
                      return Row(
                        children: [
                          BouncingWrapper(
                            shrinkScale: 0.86,
                            overshootScale: 1.10,
                            delayNavigation: false,
                            hitPadding: const EdgeInsets.symmetric(vertical: 8),
                            onTap: () {
                              final swipeBack = IosEdgeSwipeBack.of(context);
                              if (swipeBack != null) {
                                swipeBack.animateBack();
                              } else {
                                final fromAIChat = ref.read(navigatedFromAIChatProvider);
                                if (fromAIChat) {
                                  ref.read(navigatedFromAIChatProvider.notifier).state = false;
                                  context.go('/ai-chat');
                                } else {
                                  ref.read(sideDrawerOpenProvider.notifier).state = true;
                                                                    context.go('/');
                                }
                              }
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Icon(
                                    isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                                    size: 18,
                                    color: const Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Text(
                                    l10n.settings,
                                    style: isRtl
                                        ? ArabicTypography.screenHeader(color: const Color(0xFF1F2937))
                                        : const TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.6,
                                            color: Color(0xFF1F2937),
                                          ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.settingsSubtitle,
                                    style: isRtl
                                        ? ArabicTypography.subtitle(color: Colors.grey.shade600)
                                        : TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade600,
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                    },
                  ),
                ),
              ),

              // Settings Sections List
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 150),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                  // Section 1: Langue
                  _SettingsCard(
                    title: l10n.language,
                    children: [
                      Row(
                        children: [
                          _LanguageChip(
                            label: 'Français',
                            code: 'fr',
                            isSelected: currentLocale.languageCode == 'fr',
                            onTap: () => ref.read(localeProvider.notifier).setLocale('fr'),
                          ),
                          const SizedBox(width: 10),
                          _LanguageChip(
                            label: 'العربية',
                            code: 'ar',
                            isSelected: currentLocale.languageCode == 'ar',
                            onTap: () => ref.read(localeProvider.notifier).setLocale('ar'),
                          ),
                          const SizedBox(width: 10),
                          _LanguageChip(
                            label: 'English',
                            code: 'en',
                            isSelected: currentLocale.languageCode == 'en',
                            onTap: () => ref.read(localeProvider.notifier).setLocale('en'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section 2: Notifications & Alertes
                  _SettingsCard(
                    title: l10n.notificationsAlerts,
                    children: [
                      _SettingsSwitchRow(
                        icon: Icons.grade_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: l10n.notifGradesTitle,
                        subtitle: l10n.notifGradesSubtitle,
                        value: _notifGrades,
                        onChanged: (v) => setState(() => _notifGrades = v),
                      ),
                      const Divider(color: Color(0xFFF1F5F9), height: 22),
                      _SettingsSwitchRow(
                        icon: Icons.calendar_today_rounded,
                        iconColor: const Color(0xFF3B82F6),
                        title: l10n.notifTimetableTitle,
                        subtitle: l10n.notifTimetableSubtitle,
                        value: _notifSchedule,
                        onChanged: (v) => setState(() => _notifSchedule = v),
                      ),
                      const Divider(color: Color(0xFFF1F5F9), height: 22),
                      _SettingsSwitchRow(
                        icon: Icons.event_busy_rounded,
                        iconColor: const Color(0xFFEF4444),
                        title: l10n.notifAbsencesTitle,
                        subtitle: l10n.notifAbsencesSubtitle,
                        value: _notifAbsences,
                        onChanged: (v) => setState(() => _notifAbsences = v),
                      ),
                      const Divider(color: Color(0xFFF1F5F9), height: 22),
                      _SettingsSwitchRow(
                        icon: Icons.campaign_rounded,
                        iconColor: const Color(0xFF10B981),
                        title: l10n.notifAnnouncementsTitle,
                        subtitle: l10n.notifAnnouncementsSubtitle,
                        value: _notifAnnouncements,
                        onChanged: (v) => setState(() => _notifAnnouncements = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section 3: Sécurité & Accès
                  _SettingsCard(
                    title: l10n.securityAccess,
                    children: [
                      _SettingsActionRow(
                        icon: Icons.lock_outline_rounded,
                        iconColor: const Color(0xFF6366F1),
                        title: l10n.changePasswordLabel,
                        subtitle: l10n.changePasswordSubtitle,
                        onTap: _showChangePasswordDialog,
                      ),
                      const Divider(color: Color(0xFFF1F5F9), height: 22),
                      _SettingsSwitchRow(
                        icon: Icons.fingerprint_rounded,
                        iconColor: const Color(0xFF10B981),
                        title: l10n.biometricLock,
                        subtitle: l10n.biometricLockSubtitle,
                        value: _biometricLock,
                        onChanged: (v) => setState(() => _biometricLock = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section 4: Données & Stockage
                  _SettingsCard(
                    title: l10n.privacyLabel,
                    children: [
                      _SettingsSwitchRow(
                        icon: Icons.wifi_rounded,
                        iconColor: const Color(0xFF3B82F6),
                        title: 'Wi-Fi',
                        subtitle: l10n.clearCacheSubtitle,
                        value: _autoDownloadWifi,
                        onChanged: (v) => setState(() => _autoDownloadWifi = v),
                      ),
                      const Divider(color: Color(0xFFF1F5F9), height: 22),
                      _SettingsActionRow(
                        icon: Icons.cleaning_services_rounded,
                        iconColor: const Color(0xFFEC4899),
                        title: l10n.clearCache,
                        subtitle: l10n.clearCacheSubtitle,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _cacheCleared ? '0 Mo' : '14.8 Mo',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        onTap: _clearAppCache,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section 5: Support & À propos
                  _SettingsCard(
                    title: l10n.about,
                    children: [
                      _SettingsActionRow(
                        icon: Icons.support_agent_rounded,
                        iconColor: const Color(0xFF10B981),
                        title: l10n.contactUs,
                        subtitle: l10n.needHelp,
                        onTap: () => context.push('/contact'),
                      ),
                      const Divider(color: Color(0xFFF1F5F9), height: 22),
                      _SettingsActionRow(
                        icon: Icons.info_outline_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        title: l10n.appVersion,
                        subtitle: 'Pythagore Student Portal',
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _navPink.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'v1.2.0',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _navPink,
                            ),
                          ),
                        ),
                        onTap: null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final isAr = Localizations.localeOf(context).languageCode == 'ar';
              return Text(
                title,
                style: isAr
                    ? ArabicTypography.sectionHeader(fontSize: 17.5, color: const Color(0xFF0F172A))
                    : const TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
              );
            },
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  final String code;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.label,
    required this.code,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BouncingWrapper(
        shrinkScale: 0.93,
        overshootScale: 1.055,
        delayNavigation: false,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? _navPink : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(
                    color: _navPink,
                    width: 1.5,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _navPink.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: code == 'ar'
                ? GoogleFonts.cairo(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  )
                : TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF475569),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Builder(
            builder: (context) {
              final isAr = Localizations.localeOf(context).languageCode == 'ar';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: isAr
                        ? ArabicTypography.cardTitle(fontSize: 14.5, color: const Color(0xFF1E293B))
                        : const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: isAr
                        ? ArabicTypography.bodyLight(fontSize: 12, color: const Color(0xFF64748B))
                        : const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: _navPink,
          activeTrackColor: _navPink.withValues(alpha: 0.4),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: isAr
                        ? ArabicTypography.cardTitle(fontSize: 14.5, color: const Color(0xFF1E293B))
                        : const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: isAr
                        ? ArabicTypography.bodyLight(fontSize: 12, color: const Color(0xFF64748B))
                        : const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Container(
                padding: const EdgeInsets.all(7),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                ),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Icon(
                    isAr ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
