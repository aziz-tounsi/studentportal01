import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/app_localizations.dart';
import 'bouncing_wrapper.dart';
import 'ios_bounce_zoom_transition.dart';
import 'ios_loader.dart';

/// Interactive Apple-grade photo cutout and crop tool:
/// - Lets the student position, zoom, rotate, and align their profile picture into a precise square frame.
/// - Switchable mask preview: Rounded square (Student Card) or Circle (Avatar Profile).
/// - Rule-of-thirds grid with viewfinder corner brackets and center crosshair.
/// - Smooth two-finger pinch-to-zoom + single-finger panning.
/// - Precision Zoom Slider with - / + controls.
/// - 90-degree rotation control for camera orientation correction.
/// - Reset & Center actions.
/// - Generates a crisp, high-resolution 512x512 square image output in pure Flutter via dart:ui.
class PhotoCutoutScreen extends StatefulWidget {
  final Uint8List rawImageBytes;
  final String initialShape; // 'card' or 'avatar'

  const PhotoCutoutScreen({
    super.key,
    required this.rawImageBytes,
    this.initialShape = 'card',
  });

  /// Opens the interactive photo cutout screen with iOS bounce zoom transition.
  /// Returns 512x512 PNG bytes if confirmed, or `null` if cancelled.
  static Future<Uint8List?> show({
    required BuildContext context,
    required Uint8List rawImageBytes,
    String initialShape = 'card',
  }) {
    return Navigator.of(context, rootNavigator: true).push<Uint8List>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) {
          return PhotoCutoutScreen(
            rawImageBytes: rawImageBytes,
            initialShape: initialShape,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return buildIosBounceZoomTransition(
            context: context,
            animation: animation,
            child: child,
            backdropSigma: 16.0,
            maxFlightBlur: 14.0,
          );
        },
      ),
    );
  }

  @override
  State<PhotoCutoutScreen> createState() => _PhotoCutoutScreenState();
}

class _PhotoCutoutScreenState extends State<PhotoCutoutScreen> {
  ui.Image? _uiImage;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isCropping = false;

  // Viewfinder parameters
  double _cropSize = 280.0;
  late String _currentShape;

  // Transformations
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  int _rotationTurns = 0; // 0, 1, 2, 3

