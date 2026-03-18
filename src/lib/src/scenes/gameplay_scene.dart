import 'dart:io';
import 'dart:math';

import '../entities/direction.dart';
import '../entities/snake.dart';
import '../entities/vector2.dart';
import '../input/input_action.dart';
import '../rendering/ansi_color.dart';
import '../rendering/renderer.dart';
import 'game_mode.dart';
import 'game_over_scene.dart';
import 'scene.dart';

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
// Each obstacle is a short segment of this many cells.
const _obstacleSegmentLength = 3;

// Ticks to show death-flash before transitioning to game over.
// Phase 1 (ticks 12..7): board dims to grey, snake turns red.
// Phase 2 (ticks  6..1): WASTED banner flashes into view.
const _deathFlashDuration = 12;

// Combo: eat foods within N ticks to chain a score multiplier.
const _comboWindowTicks = 20;
const _comboTextDuration = 8;

// Portals: a teleporting pair that spawns periodically.
const _portalSpawnInterval = 45;
const _portalLifetime = 30;

final class GameplayScene extends Scene {
  static const _minBoardWidth = 20;
  static const _minBoardHeight = 10;
  static const _hudRows = 4; // border top + border bottom + 2 HUD lines

  static const _baseMs = 150;
  static const _minMs = 50;

  final GameMode _mode;
  late int _boardWidth;
  late int _boardHeight;
  Snake _snake;
  Vector2 _food;
  Vector2? _bonusFood;
  int _bonusCountdown = 0;
  int _ticksSinceLastBonus = 0;
  int _bonusFlashTick = 0;
  int _score = 0;
  int _nextObstacleMilestoneIdx = 0;
  final Set<Vector2> _obstacles = {};
  final List<Vector2> _newObstacles = []; // to render on next frame
  final int _highScore;
  Vector2? _prevTail;
  Vector2? _prevBonusFood;
  // Shrink pill
  Vector2? _shrinkPill;
  int _shrinkCountdown = 0;
  int _ticksSinceLastShrink = 0;
  Vector2? _prevShrinkPill;
  // Combo multiplier
  int _comboCount = 0;
  int _ticksSinceLastFood = 0;
  int _comboTextTicks = 0;
  // Portals
  Vector2? _portalA;
  Vector2? _portalB;
  int _portalCountdown = 0;
  int _ticksSinceLastPortal = 0;
  Vector2? _prevPortalA;
  Vector2? _prevPortalB;
  bool _portalsNeedRender = false;
  // Time Attack
  DateTime? _startTime;
  int _secondsLeft = _timeAttackSeconds;
  bool _isPaused = false;
  int _deathFlashTicks = 0;
  bool _needsFullRedraw = true;
  final Random _random;

  GameplayScene({Random? random, int highScore = 0, GameMode mode = GameMode.classic})
      : _random = random ?? Random(),
        _highScore = highScore,
        _mode = mode,
        _snake = Snake(
          body: [
            const Vector2(5, 5),
            const Vector2(4, 5),
            const Vector2(3, 5),
          ],
          direction: Direction.right,
        ),
        _food = const Vector2(10, 5) {
    _measureBoard();
  }

