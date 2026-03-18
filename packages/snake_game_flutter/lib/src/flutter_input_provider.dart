import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:snake_game_core/snake_game_core.dart';

/// An [InputProvider] backed by Flutter keyboard events and gesture callbacks.
final class FlutterInputProvider implements InputProvider {
  final Queue<InputAction> _queue = Queue();

  @override
  void init() {}

  /// Called by the hosting widget's [KeyboardListener] on key events.
  void handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final action = _mapKey(event.logicalKey);
    if (action != null) _queue.add(action);
  }

  InputAction? _mapKey(LogicalKeyboardKey key) => switch (key) {
        // Keyboard
        LogicalKeyboardKey.arrowUp || LogicalKeyboardKey.keyW => InputAction.moveUp,
        LogicalKeyboardKey.arrowDown || LogicalKeyboardKey.keyS => InputAction.moveDown,
        LogicalKeyboardKey.arrowLeft || LogicalKeyboardKey.keyA => InputAction.moveLeft,
        LogicalKeyboardKey.arrowRight || LogicalKeyboardKey.keyD => InputAction.moveRight,
        LogicalKeyboardKey.keyQ || LogicalKeyboardKey.escape => InputAction.quit,
        LogicalKeyboardKey.keyP => InputAction.pause,
        LogicalKeyboardKey.enter || LogicalKeyboardKey.space => InputAction.confirm,
        // Gamepad D-pad (reported as keyboard keys on most controllers)
        LogicalKeyboardKey.gameButtonA => InputAction.confirm,
        LogicalKeyboardKey.gameButtonB => InputAction.quit,
        LogicalKeyboardKey.gameButtonSelect => InputAction.pause,
        LogicalKeyboardKey.gameButtonStart => InputAction.confirm,
        _ => null,
      };

  /// Enqueue an action from a swipe gesture or on-screen D-pad.
  void handleSwipe(InputAction action) {
    _queue.add(action);
  }

  @override
  InputAction? poll() => _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void restore() {
    _queue.clear();
  }
}
