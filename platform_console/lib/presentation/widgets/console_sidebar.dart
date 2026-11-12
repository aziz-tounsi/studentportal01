import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/console_auth_provider.dart';
import '../providers/platform_provider.dart';

class ConsoleSidebar extends ConsumerWidget {
  final String currentRoute;
  const ConsoleSidebar({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    const Color(0xFF2563EB).withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
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
                    const Color(0xFF7C3AED).withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 28),
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
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PythaOne',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Super Admin SaaS',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle(title: 'PLATEFORME'),
                      _NavItem(
                        icon: Icons.dashboard_outlined,
                        label: 'Vue d\'ensemble',
                        route: '/dashboard',
                        currentRoute: currentRoute,
                      ),
                      _NavItem(
                        icon: Icons.apartment_outlined,
                        label: 'Écoles & Tenants',
                        route: '/schools',
                        currentRoute: currentRoute,
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle(title: 'FACTURATION & IA'),
                      _NavItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'Facturation',
                        route: '/billing',
                        currentRoute: currentRoute,
                        badgeCount: pendingPayments,
                      ),
                      _NavItem(
                        icon: Icons.auto_awesome_outlined,
                        label: 'Télémétrie IA',
                        route: '/ai-telemetry',
                        currentRoute: currentRoute,
                      ),
                      const SizedBox(height: 16),
                      const _SectionTitle(title: 'CONTRÔLE & SUPPORT'),
                      _NavItem(
                        icon: Icons.history_outlined,
                        label: 'Journaux d\'Audit',
                        route: '/audit',
                        currentRoute: currentRoute,
                      ),
                      _NavItem(
                        icon: Icons.bug_report_outlined,
                        label: 'Signalements',
                        route: '/bugs',
                        currentRoute: currentRoute,
                        badgeCount: openBugs,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.16),
                        ),
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
                                    color: const Color(0xFFDC2626)
                                        .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.logout_rounded,
                                    color: Color(0xFFF87171),
                                    size: 17,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Déconnexion',
                                    style: TextStyle(
                                      color: Color(0xFFFCA5A5),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
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
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isActive =
        currentRoute == route || (currentRoute == '/' && route == '/dashboard');

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF6D4CF6)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          onTap: () => context.go(route),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: isActive ? Colors.white : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFFCBD5E1),
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.25)
                          : const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
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
