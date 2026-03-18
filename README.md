# Snake the Explorer

A retro console-style snake game that feels like playing in a terminal — everywhere.

Built as a Dart pub workspace mono-repo with a platform-agnostic core, a native CLI target, and a Flutter target that runs on Android, iOS, macOS, Windows, Linux, and the web.

## Play

**Web** — [Play in your browser](https://teklund.github.io/snake_the_explorer/)

**CLI** — Download a native binary from [Releases](https://github.com/teklund/snake_the_explorer/releases), or run from source:

```bash
dart run packages/snake_game_cli/bin/main.dart
```

**Flutter** — Run on any platform:

```bash
cd packages/snake_game_flutter && flutter run
```

## Features

- **3 Game Modes** — Classic (walls kill), Zen (walls wrap), Time Attack (60 seconds)
- **3 Difficulty Levels** — Easy, Normal, Hard
- **Items** — Food, bonus food, shrink pills, portal pairs, progressive obstacles
- **Combo System** — Eat quickly to build multipliers
- **High Scores** — Persisted per mode (file-based for CLI, SharedPreferences for Flutter)
- **4 CRT Themes** — Green, amber, blue, white phosphor (press `T` to cycle)
- **Retro Effects** — Scanlines, vignette, phosphor bloom, screen shake, particles
- **Procedural Audio** — All sounds synthesized at runtime (zero audio assets)
- **Haptic Feedback** — Vibration on mobile devices
- **Gamepad Support** — D-pad, face buttons, and on-screen D-pad for touch
- **Blinking Cursor** — Real terminal cursor at 530ms blink rate
- **Platform-Adaptive Chrome** — macOS traffic lights, Windows controls, fullscreen on mobile
- **PWA Installable** — Install from browser on any device
- **Accessibility** — Semantic labels for screen readers

## Controls

| Action | Keyboard | Gamepad |
|--------|----------|---------|
| Move | Arrow keys / WASD | D-pad |
| Confirm | Enter / Space | A / Start |
| Quit | Esc / Q | B |
| Pause | P | Select |
| Cycle theme | T | — |
| Toggle sound | M | — |

## Architecture

```
snake_the_explorer/
├── packages/
│   ├── snake_game_core/    # Pure Dart — zero platform imports
│   │   └── src/
│   │       ├── entities/       # Snake, Vector2, Direction
│   │       ├── scenes/         # Menu, Gameplay, GameOver, HighScores
│   │       ├── systems/        # SpawnSystem
│   │       ├── rendering/      # Renderer + AnsiColor interfaces
│   │       ├── input/          # InputProvider + InputAction interfaces
│   │       └── persistence/    # ScoreRepository interface
│   ├── snake_game_cli/     # Terminal target (dart:io)
│   └── snake_game_flutter/ # Flutter target (all platforms)
│       └── src/
│           ├── widgets/        # ConsoleGridPainter, CrtOverlay, DpadWidget, etc.
│           ├── sound_manager.dart      # Procedural WAV synthesis
│           ├── crt_theme.dart          # 4 color themes
│           └── terminal_chrome.dart    # Platform-adaptive window frame
```

**Key design rules:**
- Core package never imports `dart:io` or `package:flutter`
- All platform I/O goes through `Renderer`, `InputProvider`, and `ScoreRepository` interfaces
- Game loop: Input → Update → Render (no logic in render pass)
- Scene-based state machine with `sealed class` transitions
- Dependencies injected via constructors — no global mutable state

## Build & Test

```bash
# Resolve all workspace dependencies
dart pub get

# Run tests (160 total)
dart test packages/snake_game_core    # 89 tests
dart test packages/snake_game_cli     # 57 tests
cd packages/snake_game_flutter && flutter test  # 14 tests

# Analyze
dart analyze

# Build CLI native binary
dart compile exe packages/snake_game_cli/bin/main.dart -o snake

# Build Flutter for any platform
cd packages/snake_game_flutter
flutter build web
flutter build macos
flutter build apk
flutter build ios --no-codesign
flutter build linux
flutter build windows
```

## CI/CD

- **CI** — Analyze, test, and build all 10 targets on every push/PR
- **GitHub Pages** — Web build auto-deploys on push to master
- **Releases** — Tag `v*.*.*` to build CLI binaries + web zip and create a GitHub Release
- **Dependabot** — Weekly updates for Dart/Flutter deps and GitHub Actions

## License

[MIT](LICENSE)
