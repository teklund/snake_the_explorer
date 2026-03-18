import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Paints CRT monitor effects on top of the game canvas:
/// - Horizontal scanlines (tinted per theme)
/// - Corner vignette darkening
/// - Slight screen curvature illusion via radial gradient
final class CrtOverlayPainter extends CustomPainter {
  /// Tint color drawn over scanline stripes.
  final Color scanlineTint;

  const CrtOverlayPainter({required this.scanlineTint});

  @override
  void paint(Canvas canvas, Size size) {
    _paintScanlines(canvas, size);
    _paintVignette(canvas, size);
  }

  /// Semi-transparent horizontal lines every 2 pixels to simulate CRT raster.
  void _paintScanlines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = scanlineTint
      ..strokeWidth = 1.0;

    for (var y = 0.0; y < size.height; y += 3.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  /// Radial vignette: darkens the corners and edges.
  void _paintVignette(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        math.sqrt(size.width * size.width + size.height * size.height) / 2;

    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          const Color(0x00000000),
          const Color(0x00000000),
          const Color(0x80000000),
        ],
        [0.0, 0.55, 1.0],
      );

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(CrtOverlayPainter oldDelegate) =>
      scanlineTint != oldDelegate.scanlineTint;
}

/// A widget that layers CRT visual effects over its [child].
///
/// Adds a phosphor bloom glow (colored by [glowColor]) around the game area,
/// themed scanlines, and a corner vignette for an authentic retro feel.
class CrtOverlay extends StatelessWidget {
  final Widget child;

  /// Phosphor glow color for the bloom box-shadow. Defaults to green.
  final Color glowColor;

  /// Scanline tint color. Defaults to a dark green.
  final Color scanlineTint;

  const CrtOverlay({
    super.key,
    required this.child,
    this.glowColor = const Color(0x1833CC33),
    this.scanlineTint = const Color(0x18001A00),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 30,
            spreadRadius: 8,
          ),
        ],
        border: Border.all(
          color: const Color(0x30666666),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            child,
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: CrtOverlayPainter(scanlineTint: scanlineTint),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
