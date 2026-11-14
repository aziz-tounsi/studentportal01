import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/console_translations.dart';
import '../providers/console_auth_provider.dart';
import '../providers/platform_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// ░░░  AURORA GLASS — Super Admin Sidebar Navigation  ░░░
// ═══════════════════════════════════════════════════════════════════

class ConsoleSidebar extends ConsumerWidget {
  final String currentRoute;
  const ConsoleSidebar({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tr = ref.watch(consoleTranslationsProvider);
    final platformState = ref.watch(platformProvider);
    final openBugs = (platformState.kpis['openBugsCount'] as int?) ?? 0;
    final pendingPayments = (platformState.kpis['pendingCount'] as int?) ?? 0;

    return Container(
      width: 272,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF070B14), Color(0xFF0D1321), Color(0xFF111827)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative gradient orb (top-right)
          Positioned(
            top: -40,
            right: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2563EB).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Decorative gradient orb (bottom-left)
          Positioned(
            bottom: 40,
            left: -50,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C3AED).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main content
          Column(
            children: [
              const SizedBox(height: 28),
              // Brand Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6D4CF6), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6D4CF6).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.shield_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr.navPlatformTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            tr.navPlatformSubtitle,
                            style: TextStyle(
                              color: const Color(0xFF60A5FA).withValues(alpha: 0.6),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Navigation list
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(title: tr.navSectionPlatform.toUpperCase()),
                      _NavItem(
                        icon: Icons.dashboard_outlined,
                        label: tr.navOverview,
                        route: '/dashboard',
                        currentRoute: currentRoute,
                      ),
                      _NavItem(
                        icon: Icons.domain_outlined,
                        label: 'Établissements',
                        route: '/schools',
                        currentRoute: currentRoute,
                      ),
                      const SizedBox(height: 8),
                      _SectionTitle(title: tr.navSectionBilling.toUpperCase()),
                      _NavItem(
                        icon: Icons.receipt_long_outlined,
                        label: tr.navBilling,
                        route: '/billing',
                        currentRoute: currentRoute,
                        badgeCount: pendingPayments,
                      ),
                      _NavItem(
                        icon: Icons.auto_awesome_outlined,
                        label: tr.navAiTelemetry,
                        route: '/ai-telemetry',
                        currentRoute: currentRoute,
                      ),
                      const SizedBox(height: 8),
                      _SectionTitle(title: tr.navSectionControl.toUpperCase()),
                      _NavItem(
                        icon: Icons.history_outlined,
                        label: tr.navAudit,
                        route: '/audit',
                        currentRoute: currentRoute,
                      ),
                      _NavItem(
                        icon: Icons.bug_report_outlined,
                        label: tr.navBugs,
                        route: '/bugs',
                        currentRoute: currentRoute,
                        badgeCount: openBugs,
                      ),
                      _NavItem(
                        icon: Icons.settings_outlined,
                        label: tr.navSettings,
                        route: '/settings',
                        currentRoute: currentRoute,
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom Logout Button (matching Admin Dashboard exactly)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            await ref.read(consoleAuthProvider.notifier).signOut();
                            if (context.mounted) context.go('/login');
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.power_settings_new_rounded,
                                    color: Color(0xFFF87171),
                                    size: 17,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  tr.navLogout,
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 12, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.25),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String route;
  final String currentRoute;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
    this.badgeCount = 0,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.currentRoute == widget.route ||
        (widget.route == '/dashboard' && widget.currentRoute == '/');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          context.go(widget.route);
        },
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: isActive
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        const Color(0xFF2563EB).withValues(alpha: 0.18),
                        const Color(0xFF7C3AED).withValues(alpha: 0.06),
                      ],
                    )
                  : null,
              color: !isActive && _isHovered
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Active indicator bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 3,
                  height: isActive ? 24 : 0,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF60A5FA) : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: const Color(0xFF60A5FA).withValues(alpha: 0.6),
                              blurRadius: 8,
                            ),
                          ]
                        : [],
                  ),
                ),
                // Icon
                Icon(
                  widget.icon,
                  color: isActive
                      ? const Color(0xFF60A5FA)
                      : _isHovered
                          ? Colors.white70
                          : Colors.white38,
                  size: 19,
                ),
                const SizedBox(width: 12),
                // Label
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white60,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                // Badge
                if (widget.badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF97316), Color(0xFFFB923C)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF97316).withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
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
