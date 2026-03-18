import 'dart:math';

import '../entities/direction.dart';
import '../entities/snake.dart';
import '../entities/vector2.dart';
import '../input/input_action.dart';
import '../persistence/score_repository.dart';
import '../rendering/ansi_color.dart';
import '../rendering/renderer.dart';
import '../game_event.dart';
import '../game_stats.dart';
import '../systems/spawn_system.dart';
import '../time_provider.dart';
import 'game_mode.dart';
import 'game_over_scene.dart';
import 'scene.dart';

/// Optional callback for game events (sound, haptics, analytics, etc.).
///
/// Receives a [GameEventData] record containing the event type and the
/// grid column/row where the event occurred.
typedef GameEventCallback = void Function(GameEventData data);

// Bonus food appears every this many ticks and lasts this many ticks.
const _bonusSpawnInterval = 20;
const _bonusLifetime = 15;

// Shrink pill: appears every N ticks, lasts M ticks, removes K tail segments.
const _shrinkSpawnInterval = 40;
const _shrinkLifetime = 20;
const _shrinkAmount = 3;

// Time Attack duration in seconds.
const _timeAttackSeconds = 60;

// Obstacle milestones: one new obstacle segment added at each of these scores.
const _obstacleScoreMilestones = [5, 10, 15, 20, 30, 40, 50];
const _obstacleSegmentLength = 3;

// Ticks to show death-flash before transitioning to game over.
const _deathFlashDuration = 12;

// Combo: eat foods within N ticks to chain a score multiplier.
const _comboWindowTicks = 20;
const _comboTextDuration = 8;

// Portals
const _portalSpawnInterval = 45;
const _portalLifetime = 30;

final class GameplayScene extends Scene {
  static const _minBoardWidth = 20;
  static const _minBoardHeight = 10;
  static const _hudRows = 4;

  static const _baseMs = 150;
  static const _minMs = 50;

  final GameMode _mode;
  final ScoreRepository _scoreRepo;
  final TimeProvider _time;
  final int _boardColumns;
  final int _boardRows;
  late final int _boardWidth;
  late final int _boardHeight;
  final SpawnSystem _spawns;
  final GameEventCallback? _onEvent;

  Snake _snake;
  Vector2 _food;
  int _score = 0;
  final int _highScore;
  Vector2? _prevTail;

  // Combo multiplier
  int _comboCount = 0;
  int _ticksSinceLastFood = 0;
  int _comboTextTicks = 0;

  // Stats
  int _foodsEaten = 0;
  int _bonusesEaten = 0;
  int _maxCombo = 0;
  int _maxLength = 3;
  int _portalsUsed = 0;

  // Time Attack
  DateTime? _startTime;
  int _secondsLeft = _timeAttackSeconds;
  bool _isPaused = false;
  int _deathFlashTicks = 0;
  bool _needsFullRedraw = true;

  GameplayScene({
    Random? random,
    int highScore = 0,
    GameMode mode = GameMode.classic,
    required ScoreRepository scoreRepo,
    required int boardColumns,
    required int boardRows,
    TimeProvider time = const SystemTimeProvider(),
    GameEventCallback? onEvent,
  })  : _onEvent = onEvent,
        _highScore = highScore,
        _mode = mode,
        _scoreRepo = scoreRepo,
        _time = time,
        _boardColumns = boardColumns,
        _boardRows = boardRows,
        _spawns = SpawnSystem(random: random),
        _snake = Snake(
          body: [
            const Vector2(5, 5),
            const Vector2(4, 5),
            const Vector2(3, 5),
          ],
          direction: Direction.right,
        ),
        _food = const Vector2(10, 5) {
    _boardWidth = (_boardColumns - 2).clamp(_minBoardWidth, 120);
    _boardHeight = (_boardRows - _hudRows).clamp(_minBoardHeight, 40);
    if (_mode == GameMode.timeAttack) _startTime = _time.now();
  }

  @override
  Duration get tickDuration {
    if (_isPaused) return const Duration(milliseconds: 200);
    if (_deathFlashTicks > 0) return const Duration(milliseconds: 60);
    if (_mode == GameMode.timeAttack) return const Duration(milliseconds: 120);
    final level = (_score ~/ 5).clamp(0, 10);
    final ms = (_baseMs - level * 10).clamp(_minMs, _baseMs);
    return Duration(milliseconds: ms);
  }

  int get _level => (_score ~/ 5).clamp(0, 10);

