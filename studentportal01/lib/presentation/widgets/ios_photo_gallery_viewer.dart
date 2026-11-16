import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../../../core/utils/file_download_helper.dart';
import 'bouncing_wrapper.dart';
import 'ios_bounce_zoom_transition.dart';

/// iOS-style interactive photo gallery viewer matching native iOS Photos:
/// - Smooth single-finger drag in ANY direction to dismiss
/// - Magnetic spring snap-back if released within threshold
/// - Swipe-to-dismiss beyond threshold or with velocity
/// - Dynamic background blur and opacity that fades with drag distance
/// - Natural pinch-to-zoom in all directions
/// - Double-tap to zoom in (2.5x) and zoom out
/// - Bounce-to-shrink close animation
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
          return buildIosBounceZoomTransition(
            context: context,
            animation: animation,
            child: child,
            backdropSigma: 0.0,
            maxFlightBlur: 14.0,
          );
        },
      ),
    );
  }

  @override
  State<IosPhotoGalleryViewer> createState() => _IosPhotoGalleryViewerState();
}

class _IosPhotoGalleryViewerState extends State<IosPhotoGalleryViewer>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;

  // Single-finger dismiss physics
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  late AnimationController _springController;
  late Animation<Offset> _springAnimation;

  // Zoom and pan state
  double _scale = 1.0;
  double _baseScale = 1.0;
  Offset _panOffset = Offset.zero;

  // Double tap animation
  late AnimationController _doubleTapController;
  Animation<double>? _doubleTapAnimation;

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

    _doubleTapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _doubleTapController.addListener(() {
      if (_doubleTapAnimation != null) {
        setState(() {
          _scale = _doubleTapAnimation!.value;
          if (_scale <= 1.0) {
            _panOffset = Offset.zero;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _springController.dispose();
    _doubleTapController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool get _isZoomed => _scale > 1.05;

  void _onScaleStart(ScaleStartDetails details) {
    if (_doubleTapController.isAnimating) _doubleTapController.stop();
    if (_springController.isAnimating) _springController.stop();

    _baseScale = _scale;

    if (!_isZoomed && details.pointerCount == 1) {
      _isDragging = true;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    // 1. Two-finger pinch-to-zoom
    if (details.pointerCount >= 2) {
      setState(() {
        _scale = (_baseScale * details.scale).clamp(0.8, 5.0);
        // If zooming, reset dismiss drag
        if (_scale > 1.0) {
          _dragOffset = Offset.zero;
          _isDragging = false;
        }
      });
      return;
    }

    // 2. Single finger while zoomed in: Pan the zoomed image
    if (_isZoomed) {
      setState(() {
        _panOffset += details.focalPointDelta;
      });
      return;
    }

    // 3. Single finger at 1.0 scale: Drag in ANY direction to dismiss
    setState(() {
      _dragOffset += details.focalPointDelta;
      _isDragging = true;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // If zoomed out below 1.0, spring back to 1.0
    if (_scale < 1.0) {
      _animateScaleTo(1.0);
      _springBackToCenter();
      return;
    }

    // If zoomed in, clamp pan offset if needed
    if (_isZoomed) {
      return;
    }

    // Dismiss drag evaluation
    final distance = _dragOffset.distance;
    final velocity = details.velocity.pixelsPerSecond.distance;

    // Threshold: dragged > 95px or flicked quickly (> 520px/s)
    if (distance > 95 || velocity > 520) {
      Navigator.of(context).pop();
    } else {
      _springBackToCenter();
    }
  }

  void _springBackToCenter() {
    _springAnimation = _springController.drive(
      Tween<Offset>(begin: _dragOffset, end: Offset.zero),
    );

    _springController.reset();
    final simulation = SpringSimulation(
      const SpringDescription(
        mass: 1.0,
        stiffness: 280.0,
        damping: 22.0,
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

  void _handleDoubleTap() {
    if (_doubleTapController.isAnimating) return;

    final targetScale = _scale > 1.2 ? 1.0 : 2.5;
    _animateScaleTo(targetScale);
  }

  void _animateScaleTo(double target) {
    _doubleTapAnimation = Tween<double>(begin: _scale, end: target).animate(
      CurvedAnimation(parent: _doubleTapController, curve: Curves.easeOutCubic),
    );
    _doubleTapController.forward(from: 0.0);
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
    final dragDist = _dragOffset.distance;
    final progress = (dragDist / 300).clamp(0.0, 1.0);
    // Background fades smoothly as photo is dragged
    final bgOpacity = (0.75 * (1.0 - progress * 0.70)).clamp(0.15, 0.75);
    // Photo smoothly scales down as dragged away
    final dragScale = (1.0 - (dragDist / 1200)).clamp(0.72, 1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dynamic blurred backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 20.0 * (1.0 - progress * 0.5),
                sigmaY: 20.0 * (1.0 - progress * 0.5),
              ),
              child: Container(
                color: Colors.black.withValues(alpha: bgOpacity),
              ),
            ),
          ),

          // Central interactive image
          AnimatedBuilder(
            animation: _springController,
            builder: (context, child) {
              final currentOffset = _springController.isAnimating
                  ? _springAnimation.value
                  : _dragOffset;

              return Transform.translate(
                offset: currentOffset,
                child: Transform.scale(
                  scale: _springController.isAnimating ? 1.0 : dragScale,
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onDoubleTap: _handleDoubleTap,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              child: PageView.builder(
                controller: _pageController,
                physics: _isZoomed || _isDragging
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemCount: widget.imageUrls.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    _scale = 1.0;
                    _panOffset = Offset.zero;
                    _dragOffset = Offset.zero;
                  });
                },
                itemBuilder: (context, index) {
                  final url = widget.imageUrls[index];
                  return Center(
                    child: Transform.translate(
                      offset: _panOffset,
                      child: Transform.scale(
                        scale: _scale,
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
                // Close button (bounces on tap)
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
