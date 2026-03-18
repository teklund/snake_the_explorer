import 'package:mocktail/mocktail.dart';
import 'package:snake_game_core/snake_game_core.dart';
import 'package:test/test.dart';

class _MockScoreRepo extends Mock implements ScoreRepository {}

class _MockRenderer extends Mock implements Renderer {}

HighScoresScene _scene({_MockScoreRepo? scoreRepo}) {
  final repo = scoreRepo ?? _MockScoreRepo();
  when(() => repo.load(any())).thenReturn(0);
  return HighScoresScene(
    scoreRepo: repo,
    boardColumns: 42,
    boardRows: 28,
  );
}

void main() {
  late _MockRenderer renderer;

  setUpAll(() {
    registerFallbackValue(AnsiColor.reset);
  });

  setUp(() {
    renderer = _MockRenderer();
    when(() => renderer.flush()).thenReturn(null);
    when(() => renderer.clearScreen()).thenReturn(null);
    when(() => renderer.moveCursor(any(), any())).thenReturn(null);
    when(() => renderer.write(any())).thenReturn(null);
    when(() => renderer.setColor(any())).thenReturn(null);
    when(() => renderer.hideCursor()).thenReturn(null);
    when(() => renderer.showCursor()).thenReturn(null);
    when(() => renderer.restore()).thenReturn(null);
  });

  group('HighScoresScene', () {
    test('render does not throw', () {
      final scene = _scene();
      expect(() => scene.render(renderer), returnsNormally);
    });

    test('render only draws once (second call is no-op)', () {
      final scene = _scene();
      scene.render(renderer);
      // Reset interaction tracking
      clearInteractions(renderer);
      // Second render should be a no-op due to _rendered flag
      scene.render(renderer);
      verifyNever(() => renderer.clearScreen());
    });

    test('confirm input transitions to MenuScene (GoTo)', () {
      final scene = _scene();
      final result = scene.update(InputAction.confirm);
      expect(result, isA<GoTo>());
      final goTo = result as GoTo;
      expect(goTo.next(), isA<MenuScene>());
    });

    test('quit input transitions to MenuScene (GoTo)', () {
      final scene = _scene();
      final result = scene.update(InputAction.quit);
      expect(result, isA<GoTo>());
      final goTo = result as GoTo;
      expect(goTo.next(), isA<MenuScene>());
    });

    test('null input returns Stay', () {
      final scene = _scene();
      expect(scene.update(null), isA<Stay>());
    });

    test('moveUp input returns Stay', () {
      final scene = _scene();
      expect(scene.update(InputAction.moveUp), isA<Stay>());
    });

    test('moveDown input returns Stay', () {
      final scene = _scene();
      expect(scene.update(InputAction.moveDown), isA<Stay>());
    });

    test('moveLeft input returns Stay', () {
      final scene = _scene();
      expect(scene.update(InputAction.moveLeft), isA<Stay>());
    });

    test('moveRight input returns Stay', () {
      final scene = _scene();
      expect(scene.update(InputAction.moveRight), isA<Stay>());
    });

    test('pause input returns Stay', () {
      final scene = _scene();
      expect(scene.update(InputAction.pause), isA<Stay>());
    });

    test('render displays stored high scores', () {
      final repo = _MockScoreRepo();
      when(() => repo.load('classic')).thenReturn(42);
      when(() => repo.load('zen')).thenReturn(10);
      when(() => repo.load('timeAttack')).thenReturn(0);

      final scene = HighScoresScene(
        scoreRepo: repo,
        boardColumns: 42,
        boardRows: 28,
      );
      scene.render(renderer);

      verify(() => repo.load('classic')).called(1);
      verify(() => repo.load('zen')).called(1);
      verify(() => repo.load('timeAttack')).called(1);
    });
  });
}
