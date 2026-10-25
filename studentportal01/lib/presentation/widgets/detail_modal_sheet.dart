import 'dart:ui';
import 'package:flutter/material.dart';

/// A detail modal sheet with two fixed states: partial (tap to open)
/// and full-screen (swipe up). No arbitrary intermediate sizes.
/// Swipe down from full screen auto-closes.
/// Uses elastic-bounce animation.
class DetailModalSheet extends StatefulWidget {
  final Widget child;
  final Widget? bottomAction;
  final double initialChildSize;

  const DetailModalSheet({
    super.key,
    required this.child,
    this.bottomAction,
    this.initialChildSize = 0.7,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    Widget? bottomAction,
    double initialChildSize = 0.7,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => Material(
        color: Colors.transparent,
        child: DetailModalSheet(
          initialChildSize: initialChildSize,
          bottomAction: bottomAction,
          child: child,
        ),
      ),
    );
  }

  @override
  State<DetailModalSheet> createState() => _DetailModalSheetState();
}

class _DetailModalSheetState extends State<DetailModalSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final ScrollController _scrollController = ScrollController();
  bool _isFullScreen = false;

  // Gesture tracking
  double? _pointerDownY;
  double? _pointerDownX;
  double? _initialPointerDownY;
  double _startExtent = 0;
  bool _touchStartedOnHandle = false;
  bool _wasFullScreenOnDown = false;
  bool _isDraggingSheet = false;

  // Velocity tracking
  double? _lastMoveY;
  int? _lastMoveTime;
  double _velocity = 0.0; // px / ms, negative = up, positive = down

  double _availHeight = 0;
  double _currentSheetTop = 0;

  double get _extent => _ctrl.value;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      value: 0.0,
      upperBound: 1.05,
      lowerBound: 0.0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animateTo(widget.initialChildSize);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _animateTo(double target, {VoidCallback? onComplete}) {
    _ctrl
        .animateTo(
          target.clamp(0.0, 1.0),
          duration: const Duration(milliseconds: 460),
          curve: Curves.easeOutBack,
        )
        .then((_) => onComplete?.call());
  }

  void _toggle() {
    if (_isFullScreen) {
      setState(() => _isFullScreen = false);
      _animateTo(widget.initialChildSize);
    } else {
      setState(() => _isFullScreen = true);
      _animateTo(1.0);
    }
  }

  void _dismiss() {
    _ctrl
        .animateTo(
          0.0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInCubic,
        )
        .then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  // ---- Pointer handling: allows dragging from handle or any area of expanded card ----

  void _onPointerDown(PointerDownEvent ev) {
    _ctrl.stop();
    _pointerDownY = ev.position.dy;
    _pointerDownX = ev.position.dx;
    _initialPointerDownY = ev.position.dy;
    _startExtent = _ctrl.value;
    _wasFullScreenOnDown = _isFullScreen;
    _touchStartedOnHandle = ev.position.dy <= _currentSheetTop + 56;
    _isDraggingSheet = false;

    _lastMoveY = ev.position.dy;
    _lastMoveTime = DateTime.now().millisecondsSinceEpoch;
    _velocity = 0.0;

    _availHeight =
        MediaQuery.of(context).size.height - MediaQuery.of(context).viewPadding.top;
  }

  void _onPointerMove(PointerMoveEvent ev) {
    if (_pointerDownY == null || _initialPointerDownY == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final dt = now - (_lastMoveTime ?? now);
    if (dt > 0 && _lastMoveY != null) {
      _velocity = (ev.position.dy - _lastMoveY!) / dt;
    }
    _lastMoveY = ev.position.dy;
    _lastMoveTime = now;

    final dy = ev.position.dy - _pointerDownY!;
    final dx = (ev.position.dx - (_pointerDownX ?? ev.position.dx)).abs();

    // Disregard horizontal gestures if horizontal drag is dominant
    if (!_isDraggingSheet && dx > dy.abs() && dx > 10) {
      return;
    }

    if (!_isDraggingSheet) {
      if (_touchStartedOnHandle) {
        if (dy.abs() > 4) _isDraggingSheet = true;
      } else if (!_wasFullScreenOnDown) {
        // In partial mode (preview card): sliding up or down anywhere on content moves sheet
        if (dy.abs() > 6) _isDraggingSheet = true;
      } else {
        // In full page mode: dragging down only starts sheet close if content is scrolled to top
        final isAtTop = !_scrollController.hasClients || _scrollController.offset <= 0.5;
        if (isAtTop && dy > 8) {
          _isDraggingSheet = true;
          // Re-anchor pointer down and start extent so motion is smoothly continuous
          _pointerDownY = ev.position.dy;
          _startExtent = _ctrl.value;
        }
      }
    }

    if (_isDraggingSheet) {
      final activeDy = ev.position.dy - _pointerDownY!;
      final newExtent = (_startExtent - activeDy / _availHeight).clamp(0.0, 1.0);
      _ctrl.value = newExtent;
    }
  }

  void _onPointerUp(PointerUpEvent ev) {
    if (_initialPointerDownY == null) return;
    final totalDy = ev.position.dy - _initialPointerDownY!;
    final extent = _ctrl.value;
    final v = _velocity;

    final hadDrag = _isDraggingSheet;

    // Reset pointers
    _pointerDownY = null;
    _initialPointerDownY = null;
    _isDraggingSheet = false;

    if (!hadDrag) {
      // Tap detected; toggle if tapped directly on the handle pill
      if (_touchStartedOnHandle) {
        _toggle();
      }
      return;
    }

    if (!_wasFullScreenOnDown) {
      // Started from partial state (0.7):
      // Slide UP even slightly (>= 20px, flick upward, or extent increased) -> expand to full page
      if (totalDy < -20 || v < -0.25 || extent > widget.initialChildSize + 0.02) {
        setState(() => _isFullScreen = true);
        _animateTo(1.0);
      }
      // Slide DOWN even slightly (>= 20px, flick downward, or extent decreased) -> dismiss / close
      else if (totalDy > 20 || v > 0.25 || extent < widget.initialChildSize - 0.02) {
        _dismiss();
      } else {
        // Barely moved, snap back to initial partial size
        setState(() => _isFullScreen = false);
        _animateTo(widget.initialChildSize);
      }
    } else {
      // Started from fullscreen state (1.0):
      // Slide DOWN even slightly (>= 25px, flick downward, or extent decreased) -> dismiss / close
      if (totalDy > 25 || v > 0.25 || extent < 0.96) {
        _dismiss();
      } else {
        // Snap back to full page
        setState(() => _isFullScreen = true);
        _animateTo(1.0);
      }
    }
  }

  void _onPointerCancel(PointerCancelEvent ev) {
    _pointerDownY = null;
    _initialPointerDownY = null;
    _isDraggingSheet = false;
    _animateTo(_isFullScreen ? 1.0 : widget.initialChildSize);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).viewPadding.top;
    final bottom = MediaQuery.of(context).viewPadding.bottom;
    final avail = MediaQuery.of(context).size.height - top;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final e = _extent;
        // clamp top so sheet never goes above the safe zone
        final sheetTop = (avail * (1.0 - e) + top).clamp(top, avail + top);
        _currentSheetTop = sheetTop;

        return Stack(
          children: [
            // scrim — tap to toggle / dismiss with blur
            GestureDetector(
              onTap: _isFullScreen ? _toggle : _dismiss,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 10.0 * e,
                    sigmaY: 10.0 * e,
                  ),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.25 * e),
                  ),
                ),
              ),
            ),
            // sheet
            Positioned(
              top: sheetTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerCancel,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: e >= 0.98
                        ? BorderRadius.zero
                        : const BorderRadius.vertical(
                            top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      // Drag handle — pill at the header of the expanded card
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        width: double.infinity,
                        color: Colors.transparent,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: e >= 0.98 ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: _isFullScreen
                              ? const ClampingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            24,
                            16,
                            24,
                            widget.bottomAction != null ? 12 : bottom + 24,
                          ),
                          child: widget.child,
                        ),
                      ),
                      if (widget.bottomAction != null)
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(24, 4, 24, bottom > 0 ? 8 : 16),
                            child: widget.bottomAction!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
