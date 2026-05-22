---
date: 2026-05-22
slug: daily-workflow-capture
topic: Daily workflow tools — capture work-in-progress across sessions and surface goals at start of day
tags: [developer-experience, context-management, scheduling, multi-session]
research: []
---

> **Ungrounded.** No research files exist in `docs/research/` yet. This brainstorm is seeded from the constraint that the user runs 3–5 concurrent Claude Code sessions across different projects and wants low-friction daily continuity.

## User

- **The core problem is context loss overnight.** You close 4 laptops' worth of sessions and next morning you're staring at a blank terminal trying to remember what was mid-flight. The tool needs to answer: "what was I doing, what's still open, and what should I focus on today?"
- **Multi-session is the killer constraint.** Any approach that requires manual invocation per-session will be skipped. If you have 5 sessions and forget one, you get incomplete capture — worse than no capture because you trust it.
- **The ideal UX is: do nothing at end of day, run one command in the morning.** /start-day from any project (or a dedicated "dashboard" project) that pulls context from all active projects.
- **Goals vs. status are different.** "What I was doing" is retrospective capture. "What I should do today" requires intent — either set the night before or derived from open work. Both are valuable but have different data sources.
- **The morning summary should be scannable in 10 seconds.** Not a wall of text. Per-project, 2–3 bullet points each, with the most actionable item first.
- **There's a spectrum from passive to active capture.** Passive: scrape git state automatically. Active: user dictates priorities. The sweet spot is probably passive capture with optional active annotation.

## Ops

- **Git is the universal source of truth across sessions.** Every session leaves traces: branches, commits, stashes, uncommitted changes, recent `git log`. This data is already there — no new persistence layer needed.
- **Claude Code's memory system (`~/.claude/projects/`) is per-project and persistent.** Memories written in one session are visible to future sessions in the same project. This is a free cross-session sync mechanism within a project.
- **Scheduled agents (`/schedule`) can run without a terminal open.** A scheduled routine could fire at e.g. 23:00 to snapshot state across all known projects, writing to a shared location.
- **Hook-based capture is zero-friction but limited.** A `PostToolUse` or session-end hook could write a breadcrumb, but hooks are per-project and there's no "session close" event — sessions just go idle and die.
- **The memory directory at `~/.claude/` is the natural cross-project meeting point.** A global memory file (not project-scoped) could aggregate daily state from all projects.
- **Multiple projects means multiple git repos.** The capture tool needs to know which repos to scan. Options: hardcode a list, scan `~/.claude/projects/` for known project paths, or let the user configure a project registry.

## Scope

- **v0.1 — `/start-day` only, git-derived, no capture step.**
  - Single skill that scans all known project directories (derived from `~/.claude/projects/`)
  - For each: current branch, uncommitted changes, last commit date/message, any stashes
  - Output: a scannable morning briefing
  - No persistence, no /end-day, no scheduled agents
  - Zero new infrastructure — just reads existing state

- **v0.2 — Add optional `/end-day` annotations.**
  - Run from any single session. Writes a note to a shared daily file (e.g. `~/.claude/daily/2026-05-22.md`)
  - /start-day reads these notes alongside git state
  - Still works fine without /end-day — git state is the baseline

- **v1 — Scheduled capture + goals.**
  - A `/schedule`d routine runs at end-of-day, snapshots all projects automatically
  - /start-day can also set goals for today (written to the daily file)
  - /start-day shows yesterday's goals vs. actual progress

- **v2 — Cross-day continuity and trends.**
  - Weekly summaries, pattern detection ("you've had this branch open for 5 days")
  - Integration with Jira/Linear if available

- **What can be cut without losing core value:** /end-day entirely. The git-only /start-day (v0.1) solves 80% of the problem with zero new habits.

## Risk

- **Scanning `~/.claude/projects/` to discover repos is fragile.** The directory names are path-encoded and may include worktrees, deleted projects, or stale entries. Need to validate that the decoded path still exists and is still a git repo.
- **Privacy/sensitivity concern.** Aggregating state across projects means /start-day in project A can see branch names and commit messages from project B. If some projects are client-confidential, this could leak context. Mitigation: allow a project-level opt-out.
- **Stale data is worse than no data.** If /start-day shows "you were working on feature-X" but you finished and merged it yesterday afternoon, it's noise. Need to detect merged/closed branches.
- **Scheduled agents are a newer Claude Code feature.** Reliability and availability may vary. v0.1 should not depend on them.
- **Writing to `~/.claude/` directly couples to Claude Code's internal directory structure.** If Anthropic changes the layout, the tool breaks. Mitigate by keeping the cross-project aggregation file in a user-controlled location (e.g. `~/.daily-briefing/` or within the-workshop itself).
- **The "known projects" list could grow unbounded.** Old projects, experiments, worktrees — the scan needs to filter to recently-active projects (e.g. had a commit in the last 7 days).

## Tensions

1. **User wants zero friction (no /end-day) vs. Ops wants richer capture (annotations, goals).** Pure git-scraping gets you status but not intent. Adding /end-day gets intent but adds friction — the exact friction the user flagged. Resolution path: make /end-day optional and additive. Git state is always the baseline; annotations enrich but aren't required.

2. **Scope wants v0.1 to be git-only vs. Risk warns that stale git data misleads.** A branch that's been merged still shows up in `git branch` locally. Pure git scraping without cleanup detection could surface outdated work. v0.1 needs at least basic staleness filtering (check if branch is merged into main, check last commit age).

3. **User wants a single invocation point vs. Ops notes data lives across N repos.** /start-day needs to run from one place but read from many. Options: (a) run it from the-workshop as the "home base" project, (b) make it a global skill that works from anywhere, (c) use a scheduled agent that writes a pre-built briefing. These have different installation and maintenance costs.

4. **Risk flags `~/.claude/projects/` coupling vs. Scope wants zero config.** Auto-discovering projects from Claude Code's internal directory is the lowest-friction approach but the most brittle. A user-maintained project list is more robust but adds setup. Middle ground: auto-discover with a simple override file.

5. **User wants morning goals vs. Scope says that's a v1 concern.** Goal-setting transforms /start-day from "read-only briefing" to "interactive planning session." The UX and data model are different. But without goals, it's just a status dump — useful but not motivating. Tension between shipping fast and shipping something that changes behaviour.
