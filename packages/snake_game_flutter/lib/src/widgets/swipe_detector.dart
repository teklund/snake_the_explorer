import 'package:flutter/widgets.dart';
import 'package:snake_game_core/snake_game_core.dart';

/// Wraps a child widget and detects swipe gestures, converting them to
/// [InputAction] values via the [onSwipe] callback. Useful for mobile play.
class SwipeDetector extends StatelessWidget {
  final Widget child;
  final void Function(InputAction action) onSwipe;

  const SwipeDetector({super.key, required this.child, required this.onSwipe});

  @override
  Widget build(BuildContext context) {
    Offset? start;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) => start = d.globalPosition,
      onPanEnd: (d) {
        if (start == null) return;
        final velocity = d.velocity.pixelsPerSecond;
        // Ignore accidental slow drags; require a deliberate swipe speed.
        if (velocity.distance >= 150.0) {
          if (velocity.dx.abs() > velocity.dy.abs()) {
            onSwipe(velocity.dx > 0 ? InputAction.moveRight : InputAction.moveLeft);
          } else {
            onSwipe(velocity.dy > 0 ? InputAction.moveDown : InputAction.moveUp);
          }
        }
        start = null;
      },
      onTap: () => onSwipe(InputAction.confirm),
      child: child,
    );
  }
}
