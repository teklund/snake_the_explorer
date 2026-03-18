# Dart CLI Game — Project Guidelines

## Tech Stack

- Dart SDK (latest stable), targeting native CLI via `dart compile exe` or `dart run`
- No third-party game libraries unless explicitly approved — use `dart:io` (`stdin`, `stdout`) for all rendering and input

## Project Structure

```
lib/
  src/
    game_loop.dart       # Core loop: input → update → render
    scenes/              # Scene/screen implementations (menu, gameplay, game over)
    entities/            # Game objects and components
    rendering/           # Terminal rendering helpers
    input/               # Input abstraction
bin/
  main.dart              # Entry point, wires up game loop
test/
  game_test.dart         # Top-level test file or test/ folder per feature
pubspec.yaml
```

## Architecture

- **Game loop pattern**: Use a fixed-timestep loop — `Input → Update → Render`. Never put game logic in the render pass.
- **Scene-based state**: Implement a scene manager that switches between screens (menu, gameplay, pause, game over). Each scene owns its own `update` and `render` methods.
- **Separate logic from I/O**: Game logic must not call `stdout`/`stdin` directly. Pass a `Renderer` and `InputProvider` abstraction so logic is testable without terminal interaction.
- **Immutable game state preferred**: Where practical, use immutable value objects (`final` fields, no setters) and return new state each tick.

## Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) style
- Use `final` for all variables that are not reassigned
- Prefer plain data classes with `const` constructors for value types (positions, scores, config)
- Use `sealed class` + pattern matching (`switch`) for state and scene transitions (Dart 3+)
- Mark classes as `final` unless designed for extension
- Collections: use unmodifiable views (`List.unmodifiable`, `UnmodifiableListView`) in public APIs
- Use `switch` expressions over `if`/`else` chains for state transitions

## Terminal Rendering

- Use ANSI escape codes (`\x1B[row;colH`) to position the cursor — avoid clearing the full screen each frame (causes flicker)
- Maintain a screen buffer (`List<List<String>>`) and diff against the previous frame to minimize writes
- Hide the cursor during gameplay: `stdout.write('\x1B[?25l')` — restore on exit: `\x1B[?25h`
- Handle terminal resize gracefully — poll `stdout.terminalColumns` / `stdout.terminalLines`

## Input Handling

- Set `stdin.lineMode = false` and `stdin.echoMode = false` for raw, non-blocking input
- Read bytes from `stdin` and map to game actions via an `InputMap` class (decouple keybinding from logic)
- Restore terminal settings in a `finally` block or signal handler on exit
- Support rebindable keys via configuration

## Testing

- Use `package:test` with `package:mocktail` for mocking
- Test game logic through the abstractions (`Renderer`, `InputProvider`), never against real `stdout`/`stdin`
- Name tests: `'methodName does expected behavior when scenario'` (sentence-style, as is idiomatic in Dart)
- Keep tests fast — no `Future.delayed` or real timers; inject a `TimeProvider` abstraction for time-dependent logic

## Build & Run

```bash
dart pub get
dart run bin/main.dart
dart test
dart compile exe bin/main.dart -o game
```

## Conventions

- No global mutable state — pass dependencies explicitly via constructors
- Avoid `async`/`await` in the game loop hot path; use synchronous code for frame processing
- Handle `ProcessSignal.sigint` for graceful shutdown (Ctrl+C), restoring terminal state before exit
- Log diagnostics (FPS, tick time) to `stderr`, not `stdout`