  void _fireEvent(GameEvent event) {
    _onEvent?.call((event: event, col: _snake.head.x, row: _snake.head.y));
  }

  @override
  SceneTransition update(InputAction? input) {
    if (input == InputAction.quit) return const Quit();

    if (_deathFlashTicks > 0) {
      _deathFlashTicks--;
      if (_deathFlashTicks == 0) {
        final newHigh = _score > _highScore ? _score : _highScore;
        return GoTo(() => GameOverScene(
              score: _score,
              highScore: newHigh,
              mode: _mode,
              scoreRepo: _scoreRepo,
              boardColumns: _boardColumns,
              boardRows: _boardRows,
              onEvent: _onEvent,
              stats: GameStats(
                foodsEaten: _foodsEaten,
                bonusesEaten: _bonusesEaten,
                maxCombo: _maxCombo,
                maxLength: _maxLength,
                portalsUsed: _portalsUsed,
              ),
            ));
      }
      return const Stay();
    }

    if (input == InputAction.pause) {
      _isPaused = !_isPaused;
      _needsFullRedraw = true;
      return const Stay();
    }

    if (_isPaused) {
      if (input != null) {
        _isPaused = false;
        _needsFullRedraw = true;
      }
      return const Stay();
    }

    // Time Attack countdown
    if (_mode == GameMode.timeAttack && _startTime != null) {
      final elapsed = _time.now().difference(_startTime!);
      _secondsLeft = (_timeAttackSeconds - elapsed.inSeconds).clamp(0, _timeAttackSeconds);
      if (_secondsLeft == 0) {
        _deathFlashTicks = _deathFlashDuration;
        _needsFullRedraw = true;
        return const Stay();
      }
    }

    // Direction input
    final newDirection = switch (input) {
      InputAction.moveUp => Direction.up,
      InputAction.moveDown => Direction.down,
      InputAction.moveLeft => Direction.left,
      InputAction.moveRight => Direction.right,
      _ => null,
    };
    if (newDirection != null) _snake = _snake.turn(newDirection);

    // Tick spawnable lifecycles
    _tickSpawnables();

    // Move snake
    return _moveAndCollide();
  }

  void _tickSpawnables() {
    if (_spawns.tickShrinkPill(spawnInterval: _shrinkSpawnInterval, lifetime: _shrinkLifetime)) {
      final pos = _spawns.spawnFood(
        boardWidth: _boardWidth, boardHeight: _boardHeight,
        snakeBody: _snake.body, exclude: _spawns.bonusFood,
      );
      _spawns.onShrinkPillSpawned(pos, _shrinkLifetime);
    }

    if (_spawns.tickBonusFood(spawnInterval: _bonusSpawnInterval, lifetime: _bonusLifetime)) {
      final pos = _spawns.spawnFood(
        boardWidth: _boardWidth, boardHeight: _boardHeight, snakeBody: _snake.body,
      );
      _spawns.onBonusFoodSpawned(pos, _bonusLifetime);
    }

    _ticksSinceLastFood++;
    if (_comboTextTicks > 0) _comboTextTicks--;

    if (_spawns.tickPortals(spawnInterval: _portalSpawnInterval, lifetime: _portalLifetime)) {
      _spawns.trySpawnPortals(
        boardWidth: _boardWidth, boardHeight: _boardHeight,
        snakeBody: _snake.body, food: _food, lifetime: _portalLifetime,
      );
    }
  }

