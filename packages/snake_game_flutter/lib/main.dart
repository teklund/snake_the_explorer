import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/memory_score_repository.dart';
import 'src/widgets/console_game_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final scoreRepo = PrefsScoreRepository(prefs);

  // Allow all orientations — the game auto-pauses on rotation so the player
  // never loses progress. Portrait shows a "rotate for best experience" hint.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Dark system chrome for the retro vibe.
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

  // Hide status bar and navigation bar on mobile for maximum screen real estate.
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  runApp(SnakeApp(scoreRepo: scoreRepo));
}

class SnakeApp extends StatelessWidget {
  final PrefsScoreRepository scoreRepo;

  const SnakeApp({super.key, required this.scoreRepo});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snake the Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
      ),
      home: Scaffold(
        body: ConsoleGameWidget(scoreRepo: scoreRepo),
      ),
    );
  }
}
