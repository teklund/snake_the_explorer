import 'dart:async';

import 'package:snake_game_cli/src/stdin_input_provider.dart';
import 'package:snake_game_core/snake_game_core.dart';
import 'package:test/test.dart';

void main() {
  group('StdinInputProvider', () {
    late StreamController<List<int>> controller;
    late StdinInputProvider provider;

    setUp(() {
      controller = StreamController<List<int>>();
      provider = StdinInputProvider.forTesting(controller.stream);
    });

    tearDown(() async {
      provider.restore();
      await controller.close();
    });

    Future<void> sendAndSettle(List<int> bytes) async {
      controller.add(bytes);
      // Allow the stream listener to process the event.
      await Future<void>.delayed(Duration.zero);
    }

    test('poll returns null when queue is empty', () {
      expect(provider.poll(), isNull);
    });

    // ---------------------------------------------------------------
    // Arrow keys (ESC [ A/B/C/D)
    // ---------------------------------------------------------------
    group('arrow keys', () {
      test('up arrow maps to moveUp', () async {
        await sendAndSettle([27, 91, 65]);
        expect(provider.poll(), equals(InputAction.moveUp));
      });

      test('down arrow maps to moveDown', () async {
        await sendAndSettle([27, 91, 66]);
        expect(provider.poll(), equals(InputAction.moveDown));
      });

      test('right arrow maps to moveRight', () async {
        await sendAndSettle([27, 91, 67]);
        expect(provider.poll(), equals(InputAction.moveRight));
      });

      test('left arrow maps to moveLeft', () async {
        await sendAndSettle([27, 91, 68]);
        expect(provider.poll(), equals(InputAction.moveLeft));
      });

      test('unknown arrow sequence is ignored', () async {
        await sendAndSettle([27, 91, 70]); // ESC [ F (End key)
        expect(provider.poll(), isNull);
      });
    });

    // ---------------------------------------------------------------
    // WASD keys
    // ---------------------------------------------------------------
    group('WASD keys', () {
      test('w maps to moveUp', () async {
        await sendAndSettle([119]); // 'w'
        expect(provider.poll(), equals(InputAction.moveUp));
      });

      test('W maps to moveUp', () async {
        await sendAndSettle([87]); // 'W'
        expect(provider.poll(), equals(InputAction.moveUp));
      });

      test('s maps to moveDown', () async {
        await sendAndSettle([115]); // 's'
        expect(provider.poll(), equals(InputAction.moveDown));
      });

      test('S maps to moveDown', () async {
        await sendAndSettle([83]); // 'S'
        expect(provider.poll(), equals(InputAction.moveDown));
      });

      test('a maps to moveLeft', () async {
        await sendAndSettle([97]); // 'a'
        expect(provider.poll(), equals(InputAction.moveLeft));
      });

      test('A maps to moveLeft', () async {
        await sendAndSettle([65]); // 'A'
        expect(provider.poll(), equals(InputAction.moveLeft));
      });

      test('d maps to moveRight', () async {
        await sendAndSettle([100]); // 'd'
        expect(provider.poll(), equals(InputAction.moveRight));
      });

      test('D maps to moveRight', () async {
        await sendAndSettle([68]); // 'D'
        expect(provider.poll(), equals(InputAction.moveRight));
      });
    });

    // ---------------------------------------------------------------
    // Special keys
    // ---------------------------------------------------------------
    group('special keys', () {
      test('bare ESC maps to quit', () async {
        await sendAndSettle([27]);
        expect(provider.poll(), equals(InputAction.quit));
      });

      test('q maps to quit', () async {
        await sendAndSettle([113]); // 'q'
        expect(provider.poll(), equals(InputAction.quit));
      });

      test('Q maps to quit', () async {
        await sendAndSettle([81]); // 'Q'
        expect(provider.poll(), equals(InputAction.quit));
      });

      test('p maps to pause', () async {
        await sendAndSettle([112]); // 'p'
        expect(provider.poll(), equals(InputAction.pause));
      });

      test('P maps to pause', () async {
        await sendAndSettle([80]); // 'P'
        expect(provider.poll(), equals(InputAction.pause));
      });

      test('Enter (\\r) maps to confirm', () async {
        await sendAndSettle([13]);
        expect(provider.poll(), equals(InputAction.confirm));
      });

      test('Enter (\\n) maps to confirm', () async {
        await sendAndSettle([10]);
        expect(provider.poll(), equals(InputAction.confirm));
      });
    });

    // ---------------------------------------------------------------
    // Unknown / empty input
    // ---------------------------------------------------------------
    group('unrecognised input', () {
      test('unknown single byte is ignored', () async {
        await sendAndSettle([0]); // NUL
        expect(provider.poll(), isNull);
      });

      test('empty byte list is ignored', () async {
        await sendAndSettle([]);
        expect(provider.poll(), isNull);
      });
    });

    // ---------------------------------------------------------------
    // Queue ordering
    // ---------------------------------------------------------------
    group('queue behaviour', () {
      test('multiple inputs are queued in order', () async {
        await sendAndSettle([119]); // w -> moveUp
        await sendAndSettle([115]); // s -> moveDown
        await sendAndSettle([97]); // a -> moveLeft

        expect(provider.poll(), equals(InputAction.moveUp));
        expect(provider.poll(), equals(InputAction.moveDown));
        expect(provider.poll(), equals(InputAction.moveLeft));
        expect(provider.poll(), isNull);
      });
    });

    // ---------------------------------------------------------------
    // restore
    // ---------------------------------------------------------------
    group('restore', () {
      test('cancels the subscription so new events are ignored', () async {
        provider.restore();
        await sendAndSettle([119]); // w
        expect(provider.poll(), isNull);
      });
    });
  });
}
