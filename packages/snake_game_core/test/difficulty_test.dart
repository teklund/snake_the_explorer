import 'package:snake_game_core/snake_game_core.dart';
import 'package:test/test.dart';

void main() {
  group('Difficulty', () {
    test('all enum values are covered', () {
      expect(Difficulty.values, hasLength(3));
      expect(
        Difficulty.values,
        containsAll([Difficulty.easy, Difficulty.normal, Difficulty.hard]),
      );
    });

    group('displayName', () {
      test('easy displays as Easy', () {
        expect(Difficulty.easy.displayName, equals('Easy'));
      });

      test('normal displays as Normal', () {
        expect(Difficulty.normal.displayName, equals('Normal'));
      });

      test('hard displays as Hard', () {
        expect(Difficulty.hard.displayName, equals('Hard'));
      });
    });

    group('speedMultiplier', () {
      test('easy has multiplier of 1.5 (slower)', () {
        expect(Difficulty.easy.speedMultiplier, equals(1.5));
      });

      test('normal has multiplier of 1.0 (baseline)', () {
        expect(Difficulty.normal.speedMultiplier, equals(1.0));
      });

      test('hard has multiplier of 0.7 (faster)', () {
        expect(Difficulty.hard.speedMultiplier, equals(0.7));
      });

      test('easy is slower than normal', () {
        expect(
          Difficulty.easy.speedMultiplier,
          greaterThan(Difficulty.normal.speedMultiplier),
        );
      });

      test('normal is slower than hard', () {
        expect(
          Difficulty.normal.speedMultiplier,
          greaterThan(Difficulty.hard.speedMultiplier),
        );
      });
    });
  });
}
