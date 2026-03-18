import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Paints CRT monitor effects on top of the game canvas:
/// - Horizontal scanlines
/// - Subtle phosphor glow (bloom)
/// - Corner vignette darkening
/// - Slight screen curvature illusion via radial gradient
final class CrtOverlayPainter extends CustomPainter {
  const CrtOverlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _paintScanlines(canvas, size);
    _paintVignette(canvas, size);
  }

  /// Semi-transparent horizontal lines every 2 pixels to simulate CRT raster.
  void _paintScanlines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x18000000)
      ..strokeWidth = 1.0;

    for (var y = 0.0; y < size.height; y += 3.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  /// Radial vignette: darkens the corners and edges.
  void _paintVignette(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.sqrt(size.width * size.width + size.height * size.height) / 2;

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
  bool shouldRepaint(CrtOverlayPainter oldDelegate) => false;
}

/// A widget that layers CRT visual effects over its [child].
class CrtOverlay extends StatelessWidget {
  final Widget child;

  const CrtOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: const CrtOverlayPainter(),
            ),
          ),
        ),
      ],
    );
  }
}