  SceneTransition _moveAndCollide() {
    final nextHead = _snake.head + _snake.direction.delta;

    final wrappedHead = _mode == GameMode.zen
        ? Vector2(
            (nextHead.x + _boardWidth) % _boardWidth,
            (nextHead.y + _boardHeight) % _boardHeight,
          )
        : nextHead;

    final atFood = wrappedHead == _food;
    final atBonus = _spawns.bonusFood != null && wrappedHead == _spawns.bonusFood;
    final atShrink = _spawns.shrinkPill != null && wrappedHead == _spawns.shrinkPill;

    if (atFood || atBonus || atShrink) {
      _handlePickup(atFood: atFood, atBonus: atBonus, atShrink: atShrink);
    } else {
      _prevTail = _snake.body.last;
      _snake = _snake.move();
    }

    // Zen mode wrap correction
    if (_mode == GameMode.zen && !atFood && !atBonus) {
      final raw = _snake.head;
      if (raw.x < 0 || raw.x >= _boardWidth || raw.y < 0 || raw.y >= _boardHeight) {
        _snake = Snake(
          body: [Vector2((raw.x + _boardWidth) % _boardWidth, (raw.y + _boardHeight) % _boardHeight), ..._snake.body.skip(1)],
          direction: _snake.direction,
        );
      }
    }

    // Portal teleport
    if (_spawns.portalA != null && _spawns.portalB != null) {
      final h = _snake.head;
      if (h == _spawns.portalA) {
        _snake = Snake(body: [_spawns.portalB!, ..._snake.body.skip(1)], direction: _snake.direction);
        _needsFullRedraw = true;
        _portalsUsed++;
        _fireEvent(GameEvent.portalUsed);
      } else if (h == _spawns.portalB) {
        _snake = Snake(body: [_spawns.portalA!, ..._snake.body.skip(1)], direction: _snake.direction);
        _needsFullRedraw = true;
        _portalsUsed++;
        _fireEvent(GameEvent.portalUsed);
      }
    }

    // Collision check
    final outOfBounds = _mode == GameMode.classic &&
        (_snake.head.x < 0 || _snake.head.x >= _boardWidth ||
         _snake.head.y < 0 || _snake.head.y >= _boardHeight);

    if (outOfBounds || _snake.isSelfColliding || _spawns.obstacles.contains(_snake.head)) {
      _deathFlashTicks = _deathFlashDuration;
      _needsFullRedraw = true;
      _fireEvent(GameEvent.death);
      return const Stay();
    }

    // Obstacle milestones
    if (_mode == GameMode.classic &&
        _spawns.nextObstacleMilestoneIdx < _obstacleScoreMilestones.length &&
        _score >= _obstacleScoreMilestones[_spawns.nextObstacleMilestoneIdx]) {
      _spawns.trySpawnObstacle(
        boardWidth: _boardWidth, boardHeight: _boardHeight,
        snakeBody: _snake.body, food: _food, segmentLength: _obstacleSegmentLength,
      );
      _spawns.nextObstacleMilestoneIdx++;
    }

    return const Stay();
  }

  void _handlePickup({required bool atFood, required bool atBonus, required bool atShrink}) {
    if (atBonus) {
      _score += 3;
      _bonusesEaten++;
      _spawns.consumeBonusFood();
      _snake = _snake.grow();
      _fireEvent(GameEvent.bonusEaten);
    } else if (atShrink) {
      _spawns.consumeShrinkPill();
      _snake = _snake.shrink(_shrinkAmount);
      _needsFullRedraw = true;
      _fireEvent(GameEvent.shrinkPillEaten);
    } else {
      _foodsEaten++;
      if (_ticksSinceLastFood <= _comboWindowTicks && _comboCount > 0) {
        _comboCount++;
      } else {
        _comboCount = 1;
      }
      if (_comboCount > _maxCombo) _maxCombo = _comboCount;
      _ticksSinceLastFood = 0;
      _score += _comboCount;
      if (_comboCount >= 2) {
        _comboTextTicks = _comboTextDuration;
        _fireEvent(GameEvent.combo);
      }
      _food = _spawns.spawnFood(
        boardWidth: _boardWidth, boardHeight: _boardHeight,
        snakeBody: _snake.body, exclude: _spawns.bonusFood,
      );
      _snake = _snake.grow();
      _prevTail = null;
      _fireEvent(GameEvent.foodEaten);
    }
    if (_snake.length > _maxLength) _maxLength = _snake.length;
  }

  // ── Rendering ─────────────────────────────────────────────────────────

  @override
  void render(Renderer renderer) {
    if (_deathFlashTicks > 0) { _renderDeathFlash(renderer); return; }
    if (_needsFullRedraw) { _renderFullFrame(renderer); return; }
    if (_isPaused) return;
    _renderIncrementalFrame(renderer);
  }

