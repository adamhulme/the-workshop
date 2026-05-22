---
description: Morning briefing — yesterday's recap, current git state, open PRs, Jira items, and today's goals
---

Read yesterday's daily file and current git state across both Vismo repos to produce a morning briefing. Run once from any session — it reads both repos regardless of your current working directory. Optionally set today's goals.

User arguments: $ARGUMENTS

## Repo config

| Name | Path | GitHub slug |
|------|------|-------------|
| engage-web | `~/code/vismo/engage-web` | `surveysolutionsuk/engage-web` |
| engage-service | `~/code/vismo/engage-service` | `surveysolutionsuk/engage-service` |

## Workday date

Determine today's date for the daily file. If the current local time is before 04:00, treat it as still the previous calendar day. Use this workday date everywhere the skill references "today." "Yesterday" means the workday before today's workday date.

## Steps

### 1. Find yesterday's daily file

Look in `~/.claude/daily/` for the previous workday's file. Try yesterday's date first (`<YYYY-MM-DD>.md`). If it doesn't exist, scan the directory for the most recent file by filename (descending sort, skip today's file if it exists). This handles weekends, holidays, and days off.

If `~/.claude/daily/` does not exist, run `mkdir -p ~/.claude/daily` and note: "No previous daily files found — skipping recap."

If no previous file is found, note: "No previous daily file — skipping recap." Continue to step 2.

If a previous file is found and it's more than 5 days old, note: "Most recent daily file is from <date> (<N> days ago)."

### 2. Fetch and snapshot both repos

For each repo in the config table:

**Fetch first** (morning briefing needs fresh remote state):

```
git -C <path> fetch --quiet 2>/dev/null
```

If the fetch fails (no network, auth issue), continue silently with local state.

If the repo path does not exist or is not a git repo, log `(skipping <name> — path missing or not a git repo)` and continue to the next repo.

**Git state:**

- **Branch:** `git -C <path> rev-parse --abbrev-ref HEAD`
- **Working tree status:** `git -C <path> status --short`. Summarise as counts by category (modified, untracked, deleted, renamed). If 10 or fewer files, include the full file list below the counts. If more than 10, show counts only.
- **Last commit:** `git -C <path> log -1 --format='%h — %s (%cr)'`
- **Stash count:** `git -C <path> stash list | wc -l`

**Staleness detection:**

- If the branch is not `main` or `master`, check if it has been merged: `git -C <path> branch -r --merged main 2>/dev/null | grep -q "origin/<branch>"` (also try `master` if `main` fails). If merged, append `(merged)` to the branch line.
- If the branch is not `main`/`master` and the last commit is older than 3 days, append `(stale — last activity N days ago)`.

**Open PRs (optional):**

Check if `gh` is available and authenticated: `gh auth status 2>/dev/null`. If available, run:

```
gh pr list -R <github-slug> --author=@me --state=open --json number,title,isDraft,reviewDecision
```

Format each PR as: `#<number> — <title>` with `(draft)` or `(review: <decision>)` suffixes as appropriate. If `gh` is unavailable or the call fails, note `(gh unavailable — skipping PR data)` and continue.

### 3. Compute snapshot diff

If a previous daily file was found in step 1 and it contains a `<!-- SNAPSHOTS:START -->` block, compare its snapshot data against the fresh snapshot from step 2. For each repo, note changes:

- Branch changed (was `feat/X`, now `main`)
- Branch gone (was `feat/X`, branch no longer exists — likely merged or deleted)
- New commits since the snapshot (compare commit hashes)
- Status changed (was clean, now has uncommitted changes — or vice versa)
- PR count changed

Present these as delta lines: `engage-web: branch changed feat/X → main, 3 new commits`.

If nothing changed, say so: `engage-web: no changes since last snapshot`.

### 4. Pull Jira items (optional)

Check whether the Atlassian Rovo MCP is available by checking for the tool `mcp__claude_ai_Atlassian_Rovo__searchJiraIssuesUsingJql`.

If available, query:

```
assignee = currentUser() AND statusCategory != Done ORDER BY priority DESC, updated DESC
```

Pull up to 10 issues with key, summary, status, and priority. Group by status category (To Do, In Progress).

If the MCP is not available, skip silently — no prompt, no warning.

### 5. Present the morning briefing

Print the briefing in this order. Use markdown formatting. Keep it scannable — the user should get the picture in 10 seconds.

**If a previous daily file exists:**

```
## Yesterday (<date>)

### Goals
<yesterday's goals from the file, if any>

### Notes
<yesterday's notes from the file, if any>

### What changed overnight
<snapshot diff from step 3>
```

If the previous file has no goals and no notes (snapshot-only), just show the diff.

**Always:**

```
## Today (<workday date>)

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
```

**If Jira items were found:**

```
### Jira
<grouped issue list>
```

### 6. Ask for today's goals

Dispatch `AskUserQuestion`:

- Question: "Set goals for today?"
- Header: "Today's goals"
- Options:
  - "No goals today"
  - "I'll type goals (Other)"

If the user provides goals via Other, format each line as a `- [ ]` checkbox item.

### 7. Write today's daily file

Target path: `~/.claude/daily/<YYYY-MM-DD>.md` using the workday date.

If the file already exists (e.g. from a mid-day /end-day run), read it first. Use HTML comment sentinels to identify sections.

**Merge rules for /start-day:**

- `<!-- GOALS:START -->` / `<!-- GOALS:END -->` — **REPLACE** if user provided new goals. **PRESERVE** if exists and user skipped goals.
- `<!-- NOTES:START -->` / `<!-- NOTES:END -->` — **PRESERVE** if exists.
- `<!-- SNAPSHOTS:START -->` / `<!-- SNAPSHOTS:END -->` — **REPLACE** with fresh snapshots.
- Frontmatter — **PRESERVE** if exists.

If the file does not exist (or sentinels are missing/corrupted), write the full file from scratch.

**File format:**

```markdown
---
date: <YYYY-MM-DD>
---

<!-- GOALS:START -->
## Goals
- [ ] <goal 1>
- [ ] <goal 2>
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

Omit the Goals section entirely if the user skipped goals and no prior goals exist. Omit the Notes section if no prior notes exist (notes are only written by /end-day). Always include Snapshots unless both repos are missing (see Degradations).

### 8. Report

Print:
- Path written (e.g. `~/.claude/daily/2026-05-22.md`)
- Whether yesterday's recap was shown or skipped
- Whether goals were set
- Suggested next: "Run `/end-day` tonight to capture notes and a final snapshot."

## Degradations

- **`~/.claude/daily/` doesn't exist** — create it, skip recap.
- **No previous daily file** — skip recap, show current state only.
- **Repo path missing or not a git repo** — skip that repo, warn once, continue.
- **Both repos missing** — write the file with goals only (no Snapshots section). Warn: "Neither repo found — snapshot skipped."
- **`gh` not installed or not authenticated** — skip PR data, note in output.
- **Jira MCP not configured** — skip silently.
- **`git fetch` fails** — continue with local state, no warning (network issues are transient).
- **Sentinels corrupted or missing in existing file** — treat as fresh write (overwrite entire file).
- **Previous file is very old (>5 days)** — show it but note the age.
