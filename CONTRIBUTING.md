# Contributing

Thanks for your interest in contributing to Snake the Explorer!

## Getting Started

1. Fork and clone the repo
2. Run `dart pub get` at the root
3. Make sure tests pass: `dart test packages/snake_game_core && dart test packages/snake_game_cli`
4. For Flutter: `cd packages/snake_game_flutter && flutter test`

## Architecture Rules

Before contributing, please read the architecture section in the [README](README.md). Key points:

- **Core package** (`snake_game_core`) must never import `dart:io` or `package:flutter`
- All platform I/O goes through `Renderer`, `InputProvider`, and `ScoreRepository` interfaces
- Game loop: **Input → Update → Render** — no game logic in the render pass
- Prefer immutable value objects (`final` fields, `const` constructors)
- Use `sealed class` + pattern matching for state transitions
- Dependencies injected via constructors — no global mutable state

## Code Style

- Follow [Effective Dart](https://dart.dev/effective-dart)
- `final` for all non-reassigned variables
- `final class` unless designed for extension
- `switch` expressions over `if`/`else` chains for state transitions
- Run `dart analyze` before submitting — zero warnings required

## Pull Requests

1. Create a feature branch from `master`
2. Keep commits focused and well-described
3. Ensure all tests pass and `dart analyze` is clean
4. Open a PR with a clear description of what and why

## Reporting Issues

Open an issue with:
- What you expected
- What happened instead
- Steps to reproduce
- Platform (CLI / Flutter + which OS)
