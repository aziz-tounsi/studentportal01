import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../providers/announcements_provider.dart';
import '../providers/nav_bar_provider.dart';

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

    if (currentRoute == targetRoute) {
      // Truly on the same page: stay bouncing purely on the same button!
      setState(() {
        _fromIndex = index;
        _selectedIndex = index;
      });
      _animationController.forward(from: 0.0);
      return;
    }

    // Navigating to a different route
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
    final navWidth = math.min(screenWidth * 0.78, 340.0);
    const double gap = 6.0;
    const double padding = 6.0;
    const double circleSize = 72.0;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      color: Colors.transparent,
      height: 96 + bottomPadding,
      alignment: Alignment.topCenter,
      child: Container(
        width: navWidth,
        height: circleSize + padding * 2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular((circleSize + padding * 2) / 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7A8698).withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular((circleSize + padding * 2) / 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius:
                    BorderRadius.circular((circleSize + padding * 2) / 2),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;
                  final totalItemsWidth =
                      items.length * circleSize + (items.length - 1) * gap;
                  final startX = (availableWidth - totalItemsWidth) / 2;

                  double getSlotX(int index) {
                    final visualIndex =
                        isRtl ? (items.length - 1 - index) : index;
                    return startX + visualIndex * (circleSize + gap);
                  }

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Animated bouncing pink circle with slow iOS elastic effect
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, _) {
                          final fromX = getSlotX(_fromIndex);
                          final targetX = getSlotX(_selectedIndex);
                          final t = _animation.value;
                          final currentX = lerpDouble(fromX, targetX, t)!;
                          final progress = _animationController.value;
                          final isSameTab = _fromIndex == _selectedIndex;

                          // Slow, smooth elastic squish/bounce scale
                          final bounceScale = isSameTab
                              ? 1.0 + 0.16 * math.sin(progress * math.pi)
                              : 1.0 + 0.10 * math.sin(progress * math.pi);

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
                                list.add(const SizedBox(width: gap));
                              }
                              list.add(_buildItem(i, items));
                            }
                            return list;
                          }(),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index, List<_NavItem> items) {
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
            width: 72,
            height: 72,
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  items[index].icon,
                  color: iconColor,
                  size: 36,
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
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        items[index].badgeCount! > 9
                            ? '9+'
                            : '${items[index].badgeCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
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
