import 'package:flutter/material.dart';

import '../cell.dart';
import '../game_color_map.dart';

/// Paints the cell buffer as a monospace character grid, emulating a CRT
/// terminal look on a dark background.
final class ConsoleGridPainter extends CustomPainter {
  final List<List<Cell>> buffer;
  final double cellWidth;
  final double cellHeight;
  final String fontFamily;

  ConsoleGridPainter({
    required this.buffer,
    required this.cellWidth,
    required this.cellHeight,
    this.fontFamily = 'monospace',
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var row = 0; row < buffer.length; row++) {
      final cells = buffer[row];
      for (var col = 0; col < cells.length; col++) {
        final cell = cells[col];
        if (cell.character == ' ') continue;

        final tp = TextPainter(
          text: TextSpan(
            text: cell.character,
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: cellHeight * 0.85,
              color: mapAnsiColor(cell.foreground),
              height: 1.0,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final x = col * cellWidth;
        final y = row * cellHeight;
        tp.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(ConsoleGridPainter oldDelegate) => true;
}
