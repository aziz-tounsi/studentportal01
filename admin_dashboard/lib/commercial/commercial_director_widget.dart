import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class ShowcaseWaypoint {
  final String title;
  final String subtitle;
  final String route;
  final Offset cursorPositionFraction; // 0.0 to 1.0 relative to window size
  final Duration travelDuration;
  final Duration dwellDuration;
  final bool triggerClick;

  const ShowcaseWaypoint({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.cursorPositionFraction,
    required this.travelDuration,
    required this.dwellDuration,
    this.triggerClick = true,
  });
}

class AdminCommercialDirectorWidget extends StatefulWidget {
  final Widget child;
  final GoRouter router;

  const AdminCommercialDirectorWidget({
    super.key,
    required this.child,
    required this.router,
  });

  @override
  State<AdminCommercialDirectorWidget> createState() =>
      _AdminCommercialDirectorWidgetState();
}

class _AdminCommercialDirectorWidgetState
    extends State<AdminCommercialDirectorWidget> with TickerProviderStateMixin {
  late final List<ShowcaseWaypoint> _waypoints;

  late final AnimationController _moveController;
  late final AnimationController _clickController;

  late Animation<Offset> _positionAnimation;
  late Animation<double> _clickRippleAnimation;
  late Animation<double> _clickScaleAnimation;

  Offset _currentCursorPos = const Offset(600, 400);
  Offset _previousCursorPos = const Offset(600, 400);

  int _currentWaypointIndex = 0;
  bool _isPlaying = true;
  bool _autoPilotEnabled = true;
  bool _hideHud = false;
  double _playbackSpeed = 1.0;
  Timer? _dwellTimer;

  @override
  void initState() {
    super.initState();

    _waypoints = [
      // 1. Dashboard Overview & Real-Time Cashflow
      const ShowcaseWaypoint(
        title: 'Scene 1: Tableau de Bord Établissement & KPIs',
        subtitle: '580 élèves • 35 professeurs • 98.4% assiduité • 458K TND recouvrés',
        route: '/dashboard',
        cursorPositionFraction: Offset(0.45, 0.22),
        travelDuration: Duration(milliseconds: 1400),
        dwellDuration: Duration(milliseconds: 3000),
        triggerClick: true,
      ),
      // 2. Users & Student Directory
      const ShowcaseWaypoint(
        title: 'Scene 2: Gestion des Élèves & Effectifs',
        subtitle: 'Annuaire unifié, badges élèves, imports Excel en 1 clic',
        route: '/users',
        cursorPositionFraction: Offset(0.08, 0.28),
        travelDuration: Duration(milliseconds: 1200),
        dwellDuration: Duration(milliseconds: 2800),
        triggerClick: true,
      ),
      // 3. Classes & Sections
      const ShowcaseWaypoint(
        title: 'Scene 3: Structure Académique & Classes',
        subtitle: 'Classes pilotes, filières scientifiques, effectifs en temps réel',
        route: '/classes',
        cursorPositionFraction: Offset(0.08, 0.42),
        travelDuration: Duration(milliseconds: 1200),
        dwellDuration: Duration(milliseconds: 2800),
        triggerClick: true,
      ),
      // 4. Timetables / Emplois du Temps
      const ShowcaseWaypoint(
        title: 'Scene 4: Emplois du Temps Intelligents',
        subtitle: 'Planning interactif des salles, professeurs et cours en direct',
        route: '/timetables',
        cursorPositionFraction: Offset(0.08, 0.48),
        travelDuration: Duration(milliseconds: 1200),
        dwellDuration: Duration(milliseconds: 2800),
        triggerClick: true,
      ),
      // 5. Results & Bulletins Scolaires
      const ShowcaseWaypoint(
        title: 'Scene 5: Bulletins, Moyennes & Examens',
        subtitle: 'Calcul automatisé des rangs, moyennes et quittances d\'examen',
        route: '/results',
        cursorPositionFraction: Offset(0.08, 0.58),
        travelDuration: Duration(milliseconds: 1200),
        dwellDuration: Duration(milliseconds: 3000),
        triggerClick: true,
      ),
      // 6. Payments & Tuition Recovery
      const ShowcaseWaypoint(
        title: 'Scene 6: Règlements & Recouvrement Financier',
        subtitle: 'Suivi des échéances scolaires, 92.9% de taux de recouvrement',
        route: '/payments',
        cursorPositionFraction: Offset(0.08, 0.68),
        travelDuration: Duration(milliseconds: 1200),
        dwellDuration: Duration(milliseconds: 3000),
        triggerClick: true,
      ),
      // 7. Return to Command Center
      const ShowcaseWaypoint(
        title: 'Scene 7: Pythagore — L\'Établissement du Futur',
        subtitle: 'La solution scolaire tout-en-un nouvelle génération',
        route: '/dashboard',
        cursorPositionFraction: Offset(0.08, 0.22),
        travelDuration: Duration(milliseconds: 1300),
        dwellDuration: Duration(milliseconds: 3500),
        triggerClick: true,
      ),
    ];

    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _clickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _clickRippleAnimation = Tween<double>(begin: 0.0, end: 48.0).animate(
      CurvedAnimation(parent: _clickController, curve: Curves.easeOutCubic),
    );

    _clickScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 70),
    ]).animate(_clickController);

    _positionAnimation = Tween<Offset>(
      begin: _currentCursorPos,
      end: _currentCursorPos,
    ).animate(_moveController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startWaypointSequence();
    });
  }

  void _startWaypointSequence() {
    if (!mounted || !_autoPilotEnabled || !_isPlaying) return;

    final wp = _waypoints[_currentWaypointIndex];
    final size = MediaQuery.of(context).size;
    final targetPos = Offset(
      wp.cursorPositionFraction.dx * size.width,
      wp.cursorPositionFraction.dy * size.height,
    );

    _previousCursorPos = _currentCursorPos;
    _positionAnimation = Tween<Offset>(
      begin: _previousCursorPos,
      end: targetPos,
    ).animate(
      CurvedAnimation(parent: _moveController, curve: Curves.easeInOutCubic),
    );

    final moveMs = (wp.travelDuration.inMilliseconds / _playbackSpeed).round();
    _moveController.duration = Duration(milliseconds: moveMs);

    _moveController.forward(from: 0.0).then((_) {
      if (!mounted || !_isPlaying || !_autoPilotEnabled) return;
      _currentCursorPos = targetPos;

      if (wp.triggerClick) {
        _clickController.forward(from: 0.0);
        widget.router.go(wp.route);
      }

      final dwellMs =
          (wp.dwellDuration.inMilliseconds / _playbackSpeed).round();
      _dwellTimer = Timer(Duration(milliseconds: dwellMs), () {
        if (!mounted || !_isPlaying || !_autoPilotEnabled) return;
        setState(() {
          _currentWaypointIndex =
              (_currentWaypointIndex + 1) % _waypoints.length;
        });
        _startWaypointSequence();
      });
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (!_isPlaying) {
        _moveController.stop();
        _dwellTimer?.cancel();
      } else {
        _startWaypointSequence();
      }
    });
  }

  void _resetSequence() {
    _dwellTimer?.cancel();
    _moveController.stop();
    setState(() {
      _currentWaypointIndex = 0;
      _isPlaying = true;
    });
    widget.router.go('/dashboard');
    _startWaypointSequence();
  }

  void _toggleAutoPilot() {
    setState(() {
      _autoPilotEnabled = !_autoPilotEnabled;
      if (!_autoPilotEnabled) {
        _dwellTimer?.cancel();
        _moveController.stop();
      } else {
        _isPlaying = true;
        _startWaypointSequence();
      }
    });
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _moveController.dispose();
    _clickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeWaypoint = _waypoints[_currentWaypointIndex];

    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.space) {
              _togglePlayPause();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyH) {
              setState(() => _hideHud = !_hideHud);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
              _resetSequence();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Stack(
          children: [
            widget.child,

            if (_autoPilotEnabled)
              AnimatedBuilder(
                animation: Listenable.merge([_moveController, _clickController]),
                builder: (context, _) {
                  final pos = _positionAnimation.value;
                  final rippleRadius = _clickRippleAnimation.value;
                  final rippleOpacity = (1.0 - _clickController.value).clamp(0.0, 1.0);
                  final cursorScale = _clickScaleAnimation.value;

                  return Positioned(
                    left: pos.dx - 24,
                    top: pos.dy - 24,
                    child: IgnorePointer(
                      child: SizedBox(
                        width: 96,
                        height: 96,
                        child: Stack(
                          alignment: Alignment.topLeft,
                          children: [
                            if (_clickController.isAnimating)
                              Positioned(
                                left: 24 - rippleRadius,
                                top: 24 - rippleRadius,
                                child: Container(
                                  width: rippleRadius * 2,
                                  height: rippleRadius * 2,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF6D4CF6).withValues(alpha: rippleOpacity * 0.9),
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF2563EB).withValues(alpha: rippleOpacity * 0.6),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            Positioned(
                              left: 20,
                              top: 20,
                              child: Transform.scale(
                                scale: cursorScale,
                                origin: const Offset(4, 4),
                                child: Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6D4CF6).withValues(alpha: 0.5),
                                        blurRadius: 16,
                                        spreadRadius: 1,
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(2, 4),
                                      ),
                                    ],
                                  ),
                                  child: CustomPaint(
                                    size: const Size(22, 28),
                                    painter: _AppleCursorPainter(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            if (!_hideHud)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070B14).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: const Color(0xFF6D4CF6).withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6D4CF6).withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.6),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _autoPilotEnabled && _isPlaying
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            boxShadow: [
                              BoxShadow(
                                color: (_autoPilotEnabled && _isPlaying
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B))
                                    .withValues(alpha: 0.8),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  activeWaypoint.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_currentWaypointIndex + 1}/${_waypoints.length}',
                                    style: const TextStyle(
                                      color: Color(0xFF93C5FD),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeWaypoint.subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 24),
                        Container(
                          width: 1,
                          height: 28,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                        const SizedBox(width: 16),

                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Pause / Reprendre (Espace)',
                          onPressed: _togglePlayPause,
                        ),

                        IconButton(
                          icon: const Icon(
                            Icons.replay_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                          tooltip: 'Redémarrer Scène 1 (R)',
                          onPressed: _resetSequence,
                        ),

                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            setState(() {
                              if (_playbackSpeed == 1.0) {
                                _playbackSpeed = 0.75;
                              } else if (_playbackSpeed == 0.75) {
                                _playbackSpeed = 1.25;
                              } else {
                                _playbackSpeed = 1.0;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_playbackSpeed}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _toggleAutoPilot,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _autoPilotEnabled
                                  ? const Color(0xFF6D4CF6).withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.08),
                              border: Border.all(
                                color: _autoPilotEnabled
                                    ? const Color(0xFF6D4CF6)
                                    : Colors.transparent,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _autoPilotEnabled ? 'Auto-Pilot: ON' : 'Mode Manuel',
                              style: TextStyle(
                                color: _autoPilotEnabled
                                    ? const Color(0xFFA78BFA)
                                    : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        IconButton(
                          icon: const Icon(
                            Icons.visibility_off_outlined,
                            color: Colors.white54,
                            size: 16,
                          ),
                          tooltip: 'Masquer l\'HUD pour enregistrement 4K (H)',
                          onPressed: () => setState(() => _hideHud = true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_hideHud)
              Positioned(
                top: 12,
                right: 12,
                child: InkWell(
                  onTap: () => setState(() => _hideHud = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Text(
                      'Appuyer sur H pour afficher l\'HUD',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppleCursorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, 22)
      ..lineTo(5.5, 17)
      ..lineTo(10, 26)
      ..lineTo(13.5, 24.5)
      ..lineTo(9, 15.5)
      ..lineTo(16, 15.5)
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
