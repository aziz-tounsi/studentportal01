import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/enrollment_model.dart';
import '../../../data/models/school_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_bar_provider.dart';
import '../../providers/suggestions_provider.dart';
import '../../providers/school_provider.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/student_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;
  Offset _expandDragOffset = Offset.zero;
  Rect? _cardRect;
  final GlobalKey _cardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    ref.read(navBarHiddenProvider.notifier).state = false;
    _expandCtrl.dispose();
    super.dispose();
  }

  void _expandCard() {
    _captureCardRect();
    setState(() {
      _expanded = true;
      _expandDragOffset = Offset.zero;
    });
    ref.read(navBarHiddenProvider.notifier).state = true;
    _expandCtrl.forward();
  }

  void _dismissExpanded() {
    ref.read(navBarHiddenProvider.notifier).state = false;
    _expandCtrl.reverse().whenComplete(() {
      if (mounted) setState(() => _expanded = false);
    });
  }

  void _captureCardRect() {
    final renderBox = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      _cardRect = null;
      return;
    }
    final origin = renderBox.localToGlobal(Offset.zero);
    _cardRect = origin & renderBox.size;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final enrollment = authState.enrollment;
    final schoolAsync = ref.watch(schoolProvider);
    final school = schoolAsync.valueOrNull;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBody: true,
      drawer: _buildDrawer(context, l10n, ref),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;
          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE8D5F2),
                      Color(0xFFD4C4E8),
                      Color(0xFFC9D6F0),
                      Color(0xFFE0EAF5),
                      Color(0xFFF0F5FA),
                    ],
                    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: -60,
                right: -60,
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(authProvider.notifier).refreshUserData();
                  },
                  color: const Color(0xFF6366F1),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: screenHeight),
                      child: Column(
                        children: [
                          SafeArea(
                            bottom: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 24),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      GestureDetector(
                                        onTap: () =>
                                            Scaffold.of(context).openDrawer(),
                                        child: Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFFF2D78),
                                                Color(0xFFFF5CA0),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(
                                                  0xFFFF2D78,
                                                ).withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.menu_rounded,
                                            color: Colors.white,
                                            size: 26,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: _buildHeader(
                                    context,
                                    ref,
                                    user,
                                    enrollment,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Frosted glass content area with rounded top
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(40),
                              topRight: Radius.circular(40),
                            ),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(40),
                                  topRight: Radius.circular(40),
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 0.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Grid Section
                                  Transform.translate(
                                    offset: const Offset(0, -2),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        0,
                                        24,
                                        0,
                                      ),
                                      child: GridView.count(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 14,
                                        crossAxisSpacing: 14,
                                        childAspectRatio: 0.90,
                                        children: _buildGridCards(
                                          context,
                                          l10n,
                                          ref,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 110),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_expanded && user != null)
                _ExpandedStudentCard(
                  listenable: _expandAnim,
                  user: user,
                  enrollment: enrollment,
                  school: school,
                  dragOffset: _expandDragOffset,
                  originRect: _cardRect,
                  onDismiss: _dismissExpanded,
                  onDragUpdate: (d) => setState(() => _expandDragOffset += d),
                  onDragEnd: () {
                    if (_expandDragOffset.dy.abs() > 80) {
                      _dismissExpanded();
                    } else {
                      setState(() => _expandDragOffset = Offset.zero);
                    }
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    dynamic enrollment,
  ) {
    final schoolAsync = ref.watch(schoolProvider);
    final userModel = user as UserModel?;
    final enrollmentModel = enrollment as EnrollmentModel?;

    if (userModel == null) {
      return const SizedBox.shrink();
    }

    return schoolAsync.when(
      data: (school) => StudentCard(
        key: _cardKey,
        user: userModel,
        enrollment: enrollmentModel,
        school: school,
        onMenuTap: () => Scaffold.of(context).openDrawer(),
        onTap: _expandCard,
      ),
      loading: () => StudentCard(
        key: _cardKey,
        user: userModel,
        enrollment: enrollmentModel,
        school: null,
        onMenuTap: () => Scaffold.of(context).openDrawer(),
        onTap: _expandCard,
      ),
      error: (_, __) => StudentCard(
        key: _cardKey,
        user: userModel,
        enrollment: enrollmentModel,
        school: null,
        onMenuTap: () => Scaffold.of(context).openDrawer(),
        onTap: _expandCard,
      ),
    );
  }

  List<Widget> _buildGridCards(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
    // Get count of suggestions that have been replied or marked as seen
    final suggestionBadgeCount = ref.watch(
      repliedOrSeenSuggestionsCountProvider,
    );

    final cards = [
      _CardData(
        icon: Icons.lightbulb_rounded,
        label: l10n.suggestions,
        subtitle: 'Partagez vos suggestions',
        route: '/suggestions',
        gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
        iconAlignment: Alignment.topLeft,
        badgeCount: suggestionBadgeCount,
      ),
      _CardData(
        icon: Icons.event_busy_rounded,
        label: l10n.absences,
        subtitle: 'Consultez vos absences',
        route: '/absences',
        gradientColors: const [Color(0xFFEC4899), Color(0xFFF43F5E)],
        iconAlignment: Alignment.topLeft,
      ),
      _CardData(
        icon: Icons.bar_chart_rounded,
        label: l10n.resultats,
        subtitle: 'Vérifiez vos résultats',
        route: '/resultats',
        gradientColors: const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
        iconAlignment: Alignment.topLeft,
      ),
      _CardData(
        icon: Icons.calendar_month_rounded,
        label: l10n.emploi,
        subtitle: 'Votre emploi du temps',
        route: '/emploi',
        gradientColors: const [Color(0xFF10B981), Color(0xFF14B8A6)],
        iconAlignment: Alignment.topLeft,
      ),
      _CardData(
        icon: Icons.payment_rounded,
        label: l10n.monSolde,
        subtitle: 'Gérez vos paiements',
        route: '/mon-solde',
        gradientColors: const [Color(0xFFF59E0B), Color(0xFFF97316)],
        iconAlignment: Alignment.topLeft,
      ),
      _CardData(
        icon: Icons.folder_rounded,
        label: l10n.documents,
        subtitle: 'Accédez aux documents',
        route: '/documents',
        gradientColors: const [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
        iconAlignment: Alignment.topLeft,
      ),
    ];

    return cards
        .map(
          (card) => GlassCard(
            icon: card.icon,
            label: card.label,
            subtitle: card.subtitle,
            gradientColors: card.gradientColors,
            iconAlignment: card.iconAlignment,
            badgeCount: card.badgeCount,
            onTap: () => context.go(card.route),
          ),
        )
        .toList();
  }

  Widget _buildDrawer(
    BuildContext context,
    AppLocalizations l10n,
    WidgetRef ref,
  ) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65),
              border: Border(
                right: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  _DrawerItem(
                    icon: Icons.person_rounded,
                    label: 'Mon Profil',
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/profile');
                    },
                  ),
                  const SizedBox(height: 4),
                  _DrawerItem(
                    icon: Icons.settings_rounded,
                    label: l10n.settings,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.contact_support_rounded,
                    label: l10n.contactUs,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/contact');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.info_rounded,
                    label: l10n.about,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/about');
                    },
                  ),
                  const Spacer(),
                  // White Logout Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await ref.read(authProvider.notifier).signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: Colors.grey[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.logout,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
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
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FB),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF374151), size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF374151),
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _CardData {
  final IconData icon;
  final String label;
  final String subtitle;
  final String route;
  final List<Color> gradientColors;
  final Alignment iconAlignment;
  final int? badgeCount;

  _CardData({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.route,
    required this.gradientColors,
    this.iconAlignment = Alignment.topLeft,
    this.badgeCount,
  });
}

