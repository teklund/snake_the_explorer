/// Difficulty levels for the snake game.
///
/// Each difficulty adjusts the game speed via [speedMultiplier], which is
/// applied against the tick duration — higher values produce a slower game.
enum Difficulty {
  easy,
  normal,
  hard;

  /// Human-readable label for menu display.
  String get displayName => switch (this) {
        Difficulty.easy => 'Easy',
        Difficulty.normal => 'Normal',
        Difficulty.hard => 'Hard',
      };

  /// Multiplier applied to the base tick duration.
  ///
  /// Values greater than 1.0 slow the game down; values below 1.0 speed it up.
  double get speedMultiplier => switch (this) {
        Difficulty.easy => 1.5,
        Difficulty.normal => 1.0,
        Difficulty.hard => 0.7,
      };
}
