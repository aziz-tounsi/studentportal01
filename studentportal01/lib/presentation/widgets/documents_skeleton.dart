import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/arabic_typography.dart';

/// Skeleton loader for the Documents screen.
/// Follows modern skeleton loader logic:
/// Scaffolding, static Sort & Filter controls, clock icons, bullet separators,
/// and chevron arrows remain STATIC and immediately visible.
/// Only variable elements (category icon box, document title, description,
/// date, file size) have shimmer placeholders.
class DocumentsCardsSkeleton extends StatelessWidget {
  final String? selectedCategoryLabel;

  const DocumentsCardsSkeleton({
    super.key,
    this.selectedCategoryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = ArabicTypography.isArabic(context);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Static Sort & Filter Bar - NOT shimmering!
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Text(
                  l10n.sortBy,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.8),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6B5CE7).withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedCategoryLabel ?? l10n.allTypes,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Document card skeletons
          _buildDocumentCardSkeleton(context, isAr, titleWidth: 160, descWidth: 220),
          _buildDocumentCardSkeleton(context, isAr, titleWidth: 200, descWidth: 180),
          _buildDocumentCardSkeleton(context, isAr, titleWidth: 140, descWidth: 240),
          _buildDocumentCardSkeleton(context, isAr, titleWidth: 175, descWidth: 210),
          _buildDocumentCardSkeleton(context, isAr, titleWidth: 155, descWidth: 190),

          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildDocumentCardSkeleton(
    BuildContext context,
    bool isAr, {
    required double titleWidth,
    required double descWidth,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category icon box shimmer (variable category icon)
          Shimmer.fromColors(
            baseColor: const Color(0xFFD1D5DB),
            highlightColor: const Color(0xFFF3F4F6),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Center texts: title & description shimmer, static meta icon & bullet
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title shimmer (variable text)
                Shimmer.fromColors(
                  baseColor: const Color(0xFFD1D5DB),
                  highlightColor: const Color(0xFFF3F4F6),
                  child: Container(
                    width: titleWidth,
                    height: 15,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 7),

                // Subtitle/description shimmer (variable text)
                Shimmer.fromColors(
                  baseColor: const Color(0xFFE5E7EB),
                  highlightColor: const Color(0xFFF9FAFB),
                  child: Container(
                    width: descWidth,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 9),

                // Meta row with STATIC clock icon and bullet, shimmer for date and size
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Shimmer.fromColors(
                      baseColor: const Color(0xFFE5E7EB),
                      highlightColor: const Color(0xFFF9FAFB),
                      child: Container(
                        width: 65,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Shimmer.fromColors(
                      baseColor: const Color(0xFFE5E7EB),
                      highlightColor: const Color(0xFFF9FAFB),
                      child: Container(
                        width: 42,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Trailing grey arrow - STATIC!
          Icon(
            isAr ? Icons.arrow_back_ios_new_rounded : Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Colors.grey[300],
          ),
        ],
      ),
    );
  }
}
