import 'package:snake_game_core/snake_game_core.dart';
import 'package:test/test.dart';

void main() {
  group('Direction', () {
    test('delta returns correct vector for each direction', () {
      expect(Direction.up.delta, equals(const Vector2(0, -1)));
      expect(Direction.down.delta, equals(const Vector2(0, 1)));
      expect(Direction.left.delta, equals(const Vector2(-1, 0)));
      expect(Direction.right.delta, equals(const Vector2(1, 0)));
    });

    test('isOppositeOf returns true for opposite pairs', () {
      expect(Direction.up.isOppositeOf(Direction.down), isTrue);
      expect(Direction.down.isOppositeOf(Direction.up), isTrue);
      expect(Direction.left.isOppositeOf(Direction.right), isTrue);
      expect(Direction.right.isOppositeOf(Direction.left), isTrue);
    });

    test('isOppositeOf returns false for non-opposite pairs', () {
      expect(Direction.up.isOppositeOf(Direction.left), isFalse);
      expect(Direction.up.isOppositeOf(Direction.right), isFalse);
      expect(Direction.up.isOppositeOf(Direction.up), isFalse);
    });
  });
}
