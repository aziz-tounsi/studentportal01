import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton loader for the Settings screen
/// Matches iOS 26 glassmorphism styling and layout
class SettingsSkeleton extends StatelessWidget {
  const SettingsSkeleton({super.key});

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  _shimmerCircle(size: 44),
                  const SizedBox(width: 16),
                  _shimmerBox(width: 150, height: 28, radius: 8),
                ],
              ),
              const SizedBox(height: 24),

              // 1. Language Card
              Container(
                width: double.infinity,
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
                    Row(
                      children: [
                        _shimmerBox(width: 36, height: 36, radius: 10),
                        const SizedBox(width: 12),
                        _shimmerBox(width: 110, height: 18, radius: 6),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: _shimmerBox(width: double.infinity, height: 44, radius: 16)),
                        const SizedBox(width: 10),
                        Expanded(child: _shimmerBox(width: double.infinity, height: 44, radius: 16)),
                        const SizedBox(width: 10),
                        Expanded(child: _shimmerBox(width: double.infinity, height: 44, radius: 16)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Notifications Card
              Container(
                width: double.infinity,
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
                    Row(
                      children: [
                        _shimmerBox(width: 36, height: 36, radius: 10),
                        const SizedBox(width: 12),
                        _shimmerBox(width: 130, height: 18, radius: 6),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _shimmerSwitchRow(),
                    const Divider(color: Color(0xFFF1F5F9), height: 22),
                    _shimmerSwitchRow(),
                    const Divider(color: Color(0xFFF1F5F9), height: 22),
                    _shimmerSwitchRow(),
                    const Divider(color: Color(0xFFF1F5F9), height: 22),
                    _shimmerSwitchRow(),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Security & Password Card
              Container(
                width: double.infinity,
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
                    Row(
                      children: [
                        _shimmerBox(width: 36, height: 36, radius: 10),
                        const SizedBox(width: 12),
                        _shimmerBox(width: 150, height: 18, radius: 6),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _shimmerSwitchRow(),
                    const Divider(color: Color(0xFFF1F5F9), height: 22),
                    Row(
                      children: [
                        _shimmerBox(width: 36, height: 36, radius: 10),
                        const SizedBox(width: 12),
                        _shimmerBox(width: 170, height: 16, radius: 4),
                        const Spacer(),
                        _shimmerBox(width: 18, height: 18, radius: 4),
                      ],
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

  static Widget _shimmerSwitchRow() {
    return Row(
      children: [
        _shimmerBox(width: 36, height: 36, radius: 10),
        const SizedBox(width: 12),
        _shimmerBox(width: 140, height: 15, radius: 4),
        const Spacer(),
        _shimmerBox(width: 44, height: 26, radius: 13),
      ],
    );
  }
}
