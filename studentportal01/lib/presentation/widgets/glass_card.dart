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
      child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
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
                                width: 72,
                                height: 72,
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
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  icon,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Title
                          Text(
                            label,
                            style: ArabicTypography.headerStyle(
                              context,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.grey[900],
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Subtitle
                          Text(
                            subtitle,
                            style: ArabicTypography.bodyStyle(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[500],
                              letterSpacing: 0,
                              height: 1.3,
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
                        top: 14,
                        right: isIconLeft ? 14 : null,
                        left: isIconLeft ? null : 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF43F5E), Color(0xFFEC4899)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF43F5E).withValues(alpha: 0.5),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
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
  }
}
