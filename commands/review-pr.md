---
description: Bounded 2-round PR review loop — Codex CLI and pr-reviewer agent trade reviewer/implementer roles, fixes auto-pushed
argument-hint: [pr-number]
---

A short, cost-bounded reviewing process. **Codex CLI** and the **`pr-reviewer` agent** trade reviewer/implementer roles across two rounds. Hard cap at 2 rounds — the cap is the point.

User arguments: $ARGUMENTS

## How to ask questions

The single user gate at step 4 uses **`AskUserQuestion`**, not a trailing prose `(y/n)`. Same for the auto-push consent question if the branch has no upstream. Trailing questions get buried; structured prompts surface clean options.

## Token / time budget (ceiling)

- 2 × Codex CLI calls (round 1 + round 2)
- 1 × `pr-reviewer` subagent call (round 1)
- Main-thread implementation pass(es)
- 1–2 `git push` calls (auto-push, no force)

= **3 LLM dispatches max**, plus implementation. No retry loops, no auto-iteration. Wall-time target: under 90s on a small-to-medium diff.

## Steps

### 1. Locate the diff

- If `$ARGUMENTS` is a PR number: run `gh pr diff <n>` and `gh pr view <n> --json baseRefName,headRefName,number,title`. Capture the head branch name; that's where auto-push goes.
- Else: detect default branch with `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` (fallback `main`), then `git diff <default>...HEAD`. Capture current branch via `git symbolic-ref --short HEAD`.
- Bail with a clear message if there is no diff: "No diff to review."
- Cap diff size: if larger than ~30k tokens, truncate with a one-line warning ("review will focus on the first 30k tokens; re-run on a narrower base").

### 2. Round 1 — parallel reviews

In a single message, dispatch **both** in parallel:

- **Codex review (Bash):** `codex exec --skip-git-repo-check "<rubric prompt>"`. Pipe or embed the diff. Same five-dimension rubric as `pr-reviewer` (correctness, scope drift, test coverage, risk-to-revert, follow-up cleanup). Ask Codex for structured output: `file:line | category | severity | finding`.
- **pr-reviewer subagent:** `Agent` tool with `subagent_type: pr-reviewer`. Prompt includes the diff and the same rubric.

If `codex` is not on PATH, fall back to a second `Agent` call with `subagent_type: general-purpose`, prompted with the same rubric. Mirrors the fallback in `/plan-eng-review` and `/plan-design-review`.

Aggregate when both return.

### 3. Consolidate findings

Merge the two reviewers' lists. Dedupe by `(file, line, category)` — when both flag the same item, keep one entry annotated `(flagged by both)`. Group using `pr-reviewer`'s existing rubric:

- **Must fix before merge**
- **Should fix in this PR**
- **Follow-up**

Print the consolidated list with counts per category.

### 4. Single user gate

Dispatch `AskUserQuestion`:

- Question: "Round 1 review: <X> must-fix · <Y> should-fix · <Z> follow-up. How should I proceed?"
- Header: "Address findings"
- Options:
  - "Address must-fix now (auto-push enabled)" *(Recommended)* — proceed to step 5
  - "Dump everything to `TODOS.md` and stop" — write the consolidated list verbatim to `TODOS.md` under a dated `## Review findings — <YYYY-MM-DD>` heading, then stop
  - "Abort" — print "Review aborted." and stop

### 5. Implementation pass

Address **must-fix** items only. Edit the relevant files, then commit as a single fix-up commit:

```
Address review findings (round 1)

- <one bullet per must-fix item, file:line and one-sentence summary>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

Append `should-fix` and `follow-up` items verbatim into `TODOS.md` under a dated `## Review findings — <YYYY-MM-DD>` heading, grouped by category. If `TODOS.md` doesn't exist, create it with a `# TODOs` H1 first.

### 6. Auto-push (the new bit)

After the round 1 fix-up commit lands locally, push it automatically — no extra confirmation when conditions are safe:

1. **Determine target.** If a PR was specified in step 1, use that PR's head branch (already captured). Otherwise use `git symbolic-ref --short HEAD`.
2. **Refuse to push to main/master/default branch.** If the current branch *is* the default branch, skip the push and print: "On default branch — skipping auto-push. Push manually if you intended to land directly." This guard is non-negotiable.
3. **Check upstream.** Run `git rev-parse --abbrev-ref --symbolic-full-name @{u}` to see if the branch has an upstream.
   - If yes: `git push` (no force, no flags). Capture the output.
   - If no: dispatch `AskUserQuestion`:
     - Question: "Branch `<branch>` has no upstream. Push and set upstream to `origin/<branch>`?"
     - Header: "Set upstream"
     - Options: "Push and set upstream" / "Skip push"
     - On "Push and set upstream": `git push -u origin <branch>`.
4. **On push failure** (non-fast-forward, auth error, hook failure): do **not** retry, do **not** force. Surface the exact `git push` stderr to the user and stop. The user resolves and re-runs.

Never use `--force`, `--force-with-lease`, or `--no-verify`.

### 7. Round 2 — role swap

Single re-review by **Codex only**. Reasoning: `pr-reviewer` saw the pre-fix diff; main-thread Claude just implemented; Codex's previous round was on the pre-fix code. Codex is the only voice that hasn't seen the new state.

- One Codex call: `codex exec --skip-git-repo-check` on the new diff (`gh pr diff <n>` again, or `git diff <default>...HEAD`). Focused prompt: "The previous review's must-fix items have been addressed. Check for **regressions**, **missed cases**, and **new issues introduced by the fix**. Same five-dimension rubric. Be terse."
- If Codex isn't on PATH, fall back to a `general-purpose` Agent for round 2.

Outcomes:

- **Zero must-fix findings:** print "Round 2 clean." and proceed to step 8.
- **New must-fix findings:** dispatch `AskUserQuestion`:
  - Question: "Round 2 surfaced <N> new must-fix items. Address them?"
  - Header: "Round 2 fixes"
  - Options: "Address now (auto-push)" / "Dump to TODOS.md and stop" / "Abort"
  - On "Address now": apply the fixes, commit as `Address review findings (round 2)`, **and run step 6 again to auto-push**.
- **Hard cap.** Whatever happens after round 2 fixes, **do not enter round 3**. If new findings remain, surface them and stop.

### 8. Report

Print a tight summary:

```
Rounds:        <1 or 2>
Findings:      R1 must=<X> should=<Y> follow=<Z>  · R2 must=<X> (or "skipped")
Addressed:     <N> commits → <SHA1>, <SHA2>
Pushed:        <branch>@<remote-sha>  (or "skipped — <reason>")
Deferred:      <N> items in TODOS.md
Wall time:     <T>
```

Suggested next step: link to the PR (if reviewing a PR), or `gh pr create` (if reviewing a feature branch with no PR yet).

## Degradations

- **No diff** → step 1 abort with a clear message.
- **`codex` not on PATH** → fall back to `general-purpose` Agent for the Codex slot, both rounds. Note the fallback in the report.
- **`pr-reviewer` agent missing** (the workshop wasn't installed, or the user is running this command from outside) → bail with: "`/review-pr` requires the `pr-reviewer` agent. Run `./install.sh` from the workshop repo."
- **Branch is default branch** → skip auto-push, do not refuse the rest of the flow.
- **Branch has no upstream** → step 6 prompts before pushing.
- **Push fails** → surface stderr, stop. No retry, no force.
- **More than 2 rounds of must-fix** → impossible by design; the cap is the feature.

## Out of scope (intentional)

- Auto-merging
- Multi-file refactors driven by review feedback (this addresses findings, not redesigns)
- Watching for new pushes / running on every commit
- More than 2 rounds — the cap is the point
- Force pushes — never

## See also

- `/plan-eng-review`, `/plan-design-review` — pre-implementation review loops; `/review-pr` is the post-implementation analogue.
- `agents/pr-reviewer.md` — the existing five-dimension diff reviewer this command reuses.
