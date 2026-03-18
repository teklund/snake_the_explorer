/// Events emitted by the gameplay scene for optional sound/haptic feedback.
enum GameEvent {
  foodEaten,
  bonusEaten,
  shrinkPillEaten,
  death,
  combo,
  portalUsed,
  newHighScore,
}

/// Payload for a game event including the grid position where it occurred.
typedef GameEventData = ({GameEvent event, int col, int row});
