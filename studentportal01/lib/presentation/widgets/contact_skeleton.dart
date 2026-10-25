import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/arabic_typography.dart';

/// Skeleton loader for the Contact Us screen.
/// Follows modern skeleton loader logic:
/// Headers, section cards, static icons, field labels, days of week,
/// map frame, and social media buttons are rendered STATIC and visible immediately.
/// Shimmer placeholders are placed ONLY on variable dynamic values
/// (phone, email, website, address, opening hours values).
class ContactSkeleton extends StatelessWidget {
  const ContactSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
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
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom App Bar with Circular Return Button (STATIC)
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
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
                        child: Icon(
                          isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      l10n.contact,
                      textAlign: isRtl ? TextAlign.right : TextAlign.left,
                      style: ArabicTypography.headerStyle(
                        context,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 1. Header Card - Solid Light White & Borderless (STATIC)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: Color(0xFF3B82F6),
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.needHelp,
                      style: ArabicTypography.headerStyle(
                        context,
                        color: const Color(0xFF1F2937),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.contactDesc,
                      textAlign: TextAlign.center,
                      style: ArabicTypography.bodyStyle(
                        context,
                        color: Colors.grey[600],
                        fontSize: 14.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Single Unified Contact Card
              Container(
                width: double.infinity,
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
                    // Header: Section Title (STATIC)
                    Text(
                      l10n.nosCoordonnees,
                      style: ArabicTypography.subtitleStyle(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Row 1: Téléphone
                    _buildSkeletonContactRow(
                      context,
                      isRtl,
                      icon: Icons.phone_rounded,
                      iconColor: const Color(0xFF10B981),
                      label: l10n.callUs,
                      valueWidth: 110,
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 22),
                    // Row 2: Email
                    _buildSkeletonContactRow(
                      context,
                      isRtl,
                      icon: Icons.email_rounded,
                      iconColor: const Color(0xFF3B82F6),
                      label: l10n.email,
                      valueWidth: 170,
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 22),
                    // Row 3: Site Web
                    _buildSkeletonContactRow(
                      context,
                      isRtl,
                      icon: Icons.language_rounded,
                      iconColor: const Color(0xFF8B5CF6),
                      label: l10n.website,
                      valueWidth: 140,
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 22),
                    // Row 4: Adresse
                    _buildSkeletonContactRow(
                      context,
                      isRtl,
                      icon: Icons.location_on_rounded,
                      iconColor: const Color(0xFFEF4444),
                      label: l10n.visitUs,
                      valueWidth: 190,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Dedicated Opening Hours Table (Horaires Card)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
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
                    // Header row: Title + Badge (STATIC)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          l10n.scheduleTitle,
                          style: ArabicTypography.subtitleStyle(
                            context,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                l10n.openToAll,
                                style: ArabicTypography.bodyStyle(
                                  context,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFF1F5F9), height: 1),
                    const SizedBox(height: 4),
                    // Days List with shimmer hours
                    _buildSkeletonDayRow(context, dayLabel: l10n.dayLun, isToday: DateTime.now().weekday == 1, isLast: false, hoursWidth: 105),
                    _buildSkeletonDayRow(context, dayLabel: l10n.dayMar, isToday: DateTime.now().weekday == 2, isLast: false, hoursWidth: 105),
                    _buildSkeletonDayRow(context, dayLabel: l10n.dayMer, isToday: DateTime.now().weekday == 3, isLast: false, hoursWidth: 105),
                    _buildSkeletonDayRow(context, dayLabel: l10n.dayJeu, isToday: DateTime.now().weekday == 4, isLast: false, hoursWidth: 105),
                    _buildSkeletonDayRow(context, dayLabel: l10n.dayVen, isToday: DateTime.now().weekday == 5, isLast: false, hoursWidth: 105),
                    _buildSkeletonDayRow(context, dayLabel: l10n.daySam, isToday: DateTime.now().weekday == 6, isLast: false, hoursWidth: 105),
                    _buildSkeletonDayRow(context, dayLabel: l10n.dayDim, isToday: DateTime.now().weekday == 7, isLast: true, hoursWidth: 60),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Clickable iOS-Style Location Map Preview Card
              Container(
                width: double.infinity,
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
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Canvas / Vector Styled Map Canvas placeholder
                    Container(
                      height: 155,
                      width: double.infinity,
                      color: const Color(0xFFF4F6F8),
                      child: Stack(
                        children: [
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.school_rounded, color: Color(0xFFEF4444), size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        l10n.etablissement,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                                ),
                              ],
                            ),
                          ),
                          // Google Maps Tag Top Right
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.map_rounded, size: 12, color: Color(0xFF3B82F6)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Google Maps',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bottom Info Bar
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.locationAccess,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _shimmerBox(width: 170, height: 13, radius: 4),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.directions,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
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
              ),
              const SizedBox(height: 28),

              // 5. Social Media Section (STATIC)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  l10n.joinUsSocial,
                  style: ArabicTypography.subtitleStyle(
                    context,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialButton(
                    iconWidget: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 32),
                    label: 'Facebook',
                  ),
                  const SizedBox(width: 20),
                  _socialButton(
                    iconWidget: Image.asset(
                      'assets/icons/insta.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.camera_alt_rounded, color: Color(0xFFE1306C), size: 32),
                    ),
                    label: 'Instagram',
                  ),
                  const SizedBox(width: 20),
                  _socialButton(
                    iconWidget: Image.asset(
                      'assets/icons/tiktok.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.music_note_rounded, color: Colors.black, size: 32),
                    ),
                    label: 'TikTok',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _shimmerBox({
    required double width,
    required double height,
    required double radius,
  }) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  static Widget _buildSkeletonContactRow(
    BuildContext context,
    bool isRtl, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required double valueWidth,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: ArabicTypography.bodyStyle(
                    context,
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                _shimmerBox(width: valueWidth, height: 15, radius: 4),
              ],
            ),
          ),
          Icon(
            isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            color: const Color(0xFFCBD5E1),
            size: 20,
          ),
        ],
      ),
    );
  }

  static Widget _buildSkeletonDayRow(
    BuildContext context, {
    required String dayLabel,
    required bool isToday,
    required bool isLast,
    required double hoursWidth,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      decoration: BoxDecoration(
        color: isToday ? const Color(0xFFF8FAFC) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF8FAFC), width: 1),
              ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              dayLabel,
              style: ArabicTypography.bodyStyle(
                context,
                fontSize: 15,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday ? const Color(0xFF0F172A) : const Color(0xFF475569),
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _shimmerBox(width: hoursWidth, height: 14, radius: 4),
          ),
        ],
      ),
    );
  }

  static Widget _socialButton({
    required Widget iconWidget,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(child: iconWidget),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}
