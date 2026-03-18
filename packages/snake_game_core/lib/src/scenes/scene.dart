import '../input/input_action.dart';
import '../rendering/renderer.dart';

sealed class SceneTransition {
  const SceneTransition();
}

final class Stay extends SceneTransition {
  const Stay();
}

final class GoTo extends SceneTransition {
  final Scene Function() next;
  const GoTo(this.next);
}

final class Quit extends SceneTransition {
  const Quit();
}

abstract class Scene {
  Duration get tickDuration => const Duration(milliseconds: 150);
  SceneTransition update(InputAction? input);
  void render(Renderer renderer);
  void onExit() {}
}
