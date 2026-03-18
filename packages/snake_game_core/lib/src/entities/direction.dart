import 'vector2.dart';

enum Direction {
  up,
  down,
  left,
  right;

  Vector2 get delta => switch (this) {
        Direction.up => const Vector2(0, -1),
        Direction.down => const Vector2(0, 1),
        Direction.left => const Vector2(-1, 0),
        Direction.right => const Vector2(1, 0),
      };

  bool isOppositeOf(Direction other) =>
      (this == Direction.up && other == Direction.down) ||
      (this == Direction.down && other == Direction.up) ||
      (this == Direction.left && other == Direction.right) ||
      (this == Direction.right && other == Direction.left);
}
