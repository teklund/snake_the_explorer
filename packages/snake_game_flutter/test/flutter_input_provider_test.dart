import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snake_game_core/snake_game_core.dart';
import 'package:snake_game_flutter/src/flutter_input_provider.dart';

/// Creates a [KeyDownEvent] for the given logical key.
KeyDownEvent _down(LogicalKeyboardKey key) => KeyDownEvent(
      logicalKey: key,
      physicalKey: PhysicalKeyboardKey.keyA, // physical key unused by provider
      timeStamp: Duration.zero,
    );

void main() {
  late FlutterInputProvider provider;

  setUp(() => provider = FlutterInputProvider());

  void press(LogicalKeyboardKey key) => provider.handleKeyEvent(_down(key));

  group('Arrow keys', () {
    test('arrowUp → moveUp', () {
      press(LogicalKeyboardKey.arrowUp);
      expect(provider.poll(), InputAction.moveUp);
    });

    test('arrowDown → moveDown', () {
      press(LogicalKeyboardKey.arrowDown);
      expect(provider.poll(), InputAction.moveDown);
    });

    test('arrowLeft → moveLeft', () {
      press(LogicalKeyboardKey.arrowLeft);
      expect(provider.poll(), InputAction.moveLeft);
    });

    test('arrowRight → moveRight', () {
      press(LogicalKeyboardKey.arrowRight);
      expect(provider.poll(), InputAction.moveRight);
    });
  });

  group('WASD keys', () {
    test('W → moveUp', () {
      press(LogicalKeyboardKey.keyW);
      expect(provider.poll(), InputAction.moveUp);
    });

    test('S → moveDown', () {
      press(LogicalKeyboardKey.keyS);
      expect(provider.poll(), InputAction.moveDown);
    });

    test('A → moveLeft', () {
      press(LogicalKeyboardKey.keyA);
      expect(provider.poll(), InputAction.moveLeft);
    });

    test('D → moveRight', () {
      press(LogicalKeyboardKey.keyD);
      expect(provider.poll(), InputAction.moveRight);
    });
  });

  group('Numpad keys', () {
    test('numpad8 → moveUp', () {
      press(LogicalKeyboardKey.numpad8);
      expect(provider.poll(), InputAction.moveUp);
    });

    test('numpad2 → moveDown', () {
      press(LogicalKeyboardKey.numpad2);
      expect(provider.poll(), InputAction.moveDown);
    });

    test('numpad4 → moveLeft', () {
      press(LogicalKeyboardKey.numpad4);
      expect(provider.poll(), InputAction.moveLeft);
    });

    test('numpad6 → moveRight', () {
      press(LogicalKeyboardKey.numpad6);
      expect(provider.poll(), InputAction.moveRight);
    });
  });

  group('Gamepad buttons', () {
    test('gameButtonA → confirm', () {
      press(LogicalKeyboardKey.gameButtonA);
      expect(provider.poll(), InputAction.confirm);
    });

    test('gameButtonX → confirm', () {
      press(LogicalKeyboardKey.gameButtonX);
      expect(provider.poll(), InputAction.confirm);
    });

    test('gameButtonB → quit', () {
      press(LogicalKeyboardKey.gameButtonB);
      expect(provider.poll(), InputAction.quit);
    });

    test('gameButtonSelect → pause', () {
      press(LogicalKeyboardKey.gameButtonSelect);
      expect(provider.poll(), InputAction.pause);
    });

    test('gameButtonStart → confirm', () {
      press(LogicalKeyboardKey.gameButtonStart);
      expect(provider.poll(), InputAction.confirm);
    });
  });

  group('Other keys', () {
    test('P → pause', () {
      press(LogicalKeyboardKey.keyP);
      expect(provider.poll(), InputAction.pause);
    });

    test('Q → quit', () {
      press(LogicalKeyboardKey.keyQ);
      expect(provider.poll(), InputAction.quit);
    });

    test('Escape → quit', () {
      press(LogicalKeyboardKey.escape);
      expect(provider.poll(), InputAction.quit);
    });

    test('Enter → confirm', () {
      press(LogicalKeyboardKey.enter);
      expect(provider.poll(), InputAction.confirm);
    });

    test('Space → confirm', () {
      press(LogicalKeyboardKey.space);
      expect(provider.poll(), InputAction.confirm);
    });

    test('unmapped key produces no action', () {
      press(LogicalKeyboardKey.keyZ);
      expect(provider.poll(), isNull);
    });
  });

  group('Queue behaviour', () {
    test('actions queue in order', () {
      press(LogicalKeyboardKey.arrowUp);
      press(LogicalKeyboardKey.arrowRight);
      expect(provider.poll(), InputAction.moveUp);
      expect(provider.poll(), InputAction.moveRight);
      expect(provider.poll(), isNull);
    });

    test('restore clears all queued actions', () {
      press(LogicalKeyboardKey.arrowUp);
      press(LogicalKeyboardKey.arrowDown);
      provider.restore();
      expect(provider.poll(), isNull);
    });

    test('handleSwipe enqueues action directly', () {
      provider.handleSwipe(InputAction.moveLeft);
      expect(provider.poll(), InputAction.moveLeft);
    });

    test('KeyUpEvent is ignored', () {
      provider.handleKeyEvent(KeyUpEvent(
        logicalKey: LogicalKeyboardKey.arrowUp,
        physicalKey: PhysicalKeyboardKey.arrowUp,
        timeStamp: Duration.zero,
      ));
      expect(provider.poll(), isNull);
    });
  });
}
