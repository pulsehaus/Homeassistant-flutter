# Home Assistant Flutter (Unofficial)

An unofficial reimplementation of the Home Assistant frontend in Flutter.

Today the official experience is split across three separate codebases — the
web frontend (Polymer/Lit), the Android app (Kotlin) and the iOS app (Swift).
This project explores unifying all of it into a **single Flutter codebase**
that targets web, Android, iOS (and potentially desktop) at once.

## Goals

- 🧩 One codebase for every platform (web, Android, iOS, desktop)
- 🔌 Connect to a Home Assistant instance via its WebSocket + REST API
- 🎨 Recreate the Lovelace dashboards and cards
- ⚙️ Reuse Home Assistant's existing YAML / UI dashboard configuration
- ⚡ Progressive feature parity with the official frontend

## Status

🚧 Early / experimental. Expect breaking changes and missing features.

## Why

Maintaining three independent frontends means every feature, fix and design
change has to be implemented and tested three times. A single Flutter codebase
aims to cut that to one, while keeping native performance on mobile and a
first-class web build.

> **Note:** The hardest part of this project is not the cross-platform UI — it
> is faithfully reimplementing the Lovelace card system and dashboard
> configuration, which makes up the bulk of the official frontend.

## Getting Started

```bash
git clone https://github.com/pulsehaus/Homeassistant-flutter.git
cd Homeassistant-flutter
fvm install            # installs the Flutter version pinned in .fvmrc
fvm flutter pub get
fvm flutter run
```

This project pins its Flutter SDK with [FVM](https://fvm.app) via `.fvmrc`
(currently 3.41.6). Install FVM once (`dart pub global activate fvm`), then run
every Flutter/Dart command through it (`fvm flutter ...` / `fvm dart ...`) so all
contributors build against the same version.

You will need a running Home Assistant instance and a long-lived access token
(Profile → Security → Long-lived access tokens).

## Architecture

The app uses a **feature-first** structure under `lib/` and
[Riverpod](https://riverpod.dev) for state management. See
[docs/architecture.md](docs/architecture.md) for the folder layout, the
state-management pattern and the conventions every feature should follow.

```
lib/
  main.dart       # entry point (ProviderScope)
  app/            # app shell (MaterialApp, global wiring)
  core/           # app-wide infrastructure (theme, config, routing…)
  features/       # one self-contained folder per feature
  shared/         # cross-feature widgets and utilities
```

## Contributing

Contributions are welcome. Please open an issue to discuss significant changes
before submitting a pull request.

Before you start, read [`AGENTS.md`](AGENTS.md) — the single source of truth for
the project's development rules (FVM usage, SOLID/clean-architecture layering,
testing, formatting, Conventional Commits referencing the issue, and the
issue/label conventions). It applies to human contributors and AI coding
assistants alike; per-tool files (`CLAUDE.md`, `GEMINI.md`, Copilot, Cursor)
just point back to it.

## License

[MIT](LICENSE)

## Disclaimer

This is an unofficial, community-built project. It is **not affiliated with,
endorsed by, or supported by** Nabu Casa or the official Home Assistant
project. "Home Assistant" is a trademark of its respective owners and is used
here for descriptive purposes only.
