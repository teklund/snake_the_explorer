import 'dart:async';

import 'scenes/scene_manager.dart';

final class GameLoop {
  final SceneManager _sceneManager;
  Timer? _timer;
  final _done = Completer<void>();
  late Duration _activeDuration;

  GameLoop(this._sceneManager);

  Future<void> run() {
    _activeDuration = _sceneManager.tickDuration;
    _startTimer();
    return _done.future;
  }

  void _startTimer() {
    _timer = Timer.periodic(_activeDuration, (_) {
      _sceneManager.tick();
      if (_sceneManager.isDone) {
        stop();
        return;
      }
      final newDuration = _sceneManager.tickDuration;
      if (newDuration != _activeDuration) {
        _activeDuration = newDuration;
        _timer?.cancel();
        _startTimer();
      }
    });
  }

  void stop() {
    _timer?.cancel();
    if (!_done.isCompleted) _done.complete();
  }
}
