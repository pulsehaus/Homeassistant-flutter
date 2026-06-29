# `.claude/`

Versioned, repo-shared configuration for [Claude Code](https://claude.com/claude-code).
Committing these here means every contributor and AI session uses the same
skills and agents instead of relying on a personal `~/.claude`.

The project-wide development rules are **not** here — they live in
[`AGENTS.md`](../AGENTS.md) at the repo root, with [`CLAUDE.md`](../CLAUDE.md)
pointing to it.

## Layout

```
.claude/
  skills/             # reusable, versioned skills
    create-issue/
      SKILL.md        # file standardized GitHub issues (title/body/labels)
  agents/             # (add as needed) project-specific subagent definitions
```

## Adding more

- **A skill:** create `skills/<name>/SKILL.md` with the standard frontmatter
  (`name`, `description`) followed by the instructions.
- **An agent:** add `agents/<name>.md`.

Keep each skill/agent self-contained so it works in a fresh session.
