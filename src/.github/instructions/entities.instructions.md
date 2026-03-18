---
description: "Use when creating or editing game entities, components, or game objects. Covers entity design patterns for a console game."
applyTo: "**/entities/**"
---
# Entity Guidelines

- Represent entities as plain data classes with `final` fields and `const` constructors — behavior lives in systems or update functions, not on the entity itself
- Use composition over inheritance: attach capabilities via component objects, not deep class hierarchies
- Position and velocity should use an immutable `Vector2` value class with `final int x, y` fields and a `const` constructor
- Keep entity creation in static factory methods — primary constructors stay minimal
