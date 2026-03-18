/// Generates pixel-art app icons for Snake the Explorer.
///
/// Run from the snake_game_flutter package directory:
///   dart run tool/generate_icon.dart
///
/// Produces:
///   assets/icon/app_icon.png          — 1024x1024 full icon
///   assets/icon/app_icon_foreground.png — 1024x1024 adaptive icon foreground
library;

import 'dart:io';

import 'package:image/image.dart' as img;

/// Color palette — retro CRT aesthetic.
final class _Palette {
  static const background = (r: 0x1a, g: 0x1a, b: 0x2e);
  static const snakeBody = (r: 0x00, g: 0xcc, b: 0x66);
  static const snakeHead = (r: 0x33, g: 0xff, b: 0x88);
  static const snakeEye = (r: 0x1a, g: 0x1a, b: 0x2e);
  static const food = (r: 0xff, g: 0x33, b: 0x55);
  static const foodShine = (r: 0xff, g: 0x88, b: 0x99);
  static const gridLine = (r: 0x22, g: 0x22, b: 0x44);
  static const border = (r: 0x33, g: 0x33, b: 0x66);
}

/// A 16x16 pixel grid defining the icon art.
///
/// Legend:
///   . = background
///   # = border
///   g = grid line accent
///   B = snake body
///   H = snake head
///   E = snake eye
///   F = food
///   S = food shine
const _grid = [
  '################',
  '#..............#',
  '#..............#',
  '#....HH........#',
  '#...HEHH.......#',
  '#...HBBH.......#',
  '#....BBH.......#',
  '#....BBH.......#',
  '#.HBBBBH...SF..#',
  '#.H......g..FF.#',
  '#.H......g..FF.#',
  '#.HHHHHH.g..SF.#',
  '#........g.....#',
  '#..gggggggg....#',
  '#..............#',
  '################',
];

typedef _Rgb = ({int r, int g, int b});

_Rgb _colorFor(String cell) => switch (cell) {
      '#' => (
        r: _Palette.border.r,
        g: _Palette.border.g,
        b: _Palette.border.b,
      ),
      'g' => (
        r: _Palette.gridLine.r,
        g: _Palette.gridLine.g,
        b: _Palette.gridLine.b,
      ),
      'B' => (
        r: _Palette.snakeBody.r,
        g: _Palette.snakeBody.g,
        b: _Palette.snakeBody.b,
      ),
      'H' => (
        r: _Palette.snakeHead.r,
        g: _Palette.snakeHead.g,
        b: _Palette.snakeHead.b,
      ),
      'E' => (
        r: _Palette.snakeEye.r,
        g: _Palette.snakeEye.g,
        b: _Palette.snakeEye.b,
      ),
      'F' => (
        r: _Palette.food.r,
        g: _Palette.food.g,
        b: _Palette.food.b,
      ),
      'S' => (
        r: _Palette.foodShine.r,
        g: _Palette.foodShine.g,
        b: _Palette.foodShine.b,
      ),
      _ => (
        r: _Palette.background.r,
        g: _Palette.background.g,
        b: _Palette.background.b,
      ),
    };

/// Renders the 16x16 [_grid] into a 1024x1024 image.
///
/// Each pixel in the grid becomes a 64x64 block in the output.
img.Image _renderGrid({required bool transparent}) {
  const gridSize = 16;
  const outputSize = 1024;
  const cellSize = outputSize ~/ gridSize; // 64

  final image = img.Image(
    width: outputSize,
    height: outputSize,
    numChannels: 4,
  );

  for (var gy = 0; gy < gridSize; gy++) {
    final row = _grid[gy];
    for (var gx = 0; gx < gridSize; gx++) {
      final cell = row[gx];
      final color = _colorFor(cell);

      // For the foreground image, make the background transparent.
      final isBackground = cell == '.' || cell == '#';
      final alpha = (transparent && isBackground) ? 0 : 255;

      for (var dy = 0; dy < cellSize; dy++) {
        for (var dx = 0; dx < cellSize; dx++) {
          final px = gx * cellSize + dx;
          final py = gy * cellSize + dy;
          image.setPixelRgba(px, py, color.r, color.g, color.b, alpha);
        }
      }
    }
  }

  return image;
}

void main() {
  final scriptDir = Platform.script.toFilePath();
  final packageDir =
      scriptDir.substring(0, scriptDir.lastIndexOf('tool/generate_icon.dart'));
  final iconDir = '${packageDir}assets/icon';

  // Ensure output directory exists.
  Directory(iconDir).createSync(recursive: true);

  // Generate full icon (opaque).
  final fullIcon = _renderGrid(transparent: false);
  final fullIconPath = '$iconDir/app_icon.png';
  File(fullIconPath).writeAsBytesSync(img.encodePng(fullIcon));
  stdout.writeln('Generated $fullIconPath (${fullIcon.width}x${fullIcon.height})');

  // Generate adaptive foreground (transparent background).
  final foreground = _renderGrid(transparent: true);
  final foregroundPath = '$iconDir/app_icon_foreground.png';
  File(foregroundPath).writeAsBytesSync(img.encodePng(foreground));
  stdout.writeln('Generated $foregroundPath (${foreground.width}x${foreground.height})');
}
