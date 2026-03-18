import 'dart:io';

import 'package:snake_game_cli/src/file_score_repository.dart';
import 'package:test/test.dart';

void main() {
  group('FileScoreRepository', () {
    late Directory tempDir;
    late File scoreFile;
    late FileScoreRepository repo;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('snake_test_');
      scoreFile = File('${tempDir.path}/.snake_high_scores');
      repo = FileScoreRepository(scoreFile);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('load returns 0 when file does not exist', () {
      expect(repo.load('classic'), equals(0));
    });

    test('save then load round-trips a score', () {
      repo.save('classic', 42);
      expect(repo.load('classic'), equals(42));
    });

    test('save only persists if score is higher than current', () {
      repo.save('classic', 100);
      repo.save('classic', 50);
      expect(repo.load('classic'), equals(100));
    });

    test('save overwrites when score is strictly higher', () {
      repo.save('classic', 10);
      repo.save('classic', 20);
      expect(repo.load('classic'), equals(20));
    });

    test('save does not overwrite when score is equal', () {
      repo.save('classic', 10);
      repo.save('classic', 10);
      expect(repo.load('classic'), equals(10));
    });

    test('independent modes do not interfere', () {
      repo.save('classic', 100);
      repo.save('zen', 200);
      repo.save('timeAttack', 300);

      expect(repo.load('classic'), equals(100));
      expect(repo.load('zen'), equals(200));
      expect(repo.load('timeAttack'), equals(300));
    });

    test('load returns 0 for unknown mode', () {
      repo.save('classic', 42);
      expect(repo.load('unknown'), equals(0));
    });

    test('handles file with malformed lines gracefully', () {
      scoreFile.writeAsStringSync('badline\nclassic=42\n=nokey\nfoo=bar\n');
      expect(repo.load('classic'), equals(42));
      expect(repo.load('badline'), equals(0));
      expect(repo.load('foo'), equals(0));
    });

    test('handles empty file gracefully', () {
      scoreFile.writeAsStringSync('');
      expect(repo.load('classic'), equals(0));
    });

    test('persists data to disk in key=value format', () {
      repo.save('classic', 99);
      final content = scoreFile.readAsStringSync();
      expect(content, contains('classic=99'));
    });

    test('preserves other mode scores when saving a new mode', () {
      repo.save('classic', 10);
      repo.save('zen', 20);

      final content = scoreFile.readAsStringSync();
      expect(content, contains('classic=10'));
      expect(content, contains('zen=20'));
    });
  });
}
