---
description: "Use when creating or editing game scenes, screen transitions, or the scene manager. Covers scene lifecycle, state ownership, and transition patterns."
applyTo: "**/scenes/**"
---
# Scene Guidelines

- Every scene implements the `Scene` abstract class with `update(GameTime)` and `render(Renderer)` methods
- Scenes do not reference each other directly — return a `SceneTransition` sealed class value from `update` and let the scene manager handle switching
- Keep per-scene state private (`_` prefix); share data between scenes via a `SharedGameState` immutable object passed through the constructor
- Clean up scene-specific resources in an `onExit()` method — don't leak state across transitions
