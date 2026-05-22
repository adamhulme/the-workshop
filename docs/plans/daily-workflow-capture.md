---
status: approved
date: 2026-05-22
task: Build /start-day and /end-day skills for daily workflow continuity across multi-session CC usage
tags: [developer-experience, context-management, scheduling, multi-session]
---

## Prior art

- **Learned principle — "Zero-dependency hooks"**: any hook scripts must use bash builtins only. Relevant if we add hooks for automatic capture.
- **Learned principle — "Layered reduction beats single-mechanism"**: multiple complementary mechanisms compound. Applies here — git scraping is the always-on layer, /end-day annotations are the opt-in enrichment, scheduled capture is the automated enforcement.
- **Brainstorm**: `docs/brainstorms/daily-workflow-capture.md` — tensions #1 (friction vs richness) and #3 (single invocation vs multi-repo) are the key design constraints.

## What we're building

Two new skills (`commands/start-day.md`, `commands/end-day.md`) and a shared data directory (`~/.claude/daily/`).

## Data model

Daily files live at `~/.claude/daily/YYYY-MM-DD.md` — one file per day. This is outside any project repo, so it's accessible from any CC session regardless of working directory. Format:

```markdown
---
date: 2026-05-22
---

## Goals
- [ ] Ship the quota feature PR
- [ ] Review EN-1370

## End-of-day notes
Quota PR is up but needs test fixes. EN-1370 blocked on design feedback.

## Snapshots

### engage-web
- **Branch:** feat/EN-1370-quotas
- **Status:** 3 modified, 1 untracked
- **Last commit:** abc1234 — "add quota display component" (2h ago)
- **Stashes:** 1
- **Open PRs:** #2080 (review-requested), #2075 (draft)

### engage-service
- **Branch:** main
- **Status:** clean
- **Last commit:** def5678 — "fix rate limiter config" (1d ago)
- **Stashes:** 0
- **Open PRs:** none
```

## Skill 1: `/end-day`

**Run once from any session.** Captures state across both repos regardless of which project the current session is in.

Steps:
1. `mkdir -p ~/.claude/daily`
2. Snapshot git state for both `~/code/vismo/engage-web` and `~/code/vismo/engage-service`:
   - Current branch (`git -C <path> rev-parse --abbrev-ref HEAD`)
   - Working tree status (`git -C <path> status --short`)
   - Last commit (`git -C <path> log -1 --oneline --format='%h — %s (%cr)'`)
   - Stash count (`git -C <path> stash list | wc -l`)
   - Open PRs via `gh pr list -R <repo> --author=@me --state=open --json number,title,isDraft,reviewDecision` (degrade gracefully if `gh` unavailable)
3. Ask for optional end-of-day notes via `AskUserQuestion`:
   - "Any notes about where you left off today?"
   - Options: "No notes — just save the snapshot" / "I'll type notes (Other)"
4. Ask for optional tomorrow goals:
   - "Any goals for tomorrow?"
   - Options: "Skip goals" / "I'll type goals (Other)"
5. Write/update `~/.claude/daily/YYYY-MM-DD.md` — if the file already exists (e.g. goals set in the morning), merge: preserve existing Goals section, append/replace snapshots and notes.
6. Report: path written, snapshot summary.

## Skill 2: `/start-day`

**Run once in the morning from any session.** Reads yesterday's data and current git state to produce a briefing.

Steps:
1. Read `~/.claude/daily/` to find yesterday's file (try yesterday's date, then scan for most recent file if yesterday doesn't exist — handles weekends/days off).
2. Fresh-snapshot both repos (same git commands as /end-day) to get current state.
3. If yesterday's file exists and has goals, compare goals against current git state to assess progress:
   - Did the branch mentioned get merged? (check `git branch -r --merged main`)
   - Are there new commits since the snapshot?
4. If Jira MCP is available (`mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql`), pull the user's current sprint items.
5. Present the morning briefing:
   - **Yesterday's recap** (from file + delta detection)
   - **Current state** (fresh git snapshot of both repos)
   - **Open PRs** across both repos
   - **Jira items** (if available)
   - **Yesterday's goals** with progress indicators
6. Ask for today's goals via `AskUserQuestion`:
   - "Set goals for today?"
   - Options: "No goals today" / "I'll type goals (Other)"
7. Write today's file (`~/.claude/daily/YYYY-MM-DD.md`) with goals and an initial snapshot.
8. Report: briefing complete, path written.

## Staleness handling

Both skills detect stale branches:
- If a branch has been merged into main/master, mark it as `(merged)` in the snapshot
- If the last commit is >3 days old on a non-main branch, flag it as `(stale — last activity N days ago)`

## Graceful degradation

- **`gh` not installed/authenticated**: skip PR data, note in output
- **Jira MCP not configured**: skip Jira in /start-day, no prompt
- **No yesterday file for /start-day**: just show current state + fresh snapshot, skip recap
- **Repo path doesn't exist**: skip that repo, warn once
- **Not a git repo** (submodule deregistered): skip, warn once

## Files to create/modify

