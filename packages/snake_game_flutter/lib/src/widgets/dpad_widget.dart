import 'dart:async';

import 'package:flutter/material.dart';
import 'package:snake_game_core/snake_game_core.dart';

/// A translucent on-screen D-pad for touch/mobile devices.
///
/// Positioned in the bottom-right corner, it fires [InputAction] values
/// through [onInput] when the user taps one of the four directional buttons.
/// Holding a button repeats the action at [_repeatInterval] intervals.
class DpadWidget extends StatelessWidget {
  final void Function(InputAction action) onInput;

  const DpadWidget({super.key, required this.onInput});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Directional controls',
      child: SizedBox(
        width: 180,
        height: 180,
        child: Stack(
          children: [
            // Up
            Align(
              alignment: Alignment.topCenter,
              child: _DpadButton(
                icon: Icons.keyboard_arrow_up,
                semanticLabel: 'Move up',
                onInput: () => onInput(InputAction.moveUp),
              ),
            ),
            // Down
            Align(
              alignment: Alignment.bottomCenter,
              child: _DpadButton(
                icon: Icons.keyboard_arrow_down,
                semanticLabel: 'Move down',
                onInput: () => onInput(InputAction.moveDown),
              ),
            ),
            // Left
            Align(
              alignment: Alignment.centerLeft,
              child: _DpadButton(
                icon: Icons.keyboard_arrow_left,
                semanticLabel: 'Move left',
                onInput: () => onInput(InputAction.moveLeft),
              ),
            ),
            // Right
            Align(
              alignment: Alignment.centerRight,
              child: _DpadButton(
                icon: Icons.keyboard_arrow_right,
                semanticLabel: 'Move right',
                onInput: () => onInput(InputAction.moveRight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single D-pad directional button with press-and-hold repeat support.
class _DpadButton extends StatefulWidget {
  final IconData icon;
  final String semanticLabel;

  /// Called immediately on press and then repeatedly while held.
  final VoidCallback onInput;

  const _DpadButton({
    required this.icon,
    required this.semanticLabel,
    required this.onInput,
  });

  @override
  State<_DpadButton> createState() => _DpadButtonState();
}

class _DpadButtonState extends State<_DpadButton> {
  /// Delay before the repeat timer starts (ms).
  static const _repeatInterval = Duration(milliseconds: 120);

  Timer? _repeatTimer;

  void _startRepeat() {
    _stopRepeat();
    widget.onInput();
    _repeatTimer = Timer.periodic(_repeatInterval, (_) => widget.onInput());
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => _startRepeat(),
        onTapUp: (_) => _stopRepeat(),
        onTapCancel: _stopRepeat,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x44FFFFFF)),
          ),
          child: Icon(widget.icon, color: const Color(0x88FFFFFF), size: 36),
        ),
      ),
    );
  }
}
