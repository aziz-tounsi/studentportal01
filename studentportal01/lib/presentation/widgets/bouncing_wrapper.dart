import 'package:flutter/material.dart';

/// A reusable iOS-style bouncing wrapper that plays a noticeable multi-oscillation
/// elastic spring bounce upon click/tap.
class BouncingWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double shrinkScale;
  final double overshootScale;
  final Duration duration;
  final HitTestBehavior behavior;
  final EdgeInsetsGeometry? hitPadding;
  final bool delayNavigation;

  const BouncingWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.shrinkScale = 0.93,
    this.overshootScale = 1.055,
    this.duration = const Duration(milliseconds: 440),
    this.behavior = HitTestBehavior.opaque,
    this.hitPadding,
    this.delayNavigation = true,
  });

  @override
  State<BouncingWrapper> createState() => _BouncingWrapperState();
}

class _BouncingWrapperState extends State<BouncingWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _isActionDispatched = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final shrink = widget.shrinkScale;
    final overshoot = widget.overshootScale;
    final secondaryUndershoot = 1.0 - (1.0 - shrink) * 0.28;
    final secondaryOvershoot = 1.0 + (overshoot - 1.0) * 0.32;

    _scale = TweenSequence<double>([
      // Phase 1 (0 -> 22%): Noticeable quick squish inward
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: shrink)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 22,
      ),
      // Phase 2 (22 -> 54%): Elastic spring explosion past 1.0
      TweenSequenceItem(
        tween: Tween<double>(begin: shrink, end: overshoot)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 32,
      ),
      // Phase 3 (54 -> 76%): Second elastic oscillation downward
      TweenSequenceItem(
        tween: Tween<double>(begin: overshoot, end: secondaryUndershoot)
            .chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 22,
      ),
      // Phase 4 (76 -> 90%): Third micro-rebound upward
      TweenSequenceItem(
        tween: Tween<double>(begin: secondaryUndershoot, end: secondaryOvershoot)
            .chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 14,
      ),
      // Phase 5 (90 -> 100%): Softly settles to resting 1.0
      TweenSequenceItem(
        tween: Tween<double>(begin: secondaryOvershoot, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 10,
      ),
    ]).animate(_ctrl);

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _ctrl.value = 0.0;
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _isActionDispatched = false;
      // Smoothly shrink to 92-95% over ~120ms (ease-out) and stay shrunk while held
      _ctrl.animateTo(0.22, duration: const Duration(milliseconds: 120), curve: Curves.easeOutCubic);
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null && !_isActionDispatched) {
      _isActionDispatched = true;
      // Finger lifts: springs forward past 1.0 and elastically bounces back to resting size
      if (_ctrl.value < 0.22) {
        _ctrl.forward(from: 0.0);
      } else {
        _ctrl.forward(from: _ctrl.value);
      }
      if (widget.delayNavigation) {
        Future.delayed(const Duration(milliseconds: 110), () {
          if (mounted) widget.onTap?.call();
        });
      } else {
        widget.onTap?.call();
      }
    }
  }

  void _onTapCancel() {
    if (_ctrl.value > 0) {
      // Finger slides off or touch cancelled: smoothly return to normal resting scale
      _ctrl.animateTo(0.0, duration: const Duration(milliseconds: 130), curve: Curves.easeOutQuad);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: child,
      ),
      child: widget.child,
    );

    if (widget.hitPadding != null) {
      content = Padding(
        padding: widget.hitPadding!,
        child: content,
      );
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.onLongPress != null
          ? () {
              _ctrl.forward(from: _ctrl.value);
              widget.onLongPress?.call();
            }
          : null,
      child: content,
    );
  }
}
