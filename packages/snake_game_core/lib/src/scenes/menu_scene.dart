import '../input/input_action.dart';
import '../persistence/score_repository.dart';
import '../rendering/ansi_color.dart';
import '../rendering/renderer.dart';
import 'game_mode.dart';
import 'gameplay_scene.dart';
import 'scene.dart';

final class MenuScene extends Scene {
  final ScoreRepository _scoreRepo;
  final int _boardColumns;
  final int _boardRows;
  final GameEventCallback? _onEvent;
  int _selected = 0;
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

  @override
  SceneTransition update(InputAction? input) {
    switch (input) {
      case InputAction.moveUp:
        _selected = (_selected - 1).clamp(0, _modes.length - 1);
        _rendered = false;
      case InputAction.moveDown:
        _selected = (_selected + 1).clamp(0, _modes.length - 1);
        _rendered = false;
      case InputAction.confirm:
        final mode = _modes[_selected];
        final best = _scoreRepo.load(mode.name);
        return GoTo(() => GameplayScene(
              mode: mode,
              highScore: best,
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

    renderer.moveCursor(20, col);
    renderer.setColor(AnsiColor.darkGray);
    renderer.write('↑ ↓ select   Enter start   Q quit');
    renderer.setColor(AnsiColor.reset);

    // Per-mode bests
    renderer.moveCursor(21, col);
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
