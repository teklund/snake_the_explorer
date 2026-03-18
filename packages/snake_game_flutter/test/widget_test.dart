import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snake_game_core/snake_game_core.dart';
import 'package:snake_game_flutter/src/cell.dart';
import 'package:snake_game_flutter/src/flutter_renderer.dart';
import 'package:snake_game_flutter/src/game_color_map.dart';
import 'package:snake_game_flutter/src/widgets/console_grid_painter.dart';
import 'package:snake_game_flutter/src/widgets/crt_overlay.dart';
import 'package:snake_game_flutter/src/widgets/dpad_widget.dart';
import 'package:snake_game_flutter/src/widgets/particle_overlay.dart';

void main() {
  group('FlutterRenderer', () {
    test('write populates buffer at cursor position', () {
      final r = FlutterRenderer(columns: 10, rows: 5);
      r.moveCursor(2, 3);
      r.setColor(AnsiColor.green);
      r.write('AB');
      expect(r.buffer[2][3].character, 'A');
      expect(r.buffer[2][3].foreground, AnsiColor.green);
      expect(r.buffer[2][4].character, 'B');
    });

    test('clearScreen resets buffer', () {
      final r = FlutterRenderer(columns: 5, rows: 3);
      r.moveCursor(0, 0);
      r.write('X');
      r.clearScreen();
      expect(r.buffer[0][0].character, ' ');
    });

    test('flush calls onFlush callback', () {
      final r = FlutterRenderer(columns: 5, rows: 3);
      var called = false;
      r.onFlush = () => called = true;
      r.flush();
      expect(called, isTrue);
    });

    test('write ignores out-of-bounds positions', () {
      final r = FlutterRenderer(columns: 3, rows: 2);
      r.moveCursor(5, 0); // out of bounds row
      expect(() => r.write('X'), returnsNormally);
    });
  });

  group('mapAnsiColor', () {
    test('maps all enum values without throwing', () {
      for (final c in AnsiColor.values) {
        expect(() => mapAnsiColor(c), returnsNormally);
      }
    });

    test('green maps to a green-ish color', () {
      final color = mapAnsiColor(AnsiColor.green);
      expect(color.g, greaterThan(color.r));
    });
  });

  group('ConsoleGridPainter', () {
    test('shouldRepaint always returns true', () {
      final buffer = List.generate(3, (_) => List.generate(5, (_) => Cell()));
      final painter = ConsoleGridPainter(
        buffer: buffer,
        cellWidth: 10,
        cellHeight: 18,
      );
      expect(painter.shouldRepaint(painter), isTrue);
    });
  });

  group('CrtOverlay', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CrtOverlay(
            child: SizedBox(width: 100, height: 100),
          ),
        ),
      );
      expect(find.byType(CrtOverlay), findsOneWidget);
      expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
    });
  });

  group('DpadWidget', () {
    testWidgets('renders four direction buttons', (tester) async {
      final actions = <InputAction>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DpadWidget(onInput: actions.add),
          ),
        ),
      );
      // DpadWidget uses GestureDetector with Icon children
      expect(find.byType(GestureDetector), findsAtLeastNWidgets(4));
    });

    testWidgets('tapping up fires moveUp', (tester) async {
      final actions = <InputAction>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DpadWidget(onInput: actions.add),
          ),
        ),
      );
      final upButton = find.byIcon(Icons.keyboard_arrow_up);
      expect(upButton, findsOneWidget);
      await tester.tap(upButton);
      expect(actions, contains(InputAction.moveUp));
    });

    testWidgets('tapping down fires moveDown', (tester) async {
      final actions = <InputAction>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DpadWidget(onInput: actions.add),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      expect(actions, contains(InputAction.moveDown));
    });
  });

  group('ParticleOverlay', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ParticleOverlay(
            cellWidth: 10,
            cellHeight: 18,
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      );
      expect(find.byType(ParticleOverlay), findsOneWidget);
    });

    testWidgets('spawnEvent does not throw', (tester) async {
      final key = GlobalKey<ParticleOverlayState>();
      await tester.pumpWidget(
        MaterialApp(
          home: ParticleOverlay(
            key: key,
            cellWidth: 10,
            cellHeight: 18,
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      );
      // Spawn all event types without crashing
      for (final event in GameEvent.values) {
        key.currentState!.spawnEvent(event, col: 5, row: 5);
      }
      await tester.pump(const Duration(milliseconds: 16));
      // Just verify no exception was thrown
    });
  });

  group('GameStats', () {
    test('default values are zero', () {
      const stats = GameStats();
      expect(stats.foodsEaten, 0);
      expect(stats.bonusesEaten, 0);
      expect(stats.maxCombo, 0);
      expect(stats.maxLength, 0);
      expect(stats.portalsUsed, 0);
    });
  });
}
