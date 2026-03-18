final class Vector2 {
  final int x;
  final int y;

  const Vector2(this.x, this.y);

  Vector2 operator +(Vector2 other) => Vector2(x + other.x, y + other.y);

  @override
  bool operator ==(Object other) =>
      other is Vector2 && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vector2($x, $y)';
}
