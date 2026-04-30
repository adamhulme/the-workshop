---
status: approved
date: 2026-04-30
task: Add /review-pr — bounded 2-round review loop using Codex CLI + pr-reviewer agent
branch: plan-for-review-pr
---

# Add `/review-pr` — bounded 2-round review loop

## Context

Adam dropped GitHub Copilot Pro for Codex CLI + Claude Code. He wants a short, bounded reviewing process baked into the workshop where the two **trade roles** — one reviews, the other implements, then swap on the second pass. Cost-bounded; not a chat loop. The workshop already has the `pr-reviewer` agent (an independent five-dimension diff reviewer) — this builds on that, adding the Codex side and the loop.

Tokens and wall time are first-class constraints: the command must complete in a handful of LLM dispatches, not iterate until "done".

## Plan

### 1. New file — `commands/review-pr.md` (~200 lines, single file)

Frontmatter:

```yaml
---
description: Bounded 2-round PR review loop — Codex CLI and pr-reviewer agent trade reviewer/implementer roles
argument-hint: [pr-number]
---
```

### 2. Step 1 — Locate the diff

- If `$ARGUMENTS` is a PR number: fetch via `gh pr diff <n>` and `gh pr view <n> --json baseRefName,headRefName,number,title`.
- Else: detect default branch via `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` (fallback `main`), then `git diff <default>...HEAD`. Bail with a clear message if no diff.
- Cap diff size: if larger than ~30k tokens, truncate with a warning ("review will focus on the first 30k tokens; re-run on a narrower base").

### 3. Step 2 — Round 1, parallel reviews

In a single message, dispatch **both** in parallel:

- **Codex review** (Bash): `codex exec --skip-git-repo-check "<rubric prompt>"` with the diff piped or embedded. Five-dimension rubric (correctness, scope drift, test coverage, risk-to-revert, follow-up cleanup), structured output: file:line, category, severity, finding.
- **pr-reviewer subagent**: `Agent` tool with `subagent_type: pr-reviewer`, prompt includes the diff and the same rubric. The pr-reviewer agent already exists; reuse it.

Both run in a single tool-message; aggregate when both return.

### 4. Step 3 — Consolidate findings

Merge the two reviewers' lists. Dedupe by `(file, line, category)` — when both flag the same item, keep one entry but note "flagged by both". Group by **must-fix / should-fix / follow-up** using pr-reviewer's existing rubric.

### 5. Step 4 — Single user gate

`AskUserQuestion`: show the consolidated list (count per category). Three options:

- Address must-fix now (default)
- Dump everything to TODOS.md and stop
- Abort

### 6. Step 5 — Implementation pass

Main-thread Claude addresses **must-fix** items only. Edits + commits as a single fix-up commit (`Address review findings (round 1)`). `should-fix` and `follow-up` findings go verbatim into `TODOS.md` under a dated `## Review findings — <YYYY-MM-DD>` heading, grouped by category.

### 7. Step 6 — Round 2 (the role-swap)

Single re-review. Whichever reviewer ran *most recently* on the just-fixed code is the implementer for round 2; the other reviews. In practice that means **Codex re-reviews** the new diff (since main-thread Claude just implemented; pr-reviewer ran in round 1 but hasn't seen the fix; Codex's previous review was on the pre-fix diff).

- One Codex call: `codex exec` on the new diff, focused prompt — "the previous review's must-fix items have been addressed; check for regressions, missed cases, and any new issues introduced by the fix".
- If new must-fix findings appear: ask the user once whether to address them. **Hard cap at 2 rounds total** — if the user says yes, address them as a second fix-up commit (`Address review findings (round 2)`), then stop. No round 3.
- If zero must-fix findings: report "clean" and stop.

### 8. Step 7 — Report

Print:

- Rounds run (1 or 2)
- Findings count per round, per category
- Items addressed (with commit SHAs)
- Items deferred to `TODOS.md`
- Total wall time
- Suggested next step: push branch, open PR comment, or `/ship`

## Token / time budget

Per `/review-pr` invocation, ceiling:

- 2 × Codex CLI calls (one-shot, ~500–2k tokens each, no session)
- 1 × pr-reviewer subagent call (bounded by diff size)
- Main-thread implementation pass (1–2 fix-up commits)

= **3 LLM dispatches max**, plus the implementation pass. No retry loops, no auto-iteration. Wall time target: under 90s on a small diff.

## Critical files

**New (workshop repo):**
- `commands/review-pr.md` — the command itself, ~200 lines

**Modified (workshop repo):**
- `VERSION` — 0.3.0 → 0.4.0 (minor bump, new skill)
- `CHANGELOG.md` — `[0.4.0]` entry under `## [Unreleased]`
- `README.md` — new row in the skills table; mention in "Where to go next"

**Reused (no edits):**
- `agents/pr-reviewer.md` — existing five-dimension diff reviewer

## Out of scope

- Auto-pushing fixes (the user reviews the fix-up commits before pushing)
- Auto-merging
- Multi-file refactors driven by review feedback (the loop addresses findings, not redesigns)
- Watching for new pushes / running on every commit
- More than 2 rounds — the cap is intentional, even if findings remain

## Verification

After implementation lands:

1. **Dependency check.** Run `codex exec --version` to confirm Codex CLI is installed and authed.
2. **Live PR test.** From a workshop checkout, run `/review-pr 10` (the v0.3.0 PR). Confirm:
   - `gh pr diff 10` fetches the diff
   - Both Codex and pr-reviewer dispatch in parallel
   - Consolidated findings appear with category grouping
   - User gate fires once
   - Fix-up commit lands when address-now is chosen
   - Round 2 runs once with Codex
   - Total ≤ 3 LLM dispatches per run
   - Wall time under ~90s on small-to-medium diff
3. **Default-branch detection.** From a feature branch with no PR, run `/review-pr` (no args). Confirm it detects `main` via `gh repo view` and produces a diff.
4. **Codex-missing fallback.** Temporarily rename `codex` on PATH; run `/review-pr`. Confirm graceful fallback to a `general-purpose` Agent in place of Codex (mirrors the fallback pattern in `/plan-eng-review` and `/plan-design-review`), or a clean error if a fallback isn't appropriate for round 2.
5. **Cap enforcement.** Manually craft a diff that produces must-fix findings on round 1 and again on round 2. Confirm the command stops after round 2 and surfaces remaining items rather than entering round 3.

## Branch

This plan-only PR lands on `plan-for-review-pr` against `main`. The implementation PR will be `feat/review-pr` (or `release-v0.4.0`) once this plan is merged.

## See also

- `/plan-eng-review` and `/plan-design-review` — pre-implementation review loops; `/review-pr` is the post-implementation analogue.
- `agents/pr-reviewer.md` — the existing five-dimension diff reviewer this command reuses.
