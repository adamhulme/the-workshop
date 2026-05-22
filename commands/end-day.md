---
description: Capture end-of-day state across engage-web and engage-service, with optional notes and tomorrow's goals
---

Snapshot git state across both Vismo repos and write a daily file to `~/.claude/daily/`. Run once from any session — it reads both repos regardless of your current working directory. Re-running overwrites snapshots and notes but preserves goals set earlier (via /start-day).

User arguments: $ARGUMENTS

## Repo config

| Name | Path | GitHub slug |
|------|------|-------------|
| engage-web | `~/code/vismo/engage-web` | `surveysolutionsuk/engage-web` |
| engage-service | `~/code/vismo/engage-service` | `surveysolutionsuk/engage-service` |

## Workday date

Determine today's date for the daily file. If the current local time is before 04:00, treat it as still the previous calendar day — a late-night session belongs to the workday that started it, not the calendar day it spills into. Use this workday date everywhere the skill references "today."

## Steps

### 1. Create the daily directory

Run `mkdir -p ~/.claude/daily`.

### 2. Snapshot both repos

For each repo in the config table, gather the following. If the repo path does not exist or is not a git repo, log `(skipping <name> — path missing or not a git repo)` and continue to the next repo.

**Git state:**

- **Branch:** `git -C <path> rev-parse --abbrev-ref HEAD`
- **Working tree status:** `git -C <path> status --short`. Summarise as counts by category (modified, untracked, deleted, renamed). If 10 or fewer files, include the full file list below the counts. If more than 10, show counts only.
- **Last commit:** `git -C <path> log -1 --format='%h — %s (%cr)'`
- **Stash count:** `git -C <path> stash list | wc -l`

**Staleness detection:**

- If the branch is not `main` or `master`, check if it has been merged using two methods (squash/rebase merges create new commits that `--merged` won't detect):
  1. Git ancestry: `git -C <path> branch -r --merged main 2>/dev/null | grep -q "origin/<branch>"` (also try `master` if `main` fails).
  2. GitHub PR state (if `gh` is available): `gh pr list -R <github-slug> --head <branch> --state merged --json number --jq 'length'`. If the count is >0, the branch was merged via PR.
  If either method confirms a merge, append `(merged)` to the branch line.
- If the branch is not `main`/`master` and the last commit is older than 3 days, append `(stale — last activity N days ago)`.

**Open PRs (optional):**

Check if `gh` is available and authenticated: `gh auth status 2>/dev/null`. If available, run:

```
gh pr list -R <github-slug> --author=@me --state=open --json number,title,isDraft,reviewDecision
```

Format each PR as: `#<number> — <title>` with `(draft)` or `(review: <decision>)` suffixes as appropriate. If `gh` is unavailable or the call fails, note `(gh unavailable — skipping PR data)` and continue.

### 3. Ask for end-of-day notes

Dispatch `AskUserQuestion`:

- Question: "Any notes about where you left off today?"
- Header: "EOD notes"
- Options:
  - "No notes — just save the snapshot"
  - "I'll type notes (Other)"

If the user provides notes via Other, capture them for the file.

### 4. Ask for tomorrow's goals

Dispatch `AskUserQuestion`:

- Question: "Any goals for tomorrow?"
- Header: "Tomorrow"
- Options:
  - "Skip goals"
  - "I'll type goals (Other)"

If the user provides goals via Other, format each line as a `- [ ]` checkbox item.

### 5. Write the daily files

/end-day writes to **two** files: today's file for notes + snapshots, and tomorrow's file for goals. This prevents /end-day from overwriting today's goals (set by /start-day that morning) and ensures /start-day tomorrow sees the goals in the right place.

**Today's file** — `~/.claude/daily/<YYYY-MM-DD>.md` using the workday date:

If the file already exists, read it first. Use HTML comment sentinels to identify sections.

- `<!-- GOALS:START -->` / `<!-- GOALS:END -->` — **PRESERVE** always. Today's goals were set by /start-day; /end-day never touches them.
- `<!-- NOTES:START -->` / `<!-- NOTES:END -->` — **REPLACE** if user provided new notes. **PRESERVE** if exists and user skipped notes.
- `<!-- SNAPSHOTS:START -->` / `<!-- SNAPSHOTS:END -->` — **REPLACE** with fresh snapshots.
- Frontmatter — **PRESERVE** if exists.

If the file does not exist, write it from scratch (without a Goals section — goals for today should have been set by /start-day).

If sentinels for a section are missing but other sentinels exist, insert the new section alongside existing content — do not treat missing sentinels as corruption when other sentinels are present. Only treat the file as corrupt (full rewrite) when it has no sentinels at all despite having content.

**Tomorrow's file** — `~/.claude/daily/<YYYY-MM-DD>.md` using the **next** workday date (workday date + 1 calendar day):

Only write this file if the user provided goals in step 4. If they skipped goals, don't create or touch tomorrow's file.

If the file already exists (unlikely but possible), read it first and use sentinels:

- `<!-- GOALS:START -->` / `<!-- GOALS:END -->` — **REPLACE** with new goals.
- All other sections — **PRESERVE** if they exist.

If the file does not exist, write it with frontmatter and the Goals section only.

**Today's file format:**

```markdown
---
date: <YYYY-MM-DD>
---

<!-- GOALS:START -->
## Goals
(preserved from /start-day — /end-day does not touch this section)
<!-- GOALS:END -->

<!-- NOTES:START -->
## End-of-day notes
<notes text>
<!-- NOTES:END -->

<!-- SNAPSHOTS:START -->
## Snapshots

### engage-web
- **Branch:** <branch> <(merged)|(stale)>
- **Status:** <summary>
- **Last commit:** <hash — message (relative time)>
- **Stashes:** <count>
- **Open PRs:** <list or "none">

### engage-service
- **Branch:** <branch> <(merged)|(stale)>
- **Status:** <summary>
- **Last commit:** <hash — message (relative time)>
- **Stashes:** <count>
- **Open PRs:** <list or "none">
<!-- SNAPSHOTS:END -->
```

Omit the Notes section if the user skipped notes and no prior notes exist. Always include Snapshots unless both repos are missing (see Degradations).

**Tomorrow's file format** (only written if user provided goals):

```markdown
---
date: <YYYY-MM-DD>
---

<!-- GOALS:START -->
## Goals
- [ ] <goal 1>
- [ ] <goal 2>
<!-- GOALS:END -->
```

### 6. Report

Print:
- Today's file path (e.g. `~/.claude/daily/2026-05-22.md`)
- Tomorrow's file path if goals were written (e.g. `~/.claude/daily/2026-05-23.md`)
- One-line summary per repo: branch, status count, PR count
- Whether notes and goals were captured or skipped

## Degradations

- **Repo path missing or not a git repo** — skip that repo, warn once, continue.
- **Both repos missing** — write the file with notes/goals only (no Snapshots section). Warn: "Neither repo found — snapshot skipped."
- **`gh` not installed or not authenticated** — skip PR data, note in output.
- **`~/.claude/daily/` can't be created** — bail with error message.
- **Some sentinels missing but others present** — insert new sections alongside existing content. Only full-rewrite when no sentinels exist at all despite having content.
- **All sentinels missing in existing file** — treat as fresh write (overwrite entire file).
