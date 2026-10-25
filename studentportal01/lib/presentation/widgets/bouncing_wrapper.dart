import 'package:flutter/material.dart';

/// A reusable iOS-style press-scale & bouncing wrapper that:
/// 1. Smoothly shrinks on touch-down (scale ~0.93) and stays shrunk as long as held.
/// 2. Springs forward and elastically bounces back to resting 1.0 on release.
/// 3. Smoothly un-shrinks if the touch cancels or slides off.
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
    this.overshootScale = 1.052,
    this.duration = const Duration(milliseconds: 320),
    this.behavior = HitTestBehavior.opaque,
    this.hitPadding,
    this.delayNavigation = true,
  });

  @override
  State<BouncingWrapper> createState() => _BouncingWrapperState();
}

class _BouncingWrapperState extends State<BouncingWrapper>
    with TickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;
  bool _isActionDispatched = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final shrink = widget.shrinkScale;
    final overshoot = widget.overshootScale;
    final secondaryUndershoot = 1.0 - (1.0 - shrink) * 0.24;
    final secondaryOvershoot = 1.0 + (overshoot - 1.0) * 0.28;

    _bounceAnim = TweenSequence<double>([
      // 1. Elastic spring explosion from shrink scale past 1.0
      TweenSequenceItem(
        tween: Tween<double>(begin: shrink, end: overshoot)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 38,
      ),
      // 2. Soft rebound slightly below 1.0
      TweenSequenceItem(
        tween: Tween<double>(begin: overshoot, end: secondaryUndershoot)
            .chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 26,
      ),
      // 3. Micro rebound slightly above 1.0
      TweenSequenceItem(
        tween: Tween<double>(begin: secondaryUndershoot, end: secondaryOvershoot)
            .chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 18,
      ),
      // 4. Softly settles to resting 1.0
      TweenSequenceItem(
        tween: Tween<double>(begin: secondaryOvershoot, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 18,
      ),
    ]).animate(_bounceCtrl);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _isActionDispatched = false;
      _bounceCtrl.stop();
      _pressCtrl.animateTo(
        1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null && !_isActionDispatched) {
      _isActionDispatched = true;
      _pressCtrl.value = 0.0;
      _bounceCtrl.forward(from: 0.0);
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
    _pressCtrl.animateTo(
      0.0,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutQuad,
    );
  }

  double get _currentScale {
    if (_bounceCtrl.isAnimating) {
      return _bounceAnim.value;
    }
    return 1.0 - (1.0 - widget.shrinkScale) * _pressCtrl.value;
  }

  @override
  Widget build(BuildContext context) {
    Widget content = AnimatedBuilder(
      animation: Listenable.merge([_pressCtrl, _bounceCtrl]),
      builder: (context, child) => Transform.scale(
        scale: _currentScale,
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
              _isActionDispatched = true;
              widget.onLongPress?.call();
            }
          : null,
      child: content,
    );
  }
}
