import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/// Standard iOS bounce zoom transition with motion flight blur in the middle of the distance.
/// When opening: zooms in with bounce (easeOutBack), passes through flight blur in the middle.
/// When closing (zooming out): zooms out with bounce (easeInBack), gets blurred in the middle of the distance.
Widget buildIosBounceZoomTransition({
  required BuildContext context,
  required Animation<double> animation,
  required Widget child,
  double backdropSigma = 12.0,
  double maxFlightBlur = 12.0,
}) {
  final scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    ),
  );

  return AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final v = animation.value.clamp(0.0, 1.0);
      final flightBlur = math.sin(v * math.pi) * maxFlightBlur;
      final currentBackdrop = backdropSigma * v;

      Widget content = ScaleTransition(
        scale: scaleAnimation,
        child: child,
      );

      if (flightBlur > 0.05) {
        content = ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: flightBlur,
            sigmaY: flightBlur,
          ),
          child: content,
        );
      }

      if (currentBackdrop > 0.05) {
        content = BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: currentBackdrop,
            sigmaY: currentBackdrop,
          ),
          child: content,
        );
      }

      return content;
    },
  );
}
