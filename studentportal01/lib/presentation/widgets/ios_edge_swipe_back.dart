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

  const IosEdgeSwipeBack({
    super.key,
    required this.child,
    this.backgroundPage,
    this.onReturn,
    this.edgeThreshold = 36.0,
  });

  @override
  State<IosEdgeSwipeBack> createState() => _IosEdgeSwipeBackState();
}

class _IosEdgeSwipeBackState extends State<IosEdgeSwipeBack>
    with SingleTickerProviderStateMixin {
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
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details, bool isRtl, double screenWidth) {
    if (_animCtrl.isAnimating) return;
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

  void _executeReturn() {
    if (!mounted) return;
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Blurred bottom destination page underneath (visible during swipe animation)
        if (_progress > 0.0) ...[
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.scale(
                scale: underPageScale,
                alignment: Alignment.center,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: (16.0 * (1.0 - (_progress * 0.75))).clamp(0.0, 16.0),
                    sigmaY: (16.0 * (1.0 - (_progress * 0.75))).clamp(0.0, 16.0),
                  ),
                  child: widget.backgroundPage ?? const HomeScreen(),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(
                alpha: (0.12 * (1.0 - _progress)).clamp(0.0, 1.0),
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
                          alpha: 0.22 * (1.0 - _progress),
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

        // 3. Edge Swipe Detector Strip (consumes touches on the edge to prevent vertical scroll)
        Positioned(
          top: 0,
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
