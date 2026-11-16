import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home/home_screen.dart';

/// Wraps a page with native iOS-style interactive edge-swipe-to-return gesture,
/// fluid card expansion from HomeScreen, and bouncing zoom-out with flight blur
/// when closing back to Home.
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

  /// Holds the origin Rect of the tapped card from HomeScreen for expansion/closing.
  static Rect? cardOriginRect;

  /// Flag indicating whether the page should animate an expand on entry.
  static bool shouldAnimateExpand = false;

  static IosEdgeSwipeBackState? of(BuildContext context) {
    return context.findAncestorStateOfType<IosEdgeSwipeBackState>();
  }

  @override
  State<IosEdgeSwipeBack> createState() => IosEdgeSwipeBackState();
}

class IosEdgeSwipeBackState extends State<IosEdgeSwipeBack>
    with TickerProviderStateMixin {
  /// Reference to the currently visible IosEdgeSwipeBackState
  static IosEdgeSwipeBackState? currentActive;

  // 1. Edge-swipe interactive gesture controller
  late AnimationController _animCtrl;
  late Animation<double> _progressAnim;

  double _progress = 0.0;
  bool _isDragging = false;

  double _startX = 0.0;
  double _lastX = 0.0;
  int _lastTime = 0;
  double _velocity = 0.0; // px / ms

  // 2. Expand entry animation controller
  AnimationController? _expandCtrl;
  Animation<double>? _expandAnim;
  bool _isExpanding = false;

  // 3. Zoom-out exit animation controller (for closing to Home)
  AnimationController? _zoomOutCtrl;
  Animation<double>? _zoomOutAnim;
  bool _isZoomingOut = false;

  Rect? _originRect;

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

    if (IosEdgeSwipeBack.shouldAnimateExpand && IosEdgeSwipeBack.cardOriginRect != null) {
      _originRect = IosEdgeSwipeBack.cardOriginRect;
      IosEdgeSwipeBack.shouldAnimateExpand = false;
      _isExpanding = true;

      _expandCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 290),
      );
      _expandAnim = CurvedAnimation(
        parent: _expandCtrl!,
        curve: const Cubic(0.20, 0.90, 0.25, 1.0),
      );
      _expandCtrl!.addListener(() {
        setState(() {});
      });
      _expandCtrl!.forward().then((_) {
        if (mounted) {
          setState(() {
            _isExpanding = false;
          });
        }
      });
    } else {
      _originRect = IosEdgeSwipeBack.cardOriginRect;
    }
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
    _expandCtrl?.dispose();
    _zoomOutCtrl?.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details, bool isRtl, double screenWidth) {
    if (_animCtrl.isAnimating || _isExpanding || _isZoomingOut) return;
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
      _progressAnim = Tween<double>(begin: _progress, end: 1.0).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
      );
      _animCtrl.forward(from: 0.0).then((_) {
        _executeReturn();
      });
    } else {
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

  /// Closes the page with smooth side sliding animation
  void animateSlideBack() {
    if (_animCtrl.isAnimating || (_zoomOutCtrl != null && _zoomOutCtrl!.isAnimating)) return;
    _progressAnim = Tween<double>(begin: _progress, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl.forward(from: 0.0).then((_) {
      _executeReturn();
    });
  }

  /// Closes the page with pop bouncing zoom-out and flight blur in the middle of the distance.
  void animateZoomOutBack() {
    if ((_zoomOutCtrl != null && _zoomOutCtrl!.isAnimating) || _animCtrl.isAnimating) return;

    _zoomOutCtrl?.dispose();
    _zoomOutCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _zoomOutAnim = CurvedAnimation(
      parent: _zoomOutCtrl!,
      curve: Curves.easeInBack, // iOS bouncing zoom-out curve
    );
    _zoomOutCtrl!.addListener(() {
      setState(() {});
    });

    setState(() {
      _isZoomingOut = true;
    });

    _zoomOutCtrl!.forward(from: 0.0).then((_) {
      _executeReturn();
      if (mounted) {
        setState(() {
          _isZoomingOut = false;
        });
      }
    });
  }

  /// Alias for backward compatibility that triggers smooth side sliding
  void animateBack() {
    animateSlideBack();
  }

  void _executeReturn() {
    if (!mounted) return;
    IosEdgeSwipeBack.didEdgeSwipe = true;
    IosEdgeSwipeBack.cardOriginRect = null;
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
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

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

    // ==========================================
    // 1. EXPAND ENTRY ANIMATION (Card -> Full Page)
    // ==========================================
    if (_isExpanding && _expandAnim != null) {
      final t = _expandAnim!.value.clamp(0.0, 1.0);
      final startRect = _originRect ??
          Rect.fromCenter(
            center: Offset(screenWidth / 2, screenHeight / 2),
            width: screenWidth * 0.45,
            height: 180,
          );
      final targetRect = Offset.zero & screenSize;
      final currentRect = Rect.lerp(startRect, targetRect, t)!;

      final radiusValue = (24.0 * (1.0 - t)).clamp(0.0, 24.0);
      final radius = BorderRadius.circular(radiusValue);
      final contentOpacity = (t / 0.20).clamp(0.0, 1.0);

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          animateSlideBack();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Underlying background layer
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: widget.backgroundGradient ?? defaultHomeGradient,
                ),
              ),
            ),
            // Scaled background page without expensive dynamic blur for 60/120 FPS
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.scale(
                  scale: 0.96 + (0.04 * (1.0 - t)),
                  alignment: Alignment.center,
                  child: RepaintBoundary(
                    child: widget.backgroundPage ?? const HomeScreen(),
                  ),
                ),
              ),
            ),
            // Dimming scrim
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.12 * t),
                ),
              ),
            ),
            // Expanding Card Container with stable full-screen child
            Positioned.fromRect(
              rect: currentRect,
              child: RepaintBoundary(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: t < 0.98
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: 0.16 * (1.0 - t),
                              ),
                              blurRadius: 24 * (1.0 - t),
                              offset: Offset(0, 8 * (1.0 - t)),
                              spreadRadius: 1.0 * (1.0 - t),
                            ),
                          ]
                        : null,
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: Colors.white),
                        // Child elements are fixed at screen (0,0) with full dimensions: ZERO moving/squishing!
                        Positioned(
                          top: -currentRect.top,
                          left: -currentRect.left,
                          width: screenWidth,
                          height: screenHeight,
                          child: Opacity(
                            opacity: contentOpacity,
                            child: RepaintBoundary(
                              child: widget.child,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ==========================================
    // 2. ZOOM-OUT EXIT ANIMATION (Centered Bounce Zoom-Out with Middle Flight Blur)
    // ==========================================
    if (_isZoomingOut && _zoomOutAnim != null && _zoomOutCtrl != null) {
      final p = _zoomOutCtrl!.value.clamp(0.0, 1.0);
      final scale = (1.0 - _zoomOutAnim!.value).clamp(0.0, 1.0);
      final flightBlur = math.sin(p * math.pi) * 12.0;
      final pageOpacity = (1.0 - p * 1.20).clamp(0.0, 1.0);
      final radius = BorderRadius.circular(30.0 * p);

      return PopScope(
        canPop: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Underlying background layer
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
                  scale: 0.96 + (0.04 * p),
                  alignment: Alignment.center,
                  child: RepaintBoundary(
                    child: widget.backgroundPage ?? const HomeScreen(),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.12 * (1.0 - p)),
                ),
              ),
            ),
            // Centered bounce zoom-out like emploi_screen detail cell
            Center(
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.center,
                child: Opacity(
                  opacity: pageOpacity,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: flightBlur,
                      sigmaY: flightBlur,
                    ),
                    child: Container(
                      width: screenWidth,
                      height: screenHeight,
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: 0.16 * (1.0 - p),
                            ),
                            blurRadius: 24,
                            spreadRadius: 1,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: radius,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: Colors.white),
                            RepaintBoundary(
                              child: widget.child,
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
        ),
      );
    }

    // ==========================================
    // 3. STANDARD / INTERACTIVE EDGE SWIPE GESTURE
    // ==========================================
    final double underPageScale = 0.94 + (0.06 * _progress);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (widget.onInterceptSwipe != null && widget.onInterceptSwipe!()) {
          return;
        }
        animateSlideBack();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
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
                  child: RepaintBoundary(
                    child: widget.backgroundPage ?? const HomeScreen(),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(
                    alpha: 0.14 * (1.0 - _progress),
                  ),
                ),
              ),
            ),
          ],

          // Sliding top page strictly translated on X axis
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

          // Edge Swipe Detector Strip
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
      ),
    );
  }
}