  void _measureBoard() {
    final cols = stdout.hasTerminal ? stdout.terminalColumns : 42;
    final rows = stdout.hasTerminal ? stdout.terminalLines : 24;
    _boardWidth = (cols - 2).clamp(_minBoardWidth, 120);
    _boardHeight = (rows - _hudRows).clamp(_minBoardHeight, 40);
    if (_mode == GameMode.timeAttack) _startTime ??= DateTime.now();
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

  @override
  SceneTransition update(InputAction? input) {
    if (input == InputAction.quit) return const Quit();

    // Death flash: count down then transition
    if (_deathFlashTicks > 0) {
      _deathFlashTicks--;
      if (_deathFlashTicks == 0) {
        final newHigh = _score > _highScore ? _score : _highScore;
        return GoTo(() => GameOverScene(score: _score, highScore: newHigh, mode: _mode));
      }
      return const Stay();
    }

    if (input == InputAction.pause) {
      _isPaused = !_isPaused;
      _needsFullRedraw = true;
      return const Stay();
    }

    if (_isPaused) {
      // Any movement key unpauses
      if (input != null) {
        _isPaused = false;
        _needsFullRedraw = true;
      }
      return const Stay();
    }

    // Time Attack: check countdown
    if (_mode == GameMode.timeAttack && _startTime != null) {
      final elapsed = DateTime.now().difference(_startTime!);
      _secondsLeft = (_timeAttackSeconds - elapsed.inSeconds).clamp(0, _timeAttackSeconds);
      if (_secondsLeft == 0) {
        _deathFlashTicks = _deathFlashDuration;
        _needsFullRedraw = true;
        return const Stay();
      }
    }

    final newDirection = switch (input) {
      InputAction.moveUp => Direction.up,
      InputAction.moveDown => Direction.down,
      InputAction.moveLeft => Direction.left,
      InputAction.moveRight => Direction.right,
      _ => null,
    };

    if (newDirection != null) {
      _snake = _snake.turn(newDirection);
    }

    // Shrink pill lifecycle
    _ticksSinceLastShrink++;
    if (_shrinkPill == null && _ticksSinceLastShrink >= _shrinkSpawnInterval) {
      _shrinkPill = _spawnFood(exclude: _bonusFood);
      _shrinkCountdown = _shrinkLifetime;
      _ticksSinceLastShrink = 0;
    }
    if (_shrinkPill != null) {
      _shrinkCountdown--;
      if (_shrinkCountdown <= 0) {
        _prevShrinkPill = _shrinkPill;
        _shrinkPill = null;
        _ticksSinceLastShrink = 0;
      }
    }

    // Bonus food lifecycle
    _ticksSinceLastBonus++;
    _bonusFlashTick++;
    if (_bonusFood == null && _ticksSinceLastBonus >= _bonusSpawnInterval) {
      _bonusFood = _spawnFood(exclude: null);
      _bonusCountdown = _bonusLifetime;
      _ticksSinceLastBonus = 0;
    }
    if (_bonusFood != null) {
      _bonusCountdown--;
      if (_bonusCountdown <= 0) {
        _prevBonusFood = _bonusFood;
        _bonusFood = null;
        _ticksSinceLastBonus = 0;
      }
    }

    // Combo timer
    _ticksSinceLastFood++;
    if (_comboTextTicks > 0) _comboTextTicks--;

    // Portal lifecycle
    _ticksSinceLastPortal++;
    if (_portalA == null && _ticksSinceLastPortal >= _portalSpawnInterval) {
      _ticksSinceLastPortal = 0;
      _spawnPortals();
    }
    if (_portalA != null) {
      _portalCountdown--;
      if (_portalCountdown <= 0) {
        _prevPortalA = _portalA;
        _prevPortalB = _portalB;
        _portalA = null;
        _portalB = null;
        _ticksSinceLastPortal = 0;
      }
    }

    final nextHead = _snake.head + _snake.direction.delta;

    // Wrap in Zen mode, die at borders in Classic
    final wrappedHead = _mode == GameMode.zen
        ? Vector2(
            (nextHead.x + _boardWidth) % _boardWidth,
            (nextHead.y + _boardHeight) % _boardHeight,
          )
        : nextHead;

    final atFood = wrappedHead == _food;
    final atBonus = _bonusFood != null && wrappedHead == _bonusFood;
    final atShrink = _shrinkPill != null && wrappedHead == _shrinkPill;

    if (atFood || atBonus || atShrink) {
      if (atBonus) {
        _score += 3;
        _prevBonusFood = _bonusFood;
        _bonusFood = null;
        _ticksSinceLastBonus = 0;
        _snake = _snake.grow();
      } else if (atShrink) {
        _prevShrinkPill = _shrinkPill;
        _shrinkPill = null;
        _ticksSinceLastShrink = 0;
        // Shrink removes tail segments — great escape move, no grow
        _snake = _snake.shrink(_shrinkAmount);
        _needsFullRedraw = true; // tail positions changed unpredictably
      } else {
        // Regular food: apply combo multiplier
        if (_ticksSinceLastFood <= _comboWindowTicks && _comboCount > 0) {
          _comboCount++;
        } else {
          _comboCount = 1;
        }
        _ticksSinceLastFood = 0;
        _score += _comboCount;
        if (_comboCount >= 2) _comboTextTicks = _comboTextDuration;
        _food = _spawnFood(exclude: _bonusFood);
        _snake = _snake.grow();
        _prevTail = null;
      }
    } else {
      _prevTail = _snake.body.last;
      _snake = _snake.move();
    }

    // In Zen mode, fix head position to wrapped coords after move
    if (_mode == GameMode.zen && !atFood && !atBonus) {
      final raw = _snake.head;
      if (raw.x < 0 || raw.x >= _boardWidth || raw.y < 0 || raw.y >= _boardHeight) {
        final wrapped = Vector2(
          (raw.x + _boardWidth) % _boardWidth,
          (raw.y + _boardHeight) % _boardHeight,
        );
        _snake = Snake(
          body: [wrapped, ..._snake.body.skip(1)],
          direction: _snake.direction,
        );
      }
    }

    // Portal teleport: if head landed on a portal, relocate to the other end
    if (_portalA != null && _portalB != null) {
      final h = _snake.head;
      if (h == _portalA) {
        _snake = Snake(body: [_portalB!, ..._snake.body.skip(1)], direction: _snake.direction);
        _needsFullRedraw = true;
      } else if (h == _portalB) {
        _snake = Snake(body: [_portalA!, ..._snake.body.skip(1)], direction: _snake.direction);
        _needsFullRedraw = true;
      }
    }

    final outOfBounds = _mode == GameMode.classic &&
        (_snake.head.x < 0 ||
            _snake.head.x >= _boardWidth ||
            _snake.head.y < 0 ||
            _snake.head.y >= _boardHeight);

    if (outOfBounds || _snake.isSelfColliding || _obstacles.contains(_snake.head)) {
      _deathFlashTicks = _deathFlashDuration;
      _needsFullRedraw = true;
      return const Stay();
    }

    // Spawn obstacle at score milestones (Classic mode only)
    if (_mode == GameMode.classic &&
        _nextObstacleMilestoneIdx < _obstacleScoreMilestones.length &&
        _score >= _obstacleScoreMilestones[_nextObstacleMilestoneIdx]) {
      _spawnObstacle();
      _nextObstacleMilestoneIdx++;
    }

    return const Stay();
  }

  Vector2 _spawnFood({required Vector2? exclude}) {
    Vector2 pos;
    do {
      pos = Vector2(
        _random.nextInt(_boardWidth),
        _random.nextInt(_boardHeight),
      );
    } while (_snake.body.contains(pos) ||
        pos == exclude ||
        pos == _shrinkPill ||
        pos == _portalA ||
        pos == _portalB ||
        _obstacles.contains(pos));
    return pos;
  }

  void _spawnObstacle() {
    // Pick a random empty row or column segment that doesn't overlap snake/food
    final horizontal = _random.nextBool();
    const attempts = 20;
    for (var i = 0; i < attempts; i++) {
      final x = _random.nextInt(_boardWidth - _obstacleSegmentLength);
      final y = _random.nextInt(_boardHeight);
      final cells = List.generate(
        _obstacleSegmentLength,
        (k) => horizontal ? Vector2(x + k, y) : Vector2(x, y + k),
      );
      final blocked = cells.any(
        (c) =>
            _snake.body.contains(c) ||
            c == _food ||
            c == _bonusFood ||
            _obstacles.contains(c),
      );
      if (!blocked) {
        _obstacles.addAll(cells);
        _newObstacles.addAll(cells);
        return;
      }
    }
    // Couldn't place — skip silently
  }

  void _spawnPortals() {
    const attempts = 30;
    for (var i = 0; i < attempts; i++) {
      final a = Vector2(_random.nextInt(_boardWidth), _random.nextInt(_boardHeight));
      final b = Vector2(_random.nextInt(_boardWidth), _random.nextInt(_boardHeight));
      if (a == b) continue;
      bool isOccupied(Vector2 p) =>
          _snake.body.contains(p) ||
          p == _food ||
          p == _bonusFood ||
          p == _shrinkPill ||
          _obstacles.contains(p);
      if (!isOccupied(a) && !isOccupied(b)) {
        _portalA = a;
        _portalB = b;
        _portalCountdown = _portalLifetime;
        _portalsNeedRender = true;
        return;
      }
    }
    // Couldn't place — retry in half the normal interval
    _ticksSinceLastPortal = _portalSpawnInterval ~/ 2;
  }

  @override
  void render(Renderer renderer) {
    // GTA-style WASTED death sequence
    if (_deathFlashTicks > 0) {
      final phase = _deathFlashTicks > 6 ? 1 : 2;

      if (phase == 1) {
        // Dim the whole board to grey scanlines
        if (_deathFlashTicks == _deathFlashDuration) {
          // First flash tick: paint entire board with dim overlay
          renderer.setColor(AnsiColor.darkGray);
          for (var y = 0; y < _boardHeight; y++) {
            for (var x = 0; x < _boardWidth; x++) {
              renderer.moveCursor(y + 1, x + 1);
              renderer.write(y.isEven ? '\u2592' : ' '); // ▒ scanlines
            }
          }
        }
        // Snake pulses red → dark red each tick
        final snakeColor = _deathFlashTicks.isEven ? AnsiColor.red : AnsiColor.darkGray;
        renderer.setColor(snakeColor);
        for (final seg in _snake.body) {
          renderer.moveCursor(seg.y + 1, seg.x + 1);
          renderer.write(_snake.head == seg ? 'X' : 'x');
        }
        renderer.setColor(AnsiColor.reset);
      } else {
        // Phase 2: WASTED banner slams in, flashing red ↔ bright white
        if (_deathFlashTicks == 6) {
          // Slam: black out the board first
          renderer.setColor(AnsiColor.darkGray);
          for (var y = 0; y < _boardHeight; y++) {
            renderer.moveCursor(y + 1, 1);
            renderer.write(' ' * _boardWidth);
          }
          // Paint snake as faint grey corpse
          renderer.setColor(AnsiColor.darkGray);
          for (final seg in _snake.body) {
            renderer.moveCursor(seg.y + 1, seg.x + 1);
            renderer.write('.');
          }
        }
        // WASTED banner — 5 rows of block letters, centred
        final bannerCol = (_boardWidth ~/ 2) - 14;
        final bannerRow = (_boardHeight ~/ 2) - 2;
        final flash = _deathFlashTicks.isEven;
        renderer.setColor(flash ? AnsiColor.red : AnsiColor.brightGreen);
        renderer.moveCursor(bannerRow,     bannerCol); renderer.write(r'##  ## ##  ## ## ####### ######## ####### ');
        renderer.moveCursor(bannerRow + 1, bannerCol); renderer.write(r'##  ## ### ## ## ##         ##    ##      ');
        renderer.moveCursor(bannerRow + 2, bannerCol); renderer.write(r'##  ## ## ### ## #####      ##    ####### ');
        renderer.moveCursor(bannerRow + 3, bannerCol); renderer.write(r'##  ## ##  ### ## ##         ##    ##      ');
        renderer.moveCursor(bannerRow + 4, bannerCol); renderer.write(r' ####  ##   ## ## #######    ##    ####### ');
        renderer.setColor(AnsiColor.reset);
      }
      return;
    }

    if (_needsFullRedraw) {
      _prevTail = null;
      _prevBonusFood = null;
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
      if (_bonusFood != null) _renderBonusFood(renderer);
      if (_shrinkPill != null) _renderShrinkPill(renderer);
      if (_portalA != null) _renderPortals(renderer);
      _renderObstacles(renderer, _obstacles);
      _drawHud(renderer);
      _needsFullRedraw = false;
      if (_isPaused) _drawPauseOverlay(renderer);
      return;
    }

    if (_isPaused) return; // no incremental updates while paused

    // Erase expired/eaten bonus food
    if (_prevBonusFood != null) {
      renderer.moveCursor(_prevBonusFood!.y + 1, _prevBonusFood!.x + 1);
      renderer.write(' ');
      _prevBonusFood = null;
    }

    // Erase expired/eaten shrink pill
    if (_prevShrinkPill != null) {
      renderer.moveCursor(_prevShrinkPill!.y + 1, _prevShrinkPill!.x + 1);
      renderer.write(' ');
      _prevShrinkPill = null;
    }

    // Erase expired portals
    if (_prevPortalA != null) {
      renderer.moveCursor(_prevPortalA!.y + 1, _prevPortalA!.x + 1);
      renderer.write(' ');
      _prevPortalA = null;
    }
    if (_prevPortalB != null) {
      renderer.moveCursor(_prevPortalB!.y + 1, _prevPortalB!.x + 1);
      renderer.write(' ');
      _prevPortalB = null;
    }

    // Erase old tail
    if (_prevTail != null) {
      renderer.moveCursor(_prevTail!.y + 1, _prevTail!.x + 1);
      renderer.write(' ');
      _prevTail = null;
    }

    // Regular food
    renderer.setColor(AnsiColor.red);
    renderer.moveCursor(_food.y + 1, _food.x + 1);
    renderer.write('@');

    // Bonus food (flash by alternating colours each tick)
    if (_bonusFood != null) _renderBonusFood(renderer);

    // Shrink pill
    if (_shrinkPill != null) _renderShrinkPill(renderer);

    // Snake head
    renderer.setColor(AnsiColor.brightGreen);
    final head = _snake.head;
    renderer.moveCursor(head.y + 1, head.x + 1);
    renderer.write('O');

    // Second segment
    if (_snake.length >= 2) {
      renderer.setColor(AnsiColor.green);
      final second = _snake.body[1];
      renderer.moveCursor(second.y + 1, second.x + 1);
      renderer.write('o');
    }

    renderer.setColor(AnsiColor.reset);
    _drawHud(renderer);

    // Render any newly spawned obstacle cells
    if (_newObstacles.isNotEmpty) {
      _renderObstacles(renderer, _newObstacles);
      _newObstacles.clear();
    }

    // Render newly spawned portals
    if (_portalsNeedRender) {
      _renderPortals(renderer);
      _portalsNeedRender = false;
    }
  }

  void _renderShrinkPill(Renderer renderer) {
    final pill = _shrinkPill;
    if (pill == null) return;
    renderer.setColor(AnsiColor.magenta);
    renderer.moveCursor(pill.y + 1, pill.x + 1);
    renderer.write('*');
    renderer.setColor(AnsiColor.reset);
  }

  void _renderPortals(Renderer renderer) {
    if (_portalA == null || _portalB == null) return;
    renderer.setColor(AnsiColor.magenta);
    renderer.moveCursor(_portalA!.y + 1, _portalA!.x + 1);
    renderer.write('[');
    renderer.moveCursor(_portalB!.y + 1, _portalB!.x + 1);
    renderer.write(']');
    renderer.setColor(AnsiColor.reset);
  }

  void _renderObstacles(Renderer renderer, Iterable<Vector2> cells) {
    renderer.setColor(AnsiColor.cyan);
    for (final c in cells) {
      renderer.moveCursor(c.y + 1, c.x + 1);
      renderer.write('▪');
    }
    renderer.setColor(AnsiColor.reset);
  }

  void _renderBonusFood(Renderer renderer) {
    final bonus = _bonusFood;
    if (bonus == null) return;
    // Flash between yellow and cyan to signal urgency as timer counts down
    final urgent = _bonusCountdown <= 5;
    renderer.setColor(_bonusFlashTick.isEven || !urgent ? AnsiColor.yellow : AnsiColor.cyan);
    renderer.moveCursor(bonus.y + 1, bonus.x + 1);
    renderer.write('\$');
    renderer.setColor(AnsiColor.reset);
  }

  void _drawBorder(Renderer renderer) {
    renderer.setColor(AnsiColor.darkGray);
    for (int x = 0; x < _boardWidth + 2; x++) {
      renderer.moveCursor(0, x);
      renderer.write('#');
      renderer.moveCursor(_boardHeight + 1, x);
      renderer.write('#');
    }
    for (int y = 1; y <= _boardHeight; y++) {
      renderer.moveCursor(y, 0);
      renderer.write('#');
      renderer.moveCursor(y, _boardWidth + 1);
      renderer.write('#');
    }
    renderer.setColor(AnsiColor.reset);
  }

  void _drawHud(Renderer renderer) {
    renderer.moveCursor(_boardHeight + 2, 0);
    final isNewBest = _score > 0 && _score >= _highScore;
    if (_mode == GameMode.timeAttack) {
      final urgentTime = _secondsLeft <= 10;
      renderer.setColor(urgentTime ? AnsiColor.red : AnsiColor.cyan);
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
    final portalHint = _portalA != null ? '  [/]portal' : '           ';
    renderer.write('WASD/Arrows: move   P: pause   Q: quit$modeLabel$levelLabel$portalHint');
    renderer.setColor(AnsiColor.reset);
  }

  void _drawPauseOverlay(Renderer renderer) {
    const col = 14;
    final row = _boardHeight ~/ 2;
    renderer.setColor(AnsiColor.yellow);
    renderer.moveCursor(row, col);
    renderer.write('+---------------+');
    renderer.moveCursor(row + 1, col);
    renderer.write('|    PAUSED     |');
    renderer.moveCursor(row + 2, col);
    renderer.write('| any key: resume|');
    renderer.moveCursor(row + 3, col);
    renderer.write('+---------------+');
    renderer.setColor(AnsiColor.reset);
  }
}
