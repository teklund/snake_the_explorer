import 'dart:io';

import 'package:snake_game_core/snake_game_core.dart';

/// Persists per-mode high scores to ~/.snake_high_scores (key=value lines).
final class FileScoreRepository implements ScoreRepository {
  /// Creates a [FileScoreRepository] backed by [file].
  ///
  /// When omitted the default location is `~/.snake_high_scores`.
  FileScoreRepository([File? file])
      : _file = file ??
            File(
              '${Platform.environment['HOME'] ?? '.'}/.snake_high_scores',
            );

  final File _file;

  Map<String, int> _loadAll() {
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

  @override
  int load(String mode) => _loadAll()[mode] ?? 0;

  @override
  void save(String mode, int score) {
    try {
      final data = _loadAll();
      if (score <= (data[mode] ?? 0)) return;
      data[mode] = score;
      _file.writeAsStringSync(
        '${data.entries.map((e) => '${e.key}=${e.value}').join('\n')}\n',
      );
    } on FileSystemException {
      // Ignore write failures silently.
    }
  }
}
