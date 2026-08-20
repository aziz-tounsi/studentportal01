import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class IosLoader extends StatelessWidget {
  final double size;
  final Color? color;
  final double radius;

  const IosLoader({
    super.key,
    this.size = 24,
    this.color,
    this.radius = 7.0,
  });

  const IosLoader.small({
    super.key,
    this.size = 16,
    this.color,
    this.radius = 5.0,
  });

  const IosLoader.large({
    super.key,
    this.size = 36,
    this.color,
    this.radius = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: CupertinoActivityIndicator(
          radius: radius,
          color: color ?? Colors.grey,
        ),
      ),
    );
  }
}
