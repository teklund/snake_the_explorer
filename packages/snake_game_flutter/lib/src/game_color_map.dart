import 'dart:ui';

import 'package:snake_game_core/snake_game_core.dart';

import 'crt_theme.dart';

/// Maps the core [AnsiColor] enum to a Flutter [Color] using the active
/// [CrtTheme].
///
/// When no theme is supplied the default green phosphor palette is used,
/// preserving backward compatibility with existing call-sites.
Color mapAnsiColor(AnsiColor c, [CrtTheme theme = CrtTheme.greenPhosphor]) =>
    theme.mapColor(c);
