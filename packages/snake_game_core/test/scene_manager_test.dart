import 'package:mocktail/mocktail.dart';
import 'package:snake_game_core/snake_game_core.dart';
import 'package:test/test.dart';

class _MockRenderer extends Mock implements Renderer {}

class _MockInputProvider extends Mock implements InputProvider {}

class _MockScoreRepo extends Mock implements ScoreRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(AnsiColor.reset);
  });

  late _MockRenderer renderer;
  late _MockInputProvider inputProvider;
  late _MockScoreRepo scoreRepo;

  setUp(() {
    renderer = _MockRenderer();
    inputProvider = _MockInputProvider();
    scoreRepo = _MockScoreRepo();
    when(() => scoreRepo.load(any())).thenReturn(0);
    when(() => renderer.flush()).thenReturn(null);
    when(() => renderer.clearScreen()).thenReturn(null);
    when(() => renderer.moveCursor(any(), any())).thenReturn(null);
    when(() => renderer.write(any())).thenReturn(null);
    when(() => renderer.setColor(any())).thenReturn(null);
  });

  test('tick calls update and render on the current scene', () {
    when(() => inputProvider.poll()).thenReturn(null);

    final scene = MenuScene(
      scoreRepo: scoreRepo,
      boardColumns: 42,
      boardRows: 24,
    );
    final manager = SceneManager(
      initialScene: scene,
      renderer: renderer,
      inputProvider: inputProvider,
    );

    manager.tick();

    verify(() => renderer.flush()).called(1);
    expect(manager.isDone, isFalse);
  });

  test('tick sets isDone when scene returns Quit', () {
    var callCount = 0;
    when(() => inputProvider.poll()).thenAnswer((_) {
      callCount++;
      return callCount == 1 ? InputAction.quit : null;
    });

    final scene = MenuScene(
      scoreRepo: scoreRepo,
      boardColumns: 42,
      boardRows: 24,
    );
    final manager = SceneManager(
      initialScene: scene,
      renderer: renderer,
      inputProvider: inputProvider,
    );

    manager.tick();

    expect(manager.isDone, isTrue);
  });
}
