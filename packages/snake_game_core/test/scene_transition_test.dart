import 'package:mocktail/mocktail.dart';
import 'package:snake_game_core/snake_game_core.dart';
import 'package:test/test.dart';

class _MockScoreRepo extends Mock implements ScoreRepository {}

void main() {
  late _MockScoreRepo scoreRepo;

  setUp(() {
    scoreRepo = _MockScoreRepo();
    when(() => scoreRepo.load(any())).thenReturn(0);
  });

  group('MenuScene transitions', () {
    test('update returns Stay when no input', () {
      final scene = MenuScene(scoreRepo: scoreRepo, boardColumns: 42, boardRows: 24);
      expect(scene.update(null), isA<Stay>());
    });

    test('update returns Quit on quit input', () {
      final scene = MenuScene(scoreRepo: scoreRepo, boardColumns: 42, boardRows: 24);
      expect(scene.update(InputAction.quit), isA<Quit>());
    });

    test('update returns GoTo on confirm input', () {
      final scene = MenuScene(scoreRepo: scoreRepo, boardColumns: 42, boardRows: 24);
      final transition = scene.update(InputAction.confirm);
      expect(transition, isA<GoTo>());
    });
  });

  group('GameplayScene transitions', () {
    test('update returns Quit on quit input', () {
      final scene = GameplayScene(
        scoreRepo: scoreRepo,
        boardColumns: 42,
        boardRows: 24,
      );
      expect(scene.update(InputAction.quit), isA<Quit>());
    });

    test('update returns Stay on movement input', () {
      final scene = GameplayScene(
        scoreRepo: scoreRepo,
        boardColumns: 42,
        boardRows: 24,
      );
      expect(scene.update(InputAction.moveRight), isA<Stay>());
    });
  });

  group('GameOverScene transitions', () {
    test('update returns Quit on quit input', () {
      final scene = GameOverScene(
        score: 5,
        highScore: 10,
        mode: GameMode.classic,
        scoreRepo: scoreRepo,
        boardColumns: 42,
        boardRows: 24,
      );
      expect(scene.update(InputAction.quit), isA<Quit>());
    });

    test('update returns GoTo on confirm input', () {
      final scene = GameOverScene(
        score: 5,
        highScore: 10,
        mode: GameMode.classic,
        scoreRepo: scoreRepo,
        boardColumns: 42,
        boardRows: 24,
      );
      expect(scene.update(InputAction.confirm), isA<GoTo>());
    });
  });
}
