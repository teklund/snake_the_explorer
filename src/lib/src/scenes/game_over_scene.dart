import '../input/input_action.dart';
import '../persistence/score_repository.dart';
import '../rendering/ansi_color.dart';
import '../rendering/renderer.dart';
import 'game_mode.dart';
import 'gameplay_scene.dart';
import 'scene.dart';

final class GameOverScene extends Scene {
  final int score;
  final int highScore;
  final GameMode mode;
  bool _rendered = false;

  GameOverScene({required this.score, required this.highScore, required this.mode}) {
    if (score > 0 && score > highScore) {
      ScoreRepository().save(mode.name, score);
    }
  }

  @override
  SceneTransition update(InputAction? input) {
    switch (input) {
      case InputAction.confirm:
        final best = ScoreRepository().load(mode.name);
        return GoTo(() => GameplayScene(highScore: best, mode: mode));
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

    // 21-char-wide centred box: | + 19 inner chars + |
    const col = 10;
    final isNewBest = score > 0 && score >= highScore;

    renderer.setColor(AnsiColor.red);
    renderer.moveCursor(7, col);
    renderer.write('+-------------------+');
    renderer.moveCursor(8, col);
    renderer.write('|     GAME  OVER    |');
    renderer.moveCursor(9, col);
    renderer.write('+-------------------+');

    renderer.setColor(isNewBest ? AnsiColor.yellow : AnsiColor.cyan);
    renderer.moveCursor(10, col);
    renderer.write('| Score: ${score.toString().padLeft(10)} |');
    renderer.moveCursor(11, col);
    renderer.write('| Best:  ${highScore.toString().padLeft(10)} |');
    renderer.moveCursor(12, col);
    renderer.write(isNewBest ? '| *** NEW BEST! *** |' : '|                   |');

    renderer.setColor(AnsiColor.red);
    renderer.moveCursor(13, col);
    renderer.write('+-------------------+');
    renderer.setColor(AnsiColor.darkGray);
    renderer.moveCursor(14, col);
    renderer.write('| [Enter] New Game  |');
    renderer.moveCursor(15, col);
    renderer.write('|   [Q]   Quit      |');
    renderer.setColor(AnsiColor.red);
    renderer.moveCursor(16, col);
    renderer.write('+-------------------+');
    renderer.setColor(AnsiColor.reset);

    _rendered = true;
  }
}
