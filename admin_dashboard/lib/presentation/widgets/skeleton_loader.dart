import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Animated shimmer effect for skeleton loaders
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: widget.child,
        );
      },
    );
  }
}

/// Helper block for skeleton shapes
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton loader specifically matching Table layouts (Users, Professors, Absences, Results, etc.)
class TableSkeletonLoader extends StatelessWidget {
  final int rowCount;

  const TableSkeletonLoader({
    super.key,
    this.rowCount = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ShimmerLoading(
            child: Column(
              children: [
                // Header row skeleton
                Container(
                  height: 44,
                  color: const Color(0xFFF9FAFB),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Row(
                    children: [
                      SkeletonBox(width: 20, height: 20, borderRadius: 4),
                      SizedBox(width: 24),
                      SkeletonBox(width: 140, height: 14),
                      Spacer(),
                      SkeletonBox(width: 80, height: 14),
                      SizedBox(width: 24),
                      SkeletonBox(width: 80, height: 14),
                      SizedBox(width: 24),
                      SkeletonBox(width: 80, height: 14),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                // Body rows
                Expanded(
                  child: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rowCount,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      return Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: const Row(
                          children: [
                            SkeletonBox(width: 16, height: 16, borderRadius: 3),
                            SizedBox(width: 20),
                            // Avatar + Name/Email skeleton
                            SkeletonBox(width: 36, height: 36, borderRadius: 18),
                            SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(width: 130, height: 14),
                                SizedBox(height: 6),
                                SkeletonBox(width: 170, height: 11),
                              ],
                            ),
                            Spacer(),
                            // Badges / Tags
                            SkeletonBox(width: 60, height: 22, borderRadius: 6),
                            SizedBox(width: 20),
                            SkeletonBox(width: 70, height: 22, borderRadius: 6),
                            SizedBox(width: 20),
                            SkeletonBox(width: 90, height: 14),
                            SizedBox(width: 20),
                            SkeletonBox(width: 24, height: 24, borderRadius: 6),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Footer pagination skeleton
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  color: const Color(0xFFFAFAFB),
                  child: const Row(
                    children: [
                      SkeletonBox(width: 120, height: 24, borderRadius: 6),
                      Spacer(),
                      SkeletonBox(width: 100, height: 14),
                      SizedBox(width: 16),
                      SkeletonBox(width: 60, height: 28, borderRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader specifically matching the 3-Column Classes screen
class ClassesSkeletonLoader extends StatelessWidget {
  const ClassesSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Row(
        children: [
          // ── LEFT PANEL SKELETON (280px) ──
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total card skeleton
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SkeletonBox(width: 40, height: 40, borderRadius: 10),
                            SizedBox(width: 12),
                            SkeletonBox(width: 110, height: 12),
                          ],
                        ),
                        SizedBox(height: 18),
                        SkeletonBox(width: 80, height: 32, borderRadius: 6),
                        SizedBox(height: 18),
                        SkeletonBox(width: double.infinity, height: 5, borderRadius: 6),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // "Par niveau" title skeleton
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 14),
                    child: SkeletonBox(width: 80, height: 16),
                  ),

                  // Niveau cards skeleton
                  ...List.generate(5, (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Expanded(child: SkeletonBox(width: 120, height: 14)),
                          SizedBox(width: 12),
                          SkeletonBox(width: 30, height: 30, borderRadius: 15),
                        ],
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ),

          // ── CENTER + RIGHT PANELS SKELETON ──
          Expanded(
            child: Column(
              children: [
                // Center header skeleton
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Color(0xFFE9EAF2))),
                  ),
                  child: const Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 180, height: 22, borderRadius: 6),
                          SizedBox(height: 6),
                          SkeletonBox(width: 90, height: 12),
                        ],
                      ),
                      Spacer(),
                      SkeletonBox(width: 320, height: 40, borderRadius: 8),
                      SizedBox(width: 16),
                      SkeletonBox(width: 140, height: 40, borderRadius: 12),
                    ],
                  ),
                ),

                // Center grid + Right panel
                Expanded(
                  child: Row(
                    children: [
                      // Center Grid Cards
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          physics: const NeverScrollableScrollPhysics(),
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: List.generate(6, (index) => Container(
                              width: 280,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      SkeletonBox(width: 40, height: 40, borderRadius: 10),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SkeletonBox(width: 100, height: 14),
                                            SizedBox(height: 4),
                                            SkeletonBox(width: 60, height: 11),
                                          ],
                                        ),
                                      ),
                                      SkeletonBox(width: 18, height: 18, borderRadius: 4),
                                    ],
                                  ),
                                  SizedBox(height: 14),
                                  Row(
                                    children: [
                                      SkeletonBox(width: 14, height: 14, borderRadius: 3),
                                      SizedBox(width: 6),
                                      SkeletonBox(width: 80, height: 12),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(child: SkeletonBox(width: double.infinity, height: 6, borderRadius: 4)),
                                      SizedBox(width: 10),
                                      SkeletonBox(width: 40, height: 12),
                                    ],
                                  ),
                                  SizedBox(height: 14),
                                  Row(
                                    children: [
                                      SkeletonBox(width: 28, height: 28, borderRadius: 14),
                                      SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SkeletonBox(width: 90, height: 12),
                                          SizedBox(height: 4),
                                          SkeletonBox(width: 70, height: 10),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )),
                          ),
                        ),
                      ),

                      // Right Panel Skeleton
                      Container(
                        width: 300,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(left: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SkeletonBox(width: 90, height: 10),
                                    SizedBox(height: 12),
                                    SkeletonBox(width: 140, height: 20),
                                    SizedBox(height: 6),
                                    SkeletonBox(width: 160, height: 13),
                                    SizedBox(height: 18),
                                    Row(
                                      children: [
                                        SkeletonBox(width: 60, height: 12),
                                        Spacer(),
                                        SkeletonBox(width: 50, height: 12),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                    Row(
                                      children: [
                                        SkeletonBox(width: 28, height: 28, borderRadius: 14),
                                        SizedBox(width: 4),
                                        SkeletonBox(width: 28, height: 28, borderRadius: 14),
                                        SizedBox(width: 4),
                                        SkeletonBox(width: 28, height: 28, borderRadius: 14),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              const SkeletonBox(width: 120, height: 14),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  children: [
                                    Row(
                                      children: [
                                        SkeletonBox(width: 14, height: 14),
                                        SizedBox(width: 8),
                                        SkeletonBox(width: 80, height: 12),
                                        Spacer(),
                                        SkeletonBox(width: 40, height: 12),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    Row(
                                      children: [
                                        SkeletonBox(width: 14, height: 14),
                                        SizedBox(width: 8),
                                        SkeletonBox(width: 70, height: 12),
                                        Spacer(),
                                        SkeletonBox(width: 60, height: 12),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
    );
  }
}

/// Skeleton loader specifically matching the Class Detail screen (Inside Class page)
class ClassDetailSkeletonLoader extends StatelessWidget {
  const ClassDetailSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Column(
        children: [
          // Header Bar Skeleton
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: const [
                SkeletonBox(width: 36, height: 36, borderRadius: 10),
                SizedBox(width: 16),
                SkeletonBox(width: 36, height: 36, borderRadius: 10),
                SizedBox(width: 12),
                SkeletonBox(width: 60, height: 20),
                SizedBox(width: 12),
                SkeletonBox(width: 120, height: 24, borderRadius: 6),
                SizedBox(width: 8),
                SkeletonBox(width: 55, height: 24, borderRadius: 6),
                SizedBox(width: 8),
                SkeletonBox(width: 50, height: 24, borderRadius: 6),
                Spacer(),
                SkeletonBox(width: 240, height: 36, borderRadius: 8),
              ],
            ),
          ),

          // Main 2-Column Body
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Tables
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card 1: Students Table
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              // Header
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: const [
                                    SkeletonBox(width: 32, height: 32, borderRadius: 8),
                                    SizedBox(width: 12),
                                    SkeletonBox(width: 130, height: 16),
                                    SizedBox(width: 8),
                                    SkeletonBox(width: 24, height: 20, borderRadius: 999),
                                    Spacer(),
                                    SkeletonBox(width: 150, height: 36, borderRadius: 10),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              // Table Header
                              Container(
                                height: 44,
                                color: const Color(0xFFF9FAFB),
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: const Row(
                                  children: [
                                    SkeletonBox(width: 16, height: 16, borderRadius: 3),
                                    SizedBox(width: 20),
                                    SkeletonBox(width: 130, height: 12),
                                    Spacer(),
                                    SkeletonBox(width: 100, height: 12),
                                    SizedBox(width: 40),
                                    SkeletonBox(width: 80, height: 12),
                                    SizedBox(width: 30),
                                    SkeletonBox(width: 20, height: 12),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              // 4 Student Rows
                              ...List.generate(4, (i) => Container(
                                height: 60,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  border: i < 3 ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))) : null,
                                ),
                                child: const Row(
                                  children: [
                                    SkeletonBox(width: 16, height: 16, borderRadius: 3),
                                    SizedBox(width: 20),
                                    SkeletonBox(width: 34, height: 34, borderRadius: 17),
                                    SizedBox(width: 12),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SkeletonBox(width: 110, height: 13),
                                        SizedBox(height: 4),
                                        SkeletonBox(width: 140, height: 10),
                                      ],
                                    ),
                                    Spacer(),
                                    SkeletonBox(width: 110, height: 20, borderRadius: 4),
                                    SizedBox(width: 30),
                                    SkeletonBox(width: 90, height: 12),
                                    SizedBox(width: 30),
                                    SkeletonBox(width: 18, height: 18, borderRadius: 4),
                                  ],
                                ),
                              )),
                              // Pagination Footer
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                color: const Color(0xFFFAFAFB),
                                child: const Row(
                                  children: [
                                    SkeletonBox(width: 110, height: 24, borderRadius: 6),
                                    Spacer(),
                                    SkeletonBox(width: 80, height: 12),
                                    SizedBox(width: 12),
                                    SkeletonBox(width: 50, height: 26, borderRadius: 6),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Card 2: Teachers Table
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: const [
                                    SkeletonBox(width: 32, height: 32, borderRadius: 8),
                                    SizedBox(width: 12),
                                    SkeletonBox(width: 150, height: 16),
                                    Spacer(),
                                    SkeletonBox(width: 80, height: 32, borderRadius: 10),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              Container(
                                height: 44,
                                color: const Color(0xFFF9FAFB),
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: const Row(
                                  children: [
                                    SkeletonBox(width: 130, height: 12),
                                    Spacer(),
                                    SkeletonBox(width: 80, height: 12),
                                    SizedBox(width: 30),
                                    SkeletonBox(width: 60, height: 12),
                                    SizedBox(width: 30),
                                    SkeletonBox(width: 60, height: 12),
                                    SizedBox(width: 30),
                                    SkeletonBox(width: 20, height: 12),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, color: Color(0xFFE2E8F0)),
                              ...List.generate(2, (i) => Container(
                                height: 60,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  border: i < 1 ? const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))) : null,
                                ),
                                child: const Row(
                                  children: [
                                    SkeletonBox(width: 34, height: 34, borderRadius: 17),
                                    SizedBox(width: 12),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SkeletonBox(width: 90, height: 13),
                                        SizedBox(height: 4),
                                        SkeletonBox(width: 120, height: 10),
                                      ],
                                    ),
                                    Spacer(),
                                    SkeletonBox(width: 80, height: 22, borderRadius: 6),
                                    SizedBox(width: 30),
                                    SkeletonBox(width: 50, height: 20, borderRadius: 6),
                                    SizedBox(width: 30),
                                    SkeletonBox(width: 70, height: 12),
                                    SizedBox(width: 30),
                                    SkeletonBox(width: 18, height: 18, borderRadius: 4),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Sidebar: Schedule Agenda
                Container(
                  width: 320,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          SkeletonBox(width: 32, height: 32, borderRadius: 8),
                          SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 130, height: 15),
                              SizedBox(height: 4),
                              SkeletonBox(width: 100, height: 11),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: const [
                            SkeletonBox(width: 44, height: 44, borderRadius: 12),
                            SizedBox(height: 16),
                            SkeletonBox(width: 140, height: 14),
                            SizedBox(height: 6),
                            SkeletonBox(width: 110, height: 11),
                          ],
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
    );
  }
}

/// Skeleton loader precisely matching the Announcements / Annonces screen (card table view)
class AnnouncementsSkeletonLoader extends StatelessWidget {
  const AnnouncementsSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ShimmerLoading(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SkeletonBox(width: 28, height: 28, borderRadius: 8),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      SkeletonBox(width: 130, height: 16),
                                      SizedBox(width: 10),
                                      SkeletonBox(width: 50, height: 20, borderRadius: 8),
                                      SizedBox(width: 8),
                                      SkeletonBox(width: 65, height: 20, borderRadius: 8),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const SkeletonBox(width: double.infinity, height: 13),
                                  const SizedBox(height: 6),
                                  const SkeletonBox(width: 280, height: 13),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: const [
                                SkeletonBox(width: 18, height: 18, borderRadius: 4),
                                SizedBox(height: 20),
                                SkeletonBox(width: 80, height: 12),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFB),
                    border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.3))),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: const Row(
                    children: [
                      SkeletonBox(width: 110, height: 24, borderRadius: 6),
                      Spacer(),
                      SkeletonBox(width: 90, height: 14),
                      SizedBox(width: 12),
                      SkeletonBox(width: 28, height: 28, borderRadius: 8),
                      SizedBox(width: 8),
                      SkeletonBox(width: 28, height: 28, borderRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader precisely matching the Suggestions screen
class SuggestionsSkeletonLoader extends StatelessWidget {
  const SuggestionsSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ShimmerLoading(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SkeletonBox(width: 28, height: 28, borderRadius: 14),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      SkeletonBox(width: 110, height: 16),
                                      SizedBox(width: 10),
                                      SkeletonBox(width: 55, height: 20, borderRadius: 8),
                                      SizedBox(width: 8),
                                      SkeletonBox(width: 60, height: 20, borderRadius: 8),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const SkeletonBox(width: double.infinity, height: 13),
                                  const SizedBox(height: 6),
                                  const SkeletonBox(width: 320, height: 13),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: const [
                                SkeletonBox(width: 18, height: 18, borderRadius: 4),
                                SizedBox(height: 20),
                                SkeletonBox(width: 100, height: 12),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFB),
                    border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.3))),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: const Row(
                    children: [
                      SkeletonBox(width: 110, height: 24, borderRadius: 6),
                      Spacer(),
                      SkeletonBox(width: 90, height: 14),
                      SizedBox(width: 12),
                      SkeletonBox(width: 28, height: 28, borderRadius: 8),
                      SizedBox(width: 8),
                      SkeletonBox(width: 28, height: 28, borderRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader precisely matching the Building Structure screen
class BuildingStructureSkeletonLoader extends StatelessWidget {
  const BuildingStructureSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(32),
      child: ShimmerLoading(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: List.generate(3, (i) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  // Building Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: const [
                        SkeletonBox(width: 40, height: 40, borderRadius: 10),
                        SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 140, height: 16),
                            SizedBox(height: 4),
                            SkeletonBox(width: 60, height: 12),
                          ],
                        ),
                        SizedBox(width: 16),
                        SkeletonBox(width: 70, height: 20, borderRadius: 6),
                        SizedBox(width: 8),
                        SkeletonBox(width: 65, height: 20, borderRadius: 6),
                        Spacer(),
                        SkeletonBox(width: 28, height: 28, borderRadius: 6),
                        SizedBox(width: 6),
                        SkeletonBox(width: 28, height: 28, borderRadius: 6),
                        SizedBox(width: 6),
                        SkeletonBox(width: 28, height: 28, borderRadius: 6),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  // Floor row
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: const [
                        SkeletonBox(width: 80, height: 24, borderRadius: 6),
                        SizedBox(width: 16),
                        SkeletonBox(width: 90, height: 36, borderRadius: 8),
                        SizedBox(width: 8),
                        SkeletonBox(width: 90, height: 36, borderRadius: 8),
                        SizedBox(width: 8),
                        SkeletonBox(width: 90, height: 36, borderRadius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            )),
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader precisely matching the Payments / Paiements screen (2-Column Classes Layout)
class PaymentsSkeletonLoader extends StatelessWidget {
  const PaymentsSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F6F8),
      child: ShimmerLoading(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── LEFT PANEL: NIVEAUX NAVIGATION (300px) ──
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: const Color(0xFFE5E7EB).withOpacity(0.5)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Niveaux Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Row(
                      children: const [
                        SkeletonBox(width: 36, height: 36, borderRadius: 10),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 80, height: 16, borderRadius: 4),
                            SizedBox(height: 4),
                            SkeletonBox(width: 130, height: 12, borderRadius: 4),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),

                  // Niveaux List Items
                  Expanded(
                    child: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: 6,
                      itemBuilder: (context, i) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: const [
                              Expanded(
                                child: SkeletonBox(width: 110, height: 15, borderRadius: 4),
                              ),
                              SkeletonBox(width: 26, height: 26, borderRadius: 13),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── RIGHT AREA: CLASSES PAYMENT GRID ──
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      children: const [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 170, height: 22, borderRadius: 4),
                            SizedBox(height: 6),
                            SkeletonBox(width: 85, height: 13, borderRadius: 4),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Grid of Class Payment Cards matching _buildPaymentClassCard
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 350,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 205,
                      ),
                      itemCount: 6,
                      itemBuilder: (context, index) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Header: 36x36 Icon + Class info
                              Row(
                                children: const [
                                  SkeletonBox(width: 36, height: 36, borderRadius: 8),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SkeletonBox(width: 90, height: 16, borderRadius: 4),
                                        SizedBox(height: 5),
                                        SkeletonBox(width: 60, height: 11, borderRadius: 4),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Amounts row: Déjà payé (left) & Total à payer (right)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SkeletonBox(width: 50, height: 11, borderRadius: 3),
                                      SizedBox(height: 4),
                                      SkeletonBox(width: 70, height: 15, borderRadius: 4),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      SkeletonBox(width: 65, height: 11, borderRadius: 3),
                                      SizedBox(height: 4),
                                      SkeletonBox(width: 75, height: 15, borderRadius: 4),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Progress Bar + Percentage
                              Row(
                                children: const [
                                  Expanded(child: SkeletonBox(height: 6, borderRadius: 3)),
                                  SizedBox(width: 10),
                                  SkeletonBox(width: 30, height: 12, borderRadius: 3),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Footer / Remaining
                              Row(
                                children: const [
                                  SkeletonBox(width: 55, height: 11, borderRadius: 3),
                                  SizedBox(width: 6),
                                  SkeletonBox(width: 65, height: 13, borderRadius: 4),
                                ],
                              ),
                            ],
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
    );
  }
}

/// Skeleton loader precisely matching the Results / Résultats screen (Niveaux / Classes selector)
class ResultsSkeletonLoader extends StatelessWidget {
  const ResultsSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F6F8),
      child: ShimmerLoading(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info header with semester badge
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: const [
                    SkeletonBox(width: 160, height: 18),
                    Spacer(),
                    SkeletonBox(width: 90, height: 22, borderRadius: 999),
                  ],
                ),
              ),

              // Cycle Card Wrapper
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF655DD5).withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFF655DD5).withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Card header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: const [
                          SkeletonBox(width: 36, height: 36, borderRadius: 8),
                          SizedBox(width: 12),
                          SkeletonBox(width: 70, height: 16),
                          SizedBox(width: 12),
                          SkeletonBox(width: 80, height: 20, borderRadius: 999),
                        ],
                      ),
                    ),

                    // Niveau rows (matching _HoverableNiveauRow cards exactly)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: List.generate(3, (i) {
                          final hasSections = i == 1;
                          return Padding(
                            padding: EdgeInsets.only(bottom: i < 2 ? 16 : 0),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.transparent,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title row
                                  Row(
                                    children: const [
                                      SkeletonBox(width: 110, height: 15),
                                      SizedBox(width: 8),
                                      SkeletonBox(width: 70, height: 12),
                                      Spacer(),
                                      SkeletonBox(width: 36, height: 18, borderRadius: 4),
                                    ],
                                  ),
                                  // Filières row if present
                                  if (hasSections) ...[
                                    const SizedBox(height: 10),
                                    Row(
                                      children: const [
                                        SkeletonBox(width: 50, height: 11),
                                        SizedBox(width: 12),
                                        SkeletonBox(width: 60, height: 20, borderRadius: 4),
                                        SizedBox(width: 8),
                                        SkeletonBox(width: 70, height: 20, borderRadius: 4),
                                        SizedBox(width: 8),
                                        SkeletonBox(width: 65, height: 20, borderRadius: 4),
                                      ],
                                    ),
                                  ],
                                  // Class pills row
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: List.generate(
                                      i == 0 ? 4 : (i == 1 ? 5 : 3),
                                      (j) => const SkeletonBox(
                                        width: 84,
                                        height: 28,
                                        borderRadius: 999,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
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
}

/// Skeleton loader precisely matching the Results Student List Table (when a class is selected)
class ResultsStudentListSkeletonLoader extends StatelessWidget {
  final int rowCount;
  const ResultsStudentListSkeletonLoader({super.key, this.rowCount = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ShimmerLoading(
            child: Column(
              children: [
                // Table header
                Container(
                  height: 44,
                  color: const Color(0xFFF9FAFB),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: const [
                      SkeletonBox(width: 16, height: 16, borderRadius: 3),
                      SizedBox(width: 20),
                      SkeletonBox(width: 16, height: 12),
                      SizedBox(width: 24),
                      SkeletonBox(width: 150, height: 12),
                      Spacer(),
                      SkeletonBox(width: 80, height: 12),
                      SizedBox(width: 40),
                      SkeletonBox(width: 60, height: 12),
                      SizedBox(width: 24),
                      SkeletonBox(width: 16, height: 12),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                // Table rows
                Expanded(
                  child: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rowCount,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      return Container(
                        height: 64,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: const [
                            SkeletonBox(width: 16, height: 16, borderRadius: 3),
                            SizedBox(width: 20),
                            SkeletonBox(width: 16, height: 12),
                            SizedBox(width: 20),
                            // Avatar + Name/Email
                            SkeletonBox(width: 32, height: 32, borderRadius: 16),
                            SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SkeletonBox(width: 130, height: 14),
                                SizedBox(height: 6),
                                SkeletonBox(width: 160, height: 11),
                              ],
                            ),
                            Spacer(),
                            // Matricule pill badge
                            SkeletonBox(width: 85, height: 24, borderRadius: 6),
                            SizedBox(width: 35),
                            // Classe pill badge
                            SkeletonBox(width: 65, height: 24, borderRadius: 6),
                            SizedBox(width: 20),
                            // Action chevron
                            SkeletonBox(width: 16, height: 16, borderRadius: 4),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Footer pagination
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAFAFB),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: Row(
                    children: const [
                      SkeletonBox(width: 140, height: 26, borderRadius: 8),
                      Spacer(),
                      SkeletonBox(width: 90, height: 14),
                      SizedBox(width: 12),
                      SkeletonBox(width: 60, height: 28, borderRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader precisely matching the Historique d'absences screen (Image 3)
class StudentAbsencesSkeletonLoader extends StatelessWidget {
  const StudentAbsencesSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: ShimmerLoading(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── TOP BAR: BACK ARROW + TITLE + VOIR LE PROFIL ──
              Row(
                children: const [
                  SkeletonBox(width: 40, height: 40, borderRadius: 10),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 200, height: 22),
                      SizedBox(height: 4),
                      SkeletonBox(width: 130, height: 13),
                    ],
                  ),
                  Spacer(),
                  SkeletonBox(width: 110, height: 38, borderRadius: 10),
                ],
              ),
              const SizedBox(height: 24),

              // ── PROFILE SUMMARY CARD ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar circle
                    const SkeletonBox(width: 80, height: 80, borderRadius: 40),
                    const SizedBox(width: 24),
                    // Name & Badge Pills
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkeletonBox(width: 180, height: 20),
                          const SizedBox(height: 4),
                          const SkeletonBox(width: 100, height: 13),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const [
                              SkeletonBox(width: 150, height: 26, borderRadius: 6),
                              SkeletonBox(width: 60, height: 26, borderRadius: 6),
                              SkeletonBox(width: 70, height: 26, borderRadius: 6),
                              SkeletonBox(width: 60, height: 26, borderRadius: 6),
                              SkeletonBox(width: 80, height: 26, borderRadius: 6),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right Contact
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Row(
                          children: [
                            SkeletonBox(width: 14, height: 14, borderRadius: 3),
                            SizedBox(width: 8),
                            SkeletonBox(width: 140, height: 13),
                          ],
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            SkeletonBox(width: 14, height: 14, borderRadius: 3),
                            SizedBox(width: 8),
                            SkeletonBox(width: 110, height: 13),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── 2-COLUMN SECTION: CALENDRIER & STATISTIQUES ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Card: Calendrier des absences (58%)
                  Expanded(
                    flex: 58,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Calendar Header with month switcher
                          Row(
                            children: const [
                              SkeletonBox(width: 180, height: 17),
                              Spacer(),
                              SkeletonBox(width: 32, height: 32, borderRadius: 8),
                              SizedBox(width: 8),
                              SkeletonBox(width: 100, height: 14),
                              SizedBox(width: 8),
                              SkeletonBox(width: 32, height: 32, borderRadius: 8),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Weekdays row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List.generate(7, (i) => const SkeletonBox(width: 20, height: 14)),
                          ),
                          const SizedBox(height: 16),
                          // Calendar 5 rows of 7 days
                          ...List.generate(5, (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: List.generate(7, (col) => Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                              )),
                            ),
                          )),
                          const SizedBox(height: 16),
                          // Legend Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SkeletonBox(width: 8, height: 8, borderRadius: 4),
                              SizedBox(width: 6),
                              SkeletonBox(width: 45, height: 11),
                              SizedBox(width: 16),
                              SkeletonBox(width: 8, height: 8, borderRadius: 4),
                              SizedBox(width: 6),
                              SkeletonBox(width: 45, height: 11),
                              SizedBox(width: 16),
                              SkeletonBox(width: 8, height: 8, borderRadius: 4),
                              SizedBox(width: 6),
                              SkeletonBox(width: 45, height: 11),
                              SizedBox(width: 16),
                              SkeletonBox(width: 8, height: 8, borderRadius: 4),
                              SizedBox(width: 6),
                              SkeletonBox(width: 65, height: 11),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Right Card: Statistiques (42%)
                  Expanded(
                    flex: 42,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              SkeletonBox(width: 100, height: 17),
                              Spacer(),
                              SkeletonBox(width: 70, height: 13),
                            ],
                          ),
                          const SizedBox(height: 28),
                          // Donut Chart skeleton
                          Center(
                            child: Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 14),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SkeletonBox(width: 60, height: 26),
                                  SizedBox(height: 6),
                                  SkeletonBox(width: 50, height: 11),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),
                          // 4 Metric rows
                          ...List.generate(4, (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              children: const [
                                SkeletonBox(width: 18, height: 18, borderRadius: 4),
                                SizedBox(width: 12),
                                SkeletonBox(width: 110, height: 13),
                                Spacer(),
                                SkeletonBox(width: 45, height: 15),
                              ],
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader precisely matching the Student Profile screen (Image 4)
class StudentProfileSkeletonLoader extends StatelessWidget {
  const StudentProfileSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: ShimmerLoading(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── TOP HEADER BAR: NAME + 4 BUTTONS ──
              Row(
                children: const [
                  SkeletonBox(width: 40, height: 40, borderRadius: 10),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 160, height: 22),
                      SizedBox(height: 4),
                      SkeletonBox(width: 100, height: 13),
                    ],
                  ),
                  Spacer(),
                  SkeletonBox(width: 90, height: 38, borderRadius: 8),
                  SizedBox(width: 10),
                  SkeletonBox(width: 160, height: 38, borderRadius: 8),
                  SizedBox(width: 10),
                  SkeletonBox(width: 150, height: 38, borderRadius: 8),
                  SizedBox(width: 10),
                  SkeletonBox(width: 170, height: 38, borderRadius: 8),
                ],
              ),
              const SizedBox(height: 24),

              // ── MAIN BODY: LEFT PROFILE CARD + RIGHT CONTENT ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── LEFT PROFILE CARD (320px) ──
                  Container(
                    width: 320,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Large Avatar with camera badge
                        const SkeletonBox(width: 100, height: 100, borderRadius: 50),
                        const SizedBox(height: 16),
                        const SkeletonBox(width: 140, height: 18),
                        const SizedBox(height: 6),
                        const SkeletonBox(width: 70, height: 20, borderRadius: 10),
                        const SizedBox(height: 8),
                        const SkeletonBox(width: 120, height: 12),
                        const SizedBox(height: 24),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 20),

                        // Property rows
                        ...List.generate(5, (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            children: const [
                              SkeletonBox(width: 70, height: 13),
                              Spacer(),
                              SkeletonBox(width: 80, height: 13),
                              SizedBox(width: 8),
                              SkeletonBox(width: 14, height: 14, borderRadius: 3),
                            ],
                          ),
                        )),
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 18),

                        // Contact Rapide
                        Align(
                          alignment: Alignment.centerLeft,
                          child: const SkeletonBox(width: 100, height: 14),
                        ),
                        const SizedBox(height: 14),
                        ...List.generate(3, (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: const [
                              SkeletonBox(width: 16, height: 16, borderRadius: 4),
                              SizedBox(width: 10),
                              SkeletonBox(width: 140, height: 12),
                              Spacer(),
                              SkeletonBox(width: 14, height: 14, borderRadius: 3),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),

                  // ── RIGHT AREA: 4 STATS + 2 CARDS + ACTIVITY ──
                  Expanded(
                    child: Column(
                      children: [
                        // 4 Quick Stats
                        Row(
                          children: List.generate(4, (i) => Expanded(
                            child: Container(
                              margin: EdgeInsets.only(right: i < 3 ? 16 : 0),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  SkeletonBox(width: 40, height: 40, borderRadius: 10),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      SkeletonBox(width: 50, height: 20),
                                      SizedBox(height: 4),
                                      SkeletonBox(width: 80, height: 11),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )),
                        ),
                        const SizedBox(height: 20),

                        // 2 Cards Side-by-Side: Présence ce mois & Paiements
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Card A: Présence ce mois
                            Expanded(
                              child: Container(
                                height: 320,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        SkeletonBox(width: 120, height: 15),
                                        Spacer(),
                                        SkeletonBox(width: 50, height: 12),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    // Month switcher
                                    Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          SkeletonBox(width: 20, height: 20, borderRadius: 4),
                                          SizedBox(width: 8),
                                          SkeletonBox(width: 80, height: 12),
                                          SizedBox(width: 8),
                                          SkeletonBox(width: 20, height: 20, borderRadius: 4),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    // Weekday header
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: List.generate(7, (i) => const SkeletonBox(width: 14, height: 11)),
                                    ),
                                    const SizedBox(height: 10),
                                    // Day squares
                                    Expanded(
                                      child: GridView.builder(
                                        physics: const NeverScrollableScrollPhysics(),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 7,
                                          crossAxisSpacing: 6,
                                          mainAxisSpacing: 6,
                                        ),
                                        itemCount: 28,
                                        itemBuilder: (_, __) => Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        SkeletonBox(width: 6, height: 6, borderRadius: 3),
                                        SizedBox(width: 4),
                                        SkeletonBox(width: 35, height: 10),
                                        SizedBox(width: 12),
                                        SkeletonBox(width: 6, height: 6, borderRadius: 3),
                                        SizedBox(width: 4),
                                        SkeletonBox(width: 35, height: 10),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),

                            // Card B: Paiements
                            Expanded(
                              child: Container(
                                height: 320,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        SkeletonBox(width: 80, height: 15),
                                        Spacer(),
                                        SkeletonBox(width: 50, height: 12),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Center(
                                      child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: const Color(0xFFE2E8F0), width: 10),
                                        ),
                                        child: const Center(
                                          child: SkeletonBox(width: 45, height: 16),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    ...List.generate(5, (i) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: const [
                                          SkeletonBox(width: 14, height: 14, borderRadius: 3),
                                          SizedBox(width: 8),
                                          SkeletonBox(width: 70, height: 12),
                                          Spacer(),
                                          SkeletonBox(width: 40, height: 12),
                                        ],
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Bottom Card: Activité Récente
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SkeletonBox(width: 130, height: 15),
                              const SizedBox(height: 16),
                              ...List.generate(2, (i) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: const [
                                    SkeletonBox(width: 32, height: 32, borderRadius: 8),
                                    SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SkeletonBox(width: 140, height: 13),
                                        SizedBox(height: 4),
                                        SkeletonBox(width: 80, height: 10),
                                      ],
                                    ),
                                    Spacer(),
                                    SkeletonBox(width: 60, height: 11),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader precisely matching the Teacher Profile screen (Accurate 1:1 Mirror)
class TeacherProfileSkeletonLoader extends StatelessWidget {
  const TeacherProfileSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: ShimmerLoading(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              // ── TOP HEADER BAR: NAME + ACTIF PILL + MODIFIER BUTTON ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: const [
                    SkeletonBox(width: 40, height: 40, borderRadius: 12),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SkeletonBox(width: 180, height: 22),
                            SizedBox(width: 12),
                            SkeletonBox(width: 50, height: 20, borderRadius: 10),
                          ],
                        ),
                        SizedBox(height: 4),
                        SkeletonBox(width: 220, height: 12),
                      ],
                    ),
                    Spacer(),
                    SkeletonBox(width: 140, height: 38, borderRadius: 8),
                  ],
                ),
              ),

              // ── 2-COLUMN BODY ──
              Padding(
                padding: const EdgeInsets.all(32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── LEFT: 340px PROFILE CARD WITH GRADIENT BANNER ──
                    Container(
                      width: 340,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Gradient Top Banner
                          Container(
                            height: 96,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                          ),
                          // Overlapping Avatar + Camera Badge
                          Transform.translate(
                            offset: const Offset(0, -48),
                            child: Column(
                              children: [
                                Stack(
                                  children: [
                                    const SkeletonBox(width: 128, height: 128, borderRadius: 64),
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFFE5E7EB)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const SkeletonBox(width: 160, height: 18),
                                const SizedBox(height: 6),
                                const SkeletonBox(width: 130, height: 12),
                                const SizedBox(height: 20),
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 16),
                                // 4 Contact Blocks
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Column(
                                    children: List.generate(4, (i) => Padding(
                                      padding: const EdgeInsets.only(bottom: 14),
                                      child: Row(
                                        children: const [
                                          SkeletonBox(width: 18, height: 18, borderRadius: 4),
                                          SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              SkeletonBox(width: 60, height: 10),
                                              SizedBox(height: 3),
                                              SkeletonBox(width: 110, height: 13),
                                            ],
                                          ),
                                        ],
                                      ),
                                    )),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 32),

                    // ── RIGHT COLUMN: SPECIALITY + CLASSES + TIMETABLE ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card 1: Spécialité & Niveaux
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SkeletonBox(width: 140, height: 12),
                                const SizedBox(height: 14),
                                Row(
                                  children: const [
                                    SkeletonBox(width: 110, height: 34, borderRadius: 10),
                                    SizedBox(width: 12),
                                    SkeletonBox(width: 70, height: 32, borderRadius: 10),
                                    SizedBox(width: 8),
                                    SkeletonBox(width: 80, height: 32, borderRadius: 10),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Card 2: Classes Assignées
                          Row(
                            children: const [
                              SkeletonBox(width: 160, height: 18),
                              Spacer(),
                              SkeletonBox(width: 65, height: 22, borderRadius: 10),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: List.generate(2, (i) => Expanded(
                              child: Container(
                                margin: EdgeInsets.only(right: i == 0 ? 16 : 0),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SkeletonBox(width: 100, height: 17),
                                            SizedBox(height: 4),
                                            SkeletonBox(width: 80, height: 12),
                                          ],
                                        ),
                                        Spacer(),
                                        SkeletonBox(width: 36, height: 36, borderRadius: 10),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: const [
                                        SkeletonBox(width: 14, height: 14, borderRadius: 3),
                                        SizedBox(width: 6),
                                        SkeletonBox(width: 75, height: 12),
                                        SizedBox(width: 16),
                                        SkeletonBox(width: 14, height: 14, borderRadius: 3),
                                        SizedBox(width: 6),
                                        SkeletonBox(width: 65, height: 12),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            )),
                          ),
                          const SizedBox(height: 24),

                          // Card 3: Emploi du temps
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    SkeletonBox(width: 18, height: 18, borderRadius: 4),
                                    SizedBox(width: 10),
                                    SkeletonBox(width: 140, height: 18),
                                    Spacer(),
                                    SkeletonBox(width: 140, height: 32, borderRadius: 10),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                ...List.generate(3, (i) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFF1F5F9)),
                                  ),
                                  child: Row(
                                    children: const [
                                      SkeletonBox(width: 80, height: 14),
                                      SizedBox(width: 16),
                                      SkeletonBox(width: 4, height: 28, borderRadius: 2),
                                      SizedBox(width: 14),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SkeletonBox(width: 120, height: 15),
                                          SizedBox(height: 4),
                                          SkeletonBox(width: 70, height: 11),
                                        ],
                                      ),
                                      Spacer(),
                                      SkeletonBox(width: 70, height: 24, borderRadius: 6),
                                    ],
                                  ),
                                )),
                              ],
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
      ),
    );
  }
}

/// Generic Skeleton loader for simple Grid / Cards layout
class GridSkeletonLoader extends StatelessWidget {
  final int itemCount;

  const GridSkeletonLoader({
    super.key,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(24),
      child: ShimmerLoading(
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 340,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 1.3,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonBox(width: 44, height: 44, borderRadius: 12),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 120, height: 16),
                          SizedBox(height: 6),
                          SkeletonBox(width: 70, height: 12),
                        ],
                      ),
                      Spacer(),
                      SkeletonBox(width: 24, height: 24, borderRadius: 6),
                    ],
                  ),
                  Spacer(),
                  SkeletonBox(width: double.infinity, height: 12),
                  SizedBox(height: 8),
                  SkeletonBox(width: 160, height: 12),
                  Spacer(),
                  Row(
                    children: [
                      SkeletonBox(width: 80, height: 24, borderRadius: 12),
                      Spacer(),
                      SkeletonBox(width: 90, height: 24, borderRadius: 12),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Skeleton loader precisely matching Grade Levels & Filières (Niveaux)
class GradeLevelsSkeletonLoader extends StatelessWidget {
  const GradeLevelsSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F6F8),
      child: ShimmerLoading(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3 Stat Overview Cards
              Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 16 : 0),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        SkeletonBox(width: 48, height: 48, borderRadius: 12),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonBox(width: 90, height: 12),
                            SizedBox(height: 8),
                            SkeletonBox(width: 50, height: 22),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 28),

              // Cycle Header
              Row(
                children: const [
                  SkeletonBox(width: 4, height: 22, borderRadius: 2),
                  SizedBox(width: 10),
                  SkeletonBox(width: 140, height: 18),
                  Spacer(),
                  SkeletonBox(width: 80, height: 26, borderRadius: 8),
                ],
              ),
              const SizedBox(height: 16),

              // Grade Level Accordion Cards
              ...List.generate(3, (i) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        SkeletonBox(width: 36, height: 36, borderRadius: 8),
                        SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 160, height: 16),
                            SizedBox(height: 6),
                            SkeletonBox(width: 100, height: 12),
                          ],
                        ),
                        Spacer(),
                        SkeletonBox(width: 70, height: 24, borderRadius: 12),
                        SizedBox(width: 10),
                        SkeletonBox(width: 28, height: 28, borderRadius: 6),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 14),
                    // Section Chips
                    Row(
                      children: const [
                        SkeletonBox(width: 70, height: 12),
                        SizedBox(width: 12),
                        SkeletonBox(width: 80, height: 24, borderRadius: 6),
                        SizedBox(width: 8),
                        SkeletonBox(width: 90, height: 24, borderRadius: 6),
                        SizedBox(width: 8),
                        SkeletonBox(width: 75, height: 24, borderRadius: 6),
                      ],
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader precisely matching Semesters / Academic Periods
class SemestersSkeletonLoader extends StatelessWidget {
  const SemestersSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: ShimmerLoading(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period Cards List
              ...List.generate(3, (i) => Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Top Row
                    Row(
                      children: const [
                        SkeletonBox(width: 42, height: 42, borderRadius: 10),
                        SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 140, height: 18),
                            SizedBox(height: 6),
                            SkeletonBox(width: 90, height: 12),
                          ],
                        ),
                        Spacer(),
                        SkeletonBox(width: 80, height: 24, borderRadius: 12),
                        SizedBox(width: 12),
                        SkeletonBox(width: 32, height: 32, borderRadius: 8),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 18),
                    // Date range & info row
                    Row(
                      children: const [
                        SkeletonBox(width: 16, height: 16, borderRadius: 4),
                        SizedBox(width: 8),
                        SkeletonBox(width: 110, height: 13),
                        SizedBox(width: 24),
                        SkeletonBox(width: 16, height: 16, borderRadius: 4),
                        SizedBox(width: 8),
                        SkeletonBox(width: 110, height: 13),
                        Spacer(),
                        SkeletonBox(width: 100, height: 28, borderRadius: 8),
                      ],
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader precisely matching Subjects Management (Matières)
class SubjectsSkeletonLoader extends StatelessWidget {
  const SubjectsSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: ShimmerLoading(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: const [
                  SkeletonBox(width: 4, height: 24, borderRadius: 2),
                  SizedBox(width: 10),
                  SkeletonBox(width: 160, height: 18),
                  Spacer(),
                  SkeletonBox(width: 110, height: 32, borderRadius: 16),
                ],
              ),
              const SizedBox(height: 24),

              // 4-Column Grid of Subject Cards
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 0.82,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                ),
                itemCount: 8,
                itemBuilder: (context, index) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            SkeletonBox(width: 40, height: 40, borderRadius: 10),
                            Spacer(),
                            SkeletonBox(width: 44, height: 22, borderRadius: 6),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const SkeletonBox(width: 140, height: 16),
                        const SizedBox(height: 6),
                        const SkeletonBox(width: 90, height: 12),
                        const Spacer(),
                        const Divider(height: 1, color: Color(0xFFF3F4F6)),
                        const SizedBox(height: 12),
                        Row(
                          children: const [
                            SkeletonBox(width: 60, height: 20, borderRadius: 6),
                            SizedBox(width: 8),
                            SkeletonBox(width: 50, height: 20, borderRadius: 6),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader precisely matching Weekly Timetable (Emploi du temps) Grid
class TimetablesSkeletonLoader extends StatelessWidget {
  const TimetablesSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ShimmerLoading(
        child: Column(
          children: [
            // Days Header Row
            Container(
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  // Time col header
                  Container(
                    width: 70,
                    alignment: Alignment.center,
                    child: const SkeletonBox(width: 36, height: 12),
                  ),
                  // 6 Days
                  ...List.generate(6, (i) => Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: const SkeletonBox(width: 60, height: 14),
                    ),
                  )),
                ],
              ),
            ),

            // Time Slots Grid
            Expanded(
              child: ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                itemBuilder: (context, rowIndex) {
                  return Container(
                    height: 80,
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                    ),
                    child: Row(
                      children: [
                        // Time label
                        Container(
                          width: 70,
                          alignment: Alignment.center,
                          child: const SkeletonBox(width: 44, height: 11),
                        ),
                        // 6 Day slots
                        ...List.generate(6, (dayIndex) {
                          final hasClass = (rowIndex + dayIndex) % 3 != 0;
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: hasClass ? const Color(0xFFF8FAFC) : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: hasClass ? Border.all(color: const Color(0xFFE2E8F0)) : null,
                              ),
                              child: hasClass
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        SkeletonBox(width: 70, height: 12),
                                        SizedBox(height: 4),
                                        SkeletonBox(width: 50, height: 10),
                                      ],
                                    )
                                  : null,
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
