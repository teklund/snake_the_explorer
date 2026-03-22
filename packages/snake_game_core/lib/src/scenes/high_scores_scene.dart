import '../input/input_action.dart';
import '../persistence/score_repository.dart';
import '../rendering/ansi_color.dart';
import '../rendering/renderer.dart';
import 'game_mode.dart';
import 'gameplay_scene.dart';
import 'menu_scene.dart';
import 'scene.dart';

final class HighScoresScene extends Scene {
  final ScoreRepository _scoreRepo;
  final int _boardColumns;
  final int _boardRows;
  final GameEventCallback? _onEvent;
  bool _rendered = false;

  HighScoresScene({
    required ScoreRepository scoreRepo,
    required int boardColumns,
    required int boardRows,
    GameEventCallback? onEvent,
  })  : _scoreRepo = scoreRepo,
        _boardColumns = boardColumns,
        _boardRows = boardRows,
        _onEvent = onEvent;

  static const _modes = [GameMode.classic, GameMode.zen, GameMode.timeAttack];
  static const _labels = ['Classic', 'Zen (wrap)', 'Time Attack'];

  @override
  SceneTransition update(InputAction? input) {
    switch (input) {
      case InputAction.confirm || InputAction.quit:
        return GoTo(() => MenuScene(
              scoreRepo: _scoreRepo,
              boardColumns: _boardColumns,
              boardRows: _boardRows,
              onEvent: _onEvent,
            ));
      default:
        return const Stay();
    }
  }

  @override
  void render(Renderer renderer) {
    if (_rendered) return;
    renderer.clearScreen();

    // Box is 23 chars wide; center horizontally and vertically.
    final col = (_boardColumns - 23) ~/ 2;
    // Content: header(3) + blank(1) + modes*2 + blank(1) + divider(1) + action(1) = 3+1+6+1+1+1 = 13
    const contentHeight = 13;
    final r0 = _boardRows > contentHeight ? (_boardRows - contentHeight) ~/ 2 : 0;

    renderer.setColor(AnsiColor.yellow);
    renderer.moveCursor(r0, col);
    renderer.write('+---------------------+');
    renderer.moveCursor(r0 + 1, col);
    renderer.write('|     HIGH SCORES     |');
    renderer.moveCursor(r0 + 2, col);
    renderer.write('+---------------------+');

    for (var i = 0; i < _modes.length; i++) {
      final mode = _modes[i];
      final label = _labels[i];
      final score = _scoreRepo.load(mode.name);
      final row = r0 + 4 + i * 2;

      renderer.setColor(AnsiColor.cyan);
      renderer.moveCursor(row, col);
      renderer.write('  $label');

      renderer.setColor(AnsiColor.green);
      renderer.moveCursor(row + 1, col);
      renderer.write('    ${score > 0 ? score.toString() : '---'}');
    }

    final actionsRow = r0 + 4 + _modes.length * 2 + 1;
    renderer.setColor(AnsiColor.darkGray);
    renderer.moveCursor(actionsRow, col);
    renderer.write('─' * 23);
    renderer.moveCursor(actionsRow + 1, col);
    renderer.write('[Enter] or [Q]  Back');
    renderer.setColor(AnsiColor.reset);

    _rendered = true;
  }
}
