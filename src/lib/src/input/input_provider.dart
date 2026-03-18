import 'input_action.dart';

abstract interface class InputProvider {
  void init();
  InputAction? poll();
  void restore();
}
