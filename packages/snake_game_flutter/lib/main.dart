import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/memory_score_repository.dart';
import 'src/widgets/console_game_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final scoreRepo = PrefsScoreRepository(prefs);

  // Lock to landscape on mobile for better grid space.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Dark system chrome for the retro vibe.
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

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
