import 'package:snake_game_core/snake_game_core.dart';

/// A single cell in the console grid buffer.
final class Cell {
  String character;
  AnsiColor foreground;

  Cell({this.character = ' ', this.foreground = AnsiColor.reset});
}