  // Gesture tracking
  double _startScale = 1.0;
  Offset _lastFocalPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    _currentShape = widget.initialShape;
    _decodeImage();
  }

  @override
  void dispose() {
    _uiImage?.dispose();
    super.dispose();
  }

  Future<void> _decodeImage() async {
    try {
      final ui.Image decoded = await decodeImageFromList(widget.rawImageBytes);
      if (!mounted) {
        decoded.dispose();
        return;
      }
      setState(() {
        _uiImage = decoded;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[PhotoCutoutScreen] Failed to decode image: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  double _calculateBaseScale(ui.Image image, double cropSize, int rotationTurns) {
    final bool isRotated90 = (rotationTurns % 2 != 0);
    final double visualWidth =
        isRotated90 ? image.height.toDouble() : image.width.toDouble();
    final double visualHeight =
        isRotated90 ? image.width.toDouble() : image.height.toDouble();
    return math.max(cropSize / visualWidth, cropSize / visualHeight);
  }

  void _clampOffset() {
    if (_uiImage == null) return;
    final baseScale =
        _calculateBaseScale(_uiImage!, _cropSize, _rotationTurns);
    final isRotated90 = (_rotationTurns % 2 != 0);
    final visualW =
        isRotated90 ? _uiImage!.height.toDouble() : _uiImage!.width.toDouble();
    final visualH =
        isRotated90 ? _uiImage!.width.toDouble() : _uiImage!.height.toDouble();

    final renderedW = visualW * baseScale * _scale;
    final renderedH = visualH * baseScale * _scale;

    final maxDragX = math.max(0.0, (renderedW - _cropSize) / 2) + 90.0;
    final maxDragY = math.max(0.0, (renderedH - _cropSize) / 2) + 90.0;

    _offset = Offset(
      _offset.dx.clamp(-maxDragX, maxDragX),
      _offset.dy.clamp(-maxDragY, maxDragY),
    );
  }

  void _rotate90() {
    HapticFeedback.lightImpact();
    setState(() {
      _rotationTurns = (_rotationTurns + 1) % 4;
      _offset = Offset.zero;
      _clampOffset();
    });
  }

  void _centerAndReset() {
    HapticFeedback.mediumImpact();
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
      _rotationTurns = 0;
    });
  }

  Future<void> _confirmAndCrop() async {
    if (_uiImage == null || _isCropping) return;

    setState(() => _isCropping = true);
    HapticFeedback.mediumImpact();

    try {
      const double outputSize = 512.0;
      final double outputScale = outputSize / _cropSize;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        const Rect.fromLTWH(0, 0, outputSize, outputSize),
      );

      // Clip to exact square output boundary
      canvas.clipRect(const Rect.fromLTWH(0, 0, outputSize, outputSize));

      // Translate origin to output center
      canvas.translate(outputSize / 2, outputSize / 2);

      // Apply pan translation scaled to output canvas
      canvas.translate(_offset.dx * outputScale, _offset.dy * outputScale);

      // Apply rotation around center
      if (_rotationTurns != 0) {
        canvas.rotate(_rotationTurns * math.pi / 2);
      }

      // Apply zoom scale
      final baseScale =
          _calculateBaseScale(_uiImage!, _cropSize, _rotationTurns);
      final effectiveScale = baseScale * _scale * outputScale;
      canvas.scale(effectiveScale, effectiveScale);

      // Draw the image centered
      canvas.drawImage(
        _uiImage!,
        Offset(-_uiImage!.width / 2, -_uiImage!.height / 2),
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final croppedUi =
          await picture.toImage(outputSize.toInt(), outputSize.toInt());
      final byteData =
          await croppedUi.toByteData(format: ui.ImageByteFormat.png);

      croppedUi.dispose();
      picture.dispose();

      if (byteData == null) {
        throw Exception('Failed to encode cropped image to byte data');
      }

      final croppedBytes = byteData.buffer.asUint8List();

      if (mounted) {
        Navigator.of(context).pop(croppedBytes);
      }
    } catch (e) {
      debugPrint('[PhotoCutoutScreen] Error during cropping: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors du recadrage de l\'image'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.88),
      body: SafeArea(
        child: Column(
          children: [
            // ── TOP APP BAR ──
            _buildTopAppBar(l10n),

            // ── SHAPE TOGGLE SWITCHER (Card vs Avatar) ──
            _buildShapeSwitcher(l10n),

            const SizedBox(height: 12),

            // ── CENTRAL INTERACTIVE VIEWFINDER ──
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: IosLoader(color: Colors.white, size: 36),
                    )
                  : _hasError
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.broken_image_rounded,
                                  color: Colors.white54, size: 48),
                              const SizedBox(height: 12),
                              Text(
                                l10n.translate('image_unavailable'),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildViewfinderArea(),
            ),

            // ── BOTTOM CONTROL DECK (Zoom slider, rotate, reset) ──
            _buildBottomControlDeck(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Cancel button
          BouncingWrapper(
            onTap: () => Navigator.of(context).pop(null),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.translate('adjust_photo'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.translate('crop_photo_hint'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Confirm "Valider" Button
          BouncingWrapper(
            onTap: _isCropping ? null : _confirmAndCrop,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isCropping
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const IosLoader(color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          l10n.translate('cropping_photo'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          l10n.translate('crop_done'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShapeSwitcher(AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Student Card Option
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _currentShape = 'card');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _currentShape == 'card'
                      ? const Color(0xFF2563EB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.badge_rounded,
                      size: 16,
                      color: _currentShape == 'card'
                          ? Colors.white
                          : Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.translate('crop_card_shape'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _currentShape == 'card'
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: _currentShape == 'card'
                            ? Colors.white
                            : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Avatar Circle Option
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _currentShape = 'avatar');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _currentShape == 'avatar'
                      ? const Color(0xFF2563EB)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.account_circle_rounded,
                      size: 16,
                      color: _currentShape == 'avatar'
                          ? Colors.white
                          : Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.translate('crop_avatar_shape'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _currentShape == 'avatar'
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: _currentShape == 'avatar'
                            ? Colors.white
                            : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewfinderArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Compute adaptive square viewfinder size
        final maxDimension = math.min(
          constraints.maxWidth - 44,
          constraints.maxHeight - 20,
        );
        _cropSize = maxDimension.clamp(240.0, 360.0);

        final baseScale =
            _calculateBaseScale(_uiImage!, _cropSize, _rotationTurns);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            _startScale = _scale;
            _lastFocalPoint = details.localFocalPoint;
          },
          onScaleUpdate: (details) {
            setState(() {
              // Zoom
              _scale = (_startScale * details.scale).clamp(0.7, 4.0);

              // Pan
              final delta = details.localFocalPoint - _lastFocalPoint;
              _offset += delta;
              _lastFocalPoint = details.localFocalPoint;

              _clampOffset();
            });
          },
          onDoubleTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (_scale > 1.2) {
                _scale = 1.0;
                _offset = Offset.zero;
              } else {
                _scale = 2.0;
              }
              _clampOffset();
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Raw photo rendered with pan/zoom/rotation
              CustomPaint(
                painter: _CutoutImagePainter(
                  image: _uiImage!,
                  scale: _scale,
                  offset: _offset,
                  rotationTurns: _rotationTurns,
                  baseScale: baseScale,
                ),
              ),

              // 2. Viewfinder dark mask, border, rule-of-thirds grid & corner brackets
              IgnorePointer(
                child: CustomPaint(
                  painter: _ViewfinderOverlayPainter(
                    cropSize: _cropSize,
                    shape: _currentShape,
                    maskColor: Colors.black.withValues(alpha: 0.72),
                    borderColor: const Color(0xFF60A5FA),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomControlDeck(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── ZOOM SLIDER ROW ──
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    color: Colors.white70, size: 22),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _scale = (_scale - 0.15).clamp(0.7, 4.0);
                    _clampOffset();
                  });
                },
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF3B82F6),
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                    thumbColor: Colors.white,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 9),
                    overlayColor:
                        const Color(0xFF3B82F6).withValues(alpha: 0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _scale.clamp(0.7, 4.0),
                    min: 0.7,
                    max: 4.0,
                    onChanged: (v) {
                      setState(() {
                        _scale = v;
                        _clampOffset();
                      });
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded,
                    color: Colors.white70, size: 22),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _scale = (_scale + 0.15).clamp(0.7, 4.0);
                    _clampOffset();
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── ACTIONS TOOLBAR: Rotate & Reset & Center ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Rotate 90 degrees
              _buildActionButton(
                icon: Icons.rotate_right_rounded,
                label: l10n.translate('crop_rotate'),
                onTap: _rotate90,
              ),

              // Center
              _buildActionButton(
                icon: Icons.filter_center_focus_rounded,
                label: l10n.translate('crop_center'),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _offset = Offset.zero;
                    _clampOffset();
                  });
                },
              ),

              // Reset to default
              _buildActionButton(
                icon: Icons.restart_alt_rounded,
                label: l10n.translate('crop_reset'),
                onTap: _centerAndReset,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return BouncingWrapper(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CUSTOM PAINTER: Renders the image with 2D transformations
// ═══════════════════════════════════════════════════════════════════

class _CutoutImagePainter extends CustomPainter {
  final ui.Image image;
  final double scale;
  final Offset offset;
  final int rotationTurns;
  final double baseScale;

  _CutoutImagePainter({
    required this.image,
    required this.scale,
    required this.offset,
    required this.rotationTurns,
    required this.baseScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.translate(offset.dx, offset.dy);

    if (rotationTurns != 0) {
      canvas.rotate(rotationTurns * math.pi / 2);
    }

    final effectiveScale = baseScale * scale;
    canvas.scale(effectiveScale, effectiveScale);

    canvas.drawImage(
      image,
      Offset(-image.width / 2, -image.height / 2),
      Paint()..filterQuality = FilterQuality.medium,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CutoutImagePainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.offset != offset ||
        oldDelegate.rotationTurns != rotationTurns ||
        oldDelegate.baseScale != baseScale;
  }
}

// ═══════════════════════════════════════════════════════════════════
// CUSTOM PAINTER: Viewfinder overlay (mask, grid, brackets, aperture)
// ═══════════════════════════════════════════════════════════════════

class _ViewfinderOverlayPainter extends CustomPainter {
  final double cropSize;
  final String shape; // 'card' or 'avatar'
  final Color maskColor;
  final Color borderColor;

  _ViewfinderOverlayPainter({
    required this.cropSize,
    required this.shape,
    required this.maskColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final cropRect = Rect.fromCenter(
      center: center,
      width: cropSize,
      height: cropSize,
    );

    // 1. Dark mask with cutout hole
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final Path maskPath = Path()..addRect(fullRect);

    final Path holePath = Path();
    if (shape == 'avatar') {
      holePath.addOval(cropRect);
    } else {
      holePath.addRRect(
        RRect.fromRectAndRadius(cropRect, const Radius.circular(26)),
      );
    }

    final combinedMask =
        Path.combine(PathOperation.difference, maskPath, holePath);
    canvas.drawPath(combinedMask, Paint()..color = maskColor);

    // 2. Rule of thirds grid lines inside the hole
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.save();
    if (shape == 'avatar') {
      canvas.clipPath(Path()..addOval(cropRect));
    } else {
      canvas.clipRRect(
        RRect.fromRectAndRadius(cropRect, const Radius.circular(26)),
      );
    }

    final third = cropSize / 3.0;
    // Vertical grid lines
    canvas.drawLine(
      Offset(cropRect.left + third, cropRect.top),
      Offset(cropRect.left + third, cropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left + third * 2, cropRect.top),
      Offset(cropRect.left + third * 2, cropRect.bottom),
      gridPaint,
    );
    // Horizontal grid lines
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + third),
      Offset(cropRect.right, cropRect.top + third),
      gridPaint,
    );
    canvas.drawLine(
      Offset(cropRect.left, cropRect.top + third * 2),
      Offset(cropRect.right, cropRect.top + third * 2),
      gridPaint,
    );

    // Center focal point
    final centerDotPaint = Paint()..color = Colors.white.withValues(alpha: 0.5);
    canvas.drawCircle(center, 2.5, centerDotPaint);

    canvas.restore();

    // 3. Viewfinder Outer Border
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.85)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    if (shape == 'avatar') {
      canvas.drawOval(cropRect, borderPaint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(cropRect, const Radius.circular(26)),
        borderPaint,
      );
    }

    // 4. Viewfinder Corner L-Brackets (Corner Marks)
    if (shape == 'card') {
      final cornerPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      const double arm = 22.0;
      const double pad = 3.0;
      final left = cropRect.left - pad;
      final right = cropRect.right + pad;
      final top = cropRect.top - pad;
      final bottom = cropRect.bottom + pad;

      // Top-Left
      canvas.drawLine(Offset(left, top + arm), Offset(left, top), cornerPaint);
      canvas.drawLine(Offset(left, top), Offset(left + arm, top), cornerPaint);

      // Top-Right
      canvas.drawLine(
          Offset(right - arm, top), Offset(right, top), cornerPaint);
      canvas.drawLine(
          Offset(right, top), Offset(right, top + arm), cornerPaint);

      // Bottom-Left
      canvas.drawLine(
          Offset(left, bottom - arm), Offset(left, bottom), cornerPaint);
      canvas.drawLine(
          Offset(left, bottom), Offset(left + arm, bottom), cornerPaint);

      // Bottom-Right
      canvas.drawLine(
          Offset(right - arm, bottom), Offset(right, bottom), cornerPaint);
      canvas.drawLine(
          Offset(right, bottom), Offset(right, bottom - arm), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ViewfinderOverlayPainter oldDelegate) {
    return oldDelegate.cropSize != cropSize ||
        oldDelegate.shape != shape ||
        oldDelegate.borderColor != borderColor;
  }
}
