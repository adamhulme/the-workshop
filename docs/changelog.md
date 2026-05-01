# Changelog

## v1.0 — 2026-05-01

First narrative changelog entry. The workshop had a keep-a-changelog file (`CHANGELOG.md`) since v0.2.0; this is the lived-in story alongside it. Covers the burst of work that landed today: tightening the interaction conventions, shipping `/review-pr` and the headed-browser skill, and finishing with the autonomous orchestrator that ties it all together.

### `/auto-do` — autonomous task runner

The non-interactive sibling of the workshop's planning chain. Takes a task description and chains `/plan` → `/plan-eng-review` (and `/plan-design-review` when UI scope is touched) → implementation → `/solution` → PR creation → `/browse` verification (when applicable) → `/review-pr`, applying a documented auto-decision policy at every gate the underlying skills would have raised.

- Creates and reviews a PR. Never merges. Never `--force`-pushes. Never bypasses hooks.
- Stops loudly on dirty tree, missing `gh`, complexity smell (>8 files), test failure before push, or round-2 must-fix findings (PR converted to draft, blocking comment posted, items committed to `TODOS.md`).
- Every auto-pick lands in the PR body's `## Auto-decisions` section so a human can audit what taste calls were taken on their behalf.
- Resolves underlying skills from the install location at runtime (`.claude/commands/<skill>.md` then `~/.claude/commands/<skill>.md`) — when those skills change shape, the orchestrator inherits the new content for free.

Source: [#18](https://github.com/adamhulme/the-workshop/pull/18) · `cf68bef`

### `/browse` — headed-browser skill with persistent auth

The compounding loop had a blind spot: every other skill produced or consumed text artefacts; nothing let Claude verify a UI change, walk a user flow, or just observe an app's current state. `/browse` orchestrates Playwright MCP (primary) or Chrome DevTools MCP (alternative) in headed mode and writes the session as a structured research note.

- `/browse --setup <login-url>` is the one-shot credential flow: drives a headed login, persists Playwright's `storageState` to `<repo>/.claude/browse/storage-state.json` (auto-`.gitignore`-d), every subsequent run reuses it. No credentials in env vars or this skill — Claude never types or sees the user's password.
- Read-only by default; destructive actions (form submit, delete, payment) are gated per-step via `AskUserQuestion`.
- Bails cleanly on missing MCP, missing required capability, unreachable localhost, non-git project, or expired storage state.
- Naming caveat: collides with gstack's `browse` skill — install with `--project` scope or rename locally if both are present.
- Bundled in the same PR (per user direction): `/review-pr` now posts the consolidated findings as a top-level PR comment at each round, so the audit trail outlives the conversation.

Source: [#16](https://github.com/adamhulme/the-workshop/pull/16) · `5e4bed9`

### `/review-pr` — bounded 2-round PR review loop with auto-push

Codex CLI and the `pr-reviewer` agent trade reviewer/implementer roles across exactly two rounds. The hard cap is the point — a review loop without a cap is just a slow merge. Round 1: parallel review. Round 2: Codex re-reviews the post-fix-up diff (the only voice that hasn't seen the new state).

- Findings are deduped by `(file, line, category)` and grouped must-fix / should-fix / follow-up.
- Single user gate at the round-1 outcome via `AskUserQuestion`. Must-fix items are addressed as a single fix-up commit; should-fix and follow-up items go verbatim to `TODOS.md`.
- Fix-up commits **auto-push** to the PR's head branch — never to default, never `--force`, never `--no-verify`. Refuses to push to the default branch as a non-negotiable guard.
- Falls back to a `general-purpose` Agent in either Codex slot if `codex` isn't on `PATH`.

Source: [#14](https://github.com/adamhulme/the-workshop/pull/14) · `ef4d38a`

### `update.sh` no longer fails on installs without a manifest

Small but real. `update.sh`'s prune step assumed a manifest from a prior install always existed; running it for the first time on a system that had been hand-installed (or installed from an older release predating manifests) would error out instead of just not pruning anything.

- First-time runs now treat a missing manifest as "nothing to prune" and proceed with the install.
- The `update.sh` install path is unchanged otherwise — this is purely the "no prior manifest" case.

Source: [#17](https://github.com/adamhulme/the-workshop/pull/17) · `edd93c5`

### `CLAUDE.md` gains a coding philosophy section

Codifies the opinions the workshop already had but hadn't written down: simplest fit, readability over cleverness, edit before adding, stay in scope, decision points use `AskUserQuestion`, no defensive logic for impossible cases. Six bullets that future agents (and future-you) can refer to without re-deriving the principles each session.

- Sets the bar that subsequent reviews (`/plan-eng-review`, `/plan-design-review`, `/review-pr`) anchor against — "tied to a stated workshop principle" stops being vague.
- Influenced the design of `/auto-do`'s auto-decision policy: when there's no recommended option and ambiguity remains, fail closed.

Source: [#15](https://github.com/adamhulme/the-workshop/pull/15) · `d259dc6`

### `/plan` switched to `AskUserQuestion` for decision points

Plan-mode-style behaviour without abusing Claude Code's native plan-mode primitives. The skill now uses `AskUserQuestion` at every decision gate — slug confirmation, save-target confirmation, scope clarification — instead of trailing prose `(y/n)` prompts that get buried under whatever the model just wrote.

- Sets the convention for every later skill in the workshop. `/review-pr`, `/browse`, `/auto-do` all inherit this pattern.
- Trailing `(y/n)` prompts are now treated as an anti-pattern in code review (`/review-pr` flags them; `/auto-do` documents them in its eng review).

Source: [#13](https://github.com/adamhulme/the-workshop/pull/13) · `c26daa5`
