import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../../../core/utils/file_download_helper.dart';
import 'bouncing_wrapper.dart';

/// iOS-style interactive photo gallery viewer with:
/// - Pinch-to-zoom (InteractiveViewer)
/// - Drag in any direction
/// - Magnetic bounce back to center if released below threshold
/// - Swipe to dismiss in any direction (velocity or distance threshold)
/// - Background opacity fades with drag distance
class IosPhotoGalleryViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const IosPhotoGalleryViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  static Future<void> show({
    required BuildContext context,
    required List<String> imageUrls,
    int initialIndex = 0,
  }) {
    if (imageUrls.isEmpty) return Future.value();
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) {
          return IosPhotoGalleryViewer(
            imageUrls: imageUrls,
            initialIndex: initialIndex,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeInBack,
            ),
          );
          return ScaleTransition(
            scale: scaleAnimation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<IosPhotoGalleryViewer> createState() => _IosPhotoGalleryViewerState();
}

class _IosPhotoGalleryViewerState extends State<IosPhotoGalleryViewer>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;
  final TransformationController _transformController = TransformationController();

  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isZoomed = false;

  late AnimationController _springController;
  late Animation<Offset> _springAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _springAnimation = _springController.drive(
      Tween<Offset>(begin: Offset.zero, end: Offset.zero),
    );

    _transformController.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final isZoomed = (scale - 1.0).abs() > 0.05;
    if (isZoomed != _isZoomed) {
      setState(() => _isZoomed = isZoomed);
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _springController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (_isZoomed) return;
    _springController.stop();
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isZoomed) return;
    final distance = _dragOffset.distance;
    final velocity = details.velocity.pixelsPerSecond.distance;

    // Threshold to dismiss: dragged more than 110px or flicked quickly
    if (distance > 110 || velocity > 650) {
      _dismissWithAnimation(details.velocity.pixelsPerSecond);
    } else {
      _bounceBackToCenter();
    }
  }

  void _bounceBackToCenter() {
    _springAnimation = _springController.drive(
      Tween<Offset>(
        begin: _dragOffset,
        end: Offset.zero,
      ),
    );

    _springController.reset();
    final simulation = SpringSimulation(
      const SpringDescription(
        mass: 1.0,
        stiffness: 220.0,
        damping: 20.0,
      ),
      0.0,
      1.0,
      0.0,
    );
    _springController.animateWith(simulation).then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = Offset.zero;
          _isDragging = false;
        });
      }
    });
  }

  void _dismissWithAnimation(Offset velocity) {
    Navigator.of(context).pop();
  }

  String _getFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image.jpg';
      return last.contains('.') ? last : '$last.jpg';
    } catch (_) {
      return 'image.jpg';
    }
  }

  @override
  Widget build(BuildContext context) {
    final distance = _dragOffset.distance;
    // Slight scale down as dragged
    final scale = (1.0 - (distance / 1200)).clamp(0.8, 1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dynamic blurred backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22.0, sigmaY: 22.0),
              child: Container(
                color: Colors.black.withValues(alpha: 0.70),
              ),
            ),
          ),

          // Central draggable & zoomable image
          AnimatedBuilder(
            animation: _springController,
            builder: (context, child) {
              final currentOffset = _springController.isAnimating
                  ? _springAnimation.value
                  : _dragOffset;

              return Transform.translate(
                offset: currentOffset,
                child: Transform.scale(
                  scale: _springController.isAnimating ? 1.0 : scale,
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: PageView.builder(
                controller: _pageController,
                physics: _isZoomed || _isDragging
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemCount: widget.imageUrls.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _transformController.value = Matrix4.identity();
                    _isZoomed = false;
                  });
                },
                itemBuilder: (context, index) {
                  final url = widget.imageUrls[index];
                  return Center(
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.8,
                      maxScale: 4.5,
                      clipBehavior: Clip.none,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey[900],
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, color: Colors.white54, size: 64),
                              SizedBox(height: 16),
                              Text(
                                'Image non disponible',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Top Header Buttons (Download & Close)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 20,
            right: 20,
            child: Row(
              children: [
                // Multiple images indicator
                if (widget.imageUrls.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                const Spacer(),
                // Download button
                BouncingWrapper(
                  shrinkScale: 0.85,
                  overshootScale: 1.15,
                  onTap: () {
                    final url = widget.imageUrls[_currentIndex];
                    FileDownloadHelper.downloadFile(
                      context: context,
                      url: url,
                      fileName: _getFileName(url),
                    );
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                // Close button
                BouncingWrapper(
                  shrinkScale: 0.85,
                  overshootScale: 1.15,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
