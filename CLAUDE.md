# CLAUDE.md

This project's development rules live in a single source of truth, **`AGENTS.md`**.
Follow it for everything: FVM usage, architecture/SOLID layering, testing,
formatting, commit/PR conventions, the assignment-before-work rule, and the
issue/label taxonomy. Do not duplicate those rules here — when they change, edit
`AGENTS.md`.

@AGENTS.md

## Claude-specific notes

- Run every Flutter/Dart command through FVM: `fvm flutter analyze`,
  `fvm flutter test`, `fvm dart format .`.
- Versioned skills live under [`.claude/skills/`](.claude/skills/). Use the
  [`create-issue`](.claude/skills/create-issue/SKILL.md) skill to file issues so
  they follow the repo's title/body/label conventions.
- Add future Claude-specific skills under `.claude/skills/<name>/SKILL.md` and
  agents under `.claude/agents/` so they're shared and versioned with the repo.
