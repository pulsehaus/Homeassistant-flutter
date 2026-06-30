# AGENTS.md

Single source of truth for how this project is developed — by humans and by AI
coding assistants alike. Every tool-specific config file (`CLAUDE.md`,
`GEMINI.md`, `.github/copilot-instructions.md`, `.cursor/rules/`) points here
instead of restating the rules, so they can never drift apart.

`AGENTS.md` is the cross-tool standard (stewarded by the Linux Foundation's
Agentic AI Foundation) and is read natively by Codex CLI, GitHub Copilot,
Cursor, Windsurf, Amp and others. If you only read one file before contributing,
read this one.

## Project

Home Assistant Flutter (unofficial) — a single Flutter codebase targeting web,
Android, iOS and (later) desktop. See [`README.md`](README.md) for the product
goals and [`docs/architecture.md`](docs/architecture.md) for the folder layout
and state-management pattern.

## Toolchain — use FVM locally

Flutter is pinned with [FVM](https://fvm.app) via [`.fvmrc`](.fvmrc) (currently
**3.41.6**). Run **every** Flutter/Dart command through FVM so all contributors
build against the exact same SDK:

```bash
fvm flutter pub get
fvm flutter run
fvm flutter analyze
fvm flutter test
fvm dart format .
```

CI does **not** need FVM installed: it reads the version straight from `.fvmrc`
and feeds it to the Flutter action (see
[`.github/workflows/ci.yml`](.github/workflows/ci.yml)). `.fvmrc` is therefore
the single source of truth for the SDK version on every machine.

## Architecture — SOLID + clean-architecture layering

The app is **feature-first** with Riverpod for state and dependency injection.
The authoritative description lives in
[`docs/architecture.md`](docs/architecture.md); the rules below are the
expectations every change must respect.

- **Feature-first.** Everything a feature needs lives under
  `lib/features/<feature>/`. Prefer adding a feature folder over a global
  technical layer.
- **Layered dependencies point inward.** Within a feature,
  `presentation → application → domain`/`data`. `data` and `domain` must never
  import `presentation`. `application` (Riverpod controllers) holds state and
  exposes intent-revealing methods.
- **`core/` vs `shared/`.** `core/` is app-wide infrastructure (theme, config,
  routing). `shared/` is reusable UI/util code with no single feature owner.
- **SOLID.** Single-responsibility classes; depend on abstractions (inject
  repositories/clients through Riverpod providers so they can be overridden in
  tests); keep widgets thin and push logic into controllers.
- **Naming.** `snake_case.dart` files, suffixed by role where it helps clarity
  (`*_controller.dart`, `*_repository.dart`, `*_page.dart`). Read theming from
  `Theme.of(context)` rather than hard-coding colours/styles.
