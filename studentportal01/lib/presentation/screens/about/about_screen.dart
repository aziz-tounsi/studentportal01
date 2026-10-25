import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/arabic_typography.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_bar_provider.dart';
import '../../providers/suggestions_provider.dart';
import '../../widgets/bouncing_wrapper.dart';
import '../../widgets/ios_edge_swipe_back.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _launchPortfolio() async {
    const portfolioUrl = 'https://aziz-tounsi.github.io/';
    final uri = Uri.parse(portfolioUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Error launching portfolio url: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
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
                            hitPadding: const EdgeInsets.all(14),
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
                                  ref.read(navBarHiddenProvider.notifier).state = true;
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
                                  l10n.about,
                                  style: ArabicTypography.headerStyle(
                                    context,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                    color: const Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.aboutSubtitle,
                                  style: ArabicTypography.subtitleStyle(
                                    context,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
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

              // Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 1. Logo & School Hero Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              size: 42,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Lycée Pythagore',
                            style: ArabicTypography.headerStyle(
                              context,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.aboutDesc,
                            style: ArabicTypography.bodyStyle(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF64748B),
                              height: 1.55,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Features Section (Redesigned: Clean, Minimal, Modern with Icons)
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFF6366F1),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.features,
                                style: ArabicTypography.subtitleStyle(
                                  context,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Feature Rows
                          _FeatureRow(
                            icon: Icons.auto_graph_rounded,
                            iconColor: const Color(0xFF3B82F6),
                            title: l10n.featureAcademicTrackingTitle,
                            subtitle: l10n.featureAcademicTrackingDesc,
                          ),
                          const Divider(color: Color(0xFFF1F5F9), height: 20),
                          _FeatureRow(
                            icon: Icons.calendar_month_rounded,
                            iconColor: const Color(0xFF10B981),
                            title: l10n.featureDynamicScheduleTitle,
                            subtitle: l10n.featureDynamicScheduleDesc,
                          ),
                          const Divider(color: Color(0xFFF1F5F9), height: 20),
                          _FeatureRow(
                            icon: Icons.verified_user_rounded,
                            iconColor: const Color(0xFFF43F5E),
                            title: l10n.featureAttendanceTitle,
                            subtitle: l10n.featureAttendanceDesc,
                          ),
                          const Divider(color: Color(0xFFF1F5F9), height: 20),
                          _FeatureRow(
                            icon: Icons.folder_shared_rounded,
                            iconColor: const Color(0xFF8B5CF6),
                            title: l10n.featureDocumentsTitle,
                            subtitle: l10n.featureDocumentsDesc,
                          ),
                          const Divider(color: Color(0xFFF1F5F9), height: 20),
                          _FeatureRow(
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            title: l10n.featureFinancialTitle,
                            subtitle: l10n.featureFinancialDesc,
                          ),
                          const Divider(color: Color(0xFFF1F5F9), height: 20),
                          _FeatureRow(
                            icon: Icons.smart_toy_rounded,
                            iconColor: const Color(0xFFFF2D78),
                            title: l10n.featureAiTitle,
                            subtitle: l10n.featureAiDesc,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. Report a Bug Section (Animated & Styled like Suggestion Page)
                    const _BugReportCard(),
                    const SizedBox(height: 20),

                    // 4. Application Developer Section (Minimal, Clean & Pro)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Developer Text
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.code_rounded,
                                size: 15,
                                color: Color(0xFFFF2D78),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.applicationDeveloper.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: Color(0xFFFF2D78),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Navbar Pink Portfolio CTA Button
                          GestureDetector(
                            onTap: _launchPortfolio,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF2D78), Color(0xFFFF5CA0)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF2D78).withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.arrow_outward_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.visitPortfolio,
                                    style: ArabicTypography.buttonStyle(
                                      context,
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Version Footer: 2026
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${l10n.appVersion} 1.2.0 • 2026',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ArabicTypography.subtitleStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: ArabicTypography.bodyStyle(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BugReportCard extends ConsumerStatefulWidget {
  const _BugReportCard();

  @override
  ConsumerState<_BugReportCard> createState() => _BugReportCardState();
}

class _BugReportCardState extends ConsumerState<_BugReportCard> {
  bool _isExpanded = false;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  String _selectedCategory = 'functional';
  final List<PlatformFile> _attachments = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshots() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachments.addAll(result.files);
        });
      }
    } catch (e) {
      debugPrint('Error picking screenshots: $e');
    }
  }

  Future<void> _submitReport(AppLocalizations l10n) async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'ar'
                ? 'يرجى كتابة عنوان وتفاصيل المشكلة'
                : 'Veuillez saisir un titre et une description du bug',
          ),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      final authState = ref.read(authProvider);
      final userId = authState.user?.id ?? supabase.auth.currentSession?.user.id ?? 'unknown';

      List<String>? attachmentUrls;
      List<String>? attachmentNames;
      List<String>? attachmentTypes;

      if (_attachments.isNotEmpty) {
        attachmentUrls = [];
        attachmentNames = [];
        attachmentTypes = [];

        for (final file in _attachments) {
          try {
            final bytes = file.bytes;
            if (bytes != null) {
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final storePath = 'bugs/$userId/${timestamp}_${file.name}';
              await supabase.storage.from('suggestions').uploadBinary(storePath, bytes);
              final url = supabase.storage.from('suggestions').getPublicUrl(storePath);
              attachmentUrls.add(url);
              attachmentNames.add(file.name);
              attachmentTypes.add(file.extension ?? 'image');
            }
          } catch (e) {
            debugPrint('Error uploading bug screenshot: $e');
          }
        }
      }

      // 1. Submit through suggestion repository (with [BUG REPORT] prefix and screenshots)
      await ref.read(suggestionRepositoryProvider).createSuggestion(
        title: '[BUG - $_selectedCategory] $title',
        body: '$desc\n\nOS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        suggestionType: 'technique',
        attachmentUrls: attachmentUrls,
        attachmentNames: attachmentNames,
        attachmentTypes: attachmentTypes,
      );

      // 2. Also try inserting into bug_reports table directly if configured on backend
      try {
        await supabase.from('bug_reports').insert({
          'user_id': userId,
          'student_name': authState.user?.fullName,
          'student_code': authState.user?.studentCode,
          'category': _selectedCategory,
          'title': title,
          'description': desc,
          'screenshots': attachmentUrls,
          'os': Platform.operatingSystem,
          'status': 'open',
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}

      if (mounted) {
        setState(() {
          _titleCtrl.clear();
          _descCtrl.clear();
          _attachments.clear();
          _isExpanded = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.bugReportSuccess)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: const Color(0xFFF43F5E),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final categories = [
      {'key': 'visual', 'label': l10n.bugTypeVisual, 'icon': Icons.palette_outlined},
      {'key': 'functional', 'label': l10n.bugTypeFunctional, 'icon': Icons.tune_rounded},
      {'key': 'crash', 'label': l10n.bugTypeCrash, 'icon': Icons.warning_amber_rounded},
      {'key': 'other', 'label': l10n.bugTypeOther, 'icon': Icons.help_outline_rounded},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _isExpanded ? const Color(0xFFF43F5E).withValues(alpha: 0.35) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isExpanded
                ? const Color(0xFFF43F5E).withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header / Toggle
          BouncingWrapper(
            shrinkScale: 0.98,
            delayNavigation: false,
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.bug_report_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.reportABug,
                          style: ArabicTypography.headerStyle(
                            context,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.reportBugSubtitle,
                          style: ArabicTypography.subtitleStyle(
                            context,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: _isExpanded ? 3 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isExpanded ? (isRtl ? -0.25 : 0.25) : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _isExpanded
                            ? const Color(0xFFF43F5E).withValues(alpha: 0.1)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                        color: _isExpanded ? const Color(0xFFF43F5E) : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Animated Form Body
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Color(0xFFF1F5F9), height: 1),
                  const SizedBox(height: 18),

                  // Category Selector
                  Text(
                    l10n.bugTypeLabel,
                    style: ArabicTypography.cardTitle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = _selectedCategory == cat['key'];
                      return BouncingWrapper(
                        shrinkScale: 0.94,
                        overshootScale: 1.05,
                        delayNavigation: false,
                        onTap: () => setState(() => _selectedCategory = cat['key'] as String),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF43F5E)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFF43F5E)
                                  : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cat['icon'] as IconData,
                                size: 15,
                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat['label'] as String,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                  color: isSelected ? Colors.white : const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Bug Title Field
                  Text(
                    l10n.bugTitleLabel,
                    style: ArabicTypography.cardTitle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: l10n.bugTitleHint,
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFF43F5E), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bug Description Field
                  Text(
                    l10n.bugDescLabel,
                    style: ArabicTypography.cardTitle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: l10n.bugDescHint,
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFF43F5E), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Screenshots Attachment Area
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.addScreenshots,
                        style: ArabicTypography.cardTitle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      BouncingWrapper(
                        shrinkScale: 0.92,
                        overshootScale: 1.06,
                        delayNavigation: false,
                        onTap: _pickScreenshots,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_photo_alternate_rounded, size: 16, color: Color(0xFF475569)),
                              SizedBox(width: 6),
                              Icon(Icons.add_rounded, size: 14, color: Color(0xFF475569)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _attachments.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final f = entry.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.image_rounded, size: 16, color: Color(0xFFF43F5E)),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 140),
                                child: Text(
                                  f.name,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => setState(() => _attachments.removeAt(idx)),
                                child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Submit Button
                  BouncingWrapper(
                    shrinkScale: 0.95,
                    overshootScale: 1.04,
                    delayNavigation: false,
                    onTap: _isSubmitting ? null : () => _submitReport(l10n),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF43F5E).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.2,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.submitBugReport,
                                    style: ArabicTypography.buttonStyle(
                                      context,
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
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
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 280),
          ),
        ],
      ),
    );
  }
}
