import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/arabic_typography.dart';
import 'bouncing_wrapper.dart';

/// Reusable animated search header component
/// Used across Notifications, Messages, and Suggestions screens
class AnimatedSearchHeader extends StatelessWidget {
  final AnimationController animationController;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onToggleSearch;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final bool isSearching;

  const AnimatedSearchHeader({
    super.key,
    required this.animationController,
    required this.searchController,
    required this.searchFocusNode,
    required this.onToggleSearch,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.isSearching,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animationController,
      builder: (context, child) {
        final screenW = MediaQuery.sizeOf(context).width;
        final scale = (screenW / 440.0).clamp(0.72, 1.15);
        final iconBoxSize = (56.0 * scale).clamp(44.0, 56.0);
        final iconSize = (28.0 * scale).clamp(22.0, 28.0);
        final titleSize = (28.0 * (1.0 + (scale - 1.0) * 0.75)).clamp(19.0, 28.0);
        final subtitleSize = (14.0 * (1.0 + (scale - 1.0) * 0.75)).clamp(11.5, 14.0);
        final searchBtnSize = (50.0 * scale).clamp(44.0, 50.0);
        final slideValue = animationController.value;
        final fadeOut = 1.0 - slideValue;
        final fadeIn = slideValue;

        return SizedBox(
          height: 76,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Normal header - slides out to left and fades
              Transform.translate(
                offset: Offset(-80 * slideValue, 0),
                child: Opacity(
                  opacity: fadeOut.clamp(0.0, 1.0),
                  child: Row(
                    children: [
                      // Icon with scale animation
                      Transform.scale(
                        scale: 1.0 - (0.3 * slideValue),
                        child: Container(
                          width: iconBoxSize,
                          height: iconBoxSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradientColors,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gradientColors.first.withValues(alpha: 0.4),
                                blurRadius: 20 * scale,
                                offset: Offset(0, 8 * scale),
                              ),
                            ],
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: iconSize,
                          ),
                        ),
                      ),
                      SizedBox(width: (16 * scale).clamp(10.0, 16.0)),
                      // Title
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final isAr = Localizations.localeOf(context).languageCode == 'ar';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: isAr
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Text(
                                    title,
                                    style: isAr
                                        ? GoogleFonts.cairo(
                                            fontSize: titleSize,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.grey[900],
                                            letterSpacing: -0.5,
                                          )
                                        : TextStyle(
                                            fontSize: titleSize,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.grey[900],
                                            letterSpacing: -0.8,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: isAr
                                      ? GoogleFonts.cairo(
                                          fontSize: subtitleSize,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[600],
                                        )
                                      : TextStyle(
                                          fontSize: subtitleSize,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      // Search button
                      BouncingWrapper(
                        shrinkScale: 0.86,
                        hitPadding: const EdgeInsets.all(8),
                        onTap: onToggleSearch,
                        child: Container(
                          width: searchBtnSize,
                          height: searchBtnSize,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.search_rounded,
                            color: Colors.grey[800],
                            size: (26 * scale).clamp(22.0, 26.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Search bar - slides in from right
              Transform.translate(
                offset: Offset(
                  MediaQuery.of(context).size.width * (1 - slideValue),
                  0,
                ),
                child: Opacity(
                  opacity: fadeIn.clamp(0.0, 1.0),
                  child: Row(
                    children: [
                      // Cancel button
                      BouncingWrapper(
                        shrinkScale: 0.86,
                        hitPadding: const EdgeInsets.all(8),
                        onTap: onToggleSearch,
                        child: Container(
                          width: searchBtnSize,
                          height: searchBtnSize,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.grey[800],
                            size: (26 * scale).clamp(22.0, 26.0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Search field - pill shaped
                      Expanded(
                        child: Container(
                          height: searchBtnSize,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.98),
                            borderRadius: BorderRadius.circular(searchBtnSize / 2),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 18,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(width: 16),
                              Icon(
                                Icons.search_rounded,
                                color: Colors.grey[600],
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Center(
                                  child: TextField(
                                    controller: searchController,
                                    focusNode: searchFocusNode,
                                    cursorColor: Colors.grey[800],
                                    textAlignVertical: TextAlignVertical.center,
                                    style: ArabicTypography.isArabic(context)
                                        ? GoogleFonts.tajawal(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey[900],
                                          )
                                        : const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF212121),
                                          ),
                                    decoration: InputDecoration(
                                      hintText: AppLocalizations.of(context).search,
                                      hintStyle: ArabicTypography.isArabic(context)
                                          ? GoogleFonts.tajawal(
                                              color: Colors.grey[500],
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            )
                                          : TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      filled: false,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      isDense: true,
                                      isCollapsed: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: searchController,
                                builder: (context, value, _) {
                                  if (value.text.isEmpty) {
                                    return const SizedBox(width: 16);
                                  }
                                  return GestureDetector(
                                    onTap: () => searchController.clear(),
                                    child: Container(
                                      margin: const EdgeInsetsDirectional.only(end: 8),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: Colors.grey[600],
                                        size: 22,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