  void _renderDeathFlash(Renderer renderer) {
    final phase = _deathFlashTicks > 6 ? 1 : 2;
    if (phase == 1) {
      if (_deathFlashTicks == _deathFlashDuration) {
        renderer.setColor(AnsiColor.darkGray);
        for (var y = 0; y < _boardHeight; y++) {
          for (var x = 0; x < _boardWidth; x++) {
            renderer.moveCursor(y + 1, x + 1);
            renderer.write(y.isEven ? '\u2592' : ' ');
          }
        }
      }
      renderer.setColor(_deathFlashTicks.isEven ? AnsiColor.red : AnsiColor.darkGray);
      for (final seg in _snake.body) {
        renderer.moveCursor(seg.y + 1, seg.x + 1);
        renderer.write(_snake.head == seg ? 'X' : 'x');
      }
      renderer.setColor(AnsiColor.reset);
    } else {
      if (_deathFlashTicks == 6) {
        renderer.setColor(AnsiColor.darkGray);
        for (var y = 0; y < _boardHeight; y++) {
          renderer.moveCursor(y + 1, 1);
          renderer.write(' ' * _boardWidth);
        }
        for (final seg in _snake.body) {
          renderer.moveCursor(seg.y + 1, seg.x + 1);
          renderer.write('.');
        }
      }
      final bannerCol = (_boardWidth ~/ 2) - 14;
      final bannerRow = (_boardHeight ~/ 2) - 2;
      renderer.setColor(_deathFlashTicks.isEven ? AnsiColor.red : AnsiColor.brightGreen);
      renderer.moveCursor(bannerRow,     bannerCol); renderer.write(r'##  ## ##  ## ## ####### ######## ####### ');
      renderer.moveCursor(bannerRow + 1, bannerCol); renderer.write(r'##  ## ### ## ## ##         ##    ##      ');
      renderer.moveCursor(bannerRow + 2, bannerCol); renderer.write(r'##  ## ## ### ## #####      ##    ####### ');
      renderer.moveCursor(bannerRow + 3, bannerCol); renderer.write(r'##  ## ##  ### ## ##         ##    ##      ');
      renderer.moveCursor(bannerRow + 4, bannerCol); renderer.write(r' ####  ##   ## ## #######    ##    ####### ');
      renderer.setColor(AnsiColor.reset);
    }
  }

  void _renderFullFrame(Renderer renderer) {
    _prevTail = null;
    _spawns.prevBonusFood = null;
    renderer.clearScreen();
    _drawBorder(renderer);
    renderer.setColor(AnsiColor.brightGreen);
    renderer.moveCursor(_snake.head.y + 1, _snake.head.x + 1);
    renderer.write('O');
    renderer.setColor(AnsiColor.green);
    for (final seg in _snake.body.skip(1)) {
      renderer.moveCursor(seg.y + 1, seg.x + 1);
      renderer.write('o');
    }
    renderer.setColor(AnsiColor.red);
    renderer.moveCursor(_food.y + 1, _food.x + 1);
    renderer.write('@');
    renderer.setColor(AnsiColor.reset);
    if (_spawns.bonusFood != null) _renderBonusFood(renderer);
    if (_spawns.shrinkPill != null) _renderShrinkPill(renderer);
    if (_spawns.portalA != null) _renderPortals(renderer);
    _renderObstacles(renderer, _spawns.obstacles);
    _drawHud(renderer);
    _needsFullRedraw = false;
    if (_isPaused) _drawPauseOverlay(renderer);
  }

  void _renderIncrementalFrame(Renderer renderer) {
    _eraseIfSet(renderer, _spawns.prevBonusFood); _spawns.prevBonusFood = null;
    _eraseIfSet(renderer, _spawns.prevShrinkPill); _spawns.prevShrinkPill = null;
    _eraseIfSet(renderer, _spawns.prevPortalA); _spawns.prevPortalA = null;
    _eraseIfSet(renderer, _spawns.prevPortalB); _spawns.prevPortalB = null;
    _eraseIfSet(renderer, _prevTail); _prevTail = null;

    renderer.setColor(AnsiColor.red);
    renderer.moveCursor(_food.y + 1, _food.x + 1);
    renderer.write('@');

    if (_spawns.bonusFood != null) _renderBonusFood(renderer);
    if (_spawns.shrinkPill != null) _renderShrinkPill(renderer);

    renderer.setColor(AnsiColor.brightGreen);
    renderer.moveCursor(_snake.head.y + 1, _snake.head.x + 1);
    renderer.write('O');

    if (_snake.length >= 2) {
      renderer.setColor(AnsiColor.green);
      final second = _snake.body[1];
      renderer.moveCursor(second.y + 1, second.x + 1);
      renderer.write('o');
    }

    renderer.setColor(AnsiColor.reset);
    _drawHud(renderer);

    if (_spawns.newObstacles.isNotEmpty) {
      _renderObstacles(renderer, _spawns.newObstacles);
      _spawns.newObstacles.clear();
    }
    if (_spawns.portalsNeedRender) {
      _renderPortals(renderer);
      _spawns.portalsNeedRender = false;
    }
  }

  void _eraseIfSet(Renderer renderer, Vector2? pos) {
    if (pos == null) return;
    renderer.moveCursor(pos.y + 1, pos.x + 1);
    renderer.write(' ');
  }

