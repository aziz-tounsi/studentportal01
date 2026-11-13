import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/localization/console_translations.dart';
import '../../core/theme/console_theme.dart';
import '../providers/console_auth_provider.dart';
import '../providers/platform_provider.dart';

class ConsoleSettingsView extends ConsumerStatefulWidget {
  final PlatformState platformState;
  final Map<String, dynamic>? user;

  const ConsoleSettingsView({
    super.key,
    required this.platformState,
    required this.user,
  });

  @override
  ConsumerState<ConsoleSettingsView> createState() => _ConsoleSettingsViewState();
}

class _ConsoleSettingsViewState extends ConsumerState<ConsoleSettingsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _defaultModelCtrl;
  late TextEditingController _fallbackModelCtrl;
  late TextEditingController _supportEmailCtrl;
  String _selectedCurrency = 'TND';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    final settings = widget.platformState.platformSettings ?? {};
    _defaultModelCtrl = TextEditingController(
      text: settings['default_ai_model']?.toString() ??
          'google/gemini-2.0-flash-exp:free',
    );
    _fallbackModelCtrl = TextEditingController(
      text: settings['fallback_ai_model']?.toString() ??
          'deepseek/deepseek-chat',
    );
    _supportEmailCtrl = TextEditingController(
      text: settings['support_email']?.toString() ?? 'support@pythagore.tn',
    );
    _selectedCurrency =
        settings['platform_fee_currency']?.toString() ?? 'TND';
  }

  @override
  void didUpdateWidget(covariant ConsoleSettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.platformState.platformSettings !=
        widget.platformState.platformSettings) {
      final s = widget.platformState.platformSettings ?? {};
      if (!_isSaving) {
        _defaultModelCtrl.text = s['default_ai_model']?.toString() ??
            'google/gemini-2.0-flash-exp:free';
        _fallbackModelCtrl.text = s['fallback_ai_model']?.toString() ??
            'deepseek/deepseek-chat';
        _supportEmailCtrl.text =
            s['support_email']?.toString() ?? 'support@pythagore.tn';
        setState(() {
          _selectedCurrency = s['platform_fee_currency']?.toString() ?? 'TND';
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _defaultModelCtrl.dispose();
    _fallbackModelCtrl.dispose();
    _supportEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings(ConsoleStrings tr) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final ok = await ref.read(platformProvider.notifier).updatePlatformSettings(
          defaultAiModel: _defaultModelCtrl.text.trim(),
          fallbackAiModel: _fallbackModelCtrl.text.trim(),
          supportEmail: _supportEmailCtrl.text.trim(),
          platformFeeCurrency: _selectedCurrency,
        );

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                ok ? tr.settingsSavedToast : 'Error saving settings',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          backgroundColor:
              ok ? ConsoleColors.success : ConsoleColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = ref.watch(consoleTranslationsProvider);
    final currentLang = ref.watch(consoleLocaleProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Tabs Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ConsoleColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                gradient: ConsoleColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: ConsoleColors.brand.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: ConsoleColors.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  icon: const Icon(Icons.language_rounded, size: 18),
                  text: tr.tabLanguage,
                ),
                Tab(
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  text: tr.tabPlatform,
                ),
                Tab(
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                  text: tr.tabSecurity,
                ),
                Tab(
                  icon: const Icon(Icons.info_outline_rounded, size: 18),
                  text: tr.tabSystem,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Tab View Content
          SizedBox(
            height: 640,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLanguageTab(tr, currentLang),
                _buildPlatformConfigTab(tr),
                _buildSecurityTab(tr),
                _buildSystemTab(tr),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: Language & Localization
  // ---------------------------------------------------------------------------
  Widget _buildLanguageTab(ConsoleStrings tr, ConsoleLanguage currentLang) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ConsoleColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 14,
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ConsoleColors.brandSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.translate_rounded,
                        color: ConsoleColors.brand,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.langChoiceTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: ConsoleColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr.langChoiceSubtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: ConsoleColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: _buildLangCard(
                        title: 'English (US)',
                        subtitle: 'Default developer console language',
                        badge: 'Default',
                        badgeColor: ConsoleColors.brand,
                        badgeLabel: 'EN',
                        badgeGradient: const [Color(0xFF6D4CF6), Color(0xFF2563EB)],
                        isSelected: currentLang == ConsoleLanguage.en,
                        onTap: () {
                          ref
                              .read(consoleLocaleProvider.notifier)
                              .setLanguage(ConsoleLanguage.en);
                          _notifyLanguageSwitch(tr.langChangedToast);
                        },
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: _buildLangCard(
                        title: 'Français (French)',
                        subtitle: 'Complete interface in French',
                        badge: 'Français',
                        badgeColor: const Color(0xFF2563EB),
                        badgeLabel: 'FR',
                        badgeGradient: const [Color(0xFF2563EB), Color(0xFF0EA5E9)],
                        isSelected: currentLang == ConsoleLanguage.fr,
                        onTap: () {
                          ref
                              .read(consoleLocaleProvider.notifier)
                              .setLanguage(ConsoleLanguage.fr);
                          _notifyLanguageSwitch('Langue changée en Français');
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: ConsoleColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: ConsoleColors.brand,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          currentLang == ConsoleLanguage.en
                              ? 'Preference is saved locally. English is loaded automatically whenever you sign in.'
                              : 'Votre préférence est sauvegardée localement. L\'anglais reste la langue par défaut.',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: ConsoleColors.textSecondary,
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

  Widget _buildLangCard({
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required String badgeLabel,
    required List<Color> badgeGradient,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected
                ? ConsoleColors.brandSoft.withValues(alpha: 0.5)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? ConsoleColors.brand : ConsoleColors.cardBorder,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: ConsoleColors.brand.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: badgeGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: badgeGradient.first.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    badgeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? ConsoleColors.brand
                                : ConsoleColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: ConsoleColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected
                    ? ConsoleColors.brand
                    : ConsoleColors.textTertiary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _notifyLanguageSwitch(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: ConsoleColors.brand,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: Global Platform Config
  // ---------------------------------------------------------------------------
  Widget _buildPlatformConfigTab(ConsoleStrings tr) {
    final killSwitchActive =
        widget.platformState.platformSettings?['global_ai_kill_switch'] == true;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ConsoleColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 14,
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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Color(0xFF2563EB),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr.platformConfigHeader,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: ConsoleColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr.platformConfigSubtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: ConsoleColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // AI Kill-Switch Direct Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: killSwitchActive
                          ? ConsoleColors.errorSoft
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: killSwitchActive
                            ? ConsoleColors.error.withValues(alpha: 0.3)
                            : ConsoleColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          killSwitchActive
                              ? Icons.gpp_bad_rounded
                              : Icons.gpp_good_rounded,
                          color: killSwitchActive
                              ? ConsoleColors.error
                              : ConsoleColors.success,
                          size: 26,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                killSwitchActive
                                    ? tr.killSwitchStatusBlocked
                                    : tr.killSwitchStatusActive,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: killSwitchActive
                                      ? ConsoleColors.error
                                      : ConsoleColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tr.killSwitchWarning,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: ConsoleColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: killSwitchActive,
                          activeThumbColor: ConsoleColors.error,
                          onChanged: (val) {
                            ref
                                .read(platformProvider.notifier)
                                .toggleAiKillSwitch(val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Models row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr.fieldDefaultModel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ConsoleColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _defaultModelCtrl,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.auto_awesome_outlined,
                                  size: 18,
                                  color: ConsoleColors.textTertiary,
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr.fieldFallbackModel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ConsoleColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _fallbackModelCtrl,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.shield_outlined,
                                  size: 18,
                                  color: ConsoleColors.textTertiary,
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Support email & currency
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr.fieldSupportEmail,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ConsoleColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _supportEmailCtrl,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.mail_outline,
                                  size: 18,
                                  color: ConsoleColors.textTertiary,
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr.fieldCurrency,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ConsoleColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCurrency,
                              items: const [
                                DropdownMenuItem(value: 'TND', child: Text('TND (Dinar Tunisien)')),
                                DropdownMenuItem(value: 'USD', child: Text('USD (US Dollar \$)')),
                                DropdownMenuItem(value: 'EUR', child: Text('EUR (Euro €)')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedCurrency = v);
                                }
                              },
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.payments_outlined,
                                  size: 18,
                                  color: ConsoleColors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : () => _saveSettings(tr),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        _isSaving ? tr.loading : tr.btnSaveSettings,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ConsoleColors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
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

  // ---------------------------------------------------------------------------
  // TAB 3: Super Admin Security & Profile
  // ---------------------------------------------------------------------------
  Widget _buildSecurityTab(ConsoleStrings tr) {
    final user = widget.user ?? {};
    final fullName = user['full_name']?.toString() ?? 'Super Administrator';
    final email = user['email']?.toString() ?? 'admin@pythagore.tn';
    final role = user['role']?.toString() ?? 'super_admin';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ConsoleColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 14,
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
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: ConsoleColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          fullName.isNotEmpty ? fullName[0].toUpperCase() : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: ConsoleColors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: ConsoleColors.brandSoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  role.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: ConsoleColors.brand,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 13,
                              color: ConsoleColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Divider(color: ConsoleColors.divider),
                const SizedBox(height: 20),

                // Credentials metadata
                _buildInfoRow(
                  icon: Icons.badge_outlined,
                  label: tr.adminRole,
                  value: tr.adminRolePill,
                ),
                const SizedBox(height: 14),
                _buildInfoRow(
                  icon: Icons.fingerprint_rounded,
                  label: 'User ID',
                  value: user['id']?.toString() ?? 'N/A',
                ),
                const SizedBox(height: 14),
                _buildInfoRow(
                  icon: Icons.lock_clock_outlined,
                  label: 'Session',
                  value: Supabase.instance.client.auth.currentSession != null
                      ? 'Active Authenticated JWT Token'
                      : 'Unknown',
                ),
                const SizedBox(height: 28),

                // Sign out button
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(consoleAuthProvider.notifier).signOut();
                  },
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 17,
                    color: ConsoleColors.error,
                  ),
                  label: Text(
                    tr.navLogout,
                    style: const TextStyle(
                      color: ConsoleColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    backgroundColor: const Color(0xFFFEF2F2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  // ---------------------------------------------------------------------------
  // TAB 4: System Info & Runtime Health
  // ---------------------------------------------------------------------------
  Widget _buildSystemTab(ConsoleStrings tr) {
    final schoolCount = widget.platformState.schools.length;
    final activeCount =
        widget.platformState.kpis['activeSchoolsCount'] ?? schoolCount;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ConsoleColors.cardBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 14,
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ConsoleColors.successSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.dns_outlined,
                        color: ConsoleColors.success,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.systemInfoHeader,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: ConsoleColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Real-time multi-tenant runtime metrics and versions',
                            style: TextStyle(
                              fontSize: 13,
                              color: ConsoleColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(color: ConsoleColors.divider),
                const SizedBox(height: 18),

                _buildInfoRow(
                  icon: Icons.layers_outlined,
                  label: tr.appVersion,
                  value: 'v1.0.0-saas (Aurora Glass Light Edition)',
                ),
                const SizedBox(height: 14),
                _buildInfoRow(
                  icon: Icons.cloud_done_outlined,
                  label: tr.databaseHost,
                  value: 'cazuauxivrboygehrkij.supabase.co (PostgreSQL 15 / RLS Enabled)',
                ),
                const SizedBox(height: 14),
                _buildInfoRow(
                  icon: Icons.domain_verification_outlined,
                  label: 'Registered Tenants',
                  value: '$schoolCount Total ($activeCount Active)',
                ),
                const SizedBox(height: 14),
                _buildInfoRow(
                  icon: Icons.shield_outlined,
                  label: tr.environment,
                  value: tr.prodEnv,
                ),
                const SizedBox(height: 14),
                _buildInfoRow(
                  icon: Icons.devices_rounded,
                  label: tr.flutterVersion,
                  value: 'Flutter 3.x (Dart 3.x / Web CanvasKit)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ConsoleColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ConsoleColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ConsoleColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: ConsoleColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
