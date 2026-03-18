import 'package:flutter/material.dart';
import 'package:snake_game_core/snake_game_core.dart';

/// A translucent on-screen D-pad for touch/mobile devices.
///
/// Positioned in the bottom-right corner, it fires [InputAction] values
/// through [onInput] when the user taps one of the four directional buttons.
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
            // Up
            Align(
              alignment: Alignment.topCenter,
              child: _DpadButton(
                icon: Icons.keyboard_arrow_up,
                semanticLabel: 'Move up',
                onTap: () => onInput(InputAction.moveUp),
              ),
            ),
            // Down
            Align(
              alignment: Alignment.bottomCenter,
              child: _DpadButton(
                icon: Icons.keyboard_arrow_down,
                semanticLabel: 'Move down',
                onTap: () => onInput(InputAction.moveDown),
              ),
            ),
            // Left
            Align(
              alignment: Alignment.centerLeft,
              child: _DpadButton(
                icon: Icons.keyboard_arrow_left,
                semanticLabel: 'Move left',
                onTap: () => onInput(InputAction.moveLeft),
              ),
            ),
            // Right
            Align(
              alignment: Alignment.centerRight,
              child: _DpadButton(
                icon: Icons.keyboard_arrow_right,
                semanticLabel: 'Move right',
                onTap: () => onInput(InputAction.moveRight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DpadButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  const _DpadButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x44FFFFFF)),
          ),
          child: Icon(icon, color: const Color(0x88FFFFFF), size: 32),
        ),
      ),
    );
  }
}
