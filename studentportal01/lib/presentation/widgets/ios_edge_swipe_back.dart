import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';

/// Wraps a page with native iOS-style interactive edge-swipe-to-return gesture.
///
/// In LTR (Latin: English, French): sliding from the left edge towards right pops the page.
/// In RTL (Arabic): sliding from the right edge towards left pops the page.
///
/// The gesture is strictly locked to the horizontal axis so that vertical scrolling
/// cannot occur simultaneously. While dragging, the destination bottom page is
/// displayed underneath with an iOS frosted glass blur, starts slightly zoomed out,
/// zooms in smoothly as you slide, and does a subtle micro-bounce as it surfaces to the top.
class IosEdgeSwipeBack extends StatefulWidget {
  final Widget child;
  final Widget? backgroundPage;
  final VoidCallback? onReturn;
  final double edgeThreshold;
  final Gradient? backgroundGradient;
  final bool Function()? onInterceptSwipe;

  const IosEdgeSwipeBack({
    super.key,
    required this.child,
    this.backgroundPage,
    this.onReturn,
    this.edgeThreshold = 44.0,
    this.backgroundGradient,
    this.onInterceptSwipe,
  });

  /// Tracks whether an edge swipe back gesture was performed to return to Home.
  static bool didEdgeSwipe = false;

  static IosEdgeSwipeBackState? of(BuildContext context) {
    return context.findAncestorStateOfType<IosEdgeSwipeBackState>();
  }

  @override
  State<IosEdgeSwipeBack> createState() => IosEdgeSwipeBackState();
}

class IosEdgeSwipeBackState extends State<IosEdgeSwipeBack>
    with SingleTickerProviderStateMixin {
  /// Reference to the currently visible IosEdgeSwipeBackState
  static IosEdgeSwipeBackState? currentActive;

  late AnimationController _animCtrl;
  late Animation<double> _progressAnim;

  double _progress = 0.0;
  bool _isDragging = false;

  double _startX = 0.0;
  double _lastX = 0.0;
  int _lastTime = 0;
  double _velocity = 0.0; // px / ms

  @override
  void initState() {
    super.initState();
    currentActive = this;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animCtrl.addListener(() {
      setState(() {
        _progress = _progressAnim.value;
      });
    });
  }

  @override
  void didUpdateWidget(IosEdgeSwipeBack oldWidget) {
    super.didUpdateWidget(oldWidget);
    currentActive = this;
  }

  @override
  void dispose() {
    if (currentActive == this) {
      currentActive = null;
    }
    _animCtrl.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details, bool isRtl, double screenWidth) {
    if (_animCtrl.isAnimating) return;
    if (widget.onInterceptSwipe != null && widget.onInterceptSwipe!()) {
      return;
    }
    _startX = details.globalPosition.dx;
    _lastX = _startX;
    _lastTime = DateTime.now().millisecondsSinceEpoch;
    _velocity = 0.0;
    _isDragging = true;
    _progress = 0.0;
    setState(() {});
  }

  void _onDragUpdate(DragUpdateDetails details, bool isRtl, double screenWidth) {
    if (!_isDragging) return;
    final currentX = details.globalPosition.dx;
    final now = DateTime.now().millisecondsSinceEpoch;
    final dt = now - _lastTime;
    if (dt > 0) {
      _velocity = (currentX - _lastX) / dt;
    }
    _lastX = currentX;
    _lastTime = now;

    // In LTR: drag from left towards right (currentX - _startX)
    // In RTL: drag from right towards left (_startX - currentX)
    final dragDist = isRtl ? (_startX - currentX) : (currentX - _startX);
    setState(() {
      _progress = (dragDist / screenWidth).clamp(0.0, 1.0);
    });
  }

  void _onDragEnd(DragEndDetails details, bool isRtl) {
    if (!_isDragging) return;
    _isDragging = false;

    final primaryVel = details.primaryVelocity ?? 0.0;
    final flicked = isRtl
        ? (primaryVel < -280 || _velocity < -0.28)
        : (primaryVel > 280 || _velocity > 0.28);
    final passedDist = _progress >= 0.22;

    if (passedDist || flicked) {
      // Animate slide completion and execute return
      _progressAnim = Tween<double>(begin: _progress, end: 1.0).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
      );
      _animCtrl.forward(from: 0.0).then((_) {
        _executeReturn();
      });
    } else {
      // Snap back to closed state
      _progressAnim = Tween<double>(begin: _progress, end: 0.0).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
      );
      _animCtrl.forward(from: 0.0);
    }
  }

  void _onDragCancel() {
    if (_isDragging) {
      _isDragging = false;
      _progressAnim = Tween<double>(begin: _progress, end: 0.0).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
      );
      _animCtrl.forward(from: 0.0);
    }
  }

  void animateBack() {
    if (_animCtrl.isAnimating) return;
    _progressAnim = Tween<double>(begin: _progress, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl.forward(from: 0.0).then((_) {
      _executeReturn();
    });
  }

  void _executeReturn() {
    if (!mounted) return;
    IosEdgeSwipeBack.didEdgeSwipe = true;
    if (widget.onReturn != null) {
      widget.onReturn!();
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final screenWidth = MediaQuery.of(context).size.width;

    // Zoomed out slightly at start (0.92), zooms smoothly to 1.0 as progress reaches 1.0
    final double underPageScale = 0.92 + (0.08 * _progress);

    const defaultHomeGradient = LinearGradient(
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
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. App background gradient layer: fills the outer margin around the zoomed-out underpage
        // completely eliminating any black/grey edge areas during swipe gesture
        if (_progress > 0.0) ...[
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: widget.backgroundGradient ?? defaultHomeGradient,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.scale(
                scale: underPageScale,
                alignment: Alignment.center,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: (14.0 * (1.0 - (_progress * 0.75))).clamp(0.0, 14.0),
                    sigmaY: (14.0 * (1.0 - (_progress * 0.75))).clamp(0.0, 14.0),
                  ),
                  child: widget.backgroundPage ?? const HomeScreen(),
                ),
              ),
            ),
          ),
        ],

        // 2. Sliding top page strictly translated on X axis
        Transform.translate(
          offset: Offset(
            isRtl ? -(_progress * screenWidth) : (_progress * screenWidth),
            0.0,
          ),
          child: Container(
            decoration: _progress > 0.0
                ? BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: 0.18 * (1.0 - _progress),
                        ),
                        blurRadius: 28,
                        spreadRadius: 2,
                        offset: Offset(isRtl ? 10 : -10, 0),
                      ),
                    ],
                  )
                : null,
            child: IgnorePointer(
              ignoring: _isDragging || _animCtrl.isAnimating,
              child: widget.child,
            ),
          ),
        ),

        // 3. Edge Swipe Detector Strip (consumes touches on the edge to prevent vertical/child gesture conflicts)
        Positioned(
          top: MediaQuery.of(context).padding.top + 80,
          bottom: 0,
          left: isRtl ? null : 0,
          right: isRtl ? 0 : null,
          width: _isDragging ? screenWidth : widget.edgeThreshold,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (details) =>
                _onDragStart(details, isRtl, screenWidth),
            onHorizontalDragUpdate: (details) =>
                _onDragUpdate(details, isRtl, screenWidth),
            onHorizontalDragEnd: (details) => _onDragEnd(details, isRtl),
            onHorizontalDragCancel: _onDragCancel,
          ),
        ),
      ],
    );
  }
}
