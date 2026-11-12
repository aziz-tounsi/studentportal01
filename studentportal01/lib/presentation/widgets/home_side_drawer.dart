import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/theme/arabic_typography.dart';
import '../providers/auth_provider.dart';
import '../providers/nav_bar_provider.dart';
import '../providers/school_provider.dart';
import 'bouncing_wrapper.dart';
import 'school_logo_widget.dart';

class HomeSideDrawer extends ConsumerWidget {
  const HomeSideDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDrawerOpen = ref.watch(sideDrawerOpenProvider);
    final school = ref.watch(schoolProvider).valueOrNull;
    final l10n = AppLocalizations.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = math.min(300.0, screenWidth * 0.76);

    return Stack(
      children: [
        // 1. Dimmed Backdrop Overlay (Scrim)
        IgnorePointer(
          ignoring: !isDrawerOpen,
          child: AnimatedOpacity(
            opacity: isDrawerOpen ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(sideDrawerOpenProvider.notifier).state = false;
              },
              onHorizontalDragUpdate: (details) {
                final delta = details.primaryDelta ?? 0;
                if (isRtl) {
                  if (delta > 6) {
                    ref.read(sideDrawerOpenProvider.notifier).state = false;
                  }
                } else {
                  if (delta < -6) {
                    ref.read(sideDrawerOpenProvider.notifier).state = false;
                  }
                }
              },
              onHorizontalDragEnd: (details) {
                final vel = details.primaryVelocity ?? 0;
                if (isRtl) {
                  if (vel > 80) {
                    ref.read(sideDrawerOpenProvider.notifier).state = false;
                  }
                } else {
                  if (vel < -80) {
                    ref.read(sideDrawerOpenProvider.notifier).state = false;
                  }
                }
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
          ),
        ),

        // 2. Edge swipe gesture to open the drawer
        if (!isDrawerOpen)
          Positioned(
            left: isRtl ? null : 0,
            right: isRtl ? 0 : null,
            top: 0,
            bottom: 0,
            width: 35,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                final delta = details.primaryDelta ?? 0;
                if (isRtl) {
                  if (delta < -8) {
                    ref.read(sideDrawerOpenProvider.notifier).state = true;
                  }
                } else {
                  if (delta > 8) {
                    ref.read(sideDrawerOpenProvider.notifier).state = true;
                  }
                }
              },
            ),
          ),

        // 3. Sliding Drawer Panel matching exact design from image
        AnimatedPositioned(
          left: isRtl ? null : (isDrawerOpen ? 0 : -drawerWidth),
          right: isRtl ? (isDrawerOpen ? 0 : -drawerWidth) : null,
          top: 0,
          bottom: 0,
          width: drawerWidth,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              final delta = details.primaryDelta ?? 0;
              if (isRtl) {
                if (delta > 6) {
                  ref.read(sideDrawerOpenProvider.notifier).state = false;
                }
              } else {
                if (delta < -6) {
                  ref.read(sideDrawerOpenProvider.notifier).state = false;
                }
              }
            },
            onHorizontalDragEnd: (details) {
              final vel = details.primaryVelocity ?? 0;
              if (isRtl) {
                if (vel > 80) {
                  ref.read(sideDrawerOpenProvider.notifier).state = false;
                }
              } else {
                if (vel < -80) {
                  ref.read(sideDrawerOpenProvider.notifier).state = false;
                }
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: Offset(isRtl ? -8 : 8, 0),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: SchoolLogoWidget(
                                  logoUrl: school?.logoUrl,
                                  size: 46,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  (school != null && school.name.isNotEmpty)
                                      ? school.name
                                      : 'Student Portal',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: ArabicTypography.headerStyle(
                                    context,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Divider(
                          height: 1,
                          indent: 22,
                          endIndent: 22,
                          color: Colors.black.withValues(alpha: 0.06),
                        ),
                        const SizedBox(height: 18),
                        _DrawerItem(
                          icon: Icons.person_rounded,
                          label: l10n.monProfil,
                          onTap: () {
                            ref.read(sideDrawerOpenProvider.notifier).state = true;
                            context.go('/profile');
                          },
                        ),
                        const SizedBox(height: 8),
                        _DrawerItem(
                          icon: Icons.settings_rounded,
                          label: l10n.settings,
                          onTap: () {
                            ref.read(sideDrawerOpenProvider.notifier).state = true;
                            context.go('/settings');
                          },
                        ),
                        const SizedBox(height: 8),
                        _DrawerItem(
                          icon: Icons.help_rounded,
                          label: l10n.contactUs,
                          onTap: () {
                            ref.read(sideDrawerOpenProvider.notifier).state = true;
                            context.go('/contact');
                          },
                        ),
                        const SizedBox(height: 8),
                        _DrawerItem(
                          icon: Icons.info_rounded,
                          label: l10n.about,
                          onTap: () {
                            ref.read(sideDrawerOpenProvider.notifier).state = true;
                            context.go('/about');
                          },
                        ),
                        const Spacer(),
                        // White Pill Logout Button with Bounce
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                            26,
                            0,
                            18,
                            math.max(MediaQuery.of(context).padding.bottom, 16.0) + 12,
                          ),
                          child: BouncingWrapper(
                            shrinkScale: 0.94,
                            overshootScale: 1.04,
                            onTap: () async {
                              ref.read(sideDrawerOpenProvider.notifier).state = false;
                              await ref.read(authProvider.notifier).signOut();
                              if (context.mounted) {
                                context.go('/login');
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.logout_rounded,
                                    color: Color(0xFF374151),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    l10n.logout,
                                    style: ArabicTypography.isArabic(context)
                                        ? GoogleFonts.cairo(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF374151),
                                          )
                                        : GoogleFonts.poppins(
                                            fontSize: 15.5,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF374151),
                                            letterSpacing: -0.2,
                                          ),
                                  ),
                                ],
                              ),
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
      ],
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = ArabicTypography.isArabic(context);
    final textStyle = isAr
        ? GoogleFonts.cairo(
            fontSize: 16.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF2D3748),
          )
        : GoogleFonts.poppins(
            fontSize: 16.5,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF2D3748),
            letterSpacing: -0.2,
          );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(26, 6, 16, 6),
      child: BouncingWrapper(
        shrinkScale: 0.95,
        overshootScale: 1.04,
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF2D3748),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: textStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