class _ExpandedStudentCard extends AnimatedWidget {
  final UserModel user;
  final EnrollmentModel? enrollment;
  final SchoolModel? school;
  final Offset dragOffset;
  final Rect? originRect;
  final VoidCallback onDismiss;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback onDragEnd;

  const _ExpandedStudentCard({
    required super.listenable,
    required this.user,
    this.enrollment,
    this.school,
    required this.dragOffset,
    this.originRect,
    required this.onDismiss,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final progress = _animation.value;
    final dragY = dragOffset.dy;
    final dismissProgress = (dragY.abs() / 250).clamp(0.0, 1.0);
    final currentProgress = (progress - dismissProgress).clamp(0.0, 1.0);
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final baseCardWidth =
        originRect?.width ?? (screenWidth - 48).clamp(1.0, 720.0).toDouble();
    final baseCardHeight = originRect?.height ?? baseCardWidth * (480 / 720);
    final targetScale = (screenWidth / baseCardHeight) * 0.96;
    final scale = lerpDouble(1.0, targetScale, currentProgress) ?? targetScale;
    final rotateZ = lerpDouble(0.0, -math.pi / 2, currentProgress) ?? 0.0;
    final targetCenter = Offset(screenWidth / 2, screenHeight / 2);
    final originCenter = originRect?.center ?? targetCenter;
    final travelOffset = originCenter - targetCenter;
    final slideOffset =
        Offset.lerp(travelOffset, Offset.zero, currentProgress) ?? Offset.zero;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          onPanStart: (_) {},
          onPanUpdate: (d) => onDragUpdate(d.delta),
          onPanEnd: (_) => onDragEnd(),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 18 * progress,
                sigmaY: 18 * progress,
              ),
              child: Container(
                color: Colors.black.withValues(alpha: 0.2 * progress),
              ),
            ),
          ),
        ),
        Center(
          child: Transform.translate(
            offset: Offset(slideOffset.dx, slideOffset.dy + dragY),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateZ(rotateZ)
                ..scale(scale, scale),
              child: SizedBox(
                width: baseCardWidth,
                child: StudentCard(
                  user: user,
                  enrollment: enrollment,
                  school: school,
                  onMenuTap: () {},
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
