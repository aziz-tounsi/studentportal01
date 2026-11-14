import 'package:flutter/material.dart';

/// Animated shimmer wrapper matching Admin Dashboard SkeletonLoader
class ConsoleShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;

  const ConsoleShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
  });

  @override
  State<ConsoleShimmerLoading> createState() => _ConsoleShimmerLoadingState();
}

class _ConsoleShimmerLoadingState extends State<ConsoleShimmerLoading>
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
      builder: (context, _) => Opacity(
        opacity: _animation.value,
        child: widget.child,
      ),
    );
  }
}

class ConsoleSkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;
  final Color? color;

  const ConsoleSkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFE2E8F0),
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
      ),
    );
  }
}

Widget _skeletonCard({required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: child,
  );
}

Widget _skeletonKpiRow(int count) {
  return Row(
    children: List.generate(count, (i) {
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: i < count - 1 ? 16 : 0),
          child: _skeletonCard(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ConsoleSkeletonBox(width: 38, height: 38, borderRadius: 10),
                    Spacer(),
                    ConsoleSkeletonBox(width: 56, height: 22, borderRadius: 11),
                  ],
                ),
                SizedBox(height: 16),
                ConsoleSkeletonBox(width: 96, height: 26, borderRadius: 6),
                SizedBox(height: 8),
                ConsoleSkeletonBox(width: 130, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ),
      );
    }),
  );
}

Widget _skeletonTable({int rows = 6, int cols = 5}) {
  return _skeletonCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            ConsoleSkeletonBox(width: 200, height: 18, borderRadius: 6),
            Spacer(),
            ConsoleSkeletonBox(width: 120, height: 34, borderRadius: 8),
          ],
        ),
        const SizedBox(height: 18),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        const SizedBox(height: 14),
        ...List.generate(rows, (r) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: List.generate(cols, (c) {
                return Expanded(
                  flex: c == 0 ? 2 : 1,
                  child: Padding(
                    padding: EdgeInsets.only(right: c < cols - 1 ? 16 : 0),
                    child: Row(
                      children: [
                        if (c == 0) ...[
                          const ConsoleSkeletonBox(
                            width: 32,
                            height: 32,
                            borderRadius: 8,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: ConsoleSkeletonBox(
                            height: c == cols - 1 ? 26 : 14,
                            borderRadius: c == cols - 1 ? 13 : 5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    ),
  );
}

// 1. Overview Page Skeleton
class ConsoleOverviewSkeleton extends StatelessWidget {
  const ConsoleOverviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ConsoleShimmerLoading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _skeletonKpiRow(4),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _skeletonTable(rows: 5, cols: 4),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _skeletonCard(
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConsoleSkeletonBox(width: 160, height: 18, borderRadius: 6),
                        SizedBox(height: 16),
                        ConsoleSkeletonBox(height: 64, borderRadius: 12),
                        SizedBox(height: 12),
                        ConsoleSkeletonBox(height: 64, borderRadius: 12),
                        SizedBox(height: 12),
                        ConsoleSkeletonBox(height: 64, borderRadius: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// 2. Schools Page Skeleton
class ConsoleSchoolsSkeleton extends StatelessWidget {
  const ConsoleSchoolsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ConsoleShimmerLoading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            _skeletonKpiRow(3),
            const SizedBox(height: 22),
            _skeletonTable(rows: 7, cols: 6),
          ],
        ),
      ),
    );
  }
}

// 3. Billing Page Skeleton
class ConsoleBillingSkeleton extends StatelessWidget {
  const ConsoleBillingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ConsoleShimmerLoading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            _skeletonCard(
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConsoleSkeletonBox(width: 250, height: 18, borderRadius: 6),
                  SizedBox(height: 16),
                  ConsoleSkeletonBox(height: 68, borderRadius: 12),
                  SizedBox(height: 12),
                  ConsoleSkeletonBox(height: 68, borderRadius: 12),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _skeletonTable(rows: 6, cols: 5),
          ],
        ),
      ),
    );
  }
}

// 4. AI Telemetry Page Skeleton
class ConsoleAiTelemetrySkeleton extends StatelessWidget {
  const ConsoleAiTelemetrySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ConsoleShimmerLoading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            _skeletonCard(
              child: const Row(
                children: [
                  ConsoleSkeletonBox(width: 44, height: 44, borderRadius: 12),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConsoleSkeletonBox(width: 280, height: 16, borderRadius: 6),
                        SizedBox(height: 8),
                        ConsoleSkeletonBox(width: 360, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  ConsoleSkeletonBox(width: 52, height: 28, borderRadius: 14),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _skeletonTable(rows: 7, cols: 6),
          ],
        ),
      ),
    );
  }
}

// 5. Audit Logs Page Skeleton
class ConsoleAuditSkeleton extends StatelessWidget {
  const ConsoleAuditSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ConsoleShimmerLoading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: _skeletonTable(rows: 9, cols: 5),
      ),
    );
  }
}

