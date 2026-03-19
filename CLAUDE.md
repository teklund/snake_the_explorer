# Snake the Explorer

## Project Structure

Dart pub workspace mono-repo with three packages:

- `packages/snake_game_core/` — Pure Dart game logic. **No dart:io, no Flutter.** Contains entities, scenes, game loop, rendering/input interfaces, score repository interface.
- `packages/snake_game_cli/` — Terminal target using `dart:io`. TerminalRenderer, StdinInputProvider, FileScoreRepository.
- `packages/snake_game_flutter/` — Flutter target. Console-style monospace grid rendering.

## Build & Run

```bash
# Resolve all workspace dependencies
dart pub get

# Run CLI version
dart run packages/snake_game_cli/bin/main.dart

# Run Flutter version
cd packages/snake_game_flutter && flutter run

# Run tests
dart test packages/snake_game_core
dart test packages/snake_game_cli
flutter test packages/snake_game_flutter/test/  # use flutter test, NOT dart test

# Analyze
dart analyze
```

## Architecture Rules

- Core package must never import `dart:io` or `package:flutter`. All platform I/O goes through `Renderer`, `InputProvider`, and `ScoreRepository` interfaces.
- Game loop pattern: Input → Update → Render. No game logic in render pass.
- Scene-based state machine: `MenuScene` → `GameplayScene` → `GameOverScene`, managed by `SceneManager`.
- Prefer immutable value objects (`final` fields, `const` constructors) for game state.
- Use `sealed class` + pattern matching for state transitions.
- Dependencies injected via constructors — no global mutable state.

## Code Style

- Follow Effective Dart
- `final` for all non-reassigned variables
- `final class` unless designed for extension
- `switch` expressions over `if`/`else` chains for state transitions
