import 'package:shared_preferences/shared_preferences.dart';
import 'package:snake_game_core/snake_game_core.dart';

/// Persists high scores via [SharedPreferences] so they survive app restarts.
final class PrefsScoreRepository implements ScoreRepository {
  final SharedPreferences _prefs;

  PrefsScoreRepository(this._prefs);

  String _key(String mode) => 'high_score_$mode';

  @override
  int load(String mode) => _prefs.getInt(_key(mode)) ?? 0;

  @override
  void save(String mode, int score) {
    final current = load(mode);
    if (score > current) {
      _prefs.setInt(_key(mode), score);
    }
  }
}
