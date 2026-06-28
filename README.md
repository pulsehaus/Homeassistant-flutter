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
flutter pub get
flutter run
```

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

## License

[MIT](LICENSE)

## Disclaimer

This is an unofficial, community-built project. It is **not affiliated with,
endorsed by, or supported by** Nabu Casa or the official Home Assistant
project. "Home Assistant" is a trademark of its respective owners and is used
here for descriptive purposes only.
