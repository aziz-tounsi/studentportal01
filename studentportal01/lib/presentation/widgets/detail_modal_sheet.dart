import 'dart:ui';
import 'package:flutter/material.dart';

/// A detail modal sheet with two fixed states: partial (tap to open)
/// and full-screen (swipe up). No arbitrary intermediate sizes.
/// Swipe down from full screen auto-closes.
/// Uses elastic-bounce animation.
class DetailModalSheet extends StatefulWidget {
  final Widget child;
  final double initialChildSize;

  const DetailModalSheet({
    super.key,
    required this.child,
    this.initialChildSize = 0.7,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    double initialChildSize = 0.7,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => Material(
        color: Colors.transparent,
        child: DetailModalSheet(
          initialChildSize: initialChildSize,
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
  bool _isFullScreen = false;

  // raw gesture tracking — finger follows
  double? _pointerDownY;
  double _startExtent = 0;

  double get _extent => _ctrl.value;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      value: widget.initialChildSize,
      upperBound: 1.0,
      lowerBound: 0.0,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _animateTo(double target, {VoidCallback? onComplete}) {
    _ctrl
        .animateTo(target.clamp(0.0, 1.0),
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut)
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
    _animateTo(0, onComplete: () => Navigator.of(context).pop());
  }

  // ---- raw pointer: sheet follows finger while dragging, snaps on release ----

  double _availHeight = 0;

  void _onPointerDown(PointerDownEvent ev) {
    _pointerDownY = ev.position.dy;
    _startExtent = _ctrl.value;
    _availHeight =
        MediaQuery.of(context).size.height - MediaQuery.of(context).viewPadding.top;
  }

  void _onPointerMove(PointerMoveEvent ev) {
    if (_pointerDownY == null) return;
    final dy = ev.position.dy - _pointerDownY!;
    // Negative dy = finger up → sheet grows. Positive dy = finger down → sheet shrinks.
    final newExtent = (_startExtent - dy / _availHeight).clamp(0.0, 1.0);
    _ctrl.value = newExtent;
  }

  void _onPointerUp(PointerUpEvent ev) {
    if (_pointerDownY == null) return;
    _pointerDownY = null;
    final e = _ctrl.value;

    if (e <= 0.15) {
      _dismiss();
    } else if (e >= 0.85) {
      setState(() => _isFullScreen = true);
      _animateTo(1.0);
    } else {
      setState(() => _isFullScreen = false);
      _animateTo(widget.initialChildSize);
    }
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
                    // Drag handle — raw Listener, no gesture arena conflicts
                    Listener(
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerUp,
                      child: GestureDetector(
                        onTap: _toggle,
                        child: Container(
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
                      ),
                    ),
                    // scrollable content
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(24, 16, 24, bottom + 24),
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
