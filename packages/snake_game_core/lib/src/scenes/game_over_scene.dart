import '../game_stats.dart';
import '../input/input_action.dart';
import '../persistence/score_repository.dart';
import '../rendering/ansi_color.dart';
import '../rendering/renderer.dart';
import 'difficulty.dart';
import 'game_mode.dart';
import 'gameplay_scene.dart';
import 'scene.dart';

final class GameOverScene extends Scene {
  final int score;
  final int highScore;
  final GameMode mode;
  final Difficulty difficulty;
  final GameStats stats;
  final ScoreRepository _scoreRepo;
  final int _boardColumns;
  final int _boardRows;
  final GameEventCallback? _onEvent;
  bool _rendered = false;

  GameOverScene({
    required this.score,
    required this.highScore,
    required this.mode,
    this.difficulty = Difficulty.normal,
    required ScoreRepository scoreRepo,
    required int boardColumns,
    required int boardRows,
    GameEventCallback? onEvent,
    this.stats = const GameStats(),
  })  : _scoreRepo = scoreRepo,
        _boardColumns = boardColumns,
        _boardRows = boardRows,
        _onEvent = onEvent {
    if (score > 0 && score > highScore) {
      _scoreRepo.save(mode.name, score);
    }
  }

  @override
  SceneTransition update(InputAction? input) {
    switch (input) {
      case InputAction.confirm:
        final best = _scoreRepo.load(mode.name);
        return GoTo(() => GameplayScene(
              highScore: best,
              mode: mode,
              difficulty: difficulty,
              scoreRepo: _scoreRepo,
              boardColumns: _boardColumns,
              boardRows: _boardRows,
              onEvent: _onEvent,
            ));
      case InputAction.quit:
        return const Quit();
      default:
        return const Stay();
    }
  }

  @override
  void render(Renderer renderer) {
    if (_rendered) return;
    renderer.clearScreen();

    const col = 10;
    final isNewBest = score > 0 && score >= highScore;

    renderer.setColor(AnsiColor.red);
    renderer.moveCursor(5, col);
    renderer.write('+---------------------+');
    renderer.moveCursor(6, col);
    renderer.write('|      GAME  OVER     |');
    renderer.moveCursor(7, col);
    renderer.write('+---------------------+');

    renderer.setColor(isNewBest ? AnsiColor.yellow : AnsiColor.cyan);
    renderer.moveCursor(8, col);
    renderer.write('| Score: ${score.toString().padLeft(12)} |');
    renderer.moveCursor(9, col);
    renderer.write('| Best:  ${highScore.toString().padLeft(12)} |');
    renderer.moveCursor(10, col);
    renderer.write(isNewBest ? '|  *** NEW BEST! ***  |' : '|                     |');

    // Stats section
    renderer.setColor(AnsiColor.darkGray);
    renderer.moveCursor(11, col);
    renderer.write('+---------------------+');
    renderer.setColor(AnsiColor.green);
    renderer.moveCursor(12, col);
    renderer.write('| Foods:  ${stats.foodsEaten.toString().padLeft(11)} |');
    renderer.moveCursor(13, col);
    renderer.write('| Bonus:  ${stats.bonusesEaten.toString().padLeft(11)} |');
    renderer.moveCursor(14, col);
    renderer.write('| Max combo: ${stats.maxCombo.toString().padLeft(8)} |');
    renderer.moveCursor(15, col);
    renderer.write('| Max length: ${stats.maxLength.toString().padLeft(7)} |');
    if (stats.portalsUsed > 0) {
      renderer.moveCursor(16, col);
      renderer.write('| Portals: ${stats.portalsUsed.toString().padLeft(10)} |');
    }

    final actionsRow = stats.portalsUsed > 0 ? 17 : 16;
    renderer.setColor(AnsiColor.red);
    renderer.moveCursor(actionsRow, col);
    renderer.write('+---------------------+');
    renderer.setColor(AnsiColor.darkGray);
    renderer.moveCursor(actionsRow + 1, col);
    renderer.write('| [Enter] New Game    |');
    renderer.moveCursor(actionsRow + 2, col);
    renderer.write('|   [Q]   Quit        |');
    renderer.setColor(AnsiColor.red);
    renderer.moveCursor(actionsRow + 3, col);
    renderer.write('+---------------------+');
    renderer.setColor(AnsiColor.reset);

    _rendered = true;
  }
}
