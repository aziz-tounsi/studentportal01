import 'package:flutter/material.dart';
import '../../data/services/school_branding_service.dart';

/// Displays a school's uploaded logo URL or falls back cleanly to the default app logo asset.
class SchoolLogoPreview extends StatelessWidget {
  final String? logoUrl;
  final double size;
  final double borderRadius;
  final BoxFit fit;

  const SchoolLogoPreview({
    super.key,
    this.logoUrl,
    this.size = 42,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = logoUrl != null && logoUrl!.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: hasUrl
            ? Image.network(
                logoUrl!.trim(),
                width: size,
                height: size,
                fit: fit,
                errorBuilder: (_, _, _) => _defaultAsset(),
              )
            : _defaultAsset(),
      ),
    );
  }

  Widget _defaultAsset() {
    return Image.asset(
      SchoolBrandingService.defaultLogoAsset,
      width: size,
      height: size,
      fit: fit,
    );
  }
}
