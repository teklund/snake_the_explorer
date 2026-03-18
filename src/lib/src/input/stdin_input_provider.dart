import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'input_action.dart';
import 'input_provider.dart';

final class StdinInputProvider implements InputProvider {
  final Queue<InputAction> _queue = Queue();
  StreamSubscription<List<int>>? _subscription;

  bool _rawModeActive = false;

  @override
  void init() {
    try {
      stdin.lineMode = false;
      stdin.echoMode = false;
      _rawModeActive = true;
    } on StdinException {
      // Not a real TTY (e.g. piped input in tests) — input will be no-ops.
    }
    _subscription = stdin.listen(_onBytes);
  }

  void _onBytes(List<int> bytes) {
    final action = _mapBytes(bytes);
    if (action != null) _queue.add(action);
  }

  InputAction? _mapBytes(List<int> bytes) {
    if (bytes.isEmpty) return null;

    // Arrow keys: ESC [ A/B/C/D
    if (bytes.length >= 3 && bytes[0] == 27 && bytes[1] == 91) {
      return switch (bytes[2]) {
        65 => InputAction.moveUp,
        66 => InputAction.moveDown,
        67 => InputAction.moveRight,
        68 => InputAction.moveLeft,
        _ => null,
      };
    }

    // Bare ESC key
    if (bytes.length == 1 && bytes[0] == 27) return InputAction.quit;

    return switch (bytes[0]) {
      119 || 87 => InputAction.moveUp, // w / W
      115 || 83 => InputAction.moveDown, // s / S
      97 || 65 => InputAction.moveLeft, // a / A
      100 || 68 => InputAction.moveRight, // d / D
      113 || 81 => InputAction.quit, // q / Q
      112 || 80 => InputAction.pause, // p / P
      13 || 10 => InputAction.confirm, // Enter (\r or \n — macOS raw mode can send either)
      _ => null,
    };
  }

  @override
  InputAction? poll() => _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void restore() {
    _subscription?.cancel();
    if (_rawModeActive) {
      try {
        stdin.lineMode = true;
        stdin.echoMode = true;
      } on StdinException {
        // Already gone — ignore.
      }
      _rawModeActive = false;
    }
  }
}
