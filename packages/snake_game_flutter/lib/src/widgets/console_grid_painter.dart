import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:snake_game_core/snake_game_core.dart';

import '../cell.dart';
import '../crt_theme.dart';
import '../game_color_map.dart';

/// A color-run: a contiguous horizontal span of characters sharing the same
/// foreground color within a single row.
final class _ColorRun {
  final int row;
  final int startCol;
  final String text;
  final AnsiColor color;

  const _ColorRun({
    required this.row,
    required this.startCol,
    required this.text,
    required this.color,
  });
}

/// Paints the cell buffer as a monospace character grid.
///
/// Optimizations over the naive per-cell approach:
/// 1. Batches consecutive same-color non-space characters into single
///    [TextPainter] calls (dramatically fewer layout + paint operations).
/// 2. Reuses [TextPainter] instances across frames via a cache keyed on
///    (text, color, fontSize).
final class ConsoleGridPainter extends CustomPainter {
  final List<List<Cell>> buffer;
  final double cellWidth;
  final double cellHeight;
  final String fontFamily;
  final CrtTheme theme;

  /// Shared cache: key → TextPainter. Cleared when it grows too large.
  static final Map<int, TextPainter> _cache = {};
  static const _maxCacheSize = 2048;

  /// Explicitly clears the text painter cache, e.g. after a theme change.
  static void clearCache() => _cache.clear();

  /// Whether the cursor should be drawn.
  final bool cursorVisible;

  /// The row position of the cursor in the grid.
  final int cursorRow;

  /// The column position of the cursor in the grid.
  final int cursorCol;

  /// Blink phase from 0.0 to 1.0. The cursor is shown when >= 0.5.
  final double blinkPhase;

  ConsoleGridPainter({
    required this.buffer,
    required this.cellWidth,
    required this.cellHeight,
    this.fontFamily = 'JetBrainsMono',
    this.theme = CrtTheme.greenPhosphor,
    this.cursorVisible = false,
    this.cursorRow = 0,
    this.cursorCol = 0,
    this.blinkPhase = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fontSize = cellHeight * 0.85;
    final runs = _buildRuns();

    for (final run in runs) {
      final tp = _getOrCreate(run.text, run.color, fontSize);
      final x = (run.startCol * cellWidth).roundToDouble();
      final verticalOffset =
          ((cellHeight - tp.height) / 2).roundToDouble();
      final y = (run.row * cellHeight + verticalOffset).roundToDouble();
      tp.paint(canvas, Offset(x, y));
    }

    if (_cache.length > _maxCacheSize) {
      _cache.clear();
    }

    // Draw blinking block cursor when visible and in the "on" phase.
    if (cursorVisible &&
        blinkPhase >= 0.5 &&
        cursorRow >= 0 &&
        cursorRow < buffer.length &&
        cursorCol >= 0 &&
        cursorCol < (buffer.isEmpty ? 0 : buffer[0].length)) {
      final cursorPaint = Paint()
        ..color = theme.mapColor(AnsiColor.green).withAlpha(200);
      final cursorRect = Rect.fromLTWH(
        cursorCol * cellWidth,
        cursorRow * cellHeight,
        cellWidth * 0.55, // half-block width (▌ style)
        cellHeight,
      );
      canvas.drawRect(cursorRect, cursorPaint);
    }
  }

  /// Walk the buffer row-by-row and merge adjacent same-color non-space cells
  /// into [_ColorRun] spans.
  List<_ColorRun> _buildRuns() {
    final runs = <_ColorRun>[];
    for (var row = 0; row < buffer.length; row++) {
      final cells = buffer[row];
      int? runStart;
      AnsiColor? runColor;
      final sb = StringBuffer();

      for (var col = 0; col < cells.length; col++) {
        final cell = cells[col];
        if (cell.character == ' ') {
          if (runStart != null) {
            runs.add(_ColorRun(
              row: row,
              startCol: runStart,
              text: sb.toString(),
              color: runColor!,
            ));
            sb.clear();
            runStart = null;
          }
          continue;
        }

        if (runStart != null && cell.foreground == runColor) {
          sb.write(cell.character);
        } else {
          if (runStart != null) {
            runs.add(_ColorRun(
              row: row,
              startCol: runStart,
              text: sb.toString(),
              color: runColor!,
            ));
            sb.clear();
          }
          runStart = col;
          runColor = cell.foreground;
          sb.write(cell.character);
        }
      }

      if (runStart != null) {
        runs.add(_ColorRun(
          row: row,
          startCol: runStart,
          text: sb.toString(),
          color: runColor!,
        ));
      }
    }
    return runs;
  }

  TextPainter _getOrCreate(String text, AnsiColor color, double fontSize) {
    final key = Object.hash(text, color, fontSize, theme);
    final cached = _cache[key];
    if (cached != null) return cached;

    final textColor = mapAnsiColor(color, theme);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: 1.0,
          letterSpacing: 0,
          fontFeatures: const [ui.FontFeature.tabularFigures()],
          foreground: Paint()
            ..color = textColor
            ..isAntiAlias = false,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    _cache[key] = tp;
    return tp;
  }

  @override
  bool shouldRepaint(ConsoleGridPainter oldDelegate) => true;
}
