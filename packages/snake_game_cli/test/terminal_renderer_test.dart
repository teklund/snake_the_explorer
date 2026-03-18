import 'dart:io';

import 'package:snake_game_cli/src/ansi_color_ext.dart';
import 'package:snake_game_cli/src/terminal_renderer.dart';
import 'package:snake_game_core/snake_game_core.dart';
import 'package:test/test.dart';

void main() {
  group('TerminalRenderer', () {
    late TerminalRenderer renderer;

    setUp(() {
      renderer = TerminalRenderer();
    });

    group('moveCursor', () {
      test('emits 1-based ANSI cursor position', () {
        renderer.moveCursor(0, 0);
        final output = _flush(renderer);
        expect(output, equals('\x1B[1;1H'));
      });

      test('offsets row and col by 1', () {
        renderer.moveCursor(4, 9);
        final output = _flush(renderer);
        expect(output, equals('\x1B[5;10H'));
      });
    });

    group('clearScreen', () {
      test('emits ANSI clear and home sequence', () {
        renderer.clearScreen();
        final output = _flush(renderer);
        expect(output, equals('\x1B[2J\x1B[H'));
      });
    });

    group('setColor', () {
      test('emits the correct ANSI code for each color', () {
        for (final color in AnsiColor.values) {
          final fresh = TerminalRenderer();
          fresh.setColor(color);
          final output = _flush(fresh);
          expect(output, equals(color.code), reason: '$color');
        }
      });
    });

    group('write', () {
      test('buffers plain text', () {
        renderer.write('hello');
        final output = _flush(renderer);
        expect(output, equals('hello'));
      });
    });

    group('flush', () {
      test('writes buffered content to stdout in one call', () {
        renderer.write('abc');
        renderer.write('def');
        final output = _flush(renderer);
        expect(output, equals('abcdef'));
      });

      test('does nothing when buffer is empty', () {
        final output = _flush(renderer);
        expect(output, isEmpty);
      });

      test('clears buffer after flushing', () {
        renderer.write('first');
        _flush(renderer);

        final second = _flush(renderer);
        expect(second, isEmpty);
      });
    });

    group('hideCursor', () {
      test('writes hide-cursor escape directly to stdout', () {
        final output = _captureStdout(() => renderer.hideCursor());
        expect(output, equals('\x1B[?25l'));
      });
    });

    group('showCursor', () {
      test('writes show-cursor escape directly to stdout', () {
        final output = _captureStdout(() => renderer.showCursor());
        expect(output, equals('\x1B[?25h'));
      });
    });

    group('combined frame', () {
      test('batches multiple operations into a single flush', () {
        renderer.clearScreen();
        renderer.moveCursor(0, 0);
        renderer.setColor(AnsiColor.green);
        renderer.write('Snake');
        renderer.setColor(AnsiColor.reset);

        final output = _flush(renderer);
        expect(
          output,
          equals(
            '\x1B[2J\x1B[H'
            '\x1B[1;1H'
            '\x1B[32m'
            'Snake'
            '\x1B[0m',
          ),
        );
      });
    });
  });
}

/// Flushes [renderer] and returns everything written to stdout.
String _flush(TerminalRenderer renderer) {
  final buf = StringBuffer();
  IOOverrides.runZoned(
    () => renderer.flush(),
    stdout: () => _BufferStdout(buf),
  );
  return buf.toString();
}

/// Captures direct stdout writes (not buffered ones).
String _captureStdout(void Function() action) {
  final buf = StringBuffer();
  IOOverrides.runZoned(
    action,
    stdout: () => _BufferStdout(buf),
  );
  return buf.toString();
}

/// Minimal [Stdout] implementation that records [write] calls.
final class _BufferStdout implements Stdout {
  _BufferStdout(this._buf);
  final StringBuffer _buf;

  @override
  void write(Object? object) => _buf.write(object);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
