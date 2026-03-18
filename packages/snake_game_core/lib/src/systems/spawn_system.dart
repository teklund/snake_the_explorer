import 'dart:math';

import '../entities/vector2.dart';

/// Holds all spawnable item state and lifecycle logic, extracted from
/// GameplayScene to keep that file focused on movement and scene transitions.
final class SpawnSystem {
  final Random _random;

  // Bonus food
  Vector2? bonusFood;
  int bonusCountdown = 0;
  int ticksSinceLastBonus = 0;
  int bonusFlashTick = 0;
  Vector2? prevBonusFood;

  // Shrink pill
  Vector2? shrinkPill;
  int shrinkCountdown = 0;
  int ticksSinceLastShrink = 0;
  Vector2? prevShrinkPill;

  // Portals
  Vector2? portalA;
  Vector2? portalB;
  int portalCountdown = 0;
  int ticksSinceLastPortal = 0;
  Vector2? prevPortalA;
  Vector2? prevPortalB;
  bool portalsNeedRender = false;

  // Obstacles
  int nextObstacleMilestoneIdx = 0;
  final Set<Vector2> obstacles = {};
  final List<Vector2> newObstacles = [];

  SpawnSystem({Random? random}) : _random = random ?? Random();

  /// Spawn a random position that doesn't overlap any occupied cells.
  Vector2 spawnFood({
    required int boardWidth,
    required int boardHeight,
    required List<Vector2> snakeBody,
    Vector2? exclude,
  }) {
    Vector2 pos;
    do {
      pos = Vector2(
        _random.nextInt(boardWidth),
        _random.nextInt(boardHeight),
      );
    } while (snakeBody.contains(pos) ||
        pos == exclude ||
        pos == shrinkPill ||
        pos == portalA ||
        pos == portalB ||
        obstacles.contains(pos));
    return pos;
  }

  /// Tick bonus food lifecycle. Returns true if a new bonus spawned.
  bool tickBonusFood({required int spawnInterval, required int lifetime}) {
    ticksSinceLastBonus++;
    bonusFlashTick++;
    if (bonusFood == null && ticksSinceLastBonus >= spawnInterval) {
      return true; // caller should spawn via spawnFood and assign bonusFood
    }
    if (bonusFood != null) {
      bonusCountdown--;
      if (bonusCountdown <= 0) {
        prevBonusFood = bonusFood;
        bonusFood = null;
        ticksSinceLastBonus = 0;
      }
    }
    return false;
  }

  /// Called after spawning bonus food externally.
  void onBonusFoodSpawned(Vector2 pos, int lifetime) {
    bonusFood = pos;
    bonusCountdown = lifetime;
    ticksSinceLastBonus = 0;
  }

  /// Tick shrink pill lifecycle. Returns true if a new pill should spawn.
  bool tickShrinkPill({required int spawnInterval, required int lifetime}) {
    ticksSinceLastShrink++;
    if (shrinkPill == null && ticksSinceLastShrink >= spawnInterval) {
      return true;
    }
    if (shrinkPill != null) {
      shrinkCountdown--;
      if (shrinkCountdown <= 0) {
        prevShrinkPill = shrinkPill;
        shrinkPill = null;
        ticksSinceLastShrink = 0;
      }
    }
    return false;
  }

  void onShrinkPillSpawned(Vector2 pos, int lifetime) {
    shrinkPill = pos;
    shrinkCountdown = lifetime;
    ticksSinceLastShrink = 0;
  }

  /// Tick portal lifecycle. Returns true if new portals should spawn.
  bool tickPortals({required int spawnInterval, required int lifetime}) {
    ticksSinceLastPortal++;
    if (portalA == null && ticksSinceLastPortal >= spawnInterval) {
      ticksSinceLastPortal = 0;
      return true;
    }
    if (portalA != null) {
      portalCountdown--;
      if (portalCountdown <= 0) {
        prevPortalA = portalA;
        prevPortalB = portalB;
        portalA = null;
        portalB = null;
        ticksSinceLastPortal = 0;
      }
    }
    return false;
  }

  /// Try to spawn a portal pair. Returns true if successful.
  bool trySpawnPortals({
    required int boardWidth,
    required int boardHeight,
    required List<Vector2> snakeBody,
    required Vector2 food,
    required int lifetime,
  }) {
    const attempts = 30;
    for (var i = 0; i < attempts; i++) {
      final a = Vector2(_random.nextInt(boardWidth), _random.nextInt(boardHeight));
      final b = Vector2(_random.nextInt(boardWidth), _random.nextInt(boardHeight));
      if (a == b) continue;
      bool isOccupied(Vector2 p) =>
          snakeBody.contains(p) ||
          p == food ||
          p == bonusFood ||
          p == shrinkPill ||
          obstacles.contains(p);
      if (!isOccupied(a) && !isOccupied(b)) {
        portalA = a;
        portalB = b;
        portalCountdown = lifetime;
        portalsNeedRender = true;
        return true;
      }
    }
    ticksSinceLastPortal = spawnInterval ~/ 2;
    return false;
  }

  static const spawnInterval = 45;

  /// Try to spawn an obstacle segment.
  void trySpawnObstacle({
    required int boardWidth,
    required int boardHeight,
    required List<Vector2> snakeBody,
    required Vector2 food,
    required int segmentLength,
  }) {
    final horizontal = _random.nextBool();
    const attempts = 20;
    for (var i = 0; i < attempts; i++) {
      final x = _random.nextInt(boardWidth - segmentLength);
      final y = _random.nextInt(boardHeight);
      final cells = List.generate(
        segmentLength,
        (k) => horizontal ? Vector2(x + k, y) : Vector2(x, y + k),
      );
      final blocked = cells.any(
        (c) =>
            snakeBody.contains(c) ||
            c == food ||
            c == bonusFood ||
            obstacles.contains(c),
      );
      if (!blocked) {
        obstacles.addAll(cells);
        newObstacles.addAll(cells);
        return;
      }
    }
  }

  /// Consume bonus food (player ate it).
  void consumeBonusFood() {
    prevBonusFood = bonusFood;
    bonusFood = null;
    ticksSinceLastBonus = 0;
  }

  /// Consume shrink pill (player ate it).
  void consumeShrinkPill() {
    prevShrinkPill = shrinkPill;
    shrinkPill = null;
    ticksSinceLastShrink = 0;
  }
}
