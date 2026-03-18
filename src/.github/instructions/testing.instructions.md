---
description: "Use when writing or editing Dart tests for the game project. Covers test structure, naming, and mocking patterns for console game logic."
applyTo: "**/test/**"
---
# Test Guidelines

- Arrange/Act/Assert structure in every test
- Name pattern (sentence-style): `'methodName returns expected when scenario'`
- Use `package:mocktail` to mock `Renderer` and `InputProvider` — never interact with real `stdout`/`stdin` in tests
- For time-dependent logic, inject a `TimeProvider` abstraction and return deterministic values in tests
- Use `package:test` `expect()` with matchers: `expect(result, equals(expected))`
- One logical assertion per test — split multi-assertion checks into separate `test()` blocks
- Test scene transitions explicitly: given scene X and input Y, verify the returned `SceneTransition` is Z
