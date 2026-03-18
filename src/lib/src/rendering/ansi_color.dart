enum AnsiColor {
  reset,
  green,
  brightGreen,
  red,
  yellow,
  cyan,
  magenta,
  darkGray;

  String get code => switch (this) {
        AnsiColor.reset => '\x1B[0m',
        AnsiColor.green => '\x1B[32m',
        AnsiColor.brightGreen => '\x1B[92m',
        AnsiColor.red => '\x1B[31m',
        AnsiColor.yellow => '\x1B[33m',
        AnsiColor.cyan => '\x1B[36m',
        AnsiColor.magenta => '\x1B[95m',
        AnsiColor.darkGray => '\x1B[90m',
      };
}
