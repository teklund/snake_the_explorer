import 'dart:ui';

import 'package:snake_game_core/snake_game_core.dart';

/// Maps the core [AnsiColor] enum to Flutter [Color] values that evoke
/// a retro CRT terminal aesthetic.
Color mapAnsiColor(AnsiColor c) => switch (c) {
      AnsiColor.reset => const Color(0xFFCCCCCC),
      AnsiColor.green => const Color(0xFF33CC33),
      AnsiColor.brightGreen => const Color(0xFF66FF66),
      AnsiColor.red => const Color(0xFFFF3333),
      AnsiColor.yellow => const Color(0xFFFFFF33),
      AnsiColor.cyan => const Color(0xFF33CCCC),
      AnsiColor.magenta => const Color(0xFFFF66FF),
      AnsiColor.darkGray => const Color(0xFF666666),
    };
