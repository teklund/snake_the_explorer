import 'dart:async';

import 'package:flutter/material.dart';
import 'package:snake_game_core/snake_game_core.dart';

/// A translucent on-screen D-pad for touch/mobile devices.
///
/// Positioned in the bottom-right corner, it fires [InputAction] values
/// through [onInput] when the user taps or holds one of the four directional
/// buttons. Holding a button repeats the action after an initial delay,
/// matching standard key-repeat behaviour.
class DpadWidget extends StatelessWidget {
  final void Function(InputAction action) onInput;

  const DpadWidget({super.key, required this.onInput});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Directional controls',
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: _DpadButton(
                icon: Icons.keyboard_arrow_up,
                semanticLabel: 'Move up',
                action: InputAction.moveUp,
                onInput: onInput,
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _DpadButton(
                icon: Icons.keyboard_arrow_down,
                semanticLabel: 'Move down',
                action: InputAction.moveDown,
                onInput: onInput,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _DpadButton(
                icon: Icons.keyboard_arrow_left,
                semanticLabel: 'Move left',
                action: InputAction.moveLeft,
                onInput: onInput,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: _DpadButton(
                icon: Icons.keyboard_arrow_right,
                semanticLabel: 'Move right',
                action: InputAction.moveRight,
                onInput: onInput,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DpadButton extends StatefulWidget {
  final IconData icon;
  final String semanticLabel;
  final InputAction action;
  final void Function(InputAction) onInput;

  const _DpadButton({
    required this.icon,
    required this.semanticLabel,
    required this.action,
    required this.onInput,
  });

  @override
  State<_DpadButton> createState() => _DpadButtonState();
}

class _DpadButtonState extends State<_DpadButton> {
  Timer? _repeatTimer;
  bool _pressed = false;

  void _start() {
    if (!mounted) return;
    setState(() => _pressed = true);
    widget.onInput(widget.action); // Fire immediately on touch-down
    // After initial delay, start repeating (matches OS key-repeat cadence).
    _repeatTimer = Timer(const Duration(milliseconds: 400), () {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        if (mounted) widget.onInput(widget.action);
      });
    });
  }

  void _stop() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    if (mounted) setState(() => _pressed = false);
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _stop(),
        onTapCancel: _stop,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _pressed
                ? const Color(0x55FFFFFF)
                : const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _pressed
                  ? const Color(0x66FFFFFF)
                  : const Color(0x44FFFFFF),
            ),
          ),
          child: Icon(widget.icon, color: const Color(0x88FFFFFF), size: 32),
        ),
      ),
    );
  }
}
