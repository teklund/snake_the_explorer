import 'dart:ui';

import 'package:snake_game_core/snake_game_core.dart';

import 'cell.dart';

/// A [Renderer] that writes to a 2D cell buffer instead of stdout.
/// After [flush], the [onFlush] callback fires so the widget can repaint.
final class FlutterRenderer implements Renderer {
  final int columns;
  final int rows;
  late List<List<Cell>> _buffer;
  AnsiColor _currentColor = AnsiColor.reset;
  int _cursorRow = 0;
  int _cursorCol = 0;
  VoidCallback? onFlush;

  FlutterRenderer({required this.columns, required this.rows}) {
    _buffer = _emptyBuffer();
  }

  List<List<Cell>> _emptyBuffer() => List.generate(
        rows,
        (_) => List.generate(columns, (_) => Cell()),
      );

  /// The current frame buffer for painting.
  List<List<Cell>> get buffer => _buffer;

  @override
  void moveCursor(int row, int col) {
    _cursorRow = row;
    _cursorCol = col;
  }

  @override
  void write(String text) {
    for (var i = 0; i < text.length; i++) {
      final col = _cursorCol + i;
      if (_cursorRow >= 0 && _cursorRow < rows && col >= 0 && col < columns) {
        _buffer[_cursorRow][col]
          ..character = text[i]
          ..foreground = _currentColor;
      }
    }
  }

  @override
  void clearScreen() {
    _buffer = _emptyBuffer();
    _cursorRow = 0;
    _cursorCol = 0;
  }

  @override
  void setColor(AnsiColor color) {
    _currentColor = color;
  }

  @override
  void flush() {
    onFlush?.call();
  }

  @override
  void hideCursor() {}

  @override
  void showCursor() {}

  @override
  void restore() {}
}
