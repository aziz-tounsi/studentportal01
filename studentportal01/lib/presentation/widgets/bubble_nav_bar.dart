import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../providers/announcements_provider.dart';
import '../providers/nav_bar_provider.dart';
import 'ios_edge_swipe_back.dart';

const Color _pink = Color(0xFFFF2D78);

class BubbleNavBar extends ConsumerStatefulWidget {
  final int currentIndex;

  const BubbleNavBar({
    super.key,
    this.currentIndex = 0,
  });

  @override
  ConsumerState<BubbleNavBar> createState() => _BubbleNavBarState();
}

class _BubbleNavBarState extends ConsumerState<BubbleNavBar>
    with SingleTickerProviderStateMixin {
  late int _selectedIndex;
  late int _fromIndex;
  late AnimationController _animationController;
  late Animation<double> _animation;

  List<_NavItem> _getNavItems() {
    final messagesCount = ref.watch(classMessagesCountProvider);
    final notificationsCount = ref.watch(globalAnnouncementsCountProvider);

    return [
      const _NavItem(
        icon: Icons.home_rounded,
        route: '/',
      ),
      _NavItem(
        icon: Icons.mail_rounded,
        route: '/messages',
        badgeCount: messagesCount,
      ),
      _NavItem(
        icon: Icons.notifications_rounded,
        route: '/notifications',
        badgeCount: notificationsCount,
      ),
      const _NavItem(
        icon: Icons.auto_awesome,
        route: '/ai-chat',
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.currentIndex;
    _fromIndex = widget.currentIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.value = 1.0;

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted && _fromIndex != _selectedIndex) {
          setState(() {
            _fromIndex = _selectedIndex;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(BubbleNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != _selectedIndex) {
      setState(() {
        _fromIndex = _selectedIndex;
        _selectedIndex = widget.currentIndex;
      });
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    final items = _getNavItems();
    final targetRoute = items[index].route;
    final currentRoute = GoRouterState.of(context).matchedLocation;

    if (currentRoute == targetRoute) {
      // Truly on the same page: stay bouncing purely on the same button!
      setState(() {
        _fromIndex = index;
        _selectedIndex = index;
      });
      _animationController.forward(from: 0.0);
      if (targetRoute == '/') {
        ref.read(homeScrollToTopTriggerProvider.notifier).state++;
      }
      return;
    }

    // If returning to Home dashboard from any of the 6 home pages, close animate by pop bouncing zoom-out with flight blur
    const homeFeatureRoutes = [
      '/suggestions',
      '/absences',
      '/resultats',
      '/emploi',
      '/mon-solde',
      '/documents',
    ];
    final isHomeFeature = homeFeatureRoutes.any((r) => currentRoute == r || currentRoute.startsWith('$r/'));

    if (targetRoute == '/' && isHomeFeature && IosEdgeSwipeBackState.currentActive != null) {
      setState(() {
        _fromIndex = _selectedIndex;
        _selectedIndex = index;
      });
      _animationController.forward(from: 0.0);
      IosEdgeSwipeBackState.currentActive!.animateSlideBack();
      return;
    }

    // Dismiss any pushed modals/sheets/popups so we cleanly show the destination tab
    dismissAllOverlaysAndPopups();
    try {
      final rootNav = Navigator.of(context, rootNavigator: true);
      while (rootNav.canPop()) {
        rootNav.pop();
      }
    } catch (_) {}
    try {
      final localNav = Navigator.of(context, rootNavigator: false);
      while (localNav.canPop()) {
        localNav.pop();
      }
    } catch (_) {}

    if (targetRoute == '/ai-chat' && currentRoute != '/ai-chat') {
      ref.read(aiChatOriginRouteProvider.notifier).state = currentRoute;
    }
    ref.read(navigatedFromAIChatProvider.notifier).state = false;
    setState(() {
      _fromIndex = _selectedIndex;
      _selectedIndex = index;
    });
    _animationController.forward(from: 0.0);
    context.go(targetRoute);
  }

  @override
  Widget build(BuildContext context) {
    final items = _getNavItems();
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    // Compute button sizes and gaps first from max available container width,
    // so the 4 buttons keep their exact sizes and centered screen positions.
    final double maxBarWidth = screenWidth >= 600
        ? 360.0
        : math.min(screenWidth - (screenWidth < 360 ? 20.0 : 32.0), 346.0);
    final int count = items.length;
    final double padding = (maxBarWidth * 0.016).clamp(4.0, 6.0);
    final double gap = (maxBarWidth * 0.016).clamp(4.0, 6.0);
    final double maxInnerWidth = maxBarWidth - (padding * 2);

    final double maxCircleAllowed =
        ((maxInnerWidth - (count - 1) * gap) / count).floorToDouble();
    final double circleSize = maxCircleAllowed.clamp(48.0, 70.0);
    final double totalItemsWidth = count * circleSize + (count - 1) * gap;

    // Trim excess horizontal pill wings on left/right while keeping a clean margin.
    final double extraHorizontalSide = maxBarWidth >= 320 ? 5.0 : 2.0;
    final double navWidth = math.min(
      maxBarWidth,
      totalItemsWidth + (padding * 2) + (extraHorizontalSide * 2),
    );
    final double availableInnerWidth = navWidth - (padding * 2);
    final double startX = (availableInnerWidth - totalItemsWidth) / 2;

    final double iconSize = (circleSize * 0.46).clamp(23.0, 34.0);
    final double badgeSize = (circleSize * 0.28).clamp(16.0, 20.0);
    final double badgeFont = (circleSize * 0.15).clamp(9.0, 11.0);
    final double barHeight = circleSize + padding * 2;
    final double safeBottomOffset =
        bottomPadding > 0 ? bottomPadding + 6.0 : 12.0;

    return Container(
      color: Colors.transparent,
      height: barHeight + safeBottomOffset,
      alignment: Alignment.topCenter,
      child: Container(
        width: navWidth,
        height: barHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(barHeight / 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7A8698).withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(barHeight / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(barHeight / 2),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.90),
                  width: 1.2,
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Animated bouncing pink circle with slow iOS elastic effect
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, _) {
                      double getSlotX(int index) {
                        final visualIndex =
                            isRtl ? (count - 1 - index) : index;
                        return startX + visualIndex * (circleSize + gap);
                      }

                      final fromX = getSlotX(_fromIndex);
                      final targetX = getSlotX(_selectedIndex);
                      final t = _animation.value;
                      final currentX = lerpDouble(fromX, targetX, t)!;
                      final progress = _animationController.value;
                      final isSameTab = _fromIndex == _selectedIndex;

                      // Slow, smooth elastic squish/bounce scale
                      final bounceScale = isSameTab
                          ? 1.0 + 0.14 * math.sin(progress * math.pi)
                          : 1.0 + 0.08 * math.sin(progress * math.pi);

                      return Positioned(
                        left: currentX,
                        top: 0,
                        width: circleSize,
                        height: circleSize,
                        child: Transform.scale(
                          scale: bounceScale,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _pink,
                              boxShadow: [
                                BoxShadow(
                                  color: _pink.withValues(alpha: 0.40),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Row of nav items sitting on top of the sliding pink circle
                  Positioned.fill(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: () {
                        final list = <Widget>[];
                        for (int i = 0; i < items.length; i++) {
                          if (i > 0) {
                            list.add(SizedBox(width: gap));
                          }
                          list.add(_buildItem(
                            i,
                            items,
                            circleSize,
                            iconSize,
                            badgeSize,
                            badgeFont,
                          ));
                        }
                        return list;
                      }(),
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

  Widget _buildItem(
    int index,
    List<_NavItem> items,
    double itemSize,
    double iconSize,
    double badgeSize,
    double badgeFont,
  ) {
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, _) {
          final isSelected = _selectedIndex == index;
          final iconColor =
              isSelected ? Colors.white : const Color(0xFF94A3B8);

          return Container(
            width: itemSize,
            height: itemSize,
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  items[index].icon,
                  color: iconColor,
                  size: iconSize,
                ),
                if (items[index].badgeCount != null &&
                    items[index].badgeCount! > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _pink,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: BoxConstraints(
                        minWidth: badgeSize,
                        minHeight: badgeSize,
                      ),
                      child: Text(
                        items[index].badgeCount! > 9
                            ? '9+'
                            : '${items[index].badgeCount}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: badgeFont,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String route;
  final int? badgeCount;

  const _NavItem({
    required this.icon,
    required this.route,
    this.badgeCount,
  });
}
