import 'package:snake_game_cli/src/ansi_color_ext.dart';
import 'package:snake_game_core/snake_game_core.dart';
import 'package:test/test.dart';

void main() {
  group('AnsiColorCode extension', () {
    test('reset produces ESC[0m', () {
      expect(AnsiColor.reset.code, equals('\x1B[0m'));
    });

    test('green produces ESC[32m', () {
      expect(AnsiColor.green.code, equals('\x1B[32m'));
    });

    test('brightGreen produces ESC[92m', () {
      expect(AnsiColor.brightGreen.code, equals('\x1B[92m'));
    });

    test('red produces ESC[31m', () {
      expect(AnsiColor.red.code, equals('\x1B[31m'));
    });

    test('yellow produces ESC[33m', () {
      expect(AnsiColor.yellow.code, equals('\x1B[33m'));
    });

    test('cyan produces ESC[36m', () {
      expect(AnsiColor.cyan.code, equals('\x1B[36m'));
    });

    test('magenta produces ESC[95m', () {
      expect(AnsiColor.magenta.code, equals('\x1B[95m'));
    });

    test('darkGray produces ESC[90m', () {
      expect(AnsiColor.darkGray.code, equals('\x1B[90m'));
    });

    test('every AnsiColor value has a code', () {
      for (final color in AnsiColor.values) {
        expect(color.code, isNotEmpty, reason: '$color should have a code');
        expect(
          color.code,
          startsWith('\x1B['),
          reason: '$color code should start with ESC[',
        );
        expect(
          color.code,
          endsWith('m'),
          reason: '$color code should end with m',
        );
      }
    });

    test('all codes are unique', () {
      final codes = AnsiColor.values.map((c) => c.code).toList();
      expect(codes.toSet().length, equals(codes.length));
    });
  });
}
