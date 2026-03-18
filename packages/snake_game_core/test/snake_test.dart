import 'package:snake_game_core/snake_game_core.dart';
import 'package:test/test.dart';

void main() {
  group('Snake', () {
    late Snake snake;

    setUp(() {
      snake = Snake(
        body: [const Vector2(5, 5), const Vector2(4, 5), const Vector2(3, 5)],
        direction: Direction.right,
      );
    });

    test('head returns first body segment', () {
      expect(snake.head, equals(const Vector2(5, 5)));
    });

    test('length returns body length', () {
      expect(snake.length, equals(3));
    });

    test('move advances head and drops tail', () {
      final moved = snake.move();
      expect(moved.head, equals(const Vector2(6, 5)));
      expect(moved.length, equals(3));
      expect(moved.body.last, equals(const Vector2(4, 5)));
    });

    test('grow advances head and keeps tail', () {
      final grown = snake.grow();
      expect(grown.head, equals(const Vector2(6, 5)));
      expect(grown.length, equals(4));
      expect(grown.body.last, equals(const Vector2(3, 5)));
    });

    test('turn ignores opposite direction', () {
      final turned = snake.turn(Direction.left);
      expect(turned.direction, equals(Direction.right));
    });

    test('turn accepts perpendicular direction', () {
      final turned = snake.turn(Direction.up);
      expect(turned.direction, equals(Direction.up));
    });

    test('shrink removes tail segments', () {
      final shrunk = snake.shrink(2);
      expect(shrunk.length, equals(1));
      expect(shrunk.head, equals(const Vector2(5, 5)));
    });

    test('shrink retains at least head', () {
      final shrunk = snake.shrink(100);
      expect(shrunk.length, equals(1));
    });

    test('isSelfColliding returns false for valid snake', () {
      expect(snake.isSelfColliding, isFalse);
    });

    test('isSelfColliding returns true when head overlaps body', () {
      final colliding = Snake(
        body: [const Vector2(4, 5), const Vector2(5, 5), const Vector2(4, 5)],
        direction: Direction.right,
      );
      expect(colliding.isSelfColliding, isTrue);
    });
  });
}