- **Riverpod scoped overrides — declare `dependencies`.** The app overrides
  `haConnectionConfigProvider` in a **nested `ProviderScope`** (`_ConnectedApp`
  in `lib/app/app.dart`, holding the connected instance's URL + token). In
  Riverpod 2.x, every provider that *transitively* reads the connection
  providers (`haWebSocketClientProvider`, `haRestClientProvider`,
  `entityStatesProvider`, `connectionStateProvider`, `entityProvider`, …) **must
  declare its scoped `dependencies`** — e.g.
  `Provider(..., dependencies: [haWebSocketClientProvider])`. Omitting it passes
  the headless tests but **crashes at real runtime** with a scoped-dependency
  assertion. Rule of thumb: when you add a *provider* that reads any
  connection-derived provider, list the direct one in `dependencies`. (Widgets
  reading providers are always fine — only new providers need this.)

## Testing — unit *and* integration

Tests are required for new logic. Pick the level **and the directory** by what
the test needs to run:

- **Unit tests** (`test/`) for isolated logic with mocked dependencies/transport
  — e.g. a controller, a repository, a parser.
- **Headless integration tests** (`test/`) for end-to-end flows that don't need a
  device — e.g. the data/network layer driven against a real or faked local
  server (a pure-Dart test with no widget binding). These run with
  `fvm flutter test` and in CI. Name the concrete flow under test.
- **Device-driven integration tests** (`integration_test/`) for flows that drive
  the running app/UI — they need a connected device or emulator. They are **not**
  run by plain `fvm flutter test` (which only covers `test/`); CI now runs them on
  an Android emulator in a dedicated job (see *How `integration_test/` runs in CI*
  below). Run them locally against a connected device/emulator with
  `fvm flutter test integration_test`. Name the concrete flow under test.
- For a **bug fix**, include a **regression test** that fails before the fix and
  passes after.

Why the split: Flutter's `integration_test/` directory drives a real device, so
its CI job (the emulator below) is slower and heavier — keep pure-Dart headless
network/integration tests under `test/` so they stay in the fast job.

Definition of done for any code change: `fvm dart format .`, `fvm flutter analyze`
and `fvm flutter test` (the headless suite) all pass. The device-driven
`integration_test/` suites run in CI on an Android emulator (the
`integration-test-android` job); run them locally with
`fvm flutter test integration_test` against a connected device/emulator.

**How `integration_test/` runs in CI.** A dedicated `integration-test-android`
job in [`ci.yml`](.github/workflows/ci.yml) boots a headless Android emulator on
`ubuntu-latest` (via `reactivecircus/android-emulator-runner`, with KVM enabled
and an AVD snapshot cache) and runs `flutter test integration_test` against it,
so the suites exercise the real Android build/install path. It is a **separate**
job from the fast headless `analyze-and-test` gate (which stays format + analyze
+ `fvm flutter test`), and the Flutter version still comes from `.fvmrc`. The
modern `flutter test integration_test` command needs **no `test_driver/` folder**
— don't add one (`flutter drive` is the legacy path, only needed for web).

## Formatting & lint

- Format with `fvm dart format .` — CI fails on unformatted code
  (`dart format --output=none --set-exit-if-changed .`).
- Lint with the configured [`flutter_lints`](analysis_options.yaml) ruleset;
  `fvm flutter analyze` must be clean (no errors or warnings).

## Commits & pull requests

- **Conventional Commits.** `type(scope): summary` — e.g.
  `feat(comm): add websocket auth handshake`. Common types: `feat`, `fix`,
  `chore`, `refactor`, `test`, `docs`.
- **Always reference the issue.** Put `#<issue-number>` in the commit message so
  GitHub links every commit to its issue on the issue timeline, e.g.
  `feat(comm): add websocket auth handshake (#2)`. PRs link their issue too.
- **Auto-close fires only on the default branch (`main`), not `develop`.** We
  work on `develop`, so a `Closes #<n>` / `Fixes #<n>` in a PR that targets
  `develop` only *links* the issue — it does **not** close it. The issue closes
  automatically only once the work reaches `main` (when `develop` is merged into
  `main`), and only if the closing keyword lives in a **commit message** that
  survives to `main` — a keyword in a feature-PR *description* never closes,
  because that PR didn't target `main`. Until then, track progress with the
  `status:` labels (`in progress` → `needs review`) and close the issue manually
  if needed.
- **Only the maintainer merges.** Contributors (human or AI) open PRs against
  `develop` and wait for review — **don't merge your own PR**. For now,
  [@pulsehaus](https://github.com/pulsehaus) reviews and merges every PR, then
  closes the linked issue manually.

## Working on an issue — assignment first

- **Work is granted before it starts.** No one — human dev or AI agent — picks
  up an issue without the team granting it to them first. Before you start, the
  issue must be **assigned** to you (GitHub assignee) and moved to
  **`status: in progress`**.
- **Don't open a PR for an issue that wasn't assigned to you.**
- One agent / one contributor per issue; keep the branch scoped to that issue.
- Branch from `develop` (the integration branch), not `main`. Suggested branch
  name: `feature/<issue-number>-<short-slug>`.

## Issues & labels

- **Issues are written in English** (open-source convention), even if discussed
  in another language.
- Use the repo's **label taxonomy**:
  - **type:** `type: bug`, `type: feature`, `type: enhancement`,
    `type: documentation`, `type: refactor`, `type: test`, `type: chore`
  - **priority:** `priority: critical`, `priority: high`, `priority: medium`,
    `priority: low`
  - **status:** `status: needs triage`, `status: in progress`,
    `status: needs review`
- Filing issues with Claude Code? Use the versioned
  [`create-issue` skill](.claude/skills/create-issue/SKILL.md) — it produces a
  typed title, a structured English body and the right labels, then creates the
  issue with `gh`.

## Per-tool config files

These thin files exist so each assistant reads its native config but the rules
stay here:

- [`CLAUDE.md`](CLAUDE.md) — Claude Code
- [`GEMINI.md`](GEMINI.md) — Gemini CLI
- [`.github/copilot-instructions.md`](.github/copilot-instructions.md) — GitHub Copilot
- [`.cursor/rules/agents.mdc`](.cursor/rules/agents.mdc) — Cursor

When the rules change, edit **this file** — not the per-tool copies.
