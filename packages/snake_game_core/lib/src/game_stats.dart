/// Accumulated gameplay statistics, passed to the game-over screen.
final class GameStats {
  final int foodsEaten;
  final int bonusesEaten;
  final int maxCombo;
  final int maxLength;
  final int portalsUsed;

  const GameStats({
    this.foodsEaten = 0,
    this.bonusesEaten = 0,
    this.maxCombo = 0,
    this.maxLength = 0,
    this.portalsUsed = 0,
  });
}
