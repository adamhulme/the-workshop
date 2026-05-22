---
status: in-progress
date: 2026-05-22
task: Build /start-day and /end-day skills for daily workflow continuity
tags: [developer-experience, context-management, scheduling, multi-session]
---

## Problem

Context loss between sessions. With 3-5 concurrent Claude Code sessions across engage-web and engage-service, closing everything at end of day means starting the next morning with no memory of what was in-flight, what PRs are open, or what the plan was.

## Options considered

1. **`/end-day` per session + `/start-day`** — rejected. Requiring /end-day in each of 3-5 sessions guarantees missed capture.
2. **Git-only `/start-day`, no `/end-day`** — v0.1 candidate. Gets 80% of the value (git state is always there) but no intent capture (notes, goals).
3. **Single `/end-day` from any session + `/start-day`** — chosen. One invocation captures both repos via `git -C`, regardless of current working directory. Optional notes and goals layer intent on top of automatic git state.
4. **Scheduled agent for automatic capture** — deferred to v2. Adds infrastructure dependency for marginal gain over a deliberate single invocation.

## Chosen approach

Option 3: two skills (`commands/end-day.md`, `commands/start-day.md`) writing to `~/.claude/daily/YYYY-MM-DD.md`.

### Key design decisions

- **Sentinel-delimited sections** (`<!-- GOALS:START/END -->`, `<!-- NOTES:START/END -->`, `<!-- SNAPSHOTS:START/END -->`) for idempotent file merging on re-runs. Each skill knows which sections to replace vs preserve.
- **Before-4am workday heuristic** — late-night sessions count as the previous workday, matching developer mental models.
- **Hardcoded repo paths and GitHub slugs** — `~/code/vismo/engage-web` (`surveysolutionsuk/engage-web`) and `~/code/vismo/engage-service` (`surveysolutionsuk/engage-service`). New repos are unlikely; explicit beats clever.
- **Fetch in /start-day only** — morning briefing needs fresh remote state; end-of-day local state is already current from the session.
- **Status count summarisation** — `git status --short` output presented as counts (3 modified, 1 untracked) with full file list only if ≤10 files.
- **Snapshot diff, not goal matching** — /start-day compares yesterday's snapshot to today's fresh state side by side. No attempt to parse goals and match them to branches.
- **Jira MCP integration** — pattern reused from /triage, degrades silently if MCP unavailable.

## See also

- [docs/brainstorms/daily-workflow-capture.md](../brainstorms/daily-workflow-capture.md) — four-lens analysis and tensions
- [docs/plans/daily-workflow-capture.md](../plans/daily-workflow-capture.md) — approved plan with engineering review
