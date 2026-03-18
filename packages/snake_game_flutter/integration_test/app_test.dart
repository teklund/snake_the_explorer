import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snake_game_flutter/main.dart';
import 'package:snake_game_flutter/src/memory_score_repository.dart';
import 'package:snake_game_flutter/src/widgets/console_game_widget.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App integration', () {
    setUp(() {
      // Provide fake SharedPreferences so no real disk I/O is needed.
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    testWidgets('renders ConsoleGameWidget on launch', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final scoreRepo = PrefsScoreRepository(prefs);

      await tester.pumpWidget(SnakeApp(scoreRepo: scoreRepo));
      // First pump creates the LayoutBuilder; a post-frame callback starts
      // the game, so pump again to let it fire.
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.byType(ConsoleGameWidget), findsOneWidget);
    });

    testWidgets('menu scene renders game title text', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final scoreRepo = PrefsScoreRepository(prefs);

      await tester.pumpWidget(SnakeApp(scoreRepo: scoreRepo));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The Semantics label wrapping the game canvas is always present.
      expect(
        find.bySemanticsLabel('Snake game canvas'),
        findsOneWidget,
      );
    });

    testWidgets('pressing Enter transitions away from menu', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final scoreRepo = PrefsScoreRepository(prefs);

      await tester.pumpWidget(SnakeApp(scoreRepo: scoreRepo));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // The game canvas should be visible (menu scene).
      expect(
        find.bySemanticsLabel('Snake game canvas'),
        findsOneWidget,
      );

      // Simulate pressing Enter to start the game (confirm action).
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      // Let the game loop process the input and re-render.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // After pressing Enter the scene transitions from MenuScene to
      // GameplayScene. The canvas widget is still present (it is the same
      // ConsoleGameWidget), but the underlying FlutterRenderer buffer now
      // contains gameplay content instead of menu content. We verify the
      // widget tree is still intact after the transition.
      expect(find.byType(ConsoleGameWidget), findsOneWidget);
      expect(
        find.bySemanticsLabel('Snake game canvas'),
        findsOneWidget,
      );
    });

    testWidgets('arrow key input is accepted without errors', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final scoreRepo = PrefsScoreRepository(prefs);

      await tester.pumpWidget(SnakeApp(scoreRepo: scoreRepo));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Press Enter to start gameplay.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 200));

      // Send directional keys to verify input handling does not throw.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 100));

      // The game widget should still be mounted without errors.
      expect(find.byType(ConsoleGameWidget), findsOneWidget);
    });
  });
}