| File | Action |
|------|--------|
| `commands/start-day.md` | **Create** — new skill |
| `commands/end-day.md` | **Create** — new skill |

## What's explicitly NOT in scope

- Scheduled agent for automatic end-of-day capture (can add later via `/schedule`)
- Weekly summaries or trend detection (v2)
- Project auto-discovery (hardcoded to the two repos)
- Hooks for automatic capture (no session-close event exists)

## Verification

- Run `/end-day` from the-workshop (not either vismo repo) — should still capture both repos
- Run `/start-day` the next invocation — should read the file just written
- Test with `gh` unavailable — should degrade gracefully
- Test with no previous daily file — /start-day should just show current state
- One repo path missing (rename temporarily) — should skip with warning
- File merge: run /end-day, then /start-day sets goals, then /end-day again — goals preserved?
- Weekend gap: no yesterday file, most recent is 3 days ago — /start-day finds it
- First-ever run: no `~/.claude/daily/` dir — /end-day creates it

## See also

- [docs/brainstorms/daily-workflow-capture.md](../brainstorms/daily-workflow-capture.md) — four-lens analysis and tensions

## Engineering Review

**Date:** 2026-05-22

### Resolved decisions

| ID | Finding | Resolution |
|----|---------|------------|
| 0A | install.sh doesn't need editing — glob picks up new .md files | Removed from files-to-modify table |
| 1A | Snapshot logic duplicated vs cross-referenced between skills | Duplicate — skills are prompt expansions, not subroutines |
| 1B | GitHub remote slug: hardcode vs derive at runtime | Hardcode (`surveysolutionsuk/engage-web`, `surveysolutionsuk/engage-service`) |
| 1C | Merge rules for daily file sections | Goals preserved, notes + snapshots replaced. Sentinel delimiters (`<!-- SECTION:START/END -->`) |
| 1D | Goal-to-branch progress matching | Dropped. Show yesterday's goals + snapshot diff side by side; user connects the dots |
| 2A | Repo config duplication across skills | Duplicate — 4 lines, rare change, no shared config file |
| 2B | Two AskUserQuestion prompts vs combined | Two prompts — clean separation |
| 3A | Verification checklist expanded | 8 smoke tests (4 original + 4 degradation paths) |
| CODEX-1 | Section merge needs sentinel delimiters | HTML comment sentinels for each section |
| CODEX-2 | Date handling across midnight | Before 04:00 = still "yesterday" workday |
| CODEX-3 | Idempotency on re-run | Silent overwrite — sentinels make it safe |
| CODEX-4 | `git status --short` can explode on large dirty trees | Summarise as counts; full file list only if ≤10 files |
| CODEX-5 | Jira MCP as scope creep | Keep — pattern established in /triage, degrades gracefully |
| CODEX-6 | `git fetch` never mentioned | Fetch in /start-day only (morning needs fresh data) |

### NOT in scope

- Concurrent-write protection (two sessions writing same daily file) — /end-day is a deliberate single invocation, not background
- Stash age filtering (stale stashes from months ago) — low value, adds complexity
- Detached HEAD / sparse checkout / worktree handling — edge cases for these two repos
- Structured frontmatter for snapshot data (JSON/YAML blocks) — prose is readable enough for LLM consumption
- Scheduled end-of-day capture via `/schedule` — deferred to v2

### What already exists

- `/triage` has a Jira MCP integration pattern (JQL query, graceful degradation) — reuse the same approach
- No existing skills touch `~/.claude/daily/` or do cross-repo git snapshots — these are genuinely new
- install.sh's glob-based installer already handles new command files automatically

### Failure modes

| Codepath | Failure | Test? | Error handling? | User sees |
|----------|---------|-------|-----------------|-----------|
| `git -C <path>` | Repo path missing | Smoke test | Skip + warn | Clear warning |
| `git -C <path>` | Not a git repo | Smoke test | Skip + warn | Clear warning |
| `gh pr list` | gh unavailable | Smoke test | Skip + note | "(gh unavailable)" in output |
| `gh pr list` | gh auth expired | No | Degrades same as unavailable | "(gh unavailable)" |
| File write | `~/.claude/daily/` permissions | No | Bash error surfaces | Error message |
| File merge | Sentinels corrupted/missing | No | Write full file (sentinel-miss = fresh write) | Silent recovery |
| Jira MCP | MCP not configured | No | Skip silently | No Jira section |
| Date logic | Run at 03:30 | No | Before-4am heuristic | Correct workday date |

No critical gaps (no failure mode has all three: no test AND no error handling AND silent behaviour).

### TODOs

None proposed. All findings resolved inline.

### Completion summary

```
Step 0 — Scope: accepted as-is (user requested large scope)
Architecture:   4 issues found, 4 resolved
Code quality:   2 issues found, 2 resolved
Tests:          diagram produced, 18 paths identified, 8 smoke tests added
Performance:    0 issues found
Outside voice:  ran (Codex) — 6 substantive findings, all resolved
NOT in scope:   written
Failure modes:  0 critical gaps
TODOs:          0 proposed
Unresolved:     none
```
