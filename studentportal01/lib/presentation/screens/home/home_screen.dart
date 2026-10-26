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
import '../../widgets/student_card_skeleton.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final bool forceDrawerOpen;

  const HomeScreen({super.key, this.forceDrawerOpen = false});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static double _savedScrollOffset = 0.0;
  bool _expanded = false;
  late AnimationController _expandCtrl;
  late Animation<double> _expandAnim;
  late ScrollController _scrollController;
  Offset _expandDragOffset = Offset.zero;
  Rect? _cardRect;
  final GlobalKey _cardKey = GlobalKey();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    final providerOffset = ref.read(homeScrollOffsetProvider);
    final initialOffset = providerOffset > 0 ? providerOffset : _savedScrollOffset;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
    _scrollController.addListener(() {
      if (!ref.read(sideDrawerOpenProvider) && _scrollController.hasClients) {
        final currentOffset = _scrollController.offset;
        if (currentOffset > 0 ||
            (_scrollController.position.haveDimensions &&
                _scrollController.position.isScrollingNotifier.value)) {
          _savedScrollOffset = currentOffset;
          ref.read(homeScrollOffsetProvider.notifier).state = currentOffset;
        }
      }
    });

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

  void _openDrawer() {
    ref.read(sideDrawerOpenProvider.notifier).state = true;
  }

  @override
  void dispose() {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _savedScrollOffset = _scrollController.offset;
      ref.read(homeScrollOffsetProvider.notifier).state =
          _scrollController.offset;
    }
    _scrollController.dispose();
    _expandCtrl.dispose();
    super.dispose();
  }

  void _expandCard() {
    _captureCardRect();
    setState(() {
      _expanded = true;
      _expandDragOffset = Offset.zero;
    });
    ref.read(studentCardExpandedProvider.notifier).state = true;
    _expandCtrl.forward();
  }

  void _dismissExpanded() {
    ref.read(studentCardExpandedProvider.notifier).state = false;
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
    super.build(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final enrollment = authState.enrollment;
    final schoolAsync = ref.watch(schoolProvider);
    final school = schoolAsync.valueOrNull;
    final l10n = AppLocalizations.of(context);

    return RepaintBoundary(
      child: Scaffold(
        extendBody: true,
        body: LayoutBuilder(
        builder: (context, constraints) {
          final isDrawerOpen = ref.watch(sideDrawerOpenProvider);
          final screenHeight = constraints.maxHeight;
          final screenWidth = constraints.maxWidth;
          final safeTop = MediaQuery.of(context).padding.top;

          // Calculate student card dimensions to obtain precise layout heights
          final baseCardWidth =
              (screenWidth - 48).clamp(1.0, 720.0).toDouble();
          final baseCardHeight = baseCardWidth * (480 / 720);

          // Menu button vertical offset: 24 (top) + 48 (icon height) + 32 (spacing)
          final cardTopPosition = safeTop + 104;
          final cardAreaHeight = baseCardHeight + 24;

          final bodyStack = Stack(
            children: [
              // 1. Background Gradient
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

              // 2. Ambient Blurred Orb
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

              // 3. Receding Payment Card Layer (Behind scrolling content)
              Positioned(
                top: cardTopPosition,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, child) {
                    final double rawOffset = _scrollController.hasClients
                        ? _scrollController.offset
                        : _scrollController.initialScrollOffset;

                    final double maxExtent =
                        (baseCardHeight + 50.0).clamp(240.0, 360.0);
                    final double overscroll =
                        rawOffset < 0 ? -rawOffset : 0.0;
                    final double progress =
                        (rawOffset / maxExtent).clamp(0.0, 1.0);

                    // 3.1 Scale: shrinks smoothly down to 0.84 or expands on overscroll
                    final double scale = rawOffset < 0
                        ? (1.0 + (overscroll / 650.0)).clamp(1.0, 1.15)
                        : (1.0 - (0.16 * progress));

                    // 3.2 Opacity: stays highly visible through middle of scroll, fading to 0.0 only when fully covered
                    final double opacity = rawOffset < 0
                        ? 1.0
                        : (1.0 - math.pow(progress, 2.5)).clamp(0.0, 1.0).toDouble();

                    // 3.3 Blur: gradually blurs up to 8.0 sigma as card recedes
                    final double blurSigma =
                        (8.0 * math.pow(progress, 1.8)).clamp(0.0, 8.0).toDouble();

                    // 3.4 Parallax translation: moves deeper into background space
                    final double translateY =
                        rawOffset < 0 ? 0.0 : -rawOffset * 0.30;

                    // 3.5 3D Tilt perspective: thrown backward top-first
                    final double rotateX =
                        rawOffset < 0 ? 0.0 : -0.12 * progress;

                    Widget cardContent = child!;

                    if (blurSigma > 0.3) {
                      cardContent = ImageFiltered(
                        imageFilter: ImageFilter.blur(
                          sigmaX: blurSigma,
                          sigmaY: blurSigma,
                        ),
                        child: cardContent,
                      );
                    }

                    return Transform(
                      alignment: Alignment.topCenter,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..translateByDouble(0.0, translateY, 0.0, 1.0)
                        ..scaleByDouble(scale, scale, 1.0, 1.0)
                        ..rotateX(rotateX),
                      child: Opacity(
                        opacity: opacity,
                        child: cardContent,
                      ),
                    );
                  },
                  child: _buildHeader(
                    context,
                    ref,
                    user,
                    enrollment,
                  ),
                ),
              ),

              // 4. Scrollable Foreground Layer (Feature Cards section sliding OVER payment card)
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(authProvider.notifier).refreshUserData();
                  },
                  color: const Color(0xFFFF2D78),
                  backgroundColor: Colors.white,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: isDrawerOpen
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: screenHeight),
                      child: Column(
                        children: [
                          SizedBox(height: cardTopPosition),

                          // Transparent tap target area for the card to restore full screen expansion tap
                          GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _expandCard,
                            child: SizedBox(
                              width: double.infinity,
                              height: cardAreaHeight,
                            ),
                          ),

                          // Frosted glass content area sliding over payment card
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(40),
                              topRight: Radius.circular(40),
                            ),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(40),
                                  topRight: Radius.circular(40),
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 0.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 24),
                                  // Grid Section
                                  Transform.translate(
                                    offset: const Offset(0, -2),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24,
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
                                  const SizedBox(height: 130),
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

              // 5. Pinned Menu Button Row (Top Layer)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _openDrawer,
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

          final isRtl = Directionality.of(context) == TextDirection.rtl;

          return Container(
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
            child: AnimatedScale(
              scale: isDrawerOpen ? 0.93 : 1.0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              alignment: isRtl ? Alignment.centerLeft : Alignment.centerRight,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(isDrawerOpen ? 24.0 : 0.0),
                  boxShadow: isDrawerOpen
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: isDrawerOpen ? 10.0 : 0.0,
                    sigmaY: isDrawerOpen ? 10.0 : 0.0,
                  ),
                  child: IgnorePointer(
                    ignoring: isDrawerOpen,
                    child: bodyStack,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    dynamic enrollment,
  ) {
    final authState = ref.watch(authProvider);
    final schoolAsync = ref.watch(schoolProvider);
    final userModel = user as UserModel?;
    final enrollmentModel = enrollment as EnrollmentModel?;

    if (authState.isLoading || userModel == null) {
      return const StudentCardSkeleton();
    }

    return schoolAsync.when(
      data: (school) => StudentCard(
        key: _cardKey,
        user: userModel,
        enrollment: enrollmentModel,
        school: school,
        onMenuTap: _openDrawer,
        onTap: _expandCard,
      ),
      loading: () => StudentCard(
        key: _cardKey,
        user: userModel,
        enrollment: enrollmentModel,
        school: null,
        onMenuTap: _openDrawer,
        onTap: _expandCard,
      ),
      error: (_, _) => StudentCard(
        key: _cardKey,
        user: userModel,
        enrollment: enrollmentModel,
        school: null,
        onMenuTap: _openDrawer,
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
        subtitle: l10n.homeSubtitleSuggestions,
        route: '/suggestions',
        gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6366F1)],
        iconAlignment: Alignment.topLeft,
        badgeCount: suggestionBadgeCount,
      ),
      _CardData(
        icon: Icons.event_busy_rounded,
        label: l10n.absences,
        subtitle: l10n.homeSubtitleAbsences,
        route: '/absences',
        gradientColors: const [Color(0xFFEC4899), Color(0xFFF43F5E)],
        iconAlignment: Alignment.topLeft,
      ),
      _CardData(
        icon: Icons.bar_chart_rounded,
        label: l10n.resultats,
        subtitle: l10n.homeSubtitleResults,
        route: '/resultats',
        gradientColors: const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
        iconAlignment: Alignment.topLeft,
      ),
      _CardData(
        icon: Icons.calendar_month_rounded,
        label: l10n.emploi,
        subtitle: l10n.homeSubtitleTimetable,
        route: '/emploi',
        gradientColors: const [Color(0xFF10B981), Color(0xFF14B8A6)],
        iconAlignment: Alignment.topLeft,
      ),
      _CardData(
        icon: Icons.payment_rounded,
        label: l10n.monSolde,
        subtitle: l10n.homeSubtitleSolde,
        route: '/mon-solde',
        gradientColors: const [Color(0xFFF59E0B), Color(0xFFF97316)],
        iconAlignment: Alignment.topLeft,
      ),
      _CardData(
        icon: Icons.folder_rounded,
        label: l10n.documents,
        subtitle: l10n.homeSubtitleDocuments,
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
            onTap: () {
              if (_scrollController.hasClients && _scrollController.offset > 0) {
                _savedScrollOffset = _scrollController.offset;
                ref.read(homeScrollOffsetProvider.notifier).state =
                    _scrollController.offset;
              }
              context.go(card.route);
            },
          ),
        )
        .toList();
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
                ..scaleByDouble(scale, scale, 1.0, 1.0),
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
