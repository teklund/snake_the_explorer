import 'package:snake_game_core/snake_game_core.dart';
import 'package:test/test.dart';

void main() {
  group('Vector2', () {
    test('addition returns correct result', () {
      const a = Vector2(1, 2);
      const b = Vector2(3, 4);
      expect(a + b, equals(const Vector2(4, 6)));
    });

    test('equality holds for same coordinates', () {
      expect(const Vector2(5, 10), equals(const Vector2(5, 10)));
    });

    test('inequality holds for different coordinates', () {
      expect(const Vector2(1, 2), isNot(equals(const Vector2(2, 1))));
    });

    test('hashCode is consistent with equality', () {
      expect(const Vector2(3, 7).hashCode, equals(const Vector2(3, 7).hashCode));
    });
  });
}
