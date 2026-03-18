import 'dart:io';

import 'package:snake_game/src/game_loop.dart';
import 'package:snake_game/src/input/stdin_input_provider.dart';
import 'package:snake_game/src/rendering/terminal_renderer.dart';
import 'package:snake_game/src/scenes/menu_scene.dart';
import 'package:snake_game/src/scenes/scene_manager.dart';

Future<void> main() async {
  final renderer = TerminalRenderer();
  final inputProvider = StdinInputProvider();

  inputProvider.init();
  renderer.hideCursor();

  final sceneManager = SceneManager(
    initialScene: MenuScene(),
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
