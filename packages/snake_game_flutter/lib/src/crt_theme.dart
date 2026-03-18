import 'dart:ui';

import 'package:snake_game_core/snake_game_core.dart';

/// Defines a CRT monitor color theme that maps core [AnsiColor] values to
/// Flutter [Color]s and provides glow/scanline/background colors for the
/// overlay effects.
///
/// Use [CrtTheme.values] to iterate over all available themes, or
/// [CrtTheme.fromName] to restore a persisted selection.
enum CrtTheme {
  /// Classic green phosphor terminal (default).
  greenPhosphor(
    displayName: 'Green Phosphor',
    glowColor: Color(0x1833CC33),
    scanlineTint: Color(0x18001A00),
    backgroundColor: Color(0xFF0A0A0A),
    colorMap: _greenColors,
  ),

  /// Warm amber/orange phosphor monitor.
  amberPhosphor(
    displayName: 'Amber Phosphor',
    glowColor: Color(0x18CC8833),
    scanlineTint: Color(0x181A0E00),
    backgroundColor: Color(0xFF0A0800),
    colorMap: _amberColors,
  ),

  /// Cool blue phosphor monitor.
  bluePhosphor(
    displayName: 'Blue Phosphor',
    glowColor: Color(0x183366CC),
    scanlineTint: Color(0x1800001A),
    backgroundColor: Color(0xFF060810),
    colorMap: _blueColors,
  ),

  /// White/gray classic monochrome monitor.
  whitePhosphor(
    displayName: 'White Phosphor',
    glowColor: Color(0x18AAAAAA),
    scanlineTint: Color(0x18101010),
    backgroundColor: Color(0xFF080808),
    colorMap: _whiteColors,
  );

  /// Human-readable name shown in the UI.
  final String displayName;

  /// Phosphor glow color used for the bloom box-shadow effect.
  final Color glowColor;

  /// Tint applied to scanline stripes.
  final Color scanlineTint;

  /// Screen background color.
  final Color backgroundColor;

  /// Maps each [AnsiColor] to a themed Flutter [Color].
  final Map<AnsiColor, Color> colorMap;

  const CrtTheme({
    required this.displayName,
    required this.glowColor,
    required this.scanlineTint,
    required this.backgroundColor,
    required this.colorMap,
  });

  /// Returns the Flutter [Color] for the given [AnsiColor] in this theme.
  Color mapColor(AnsiColor c) => colorMap[c] ?? const Color(0xFFCCCCCC);

  /// Returns the next theme in the cycle.
  CrtTheme get next => CrtTheme.values[(index + 1) % CrtTheme.values.length];

  /// Looks up a theme by its [name]. Returns [greenPhosphor] if not found.
  static CrtTheme fromName(String name) {
    for (final theme in CrtTheme.values) {
      if (theme.name == name) return theme;
    }
    return greenPhosphor;
  }
}

// ---------------------------------------------------------------------------
// Color maps — const top-level maps shared by the enum variants.
// ---------------------------------------------------------------------------

const _greenColors = {
  AnsiColor.reset: Color(0xFFCCCCCC),
  AnsiColor.green: Color(0xFF33CC33),
  AnsiColor.brightGreen: Color(0xFF66FF66),
  AnsiColor.red: Color(0xFFFF3333),
  AnsiColor.yellow: Color(0xFFFFFF33),
  AnsiColor.cyan: Color(0xFF33CCCC),
  AnsiColor.magenta: Color(0xFFFF66FF),
  AnsiColor.darkGray: Color(0xFF666666),
};

const _amberColors = {
  AnsiColor.reset: Color(0xFFCCB080),
  AnsiColor.green: Color(0xFFCCA033),
  AnsiColor.brightGreen: Color(0xFFFFCC66),
  AnsiColor.red: Color(0xFFFF6633),
  AnsiColor.yellow: Color(0xFFFFDD44),
  AnsiColor.cyan: Color(0xFFDDAA55),
  AnsiColor.magenta: Color(0xFFFF9966),
  AnsiColor.darkGray: Color(0xFF886644),
};

const _blueColors = {
  AnsiColor.reset: Color(0xFFAABBDD),
  AnsiColor.green: Color(0xFF3399CC),
  AnsiColor.brightGreen: Color(0xFF66CCFF),
  AnsiColor.red: Color(0xFFCC5577),
  AnsiColor.yellow: Color(0xFF99CCFF),
  AnsiColor.cyan: Color(0xFF44AAEE),
  AnsiColor.magenta: Color(0xFFAA77DD),
  AnsiColor.darkGray: Color(0xFF556688),
};

const _whiteColors = {
  AnsiColor.reset: Color(0xFFCCCCCC),
  AnsiColor.green: Color(0xFFBBBBBB),
  AnsiColor.brightGreen: Color(0xFFEEEEEE),
  AnsiColor.red: Color(0xFFDD9999),
  AnsiColor.yellow: Color(0xFFDDDDBB),
  AnsiColor.cyan: Color(0xFFBBCCCC),
  AnsiColor.magenta: Color(0xFFCCBBCC),
  AnsiColor.darkGray: Color(0xFF777777),
};
