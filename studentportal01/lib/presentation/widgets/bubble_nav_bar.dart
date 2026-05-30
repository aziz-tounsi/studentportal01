import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/announcements_provider.dart';

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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void didUpdateWidget(BubbleNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = widget.currentIndex;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    final items = _getNavItems();
    setState(() {
      _selectedIndex = index;
    });
    _animationController.reset();
    _animationController.forward();
    context.go(items[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final items = _getNavItems();
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final navWidth = math.min(screenWidth * 0.78, 340.0);
    const double gap = 6;
    const double padding = 6;
    final double circleSize = 72.0;

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
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular((circleSize + padding * 2) / 2),
              ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index, List<_NavItem> items) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? _pink : Colors.transparent,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _pink.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  items[index].icon,
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF94A3B8),
                  size: 36,
                ),
                if (items[index].badgeCount != null &&
                    items[index].badgeCount! > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: _pink,
                        shape: BoxShape.circle,
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
