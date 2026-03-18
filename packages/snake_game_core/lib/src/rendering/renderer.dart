import 'ansi_color.dart';

abstract interface class Renderer {
  void moveCursor(int row, int col);
  void write(String text);
  void clearScreen();
  void hideCursor();
  void showCursor();
  void setColor(AnsiColor color);
  void flush();
  void restore();
}
