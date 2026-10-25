import 'package:flutter/material.dart';

/// A reusable iOS-style bouncing wrapper that smoothly scales down on tap-down
/// and springs back with elastic feedback on tap-up.
class BouncingWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double shrinkScale;
  final Duration downDuration;
  final Duration upDuration;
  final HitTestBehavior behavior;
  final EdgeInsetsGeometry? hitPadding;

  const BouncingWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.shrinkScale = 0.94,
    this.downDuration = const Duration(milliseconds: 110),
    this.upDuration = const Duration(milliseconds: 320),
    this.behavior = HitTestBehavior.opaque,
    this.hitPadding,
  });

  @override
  State<BouncingWrapper> createState() => _BouncingWrapperState();
}

class _BouncingWrapperState extends State<BouncingWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.downDuration,
      reverseDuration: widget.upDuration,
    );
    _scale = Tween<double>(begin: 1.0, end: widget.shrinkScale).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _ctrl.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      _ctrl.reverse();
      widget.onTap?.call();
    }
  }

  void _onTapCancel() {
    _ctrl.reverse();
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
              _ctrl.reverse();
              widget.onLongPress?.call();
            }
          : null,
      child: content,
    );
  }
}
