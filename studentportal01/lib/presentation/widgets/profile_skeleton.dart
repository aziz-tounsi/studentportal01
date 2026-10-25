import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/arabic_typography.dart';

const Color _navPink = Color(0xFFFF2D78);

/// Skeleton loader for the Profile screen (Mon Profil).
/// Follows modern skeleton loader logic:
/// Scaffolding, navigation, headers, section titles, row icons, field labels,
/// and the logout button remain STATIC and immediately visible.
/// Only variable student data (avatar, full name, email, student code, phone,
/// birthday, address, school, level, section, class, status) has shimmer placeholders.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

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
            children: [
              // Header Row - Back Button + Title + Subtitle (STATIC)
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
                          isRtl
                              ? Icons.arrow_forward_ios_rounded
                              : Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: const Color(0xFF1F2937),
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
                          l10n.monProfil,
                          style: ArabicTypography.headerStyle(
                            context,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1F2937),
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.profilSubtitle,
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
              ),
              const SizedBox(height: 20),

              // Hero Profile Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
                    // Avatar stack: gradient ring + inner shimmer circle + static pink camera badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_navPink, Color(0xFFFF5E98)],
                            ),
                          ),
                          padding: const EdgeInsets.all(3.5),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: ClipOval(
                              child: _shimmerCircle(size: 100),
                            ),
                          ),
                        ),
                        // Camera edit badge - PINK color (STATIC)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [_navPink, Color(0xFFFF5E98)],
                              ),
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: _navPink.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Full Name shimmer (variable text)
                    _shimmerBox(width: 160, height: 20, radius: 6),
                    const SizedBox(height: 8),
                    // Email shimmer (variable text)
                    _shimmerBox(width: 130, height: 14, radius: 4),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 1: Informations Personnelles Card
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
                    // Section Title (STATIC)
                    Text(
                      l10n.personalInfo,
                      style: ArabicTypography.subtitleStyle(
                        context,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSkeletonInfoItem(
                      context,
                      icon: Icons.person_outline_rounded,
                      color: const Color(0xFF3B82F6),
                      label: l10n.fullName,
                      valueWidth: 150,
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),
                    _buildSkeletonInfoItem(
                      context,
                      icon: Icons.badge_outlined,
                      color: const Color(0xFF6366F1),
                      label: l10n.studentCode,
                      valueWidth: 100,
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),
                    _buildSkeletonInfoItem(
                      context,
                      icon: Icons.email_outlined,
                      color: const Color(0xFF10B981),
                      label: l10n.email,
                      valueWidth: 170,
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),
                    _buildSkeletonInfoItem(
                      context,
                      icon: Icons.phone_outlined,
                      color: const Color(0xFFF59E0B),
                      label: l10n.phone,
                      valueWidth: 120,
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),
                    _buildSkeletonInfoItem(
                      context,
                      icon: Icons.cake_outlined,
                      color: const Color(0xFFEC4899),
                      label: l10n.dateOfBirth,
                      valueWidth: 110,
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),
                    _buildSkeletonInfoItem(
                      context,
                      icon: Icons.location_on_outlined,
                      color: const Color(0xFF8B5CF6),
                      label: l10n.address,
                      valueWidth: 160,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 2: Informations Académiques Card
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
                    // Section Title (STATIC)
                    Text(
                      l10n.academicInfo,
                      style: ArabicTypography.subtitleStyle(
                        context,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSkeletonInfoItem(
                      context,
                      icon: Icons.account_balance_outlined,
                      color: const Color(0xFF3B82F6),
                      label: l10n.etablissement,
                      valueWidth: 140,
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),
                    _buildSkeletonInfoItem(
                      context,
                      icon: Icons.layers_outlined,
                      color: const Color(0xFF8B5CF6),
                      label: l10n.niveau,
                      valueWidth: 100,
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),
                    _buildSkeletonInfoItem(
                      context,
                      icon: Icons.school_outlined,
                      color: const Color(0xFFEC4899),
                      label: l10n.filiere,
                      valueWidth: 150,
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),
                    _buildSkeletonInfoItem(
                      context,
                      icon: Icons.class_outlined,
                      color: const Color(0xFF10B981),
                      label: l10n.currentClass,
                      valueWidth: 90,
                    ),
                    const Divider(color: Color(0xFFF1F5F9), height: 16),
                    _buildSkeletonInfoItem(
                      context,
                      icon: Icons.verified_outlined,
                      color: const Color(0xFF10B981),
                      label: l10n.enrollmentStatus,
                      valueWidth: 130,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Déconnexion Button (STATIC)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.logout,
                      style: ArabicTypography.buttonStyle(
                        context,
                        color: const Color(0xFFEF4444),
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _shimmerCircle({required double size}) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFE2E8F0),
          shape: BoxShape.circle,
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

  static Widget _buildSkeletonInfoItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required double valueWidth,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
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
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 6),
                _shimmerBox(width: valueWidth, height: 14, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
