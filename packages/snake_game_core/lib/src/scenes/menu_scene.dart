import '../input/input_action.dart';
import '../persistence/score_repository.dart';
import '../rendering/ansi_color.dart';
import '../rendering/renderer.dart';
import 'difficulty.dart';
import 'game_mode.dart';
import 'gameplay_scene.dart';
import 'high_scores_scene.dart';
import 'scene.dart';

final class MenuScene extends Scene {
  final ScoreRepository _scoreRepo;
  final int _boardColumns;
  final int _boardRows;
  final GameEventCallback? _onEvent;
  int _selected = 0;
  int _difficultyIndex = 1; // default: normal
  bool _rendered = false;

  MenuScene({
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
  static const _descs = [
    'Walls are deadly.',
    'Wrap through walls.',
    '60 seconds — max score!',
  ];
  static const _highScoresLabel = 'High Scores';
  static const _highScoresDesc = 'View all-time bests';
  static const _difficulties = Difficulty.values;
  int get _itemCount => _modes.length + 1;

  Difficulty get _difficulty => _difficulties[_difficultyIndex];

  @override
  SceneTransition update(InputAction? input) {
    switch (input) {
      case InputAction.moveUp:
        _selected = (_selected - 1).clamp(0, _itemCount - 1);
        _rendered = false;
      case InputAction.moveDown:
        _selected = (_selected + 1).clamp(0, _itemCount - 1);
        _rendered = false;
      case InputAction.moveLeft:
        _difficultyIndex =
            (_difficultyIndex - 1).clamp(0, _difficulties.length - 1);
        _rendered = false;
      case InputAction.moveRight:
        _difficultyIndex =
            (_difficultyIndex + 1).clamp(0, _difficulties.length - 1);
        _rendered = false;
      case InputAction.confirm:
        if (_selected < _modes.length) {
          final mode = _modes[_selected];
          final best = _scoreRepo.load(mode.name);
          return GoTo(() => GameplayScene(
                mode: mode,
                difficulty: _difficulty,
                highScore: best,
                scoreRepo: _scoreRepo,
                boardColumns: _boardColumns,
                boardRows: _boardRows,
                onEvent: _onEvent,
              ));
        }
        return GoTo(() => HighScoresScene(
              scoreRepo: _scoreRepo,
              boardColumns: _boardColumns,
              boardRows: _boardRows,
              onEvent: _onEvent,
            ));
      case InputAction.quit:
        return const Quit();
      default:
        break;
    }
    return const Stay();
  }

  @override
  void render(Renderer renderer) {
    if (_rendered) return;
    renderer.clearScreen();

    const col = 8;
    renderer.setColor(AnsiColor.brightGreen);
    renderer.moveCursor(4, col + 3);
    renderer.write(' ___  _  _   __   _  _  ____ ');
    renderer.moveCursor(5, col + 3);
    renderer.write('/ __)( \\( ) / _\\ ( )/ )( ___)');
    renderer.moveCursor(6, col + 3);
    renderer.write('\\__ \\ )  ( /    \\ )  <  )__)  ');
    renderer.moveCursor(7, col + 3);
    renderer.write('(___/(_)\\_)\\_/\\_/(_)\\_)(____)');
    renderer.setColor(AnsiColor.reset);

    renderer.moveCursor(9, col);
    renderer.setColor(AnsiColor.darkGray);
    renderer.write('─' * 32);
    renderer.setColor(AnsiColor.reset);

    for (var i = 0; i < _modes.length; i++) {
      final isActive = i == _selected;
      renderer.moveCursor(11 + i * 3, col);
      if (isActive) {
        renderer.setColor(AnsiColor.yellow);
        renderer.write('▶ ${_labels[i].padRight(13)} ${_descs[i]}');
      } else {
        renderer.setColor(AnsiColor.darkGray);
        renderer.write('  ${_labels[i].padRight(13)} ${_descs[i]}');
      }
      renderer.setColor(AnsiColor.reset);
    }

    // High Scores option
    final hsRow = 11 + _modes.length * 3;
    final hsActive = _selected == _modes.length;
    renderer.moveCursor(hsRow, col);
    if (hsActive) {
      renderer.setColor(AnsiColor.yellow);
      renderer.write('▶ ${_highScoresLabel.padRight(13)} $_highScoresDesc');
    } else {
      renderer.setColor(AnsiColor.darkGray);
      renderer.write('  ${_highScoresLabel.padRight(13)} $_highScoresDesc');
    }
    renderer.setColor(AnsiColor.reset);

    // Difficulty selector
    renderer.moveCursor(hsRow + 2, col);
    renderer.setColor(AnsiColor.cyan);
    final diffLabel = _difficulty.displayName;
    final leftArrow = _difficultyIndex > 0 ? '◀' : ' ';
    final rightArrow =
        _difficultyIndex < _difficulties.length - 1 ? '▶' : ' ';
    renderer.write('Difficulty: $leftArrow $diffLabel $rightArrow');
    renderer.setColor(AnsiColor.reset);

    renderer.moveCursor(hsRow + 4, col);
    renderer.setColor(AnsiColor.darkGray);
    renderer.write('↑ ↓ select   ← → difficulty   Enter start   Q quit');
    renderer.setColor(AnsiColor.reset);

    // Per-mode bests
    renderer.moveCursor(hsRow + 5, col);
    renderer.setColor(AnsiColor.cyan);
    final bests = _modes.map((m) {
      final b = _scoreRepo.load(m.name);
      return b > 0 ? '${_labels[_modes.indexOf(m)]}: $b' : null;
    }).whereType<String>().join('   ');
    if (bests.isNotEmpty) renderer.write('Best  $bests');
    renderer.setColor(AnsiColor.reset);

    _rendered = true;
  }
}
