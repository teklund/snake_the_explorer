import '../input/input_action.dart';
import '../input/input_provider.dart';
import '../rendering/renderer.dart';
import 'scene.dart';

final class SceneManager {
  Scene _current;
  final Renderer _renderer;
  final InputProvider _inputProvider;
  bool _done = false;

  SceneManager({
    required Scene initialScene,
    required Renderer renderer,
    required InputProvider inputProvider,
  })  : _current = initialScene,
        _renderer = renderer,
        _inputProvider = inputProvider;

  bool get isDone => _done;
  Duration get tickDuration => _current.tickDuration;

  void tick() {
    // Drain the full input queue but keep the FIRST direction action.
    // Keeping the last would let the player U-turn through themselves by
    // pressing two opposite keys within a single tick.
    InputAction? input;
    InputAction? next;
    while ((next = _inputProvider.poll()) != null) {
      input ??= next;
    }
    final transition = _current.update(input);

    switch (transition) {
      case Stay():
        break;
      case GoTo(:final next):
        _current.onExit();
        _current = next();
      case Quit():
        _current.onExit();
        _done = true;
        return;
    }

    _current.render(_renderer);
    _renderer.flush();
  }
}
