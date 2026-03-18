import 'dart:math';

import 'package:snake_game_core/snake_game_core.dart';
import 'package:test/test.dart';

void main() {
  group('SpawnSystem', () {
    group('spawnFood', () {
      test('returns position within board bounds', () {
        final spawns = SpawnSystem(random: Random(42));
        final pos = spawns.spawnFood(
          boardWidth: 20,
          boardHeight: 10,
          snakeBody: [const Vector2(5, 5)],
        );
        expect(pos.x, greaterThanOrEqualTo(0));
        expect(pos.x, lessThan(20));
        expect(pos.y, greaterThanOrEqualTo(0));
        expect(pos.y, lessThan(10));
      });

      test('avoids snake body', () {
        // Fill nearly all cells with snake so the only option is (0, 0).
        final body = <Vector2>[];
        for (var y = 0; y < 2; y++) {
          for (var x = 0; x < 2; x++) {
            if (x == 0 && y == 0) continue;
            body.add(Vector2(x, y));
          }
        }
        final spawns = SpawnSystem(random: Random(0));
        final pos = spawns.spawnFood(
          boardWidth: 2,
          boardHeight: 2,
          snakeBody: body,
        );
        expect(pos, equals(const Vector2(0, 0)));
      });

      test('avoids exclude position', () {
        // 1x2 board, snake at (0,0), exclude (0,1) — no valid position
        // Actually let's use 2x1: snake at (0,0), exclude at (1,0) — impossible,
        // but let's test that it avoids exclude with a solvable case.
        final spawns = SpawnSystem(random: Random(0));
        // 3x1 board, snake at (0,0), exclude (1,0) — must be (2,0)
        final body = [const Vector2(0, 0)];
        const exclude = Vector2(1, 0);
        final pos = spawns.spawnFood(
          boardWidth: 3,
          boardHeight: 1,
          snakeBody: body,
          exclude: exclude,
        );
        expect(pos, equals(const Vector2(2, 0)));
      });

      test('avoids obstacles', () {
        final spawns = SpawnSystem(random: Random(0));
        spawns.obstacles.add(const Vector2(1, 0));
        // 2x1 board, snake at nothing relevant, obstacle at (1,0)
        final pos = spawns.spawnFood(
          boardWidth: 2,
          boardHeight: 1,
          snakeBody: [const Vector2(99, 99)],
        );
        expect(pos, isNot(equals(const Vector2(1, 0))));
      });
    });

    group('tickBonusFood', () {
      test('returns true when spawn interval reached and no bonus active', () {
        final spawns = SpawnSystem();
        // Tick up to spawnInterval
        for (var i = 0; i < 19; i++) {
          expect(
            spawns.tickBonusFood(spawnInterval: 20, lifetime: 15),
            isFalse,
          );
        }
        // 20th tick should trigger spawn
        expect(
          spawns.tickBonusFood(spawnInterval: 20, lifetime: 15),
          isTrue,
        );
      });

      test('expires bonus food after countdown reaches zero', () {
        final spawns = SpawnSystem();
        spawns.onBonusFoodSpawned(const Vector2(5, 5), 3);
        expect(spawns.bonusFood, isNotNull);

        spawns.tickBonusFood(spawnInterval: 20, lifetime: 3); // countdown 2
        expect(spawns.bonusFood, isNotNull);

        spawns.tickBonusFood(spawnInterval: 20, lifetime: 3); // countdown 1
        expect(spawns.bonusFood, isNotNull);

        spawns.tickBonusFood(spawnInterval: 20, lifetime: 3); // countdown 0
        expect(spawns.bonusFood, isNull);
        expect(spawns.prevBonusFood, equals(const Vector2(5, 5)));
      });
    });

    group('tickShrinkPill', () {
      test('returns true at spawn interval', () {
        final spawns = SpawnSystem();
        for (var i = 0; i < 39; i++) {
          spawns.tickShrinkPill(spawnInterval: 40, lifetime: 20);
        }
        expect(
          spawns.tickShrinkPill(spawnInterval: 40, lifetime: 20),
          isTrue,
        );
      });

      test('expires pill after countdown', () {
        final spawns = SpawnSystem();
        spawns.onShrinkPillSpawned(const Vector2(3, 3), 2);

        spawns.tickShrinkPill(spawnInterval: 40, lifetime: 2);
        expect(spawns.shrinkPill, isNotNull);

        spawns.tickShrinkPill(spawnInterval: 40, lifetime: 2);
        expect(spawns.shrinkPill, isNull);
        expect(spawns.prevShrinkPill, equals(const Vector2(3, 3)));
      });
    });

    group('tickPortals', () {
      test('returns true at spawn interval', () {
        final spawns = SpawnSystem();
        for (var i = 0; i < 44; i++) {
          spawns.tickPortals(spawnInterval: 45, lifetime: 30);
        }
        expect(spawns.tickPortals(spawnInterval: 45, lifetime: 30), isTrue);
      });

      test('expires portals after countdown', () {
        final spawns = SpawnSystem();
        spawns.portalA = const Vector2(1, 1);
        spawns.portalB = const Vector2(8, 8);
        spawns.portalCountdown = 2;

        spawns.tickPortals(spawnInterval: 45, lifetime: 30); // countdown 1
        expect(spawns.portalA, isNotNull);

        spawns.tickPortals(spawnInterval: 45, lifetime: 30); // countdown 0
        expect(spawns.portalA, isNull);
        expect(spawns.portalB, isNull);
        expect(spawns.prevPortalA, equals(const Vector2(1, 1)));
        expect(spawns.prevPortalB, equals(const Vector2(8, 8)));
      });
    });

    group('trySpawnPortals', () {
      test('spawns two distinct portals on open board', () {
        final spawns = SpawnSystem(random: Random(42));
        final result = spawns.trySpawnPortals(
          boardWidth: 20,
          boardHeight: 10,
          snakeBody: [const Vector2(5, 5)],
          food: const Vector2(10, 5),
          lifetime: 30,
        );
        expect(result, isTrue);
        expect(spawns.portalA, isNotNull);
        expect(spawns.portalB, isNotNull);
        expect(spawns.portalA, isNot(equals(spawns.portalB)));
        expect(spawns.portalCountdown, equals(30));
        expect(spawns.portalsNeedRender, isTrue);
      });
    });

    group('consumeBonusFood', () {
      test('clears bonus and stores prev', () {
        final spawns = SpawnSystem();
        spawns.onBonusFoodSpawned(const Vector2(7, 7), 10);
        spawns.consumeBonusFood();

        expect(spawns.bonusFood, isNull);
        expect(spawns.prevBonusFood, equals(const Vector2(7, 7)));
        expect(spawns.ticksSinceLastBonus, equals(0));
      });
    });

    group('consumeShrinkPill', () {
      test('clears pill and stores prev', () {
        final spawns = SpawnSystem();
        spawns.onShrinkPillSpawned(const Vector2(2, 2), 10);
        spawns.consumeShrinkPill();

        expect(spawns.shrinkPill, isNull);
        expect(spawns.prevShrinkPill, equals(const Vector2(2, 2)));
        expect(spawns.ticksSinceLastShrink, equals(0));
      });
    });

    group('trySpawnObstacle', () {
      test('adds cells to obstacles set', () {
        final spawns = SpawnSystem(random: Random(42));
        spawns.trySpawnObstacle(
          boardWidth: 20,
          boardHeight: 10,
          snakeBody: [const Vector2(5, 5)],
          food: const Vector2(10, 5),
          segmentLength: 3,
        );
        expect(spawns.obstacles.length, equals(3));
        expect(spawns.newObstacles.length, equals(3));
      });
    });
  });
}
