import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/l10n/app_localizations.dart';

class MonSoldeSkeleton extends StatelessWidget {
  const MonSoldeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 136 + bottomInset),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _buildBalanceCardSkeleton(context),
          const SizedBox(height: 28),
          Text(
            l10n.paymentSchedule,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentCirclesSkeleton(),
          const SizedBox(height: 28),
          Text(
            l10n.translate('repartition_categorie'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          _buildCategoryCardSkeleton(),
          _buildCategoryCardSkeleton(),
          _buildCategoryCardSkeleton(),
          _buildCategoryCardSkeleton(),
        ]),
      ),
    );
  }

  Widget _buildBalanceCardSkeleton(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('solde_restant'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.white.withValues(alpha: 0.35),
                  highlightColor: Colors.white.withValues(alpha: 0.75),
                  child: Container(
                    width: 120,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 6, right: 6),
                  child: Text(
                    l10n.translate('currency_tnd'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Shimmer.fromColors(
                baseColor: Colors.white.withValues(alpha: 0.25),
                highlightColor: Colors.white.withValues(alpha: 0.7),
                child: Container(
                  height: 8,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '${l10n.statusPaid}: ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.white.withValues(alpha: 0.35),
                      highlightColor: Colors.white.withValues(alpha: 0.75),
                      child: Container(
                        width: 44,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Text(
                      ' ${l10n.translate('currency_tnd')}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${l10n.translate('total')}: ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Shimmer.fromColors(
                      baseColor: Colors.white.withValues(alpha: 0.35),
                      highlightColor: Colors.white.withValues(alpha: 0.75),
                      child: Container(
                        width: 44,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Text(
                      ' ${l10n.translate('currency_tnd')}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCirclesSkeleton() {
    return SizedBox(
      height: 240,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centerX = constraints.maxWidth / 2;
          const centerY = 110.0;
          const circleSize = 160.0;
          const sideScale = 0.76;
          const sideOffset = 118.0;
          const sideVOffset = 26.0;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Left Circle (previous month in carousel)
              Positioned(
                left: centerX - sideOffset - circleSize / 2,
                top: centerY + sideVOffset - circleSize / 2,
                child: SizedBox(
                  width: circleSize,
                  height: circleSize,
                  child: Transform.scale(
                    scale: sideScale,
                    child: Opacity(
                      opacity: 0.65,
                      child: _buildSinglePaymentCircleSkeleton(isCenter: false),
                    ),
                  ),
                ),
              ),

              // Right Circle (next month in carousel)
              Positioned(
                left: centerX + sideOffset - circleSize / 2,
                top: centerY + sideVOffset - circleSize / 2,
                child: SizedBox(
                  width: circleSize,
                  height: circleSize,
                  child: Transform.scale(
                    scale: sideScale,
                    child: Opacity(
                      opacity: 0.65,
                      child: _buildSinglePaymentCircleSkeleton(isCenter: false),
                    ),
                  ),
                ),
              ),

              // Center Circle (current focused month)
              Positioned(
                left: centerX - circleSize / 2,
                top: centerY - circleSize / 2,
                child: SizedBox(
                  width: circleSize,
                  height: circleSize,
                  child: _buildSinglePaymentCircleSkeleton(isCenter: true),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSinglePaymentCircleSkeleton({required bool isCenter}) {
    const shimmerBase = Color(0xFFE2E8F0);
    const shimmerHighlight = Color(0xFFF8FAFC);

    Widget circleCard = Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isCenter ? 0.08 : 0.04),
            blurRadius: isCenter ? 20 : 12,
            offset: const Offset(0, 6),
          ),
          if (isCenter)
            BoxShadow(
              color: const Color(0xFFFF6B9D).withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Shimmer.fromColors(
        baseColor: shimmerBase,
        highlightColor: shimmerHighlight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Month label
            Container(
              width: 38,
              height: 11,
              decoration: BoxDecoration(
                color: shimmerBase,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            // Amount
            Container(
              width: 74,
              height: 24,
              decoration: BoxDecoration(
                color: shimmerBase,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 5),
            // Currency
            Container(
              width: 26,
              height: 9,
              decoration: BoxDecoration(
                color: shimmerBase,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            // Status capsule badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: shimmerBase.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: shimmerBase,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 32,
                    height: 8,
                    decoration: BoxDecoration(
                      color: shimmerBase,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isCenter) {
      circleCard = Stack(
        clipBehavior: Clip.none,
        children: [
          circleCard,
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Center(
              child: Shimmer.fromColors(
                baseColor: const Color(0xFFFFD1E1),
                highlightColor: const Color(0xFFFFEFF5),
                child: Container(
                  width: 62,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD1E1),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B9D).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return circleCard;
  }

  Widget _buildCategoryCardSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Shimmer.fromColors(
                  baseColor: const Color(0xFFD1D5DB),
                  highlightColor: const Color(0xFFF3F4F6),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Shimmer.fromColors(
                        baseColor: const Color(0xFFD1D5DB),
                        highlightColor: const Color(0xFFF3F4F6),
                        child: Row(
                          children: [
                            Container(
                              width: 80,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1D5DB),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 50,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1D5DB),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Shimmer.fromColors(
                        baseColor: const Color(0xFFE5E7EB),
                        highlightColor: const Color(0xFFF9FAFB),
                        child: Container(
                          width: double.infinity,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Shimmer.fromColors(
                        baseColor: const Color(0xFFE5E7EB),
                        highlightColor: const Color(0xFFF9FAFB),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 100,
                              height: 11,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Container(
                              width: 70,
                              height: 11,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(4),
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
      ),
    );
  }
}
