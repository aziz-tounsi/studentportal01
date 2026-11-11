import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme/arabic_typography.dart';
import 'bouncing_wrapper.dart';

class GlassCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final Alignment iconAlignment;
  final int? badgeCount;
  final VoidCallback onTap;

  const GlassCard({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    this.iconAlignment = Alignment.topLeft,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isIconLeft = iconAlignment == Alignment.topLeft;

    return BouncingWrapper(
      shrinkScale: 0.93,
      overshootScale: 1.055,
      delayNavigation: true,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth;
          // Reference card width on iPhone 16 Pro Max is ~189.0
          final scale = (cardWidth / 189.0).clamp(0.68, 1.25);

          final cardRadius = (28.0 * scale).clamp(18.0, 28.0);
          final cardPadding = (16.0 * scale).clamp(10.0, 16.0);
          final iconCircleSize = (72.0 * scale).clamp(46.0, 72.0);
          final iconSize = (36.0 * scale).clamp(23.0, 36.0);
          final iconBlur = (16.0 * scale).clamp(8.0, 16.0);
          final titleFontSize = (20.0 * scale).clamp(14.0, 20.0);
          final subtitleFontSize = (14.0 * scale).clamp(11.0, 14.0);
          final badgePaddingH = (9.0 * scale).clamp(6.0, 9.0);
          final badgePaddingV = (5.0 * scale).clamp(3.0, 5.0);
          final badgeFontSize = (11.0 * scale).clamp(9.0, 11.0);

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cardRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20 * scale,
                  offset: Offset(0, 6 * scale),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(cardRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(cardRadius),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Icon Row
                            Row(
                              mainAxisAlignment: isIconLeft
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: iconCircleSize,
                                  height: iconCircleSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: gradientColors,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: gradientColors.first
                                            .withValues(alpha: 0.35),
                                        blurRadius: iconBlur,
                                        offset: Offset(0, 6 * scale),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    icon,
                                    color: Colors.white,
                                    size: iconSize,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Title with FittedBox so it never clips with ellipsis
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: isIconLeft
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: Text(
                                label,
                                style: ArabicTypography.headerStyle(
                                  context,
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.grey[900],
                                  letterSpacing: -0.3,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                              ),
                            ),
                            SizedBox(height: 3 * scale),
                            // Subtitle
                            Text(
                              subtitle,
                              style: ArabicTypography.bodyStyle(
                                context,
                                fontSize: subtitleFontSize,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[500],
                                letterSpacing: 0,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Badge
                      if (badgeCount != null && badgeCount! > 0)
                        Positioned(
                          top: 12 * scale,
                          right: isIconLeft ? 12 * scale : null,
                          left: isIconLeft ? null : 12 * scale,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: badgePaddingH,
                              vertical: badgePaddingV,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF43F5E), Color(0xFFEC4899)],
                              ),
                              borderRadius:
                                  BorderRadius.circular(14 * scale),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF43F5E)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 10 * scale,
                                  offset: Offset(0, 3 * scale),
                                ),
                              ],
                            ),
                            child: Text(
                              badgeCount.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: badgeFontSize,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
