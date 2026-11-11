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
    final isIconStart = iconAlignment == Alignment.topLeft;
    final isAr = ArabicTypography.isArabic(context);

    return BouncingWrapper(
      shrinkScale: 0.93,
      overshootScale: 1.055,
      delayNavigation: true,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth;
          // Reference card width on iPhone 16 Pro Max is 189.0.
          // Scale uniformly across all screen widths without distorting text-to-card proportions.
          final scale = (cardWidth / 189.0).clamp(0.65, 1.25);

          final cardRadius = 28.0 * scale;
          final cardPadding = 16.0 * scale;
          final iconCircleSize = 72.0 * scale;
          final iconSize = 36.0 * scale;
          final iconBlur = 16.0 * scale;

          // Calibrate Cairo & Tajawal visual height/weight in Arabic to match Latin reference proportions.
          final titleFontSize = (isAr ? 20.0 : 22.0) * scale;
          final subtitleFontSize = (isAr ? 16.0 : 15.5) * scale;
          final titleGap = (isAr ? 5.0 : 3.5) * scale;

          final badgePaddingH = 9.0 * scale;
          final badgePaddingV = 5.0 * scale;
          final badgeFontSize = 11.0 * scale;

          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: Container(
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
                              // Icon Row (start-aligned so LTR puts it top-left, RTL puts it top-right)
                              Row(
                                mainAxisAlignment: isIconStart
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
                              // Title with directional alignment & FittedBox so it never clips
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: isIconStart
                                    ? AlignmentDirectional.centerStart
                                    : AlignmentDirectional.centerEnd,
                                child: Text(
                                  label,
                                  textAlign: isIconStart
                                      ? TextAlign.start
                                      : TextAlign.end,
                                  style: ArabicTypography.headerStyle(
                                    context,
                                    fontSize: titleFontSize,
                                    fontWeight: isAr
                                        ? FontWeight.w700
                                        : FontWeight.w800,
                                    color: Colors.grey[900],
                                    letterSpacing: isAr ? 0.0 : -0.3,
                                    height: isAr ? 1.28 : 1.2,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              SizedBox(height: titleGap),
                              // Subtitle with matching directional alignment
                              Text(
                                subtitle,
                                textAlign: isIconStart
                                    ? TextAlign.start
                                    : TextAlign.end,
                                style: ArabicTypography.bodyStyle(
                                  context,
                                  fontSize: subtitleFontSize,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[500],
                                  letterSpacing: 0.0,
                                  height: isAr ? 1.3 : 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Badge placed at opposite top corner using directional positioning
                        if (badgeCount != null && badgeCount! > 0)
                          PositionedDirectional(
                            top: 12 * scale,
                            end: isIconStart ? 12 * scale : null,
                            start: isIconStart ? null : 12 * scale,
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
            ),
          );
        },
      ),
    );
  }
}
