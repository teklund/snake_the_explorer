import 'direction.dart';
import 'vector2.dart';

final class Snake {
  final List<Vector2> _body;
  final Direction direction;

  Snake({required List<Vector2> body, required this.direction})
      : _body = List.unmodifiable(body);

  List<Vector2> get body => _body;
  Vector2 get head => _body.first;
  int get length => _body.length;

  Snake move() {
    final newHead = head + direction.delta;
    return Snake(
      body: [newHead, ..._body.sublist(0, _body.length - 1)],
      direction: direction,
    );
  }

  Snake grow() {
    final newHead = head + direction.delta;
    return Snake(body: [newHead, ..._body], direction: direction);
  }

  Snake turn(Direction newDirection) {
    if (newDirection.isOppositeOf(direction)) return this;
    return Snake(body: List.of(_body), direction: newDirection);
  }

  /// Returns a new snake with up to [n] segments removed from the tail.
  /// The snake will always retain at least 1 segment (the head).
  Snake shrink(int n) {
    final trimmed = (_body.length - n).clamp(1, _body.length);
    return Snake(body: _body.sublist(0, trimmed), direction: direction);
  }

  bool get isSelfColliding => _body.skip(1).contains(head);
}
