import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton loader for the About screen
/// Matches iOS 26 glassmorphism styling and layout
class AboutSkeleton extends StatelessWidget {
  const AboutSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
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
              // Header Row
              Row(
                children: [
                  _shimmerCircle(size: 44),
                  const SizedBox(width: 16),
                  _shimmerBox(width: 130, height: 28, radius: 8),
                ],
              ),
              const SizedBox(height: 24),

              // 1. Logo and Intro Card
              Container(
                width: double.infinity,
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
                    _shimmerCircle(size: 80),
                    const SizedBox(height: 18),
                    _shimmerBox(width: 160, height: 22, radius: 6),
                    const SizedBox(height: 12),
                    _shimmerBox(width: 240, height: 14, radius: 4),
                    const SizedBox(height: 6),
                    _shimmerBox(width: 180, height: 14, radius: 4),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Features Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                    Row(
                      children: [
                        _shimmerBox(width: 36, height: 36, radius: 10),
                        const SizedBox(width: 12),
                        _shimmerBox(width: 150, height: 18, radius: 6),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _shimmerFeatureRow(),
                    const Divider(color: Color(0xFFF1F5F9), height: 22),
                    _shimmerFeatureRow(),
                    const Divider(color: Color(0xFFF1F5F9), height: 22),
                    _shimmerFeatureRow(),
                    const Divider(color: Color(0xFFF1F5F9), height: 22),
                    _shimmerFeatureRow(),
                    const Divider(color: Color(0xFFF1F5F9), height: 22),
                    _shimmerFeatureRow(),
                    const Divider(color: Color(0xFFF1F5F9), height: 22),
                    _shimmerFeatureRow(),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Developer & Portfolio Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                    _shimmerBox(width: 150, height: 24, radius: 12),
                    const SizedBox(height: 16),
                    _shimmerCircle(size: 60),
                    const SizedBox(height: 12),
                    _shimmerBox(width: 130, height: 20, radius: 6),
                    const SizedBox(height: 6),
                    _shimmerBox(width: 170, height: 13, radius: 4),
                    const SizedBox(height: 18),
                    _shimmerBox(width: double.infinity, height: 48, radius: 14),
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

  static Widget _shimmerFeatureRow() {
    return Row(
      children: [
        _shimmerBox(width: 42, height: 42, radius: 12),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _shimmerBox(width: 120, height: 14, radius: 4),
              const SizedBox(height: 5),
              _shimmerBox(width: 200, height: 12, radius: 4),
            ],
          ),
        ),
      ],
    );
  }
}
