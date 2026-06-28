# Architecture

This document defines the project's folder structure and state-management
convention. It is the foundation every feature plugs into — please follow it so
the connection layer, UI and dashboards stay consistent instead of diverging.

## State management: Riverpod

We use [Riverpod](https://riverpod.dev) (`flutter_riverpod`) for state
management and dependency injection.

Why Riverpod over the alternatives:

- **Async & streams first-class.** Home Assistant pushes real-time entity
  updates over a WebSocket. Riverpod's `StreamProvider`/`FutureProvider` and
  `AsyncValue` model loading/data/error states cleanly, which fits this domain
  better than event-driven Bloc boilerplate or plain Provider.
- **Dependency injection & testability.** Providers can be overridden in tests
  and at the root `ProviderScope`, so we can swap a fake Home Assistant client
  without touching widgets.
- **Compile-safe.** Providers are referenced as top-level objects, avoiding the
  runtime `BuildContext` lookups Provider relies on.

The whole app is wrapped in a `ProviderScope` in [`lib/main.dart`](../lib/main.dart).

### Pattern

Each feature exposes its state through a controller in its `application/` layer:

- A `Notifier` (or `AsyncNotifier`/`StreamNotifier` for async data) holds the
  state and exposes methods that mutate it.
- A matching provider exposes the controller.
- Widgets `ref.watch(...)` to rebuild on change and `ref.read(...).method()` to
  dispatch actions.

The reference implementation is the trivial counter in
[`lib/features/home/`](../lib/features/home) — it wires one provider end to end
and can be deleted once a real feature replaces the home screen.

## Folder structure (feature-first)

```
lib/
  main.dart                 # entry point: wraps the app in a ProviderScope
  app/                      # app shell (MaterialApp, global wiring)
  core/                     # app-wide infrastructure (theme, config, routing…)
  features/                 # one folder per feature, each self-contained
    <feature>/
      data/                 # data sources (WebSocket/REST) + repositories
      domain/               # plain models / entities for this feature
      application/          # Riverpod controllers (Notifiers) + providers
      presentation/         # screens and feature-specific widgets
  shared/                   # cross-feature widgets, extensions, utilities
```

Guidelines:

- **Feature-first.** Everything a feature needs lives under
  `features/<feature>/`. Prefer adding a feature folder over a global technical
  layer.
- **Layers within a feature.** `presentation` depends on `application`, which
  depends on `domain` and `data`. Dependencies point inward — `data`/`domain`
  never import `presentation`.
- **`core/` vs `shared/`.** `core/` is app-wide infrastructure (theme, config,
  routing). `shared/` is reusable UI/util code with no feature ownership. Not
  every subfolder needs to exist up front — create them as features require.
- **Naming.** `snake_case.dart` files; suffix by role where it aids clarity
  (`*_controller.dart`, `*_repository.dart`, `*_page.dart`).

## Quality gates

`flutter analyze` and `flutter test` must pass. CI enforces formatting,
analysis and tests on `main`, `develop` and pull requests.
