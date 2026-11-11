import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/l10n/app_localizations.dart';
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
        final searchBtnSize = (44.0 * scale).clamp(38.0, 44.0);
        final slideValue = animationController.value;
        final fadeOut = 1.0 - slideValue;
        final fadeIn = slideValue;

        return SizedBox(
          height: 72,
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
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.search_rounded,
                            color: Colors.grey[700],
                            size: (22 * scale).clamp(18.0, 22.0),
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
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.grey[700],
                            size: (22 * scale).clamp(18.0, 22.0),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Search field - pill shaped
                      Expanded(
                        child: Container(
                          height: searchBtnSize,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(searchBtnSize / 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              Icon(
                                Icons.search_rounded,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final isAr = Localizations.localeOf(context).languageCode == 'ar';
                                    return TextField(
                                      controller: searchController,
                                      focusNode: searchFocusNode,
                                      cursorColor: Colors.grey[600],
                                      style: isAr
                                          ? GoogleFonts.tajawal(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[800],
                                            )
                                          : TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[800],
                                            ),
                                      decoration: InputDecoration(
                                        hintText: AppLocalizations.of(context).search,
                                        hintStyle: isAr
                                            ? GoogleFonts.tajawal(
                                                color: Colors.grey[400],
                                                fontSize: 15,
                                                fontWeight: FontWeight.w400,
                                              )
                                            : TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 15,
                                                fontWeight: FontWeight.w400,
                                              ),
                                        filled: false,
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
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
