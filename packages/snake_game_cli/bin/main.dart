import 'dart:io';

import 'package:snake_game_core/snake_game_core.dart';

import 'package:snake_game_cli/src/file_score_repository.dart';
import 'package:snake_game_cli/src/stdin_input_provider.dart';
import 'package:snake_game_cli/src/terminal_renderer.dart';

Future<void> main() async {
  final renderer = TerminalRenderer();
  final inputProvider = StdinInputProvider();
  final scoreRepo = FileScoreRepository();

  inputProvider.init();
  renderer.hideCursor();

  final cols = stdout.hasTerminal ? stdout.terminalColumns : 42;
  final rows = stdout.hasTerminal ? stdout.terminalLines : 24;

  final sceneManager = SceneManager(
    initialScene: MenuScene(
      scoreRepo: scoreRepo,
      boardColumns: cols,
      boardRows: rows,
    ),
    renderer: renderer,
    inputProvider: inputProvider,
  );

  final loop = GameLoop(sceneManager);

  // Graceful shutdown on Ctrl+C
  ProcessSignal.sigint.watch().listen((_) {
    loop.stop();
    inputProvider.restore();
    renderer.restore();
    exit(0);
  });

  await loop.run();

  inputProvider.restore();
  renderer.restore();
}
