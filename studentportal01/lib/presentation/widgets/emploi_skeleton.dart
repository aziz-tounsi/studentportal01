import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class EmploiSkeleton extends StatelessWidget {
  const EmploiSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Shimmer.fromColors(
          baseColor: const Color(0xFFE5E7EB),
          highlightColor: const Color(0xFFF3F4F6),
          child: Column(
            children: [
              // Day headers
              Container(
                height: 40,
                padding: const EdgeInsets.only(left: 35),
                child: Row(
                  children: List.generate(6, (i) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 28,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  )),
                ),
              ),
              // Time grid
              Expanded(
                child: Row(
                  children: [
                    // Time labels
                    SizedBox(
                      width: 35,
                      child: Column(
                        children: List.generate(9, (i) => Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.withValues(alpha: i % 2 == 0 ? 0.35 : 0.1),
                                  width: i % 2 == 0 ? 1.5 : 0.5,
                                ),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: Container(
                                width: 30,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1D5DB),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        )),
                      ),
                    ),
                    // Grid cells
                    Expanded(
                      child: Column(
                        children: List.generate(9, (hour) => Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.withValues(alpha: hour % 2 == 0 ? 0.35 : 0.1),
                                  width: hour % 2 == 0 ? 1.5 : 0.5,
                                ),
                              ),
                            ),
                            child: Row(
                              children: List.generate(6, (day) => Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color: Colors.grey.withValues(alpha: 0.2),
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              )),
                            ),
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
      ),
    );
  }
}
