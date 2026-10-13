import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class StudentCardSkeleton extends StatelessWidget {
  const StudentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: AspectRatio(
            aspectRatio: 720 / 480,
            child: _SkeletonContent(),
          ),
        ),
      ),
    );
  }
}

class _SkeletonContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / 720;
        double s(double value) => value * scale;

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FB),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0x5A3A1022),
                blurRadius: s(60),
                offset: Offset(0, s(25)),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: Shimmer.fromColors(
                  baseColor: const Color(0xFFE8EBF0),
                  highlightColor: const Color(0xFFF5F7FB),
                  child: Container(
                    color: const Color(0xFFE8EBF0),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: -s(60),
                height: s(220),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(s(150)),
                    bottomRight: Radius.circular(s(150)),
                  ),
                  child: Shimmer.fromColors(
                    baseColor: const Color(0xFFE0A0B8),
                    highlightColor: const Color(0xFFF0C0D0),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: [0.0, 0.45, 1.0],
                          colors: [
                            Color(0xFFFF85B0),
                            Color(0xFF54172D),
                            Color(0xFFFF2D78),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: s(60),
                left: s(300),
                child: Shimmer.fromColors(
                  baseColor: Colors.white.withValues(alpha: 0.4),
                  highlightColor: Colors.white.withValues(alpha: 0.8),
                  child: Container(
                    width: s(180),
                    height: s(50),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(s(8)),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: s(95),
                left: s(60),
                child: Shimmer.fromColors(
                  baseColor: const Color(0xFFD0D5DB),
                  highlightColor: const Color(0xFFE8EBF0),
                  child: Container(
                    width: s(180),
                    height: s(180),
                    padding: EdgeInsets.all(s(8)),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF85B0),
                          Color(0xFF54172D),
                        ],
                      ),
                    ),
                    child: ClipOval(
                      child: Container(
                        color: const Color(0xFFD0D5DB),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: s(300),
                top: s(250),
                width: s(380),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRowSkeleton('Nom', s),
                    _detailRowSkeleton('CI', s),
                    _detailRowSkeleton('D.D.N', s),
                    _detailRowSkeleton('Adresse', s),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                width: s(300),
                top: s(340),
                child: Center(
                  child: Shimmer.fromColors(
                    baseColor: const Color(0xFFD0D5DB),
                    highlightColor: const Color(0xFFE8EBF0),
                    child: Container(
                      width: s(140),
                      height: s(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0D5DB),
                        borderRadius: BorderRadius.circular(s(4)),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: s(32),
                child: Shimmer.fromColors(
                  baseColor: const Color(0xFF822B4A),
                  highlightColor: const Color(0xFFD6316D),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFF822B4A),
                          Color(0xFFD6316D),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRowSkeleton(String label, double Function(double) s) {
    return Padding(
      padding: EdgeInsets.only(bottom: s(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: s(96),
            child: Shimmer.fromColors(
              baseColor: const Color(0xFFD0D5DB),
              highlightColor: const Color(0xFFE8EBF0),
              child: Container(
                height: s(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DB),
                  borderRadius: BorderRadius.circular(s(4)),
                ),
              ),
            ),
          ),
          SizedBox(
            width: s(24),
            child: Shimmer.fromColors(
              baseColor: const Color(0xFFD0D5DB),
              highlightColor: const Color(0xFFE8EBF0),
              child: Container(
                height: s(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DB),
                  borderRadius: BorderRadius.circular(s(4)),
                ),
              ),
            ),
          ),
          Expanded(
            child: Shimmer.fromColors(
              baseColor: const Color(0xFFD0D5DB),
              highlightColor: const Color(0xFFE8EBF0),
              child: Container(
                height: s(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DB),
                  borderRadius: BorderRadius.circular(s(4)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
