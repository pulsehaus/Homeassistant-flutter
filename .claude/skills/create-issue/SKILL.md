---
name: create-issue
description: >-
  Turn a free-form description into a clean, standardized GitHub issue and
  create it with `gh`. Use this whenever the user wants to file, open, create,
  or draft a GitHub issue — including phrasings like "report a bug", "create a
  ticket", "open an issue for X", "track this", "we should add Y", or pasting a
  rough description they want turned into a proper issue. Trigger even when the
  user doesn't say the word "issue" but clearly describes a bug to log or a
  feature/task to track in a git project. Produces a typed title, a structured
  English body (template adapted to bug vs feature/task), and the right labels
  from the repo's taxonomy, then creates the issue on the current git repo.
---

# Create standardized GitHub issue

Turn a rough, free-form description into a well-formed GitHub issue: a clear
title, a structured body, and consistent labels — then create it with `gh` on
the current repository. The goal is that every issue in the project looks the
same and carries the metadata needed to triage it, no matter who (or which
session) filed it.

Issues are **written in English** (open-source convention) even if the user
describes the problem in another language — translate as needed.

## Workflow at a glance

1. Understand the request (ask only if genuinely ambiguous).
2. Classify: type + priority.
3. Build the title and the type-appropriate body.
4. Resolve the target repo and validate labels.
5. **Show the full draft and wait for explicit confirmation.**
6. Create the issue with `gh` and return the URL.

Creating an issue is an outward-facing action — it's visible to anyone watching
the repo and may send notifications. That's why step 5 (confirmation) is not
optional: never call `gh issue create` before the user approves the draft.

## Step 1 — Understand the request

Read the user's description. Most of the time it's enough to proceed. Only ask a
clarifying question when something essential for a useful issue is missing — for
a bug, that's usually *what's the expected vs actual behavior* or *how to
reproduce*; for a feature, *what problem it solves*. Ask at most **two** short
questions, and only if you truly can't write a sensible issue without them.
Don't interrogate the user — a slightly imperfect issue they can edit beats a
wall of questions.

## Step 2 — Classify

Pick exactly one **type** and one **priority** from the repo's taxonomy.

**Type** (choose the closest):
- `type: bug` — something is broken or behaves incorrectly
- `type: feature` — a new capability that doesn't exist yet
- `type: enhancement` — improving something that already exists
- `type: documentation` — docs only
- `type: refactor` — internal code change, no behavior change
- `type: test` — adding/fixing tests
- `type: chore` — tooling, build, dependencies, CI, maintenance

**Priority** (infer conservatively, default `medium`):
- `priority: critical` — crash, data loss, security issue, or blocks all work
- `priority: high` — important and should be addressed soon; blocks a feature
- `priority: medium` — normal work (the default when unsure)
- `priority: low` — nice-to-have, cosmetic, or "someday"

Always also add **`status: needs triage`** — a freshly filed issue hasn't been
triaged yet.