// 6. Bug Reports Page Skeleton
class ConsoleBugReportsSkeleton extends StatelessWidget {
  const ConsoleBugReportsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ConsoleShimmerLoading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            _skeletonKpiRow(4),
            const SizedBox(height: 22),
            ...List.generate(3, (_) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _skeletonCard(
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ConsoleSkeletonBox(width: 72, height: 22, borderRadius: 6),
                          SizedBox(width: 12),
                          Expanded(
                            child: ConsoleSkeletonBox(height: 16, borderRadius: 6),
                          ),
                          SizedBox(width: 16),
                          ConsoleSkeletonBox(width: 96, height: 26, borderRadius: 13),
                        ],
                      ),
                      SizedBox(height: 12),
                      ConsoleSkeletonBox(height: 54, borderRadius: 10),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// 7. Settings Page Skeleton
class ConsoleSettingsSkeleton extends StatelessWidget {
  const ConsoleSettingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ConsoleShimmerLoading(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tabs row skeleton
            Row(
              children: List.generate(4, (i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ConsoleSkeletonBox(
                    width: 140,
                    height: 42,
                    borderRadius: 10,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            // First large card
            _skeletonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ConsoleSkeletonBox(width: 220, height: 22, borderRadius: 6),
                  const SizedBox(height: 8),
                  const ConsoleSkeletonBox(width: 380, height: 14, borderRadius: 6),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: const Row(
                            children: [
                              ConsoleSkeletonBox(width: 40, height: 40, borderRadius: 10),
                              SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ConsoleSkeletonBox(width: 100, height: 16, borderRadius: 4),
                                    SizedBox(height: 6),
                                    ConsoleSkeletonBox(width: 160, height: 12, borderRadius: 4),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: const Row(
                            children: [
                              ConsoleSkeletonBox(width: 40, height: 40, borderRadius: 10),
                              SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ConsoleSkeletonBox(width: 100, height: 16, borderRadius: 4),
                                    SizedBox(height: 6),
                                    ConsoleSkeletonBox(width: 160, height: 12, borderRadius: 4),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            // Second settings card
            _skeletonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ConsoleSkeletonBox(width: 240, height: 22, borderRadius: 6),
                  const SizedBox(height: 8),
                  const ConsoleSkeletonBox(width: 420, height: 14, borderRadius: 6),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: ConsoleSkeletonBox(height: 48, borderRadius: 10)),
                      const SizedBox(width: 16),
                      Expanded(child: ConsoleSkeletonBox(height: 48, borderRadius: 10)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: ConsoleSkeletonBox(height: 48, borderRadius: 10)),
                      const SizedBox(width: 16),
                      Expanded(child: ConsoleSkeletonBox(height: 48, borderRadius: 10)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const ConsoleSkeletonBox(width: 180, height: 42, borderRadius: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 5. School Profile Page Skeleton
class SchoolProfileSkeleton extends StatelessWidget {
  const SchoolProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ConsoleShimmerLoading(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // 2-Column Grid (Body only, no skeleton header)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column (360px)
                SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      // School Identity Card Skeleton
                      _skeletonCard(
                        child: Column(
                          children: [
                            const ConsoleSkeletonBox(width: 72, height: 72, shape: BoxShape.circle),
                            const SizedBox(height: 14),
                            const ConsoleSkeletonBox(width: 180, height: 20, borderRadius: 6),
                            const SizedBox(height: 8),
                            const ConsoleSkeletonBox(width: 80, height: 22, borderRadius: 11),
                            const SizedBox(height: 20),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            const SizedBox(height: 16),
                            ...List.generate(4, (i) => const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  ConsoleSkeletonBox(width: 90, height: 14, borderRadius: 4),
                                  ConsoleSkeletonBox(width: 120, height: 14, borderRadius: 4),
                                ],
                              ),
                            )),
                            const SizedBox(height: 8),
                            const ConsoleSkeletonBox(height: 38, borderRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Subscription Card Skeleton
                      _skeletonCard(
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ConsoleSkeletonBox(width: 120, height: 16, borderRadius: 4),
                                ConsoleSkeletonBox(width: 60, height: 22, borderRadius: 11),
                              ],
                            ),
                            SizedBox(height: 16),
                            ConsoleSkeletonBox(width: 160, height: 22, borderRadius: 6),
                            SizedBox(height: 8),
                            ConsoleSkeletonBox(width: 200, height: 14, borderRadius: 4),
                            SizedBox(height: 20),
                            ConsoleSkeletonBox(height: 6, borderRadius: 3),
                            SizedBox(height: 16),
                            ConsoleSkeletonBox(height: 38, borderRadius: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),

                // Right Column (Expanded)
                Expanded(
                  child: Column(
                    children: [
                      // 4 KPIs
                      _skeletonKpiRow(4),
                      const SizedBox(height: 24),
                      // Table Skeleton
                      _skeletonTable(rows: 6, cols: 5),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }
}

