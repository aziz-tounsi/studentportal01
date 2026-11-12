import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Displays a tenant school's custom logo when configured, falling back seamlessly
/// to the default Red & Black Modern Education app logo asset.
class SchoolLogoWidget extends StatelessWidget {
  static const String defaultLogoAsset = 'assets/images/app_logo.png';

  final String? logoUrl;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;

  const SchoolLogoWidget({
    super.key,
    this.logoUrl,
    this.size = 48,
    this.borderRadius,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = logoUrl?.trim();
    final hasRemoteLogo = trimmed != null && trimmed.isNotEmpty;
    final radius = borderRadius ?? BorderRadius.circular(size * 0.28);

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: hasRemoteLogo
            ? CachedNetworkImage(
                imageUrl: trimmed,
                width: size,
                height: size,
                fit: fit,
                placeholder: (_, _) => _buildDefaultAsset(),
                errorWidget: (_, _, _) => _buildDefaultAsset(),
              )
            : _buildDefaultAsset(),
      ),
    );
  }

  Widget _buildDefaultAsset() {
    return Image.asset(
      defaultLogoAsset,
      width: size,
      height: size,
      fit: fit,
    );
  }
}