State your type/priority reasoning briefly in the draft so the user can override
it (e.g. "labelled `type: bug` / `priority: high` because it sounds like a
crash"). Priority is a judgment call — make it easy to correct.

## Step 3 — Build the issue

### Title
- Concise, specific, imperative or descriptive. No trailing period.
- Describe the symptom or the goal, not the type (labels carry the type).
- Good: `WebSocket reconnect fails after token refresh`
- Good: `Add long-lived token login screen`
- Avoid: `Bug` · `Fix the app` · `[FEATURE] please add dark mode!!!`

### Body
Use the template matching the type. Keep empty/unknown sections out rather than
filling them with "N/A" — but keep the headings the user will need.

**For `type: bug`:**

```markdown
## Context
<Where it happens and any relevant environment: platform (Android/iOS/web),
Flutter version, app area.>

## Steps to reproduce
1. ...
2. ...

## Expected behavior
<What should happen.>

## Actual behavior
<What happens instead. Include error messages/logs if available.>

## Additional context
<Screenshots, logs, links — omit this section if there's nothing.>
```

**For everything else (`feature`, `enhancement`, `refactor`, `chore`, `test`,
`documentation`):**

```markdown
## Context
<The problem or motivation — why this matters.>

## Proposed solution
<What to build or change. Describe the approach if known.>

## Acceptance criteria
- [ ] ...
- [ ] ...

## Additional context
<Links, references, constraints — omit this section if there's nothing.>
```

Write the body from the user's description: extract concrete repro steps,
expected/actual behavior, or acceptance criteria where the user implied them.
Don't invent technical specifics that weren't provided — leave a clear
placeholder instead so the user can fill it in.

### Testing policy

Changes usually need tests, so make testing an explicit part of the issue rather
than an afterthought. For any issue that involves code behavior — `bug`,
`feature`, `enhancement`, `refactor` — include the testing expectation directly:

- Add a testing line to the **acceptance criteria**, e.g.
  `- [ ] Covered by unit tests (and a widget/integration test where it touches UI)`.
- Distinguish the levels and require both where they apply:
  - **Unit tests** for isolated logic (mocked dependencies/transport).
  - **Integration tests** (under `integration_test/`) for end-to-end flows —
    e.g. a real/faked server, a full screen, or a feature exercised top to bottom.
    Name the concrete flow to cover, not just "add integration tests".
- For a **bug**, the fix should come with a **regression test** that fails before
  the fix and passes after — call that out explicitly.
- For a **feature/enhancement**, name what should be tested (the new logic, edge
  cases, error paths), not just "add tests".
- Note that `fvm flutter analyze`, `fvm flutter test` and the `integration_test`
  suite must pass as part of done (this project pins Flutter via FVM / `.fvmrc`;
  always run Flutter/Dart commands through `fvm`).

Skip or lighten this only when tests genuinely don't apply (`documentation`,
`chore`, pure tooling) — and say briefly why in the draft instead of silently
dropping it. If the project has an agreed test convention (see its `AGENTS.md` /
`CLAUDE.md`), follow that wording.

## Step 4 — Resolve repo and validate labels

Detect the target repo from the current git working directory:

```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```

If that fails (not a git repo, no remote, or `gh` not authenticated), tell the
user what's wrong (e.g. run `gh auth login`, or ask which repo to target) rather
than guessing.

Confirm the chosen labels actually exist on the repo before using them — a label
that doesn't exist makes `gh issue create` fail:

```bash
gh label list --limit 100
```

If a label you'd use is missing (e.g. the repo doesn't follow the
`type:`/`priority:` taxonomy), adapt: map to the closest existing label, or
proceed with the labels that do exist and mention in the draft which ones you
dropped. Don't silently fail.

## Step 5 — Show the draft and confirm

Present the complete draft to the user before creating anything:

- **Repo**: `owner/name`
- **Title**: ...
- **Labels**: `type: …`, `priority: …`, `status: needs triage`
- **Body**: the full rendered markdown

Then ask for confirmation, e.g. "Create this issue, or want to tweak anything?"
Apply any edits the user asks for and re-show if the change is substantial. Only
move on once they approve.

## Step 6 — Create the issue

Write the body to a temporary file first — this avoids shell-quoting problems
with multi-line markdown (especially in PowerShell on Windows). Then:

```bash
gh issue create \
  --title "WebSocket reconnect fails after token refresh" \
  --body-file <path-to-temp-body.md> \
  --label "type: bug" \
  --label "priority: high" \
  --label "status: needs triage"
```

On Windows PowerShell, the same idea — write the body to a temp `.md` file and
pass `--body-file`. Use one `--label` flag per label (label names contain spaces
and a colon, so always quote them).

`gh issue create` prints the new issue URL on success — return that URL to the
user so they can click straight through. If creation fails, surface the actual
`gh` error (bad label, auth, permissions) instead of retrying blindly.

## Notes

- This skill is repo-agnostic: it always targets the current git repo. To file
  against a different repo, the user can `cd` there or pass an explicit
  `--repo owner/name` to the `gh` commands.
- Don't assign milestones, projects, or assignees unless the user asks — keep
  the default flow about producing a clean, well-labelled issue.
- Keep the issue self-contained: someone reading it cold (a contributor, or a
  future session) should understand what's being asked without this chat's
  context.
