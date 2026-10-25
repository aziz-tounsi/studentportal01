import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Wraps a page with native iOS-style interactive edge-swipe-to-return gesture.
///
/// In LTR (Latin: English, French): sliding from the left edge towards right pops the page.
/// In RTL (Arabic): sliding from the right edge towards left pops the page.
class IosEdgeSwipeBack extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReturn;
  final double edgeThreshold;

  const IosEdgeSwipeBack({
    super.key,
    required this.child,
    this.onReturn,
    this.edgeThreshold = 38.0,
  });

  @override
  State<IosEdgeSwipeBack> createState() => _IosEdgeSwipeBackState();
}

class _IosEdgeSwipeBackState extends State<IosEdgeSwipeBack>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _progressAnim;

  double _progress = 0.0;
  bool _isEdgeTouch = false;
  bool _isDragging = false;

  double _startX = 0.0;
  double _startY = 0.0;
  double _lastX = 0.0;
  int _lastTime = 0;
  double _velocity = 0.0; // px / ms

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
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

  void _onPointerDown(PointerDownEvent ev, bool isRtl, double screenWidth) {
    if (_animCtrl.isAnimating) return;

    final x = ev.position.dx;
    final isEdge = isRtl
        ? (x >= screenWidth - widget.edgeThreshold)
        : (x <= widget.edgeThreshold);

    if (isEdge) {
      _isEdgeTouch = true;
      _isDragging = false;
      _startX = x;
      _startY = ev.position.dy;
      _lastX = x;
      _lastTime = DateTime.now().millisecondsSinceEpoch;
      _velocity = 0.0;
      _progress = 0.0;
    } else {
      _isEdgeTouch = false;
    }
  }

  void _onPointerMove(PointerMoveEvent ev, bool isRtl, double screenWidth) {
    if (!_isEdgeTouch) return;

    final currentX = ev.position.dx;
    final currentY = ev.position.dy;

    final now = DateTime.now().millisecondsSinceEpoch;
    final dt = now - _lastTime;
    if (dt > 0) {
      _velocity = (currentX - _lastX) / dt;
    }
    _lastX = currentX;
    _lastTime = now;

    final dx = currentX - _startX;
    final dy = (currentY - _startY).abs();

    if (!_isDragging) {
      // If predominantly vertical movement, ignore as normal page scrolling
      if (dy > dx.abs() && dy > 8) {
        _isEdgeTouch = false;
        return;
      }

      // Check if moving in valid return direction
      final isValidDirection = isRtl ? (dx < -6) : (dx > 6);
      if (isValidDirection) {
        _isDragging = true;
      }
    }

    if (_isDragging) {
      final dragDist = isRtl ? (_startX - currentX) : (currentX - _startX);
      setState(() {
        _progress = (dragDist / screenWidth).clamp(0.0, 1.0);
      });
    }
  }

  void _onPointerUp(PointerUpEvent ev, bool isRtl) {
    if (!_isEdgeTouch) return;
    _isEdgeTouch = false;

    if (!_isDragging) return;
    _isDragging = false;

    // Check if threshold or velocity passed
    final passedDist = _progress >= 0.25;
    final flicked = isRtl ? (_velocity < -0.28) : (_velocity > 0.28);

    if (passedDist || flicked) {
      // Animate remaining distance to complete return
      _progressAnim = Tween<double>(begin: _progress, end: 1.0).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutQuad),
      );
      _animCtrl.forward(from: 0.0).then((_) {
        _executeReturn();
      });
    } else {
      // Snap back to 0 (cancel return)
      _progressAnim = Tween<double>(begin: _progress, end: 0.0).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutQuad),
      );
      _animCtrl.forward(from: 0.0);
    }
  }

  void _onPointerCancel(PointerCancelEvent ev) {
    if (_isDragging) {
      _isDragging = false;
      _isEdgeTouch = false;
      _progressAnim = Tween<double>(begin: _progress, end: 0.0).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutQuad),
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

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (ev) => _onPointerDown(ev, isRtl, screenWidth),
      onPointerMove: (ev) => _onPointerMove(ev, isRtl, screenWidth),
      onPointerUp: (ev) => _onPointerUp(ev, isRtl),
      onPointerCancel: _onPointerCancel,
      child: Stack(
        children: [
          // Background dimming scrim that fades out as the page slides away
          if (_progress > 0.0)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(
                  alpha: 0.16 * (1.0 - _progress),
                ),
              ),
            ),
          // Interactive sliding page with iOS-style edge drop shadow
          Transform.translate(
            offset: Offset(
              isRtl ? -(_progress * screenWidth) : (_progress * screenWidth),
              0,
            ),
            child: Container(
              decoration: _progress > 0.0
                  ? BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.18 * (1.0 - _progress),
                          ),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: Offset(isRtl ? 8 : -8, 0),
                        ),
                      ],
                    )
                  : null,
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