  void _renderShrinkPill(Renderer renderer) {
    final pill = _spawns.shrinkPill;
    if (pill == null) return;
    renderer.setColor(AnsiColor.magenta);
    renderer.moveCursor(pill.y + 1, pill.x + 1);
    renderer.write('*');
    renderer.setColor(AnsiColor.reset);
  }

  void _renderPortals(Renderer renderer) {
    if (_spawns.portalA == null || _spawns.portalB == null) return;
    renderer.setColor(AnsiColor.magenta);
    renderer.moveCursor(_spawns.portalA!.y + 1, _spawns.portalA!.x + 1);
    renderer.write('[');
    renderer.moveCursor(_spawns.portalB!.y + 1, _spawns.portalB!.x + 1);
    renderer.write(']');
    renderer.setColor(AnsiColor.reset);
  }

  void _renderObstacles(Renderer renderer, Iterable<Vector2> cells) {
    renderer.setColor(AnsiColor.cyan);
    for (final c in cells) {
      renderer.moveCursor(c.y + 1, c.x + 1);
      renderer.write('\u25aa');
    }
    renderer.setColor(AnsiColor.reset);
  }

  void _renderBonusFood(Renderer renderer) {
    final bonus = _spawns.bonusFood;
    if (bonus == null) return;
    final urgent = _spawns.bonusCountdown <= 5;
    renderer.setColor(_spawns.bonusFlashTick.isEven || !urgent ? AnsiColor.yellow : AnsiColor.cyan);
    renderer.moveCursor(bonus.y + 1, bonus.x + 1);
    renderer.write('\$');
    renderer.setColor(AnsiColor.reset);
  }

  void _drawBorder(Renderer renderer) {
    renderer.setColor(AnsiColor.darkGray);
    for (int x = 0; x < _boardWidth + 2; x++) {
      renderer.moveCursor(0, x); renderer.write('#');
      renderer.moveCursor(_boardHeight + 1, x); renderer.write('#');
    }
    for (int y = 1; y <= _boardHeight; y++) {
      renderer.moveCursor(y, 0); renderer.write('#');
      renderer.moveCursor(y, _boardWidth + 1); renderer.write('#');
    }
    renderer.setColor(AnsiColor.reset);
  }

  void _drawHud(Renderer renderer) {
    renderer.moveCursor(_boardHeight + 2, 0);
    final isNewBest = _score > 0 && _score >= _highScore;
    if (_mode == GameMode.timeAttack) {
      renderer.setColor(_secondsLeft <= 10 ? AnsiColor.red : AnsiColor.cyan);
      renderer.write('Score: $_score   \u23f1 ${_secondsLeft}s   Best: $_highScore   ');
    } else if (isNewBest) {
      renderer.setColor(AnsiColor.yellow);
      renderer.write('Score: $_score  \u2605 NEW BEST!     ');
    } else if (_comboTextTicks > 0 && _comboCount >= 2) {
      renderer.setColor(AnsiColor.yellow);
      renderer.write('Score: $_score  x$_comboCount COMBO! (+${_comboCount - 1})     ');
    } else {
      renderer.setColor(AnsiColor.cyan);
      renderer.write('Score: $_score   Best: $_highScore   ');
    }
    renderer.setColor(AnsiColor.reset);
    renderer.moveCursor(_boardHeight + 3, 0);
    renderer.setColor(AnsiColor.darkGray);
    final modeLabel = switch (_mode) {
      GameMode.zen => '  [Zen]',
      GameMode.timeAttack => '  [Time Attack]',
      _ => '',
    };
    final levelLabel = _mode != GameMode.timeAttack && _level > 0 ? '  Lv$_level' : '';
    final portalHint = _spawns.portalA != null ? '  [/]portal' : '           ';
    renderer.write('WASD/Arrows: move   P: pause   Q: quit$modeLabel$levelLabel$portalHint');
    renderer.setColor(AnsiColor.reset);
  }

  void _drawPauseOverlay(Renderer renderer) {
    const col = 14;
    final row = _boardHeight ~/ 2;
    renderer.setColor(AnsiColor.yellow);
    renderer.moveCursor(row, col);     renderer.write('+---------------+');
    renderer.moveCursor(row + 1, col); renderer.write('|    PAUSED     |');
    renderer.moveCursor(row + 2, col); renderer.write('| any key: resume|');
    renderer.moveCursor(row + 3, col); renderer.write('+---------------+');
    renderer.setColor(AnsiColor.reset);
  }
}
