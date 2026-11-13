import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/arabic_typography.dart';
import '../../../core/theme/responsive.dart';
import '../../providers/nav_bar_provider.dart';
import '../../providers/school_provider.dart';
import '../../widgets/bouncing_wrapper.dart';
import '../../widgets/ios_edge_swipe_back.dart';
import '../../widgets/school_logo_widget.dart';

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
    final school = ref.watch(schoolProvider).valueOrNull;
    final schoolName = (school != null && school.name.trim().isNotEmpty)
        ? school.name.trim()
        : 'Student Portal';
    final schoolBio = school?.bio?.trim();

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
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  // Custom Header with Circular Back Button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(context.horizontalPadding, 16, context.horizontalPadding, 16),
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
                                  width: context.scaleW(44).clamp(38.0, 48.0),
                                  height: context.scaleW(44).clamp(38.0, 48.0),
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
                                        size: context.scaleW(18).clamp(16.0, 20.0),
                                        color: const Color(0xFF1F2937),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: context.scaleW(14).clamp(10.0, 16.0)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: AlignmentDirectional.centerStart,
                                      child: Text(
                                        l10n.about,
                                        style: ArabicTypography.headerStyle(
                                          context,
                                          fontSize: context.sp(26),
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.6,
                                          color: const Color(0xFF1F2937),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.aboutSubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: ArabicTypography.subtitleStyle(
                                        context,
                                        fontSize: context.sp(13.5),
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
                    padding: EdgeInsets.fromLTRB(context.horizontalPadding, 8, context.horizontalPadding, 124 + MediaQuery.of(context).padding.bottom),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // 1. Logo & School Hero Card
                        Container(
                          padding: EdgeInsets.all(AppResponsive.cardPadding(context, base: 26.0)),
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
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: SchoolLogoWidget(
                              logoUrl: school?.logoUrl,
                              size: 80,
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            schoolName,
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
                            (schoolBio != null && schoolBio.isNotEmpty)
                                ? schoolBio
                                : l10n.aboutDesc,
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

                    // 3. Report a Bug Section (Navigates to dedicated /report-bug page)
                    BouncingWrapper(
                      shrinkScale: 0.95,
                      overshootScale: 1.04,
                      delayNavigation: false,
                      onTap: () => context.go('/report-bug'),
                      child: Container(
                        padding: const EdgeInsets.all(20),
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
                        child: Builder(
                          builder: (ctx) {
                            final isRtl = Directionality.of(ctx) == TextDirection.rtl;
                            return Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.bug_report_rounded,
                                    color: Color(0xFFEF4444),
                                    size: 26,
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
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        l10n.reportBugSubtitle,
                                        style: ArabicTypography.bodyStyle(
                                          context,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w400,
                                          color: const Color(0xFF64748B),
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isRtl ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: Colors.grey.shade400,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
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

                          // Navbar Pink Portfolio CTA Button with press-hold bounce
                          BouncingWrapper(
                            shrinkScale: 0.93,
                            overshootScale: 1.052,
                            delayNavigation: false,
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
