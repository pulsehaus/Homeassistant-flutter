# Contributing

Thanks for your interest in **Home Assistant Flutter**! This guide gets you from
zero to your first merged change. The full rules live in
[`AGENTS.md`](AGENTS.md) — this file is the friendly summary.

## Looking for a first contribution?

Start with an issue labelled
[**`good first issue`**](https://github.com/pulsehaus/Homeassistant-flutter/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22).
These are small and well-scoped, with a **"Where to look"** section pointing you
to the right files. Comment on the issue to ask anything — questions are welcome.

## Setup

This project pins its Flutter SDK with [FVM](https://fvm.app) via `.fvmrc`
(currently **3.41.6**). Install FVM once, then run **every** Flutter/Dart command
through it so you build against the same version as everyone else:

```bash
dart pub global activate fvm
fvm flutter pub get
fvm flutter run
```

You'll need a running Home Assistant instance and a long-lived access token
(Profile → Security → Long-lived access tokens) to use the app.

## Workflow

1. **Get the issue assigned to you first.** Don't start work (or open a PR) on an
   issue that isn't assigned to you and moved to `status: in progress` — this
   avoids two people doing the same thing.
2. **Branch from `develop`** (the integration branch, not `main`):
   `feature/<issue-number>-<short-slug>`.
3. **Code** following the architecture in
   [`docs/architecture.md`](docs/architecture.md) (feature-first, Riverpod, SOLID).
4. **Test.** Add headless tests under `test/` (unit + widget). New logic needs
   tests; a bug fix needs a regression test. See the testing section of
   [`AGENTS.md`](AGENTS.md) for the `test/` vs `integration_test/` split.
5. **Check it's green** before pushing:
   ```bash
   fvm dart format .
   fvm flutter analyze
   fvm flutter test
   ```
6. **Commit** with [Conventional Commits](https://www.conventionalcommits.org)
   that reference the issue, e.g. `feat(charts): add entity picker (#20)`.
7. **Open a PR against `develop`** describing what changed and referencing the
   issue (`Refs #<n>`).

## Review & merge

> **Only the maintainer merges PRs.** Open your PR against `develop` and wait for
> review — please **don't merge your own PR**. For now, [@pulsehaus](https://github.com/pulsehaus)
> reviews and merges everything. (Note: because we target `develop`, GitHub won't
> auto-close the issue on merge — the maintainer closes it manually.)

## The full rules

[`AGENTS.md`](AGENTS.md) is the single source of truth for how this project is
developed — read it before your first PR. The per-tool AI config files
(`CLAUDE.md`, `GEMINI.md`, Copilot, Cursor) just point back to it.
