import 'dart:io';

import 'package:snake_game_core/snake_game_core.dart';

import 'ansi_color_ext.dart';

/// Buffers all writes for a frame and flushes them in a single [stdout.write]
/// call to minimise flicker and system-call overhead.
final class TerminalRenderer implements Renderer {
  final StringBuffer _buf = StringBuffer();

  void _emit(String s) => _buf.write(s);

  /// Flush the in-memory buffer to stdout. Call once at the end of every frame.
  @override
  void flush() {
    if (_buf.isEmpty) return;
    stdout.write(_buf.toString());
    _buf.clear();
  }

  @override
  void moveCursor(int row, int col) =>
      _emit('\x1B[${row + 1};${col + 1}H');

  @override
  void write(String text) => _emit(text);

  @override
  void clearScreen() => _emit('\x1B[2J\x1B[H');

  @override
  void hideCursor() {
    stdout.write('\x1B[?25l');
  }

  @override
  void showCursor() {
    stdout.write('\x1B[?25h');
  }

  @override
  void setColor(AnsiColor color) => _emit(color.code);

  @override
  void restore() {
    showCursor();
    stdout.write('\x1B[${stdout.terminalLines};0H\n');
  }
}
