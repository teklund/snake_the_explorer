import 'dart:io';

/// Persists per-mode high scores to ~/.snake_high_scores (key=value lines).
final class ScoreRepository {
  static final _file = File('${Platform.environment['HOME'] ?? '.'}/.snake_high_scores');

  Map<String, int> _load() {
    try {
      final result = <String, int>{};
      for (final line in _file.readAsLinesSync()) {
        final parts = line.split('=');
        if (parts.length == 2) {
          final v = int.tryParse(parts[1].trim());
          if (v != null) result[parts[0].trim()] = v;
        }
      }
      return result;
    } on FileSystemException {
      return {};
    }
  }

  /// Loads the best score for the given mode key (e.g. 'classic', 'zen', 'timeAttack').
  int load(String mode) => _load()[mode] ?? 0;

  /// Saves [score] for [mode] if it is higher than the stored value.
  void save(String mode, int score) {
    try {
      final data = _load();
      if (score <= (data[mode] ?? 0)) return;
      data[mode] = score;
      _file.writeAsStringSync(
        data.entries.map((e) => '${e.key}=${e.value}').join('\n') + '\n',
      );
    } on FileSystemException {
      // Ignore write failures silently.
    }
  }
}

