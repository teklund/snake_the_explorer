/// Platform-agnostic interface for persisting per-mode high scores.
abstract interface class ScoreRepository {
  /// Loads the best score for the given mode key (e.g. 'classic', 'zen', 'timeAttack').
  int load(String mode);

  /// Saves [score] for [mode] if it is higher than the stored value.
  void save(String mode, int score);
}
