---
description: Autonomous task runner — chains plan, eng review (and design review + /browse verification when UI is touched), implementation, PR creation, and review-pr with a documented auto-decision policy. No prompts from /auto-do itself; external prerequisites (gh auth, MCP availability, dev server) must already be in place. Stops before merge.
argument-hint: <task description>
---

The non-interactive sibling of the workshop's planning chain. `/auto-do` takes a task and runs it through `/plan` → `/plan-eng-review` (and `/plan-design-review` when UI scope is touched) → implementation → `/solution` → `gh pr create` → `/browse` (for UI verification, where applicable) → `/review-pr`, applying a documented auto-decision policy at every gate the underlying skills would have raised. The PR is created and reviewed but **never merged** — the merge gate stays human.

User arguments: $ARGUMENTS

## What "non-interactive" means here

- **No prompts from `/auto-do` itself.** Every gate the underlying skills raise gets a default; no `AskUserQuestion` calls reach the user.
- **External prerequisites must already be satisfied.** `gh auth status` must pass, the test command must be runnable, the dev server must be reachable for the `/browse` pass, Playwright MCP storage state must already be captured if the target is auth-gated. `/auto-do` checks and bails on missing prerequisites — it never tries to set them up itself.
- **Auto-decisions are logged.** Every default `/auto-do` takes is appended to a structured **Auto-decision log** in the PR body. Auditing is the price of autonomy.

## How `/auto-do` orchestrates the existing skills

This is a markdown skill, not a runtime. Slash commands are prompt expansions, not callable subroutines. So at each step, `/auto-do`:

1. Reads the underlying skill file from disk (`commands/<skill>.md`).
2. Executes its numbered steps inline, applying the auto-decision policy below at every prompt.
3. Logs each auto-decision to the Auto-decision log.

When the underlying skills change shape, this orchestrator re-reads the new bodies on next invocation. No re-implementation; the underlying skills stay the single source of truth.

## Auto-decision policy

- **Recommended option, when one is marked** → take it.
- **No recommended option, multiple choices** → pick the option that minimises diff and ties to a stated workshop principle (DRY, explicit > clever, edit-before-add, smallest viable change). If still ambiguous, **fail closed** — stop with a clear "/auto-do hit ambiguity at <step>" message rather than guessing.
- **Cross-model tension surfaced by Codex outside voice** → take the safer side (more tests, narrower scope, documented assumption).
- **Eng-review per-issue triage:**
  - **Must-fix** → take the recommended fix option (fix inline, edit the plan).
  - **Should-fix** → A (TODOS.md).
  - **Follow-up** → A (TODOS.md).
  - **Test gap or regression test** → C (build inline). Non-negotiable.
- **Design review per-dimension:** every dimension below 8 → "Add the missing spec to the plan." Skip the variants step. Skip Codex outside voice (eng-review's outside voice is sufficient — bounding LLM cost is the trade-off; the user can always run `/plan-design-review` interactively for deeper coverage).
- **Round-1 review gate** → "Address must-fix now (auto-push enabled)".
- **Round-2 review with new must-fix** → see step 11 below for the safe-stop behaviour. Not a silent dump.

## Hard safety rules

- **Never push to default branch.** If `HEAD` is on `main` / `master` / the repo's default branch, derive `auto-do/<slug>` and `git checkout -b` before touching files.
- **Never `--force`, `--force-with-lease`, or `--no-verify`.**
- **Never merge the PR.** Even on a clean review.
- **Bail loudly on irrecoverable state.** Dirty working tree, missing `gh`, unresolved conflicts, failed test before push → stop with a clear message.
- **Stop after round 2.** Inherit `/review-pr`'s hard cap.
- **Stop on complexity smell.** If eng review's scope challenge concludes the plan trips the smell (>8 files or 2+ new services/classes), stop after step 5. `/auto-do` is for executable plans, not for re-planning.

## Steps

### 1. Pre-flight

- `git rev-parse --show-toplevel` — must be in a repo. Bail if not.
- `git status --porcelain` — must be empty. Bail with: "auto-do refuses to start with a dirty working tree. Commit, stash, or revert first."
- `gh auth status` — must pass. Bail with: "auto-do needs `gh` authenticated; run `gh auth login` and retry."
- Detect default branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` (fallback `main`).
- Derive `<slug>` from `$ARGUMENTS`:
  - Lift the validation rules from `commands/research.md`'s slug section: reject path separators / `..` / drive letters; reject filesystem-illegal characters and Windows reserved names; normalise to kebab-case (lowercase ASCII alphanumerics + hyphens, repeated hyphens collapsed, leading/trailing hyphens trimmed).
  - Cap at **60 chars** (headroom under git's remote-ref limit).
  - If the result is empty, fall back to `auto-do-<YYYYMMDD-HHMM>`.
- If `auto-do/<slug>` already exists locally OR on the remote (`git ls-remote --heads origin auto-do/<slug>`), suffix `-2`, `-3`, … until unique.
- If current branch equals the default branch, `git checkout -b auto-do/<slug>`. Otherwise reuse the current branch and treat it as the auto-do target.
- Log: `branch: <branch>` to the auto-decision log.

### 2. Plan

Read `commands/plan.md`. Execute its numbered steps inline with these auto-decisions:

- Skip every interactive prompt; take the recommended path.
- Slug: derived in step 1 (do not re-derive).
- Persist the plan to `docs/plans/<slug>.md` if `docs/plans/` exists. If missing, log: `plan: in-conversation only — docs/plans/ not present` and continue.
- Auto-link `docs/research/*` files **only when** the file's slug shares **≥2 non-stopword tokens** with the task. Bad links are worse than no links. The links go in the plan file's `## See also` section, not in the PR body.

### 3. Detect design scope (initial pass)

- **Keyword test on `$ARGUMENTS`**: ui, screen, page, view, modal, button, form, layout, dashboard, theme, mobile, responsive, frontend, component, design, css, style.
- **File-path test on the plan's affected files**: `src/components`, `app/`, `pages/`, `templates/`, `views/`, `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`, `*.scss`.

If either fires, mark `ui-scope: detected` (initial). If neither, mark `ui-scope: none` and proceed to step 5.

### 4. Design review (conditional)

Read `commands/plan-design-review.md`. Execute inline with these auto-decisions:

- Score all 8 dimensions.
- For each dimension below 8: "Add the missing spec to the plan" (option 1 in the underlying skill). Patch the plan in place.
- Skip the variants step.
- Skip the Codex outside voice (logged: `design-review-outside-voice: skipped — auto-mode`).

### 5. Engineering review

Read `commands/plan-eng-review.md`. Execute inline with these auto-decisions:

- Run all sections: scope challenge, architecture, code quality, tests, performance.
- Per-issue triage: per the **Auto-decision policy** above.
- Run the outside-voice / Codex step (auto-mode invests in the cross-model second opinion). On CROSS-MODEL TENSION: take the safer side, log the rationale.

**Stop conditions:**

- Eng review's scope challenge concludes the plan exceeds the complexity smell (>8 files or 2+ new services/classes) → stop after this step. Print the reasoning, exit. No PR is created.
- Eng review surfaces a must-fix item without a recommended option AND no clear safer side → fail closed: "/auto-do hit ambiguity at eng review section <N>. Re-run interactively." Stop.

### 6. Solution doc — decided

Equivalent of `/solution <slug>` at the `decided` stage:

- Write `docs/solutions/<slug>.md` with frontmatter (`status: decided`, `date: <today>`, `slug: <slug>`).
- Body: `## Problem`, `## Options considered`, `## Chosen approach`, `## Rationale`, lifted from the plan and the eng review block.
- If `docs/solutions/` is missing, log `solution-doc: skipped — docs/solutions/ not present` to the auto-decision log and continue. Skips are logged, never silent.

### 7. Implement

Edit files per the (now-reviewed) plan:

- Stage and commit in logical chunks. Commit messages: imperative, scoped. Format: `auto-do(<slug>): <one-line>`.
- Per-commit testing is a soft-check — fast lints / type-checks if the project standardises one. The authoritative gate is the pre-push run in step 9.
- Regression tests added during step 5 are non-negotiable: write them as part of this step.

### 8. Solution doc — in-progress

Advance `docs/solutions/<slug>.md` to `in-progress`:

- Append `## In progress` with branch name, commit range, and one paragraph on what was actually built.
- Update frontmatter: `status: in-progress`, add `started: <today>`.

### 9. Pre-push verification

Before pushing, run **two** checks in this order:

1. **Test gate.** Detect and run the project's test command (`npm test`, `pnpm test`, `pytest`, `cargo test`, project Makefile target). Detection rules:
   - Prefer the command surfaced by the project's own `CLAUDE.md` if it documents one.
   - Otherwise, look for a top-level `package.json` with a `test` script, then `pyproject.toml`, then `Cargo.toml`, then `Makefile`.
   - For monorepos, run only the workspace-scoped test command if the diff is contained to one workspace; run the root command otherwise.
   - **Skip watchers.** If a test command would run in watch mode by default, append the equivalent of `--run` / `--ci` / `CI=1` to force a single-pass run. If unsure, log `tests: skipped — could not detect a non-watch invocation` and continue (do not block on detection failure alone).
2. **Diff complexity re-check.** Recount the diff's affected files (`git diff main..HEAD --name-only | wc -l`). If the implemented diff exceeds 8 files (the complexity smell threshold), do not block — but log to the auto-decision log: `diff-complexity: <N> files (>8 — flag for human review)`. The human reviewer is the gate.

If the test gate fails, stop. Surface the failing output. Commits stay locally; nothing is pushed.

### 10. Push and create PR

- `git push origin HEAD:refs/heads/<branch>` (the branch from step 1). Set upstream on first push.
- `gh pr create --title "<one-line task summary>" --body "<auto-generated body>"`. Body must include:
  - Heading `## auto-do output — review before merge`.
  - Links to `docs/plans/<slug>.md` and `docs/solutions/<slug>.md` (if written).
  - The full **Auto-decision log** (see structure below).
  - The eng review's `## Engineering Review` block (from `docs/plans/<slug>.md`).
  - The design review's `## Design Review` block, if step 4 ran.
  - A placeholder `## /browse verification` section that step 11 fills in (or step 11 marks "skipped" with a reason). The placeholder is added now so the PR body has a stable structure.
- Capture the PR URL.

### 11. UI verification via /browse (conditional)

Re-detect UI scope from the **actual** diff (`git diff main..HEAD --name-only`) — initial detection from step 3 may have been wrong. If the implemented diff has UI files, run the verification pass even if step 3 missed it; if the diff has no UI files despite step 3 detecting UI scope, skip and log the discrepancy.

When the verification pass runs:

- Check `<repo>/.claude/browse/storage-state.json`. If the target URL is auth-gated AND no storage state exists, **skip**: log `browse: skipped — no storage state for <url>; run /browse --setup once to enable next-time UI verification` to the auto-decision log and to the PR body's `## /browse verification` section. `/auto-do` does NOT run `/browse --setup` — setup is interactive by nature.
- If storage state exists OR the target is unauthenticated (localhost dev server, public URL), read `commands/browse.md` and execute it inline with these auto-decisions:
  - Target URL: derived from the project's dev URL config (`package.json` `scripts.dev` port, or `CLAUDE.md` if it documents one). If no dev URL is discoverable, skip and log.
  - Scenario: "Verify the change introduced by this PR" — feed the diff filenames as context.
  - Destructive-action gate: ANY destructive action surfaces and stops the verification pass. `/auto-do` does not auto-confirm destructive actions — log `browse: stopped at destructive-action gate on <action>; manual verification needed`.
- If `/browse` detects a login redirect despite storage state being present, log `browse: storage state expired — verification skipped` and continue. Don't bail.
- After the browse pass (or skip), update the PR body's `## /browse verification` section with the session note path (or the skip reason).

### 12. Review the PR

Read `commands/review-pr.md`. Execute inline with these auto-decisions:

- Pass the PR number from step 10.
- Round 1 (Codex + pr-reviewer in parallel) runs as the underlying skill describes. The new round-comment posting (added in PR #16, commit `878e25b`) puts the consolidated findings on the PR for the audit trail.
- At the round-1 user gate: auto-pick **"Address must-fix now (auto-push enabled)"**.
- Round 2 (Codex re-review) runs.
- **Round-2 outcomes:**
  - **Clean:** print "Round 2 clean.", proceed to the report.
  - **New must-fix items:** the underlying `/review-pr` posts the round-2 findings as a PR comment. `/auto-do` then marks the run as **failed**:
    - `gh pr ready --undo <n>` — convert to draft so it cannot be merged accidentally.
    - `gh pr comment <n> --body "auto-do: round 2 surfaced N new must-fix items. PR converted to draft. Items dumped to TODOS.md. Human attention needed."`
    - Append the items to `TODOS.md` under `## Review findings — <YYYY-MM-DD>` per the existing convention.
    - Append a "Final status: failed" note to the PR body.
    - Stop. No round 3.

### 13. Final report

Print:

```
auto-do summary
---------------
Task:           <one-line summary>
Branch:         <branch>
Plan:           docs/plans/<slug>.md  (or "in-conversation only")
Design review:  <ran | skipped — no UI scope>
Eng review:     <N> issues raised, <M> patched in plan, <K> deferred to TODOS.md
Solution doc:   docs/solutions/<slug>.md  (status: in-progress)  (or "skipped — <reason>")
Pre-push:       tests=<passed|failed|skipped>  diff-files=<N>
PR:             <url>
Browse verify:  <ran:<note-path> | skipped:<reason>>
Review rounds:  <1 | 2>
Findings R1:    must=<X> should=<Y> follow=<Z>
Findings R2:    must=<X>  (or "skipped — round 1 clean")
Final status:   <success | failed:round-2-must-fix | failed:test-gate | failed:complexity-smell | failed:ambiguity>
Auto-decisions: see PR body
Next:           Human reviews PR. /auto-do does not merge.
```

## Auto-decision log structure (required in PR body)

A `## Auto-decisions` section in the PR body lists every auto-pick `/auto-do` made. Each line: `<step>: <decision> — <one-line rationale>`.

Required entries:

- `branch: <name>` (from step 1).
- `plan: <path | in-conversation only>` (from step 2).
- `research-back-links: <N | none>` (from step 2).
- `ui-scope-initial: <detected | none>` (from step 3).
- For each design-review dimension below 8: `design:<dimension>: <patched-in-plan | deferred>`.
- `design-review-outside-voice: skipped — auto-mode`.
- For each eng-review issue: `eng-review:<section>:<issue>: <recommended | safer-side: <rationale>>`.
- For each TODO triage decision: `eng-review:todo:<item>: <A | C-test-gap | C-regression>`.
- `solution-doc: <written | skipped — <reason>>`.
- `tests: <passed | failed | skipped — <reason>>`.
- `diff-complexity: <N files>`.
- `ui-scope-final: <detected-from-diff | none>`.
- `browse: <ran:<note-path> | skipped:<reason>>`.
- `review-r1-gate: address-must-fix-now`.
- `review-r2: <clean | failed: N must-fix>`.

## Degradations

- **Not in a git repo / dirty tree / missing `gh`** → step 1 bail.
- **Default branch as HEAD** → step 1 creates `auto-do/<slug>`.
- **`docs/plans/` missing** → step 2 holds the plan in conversation; logged.
- **`docs/solutions/` missing** → step 6 skips; logged.
- **`codex` not on PATH** → eng-review's outside voice falls back to `general-purpose` Agent (per `/plan-eng-review`'s existing handling); same for `/review-pr`'s round-2 Codex slot.
- **Test command not detectable** → step 9 logs and continues (does not block solely on detection failure).
- **Test command fails** → step 9 stops; nothing pushed.
- **Diff complexity exceeds smell threshold** → step 9 logs but does not block; human reviewer is the gate.
- **Plan trips complexity smell during eng review** → step 5 stops; no PR.
- **Branch name collision** → step 1 suffixes `-2`, `-3`, ….
- **No dev URL discoverable for /browse** → step 11 skips; logged.
- **No storage state for auth-gated target** → step 11 skips; logged with the "run /browse --setup" hint.
- **Storage state expired (login redirect mid-session)** → step 11 logs and continues with the partial session.
- **Browse hits destructive-action gate** → step 11 stops the verification pass; no auto-confirmation.
- **Round 2 surfaces must-fix** → step 12 marks the PR as draft, dumps to TODOS.md, posts a blocking comment, ends with `Final status: failed:round-2-must-fix`.
- **Ambiguity (no recommended option AND no clear safer side)** → fail closed at the relevant step with `/auto-do hit ambiguity at <step>`.

## Out of scope (intentional)

- Auto-merging the PR.
- `--force`-pushing or skipping hooks.
- Watching for new pushes / re-running on every commit.
- Re-planning when eng review surfaces architectural gaps.
- Multi-PR sequencing for very large tasks.
- Running `/browse --setup` mid-flow — setup is interactive.
- Distinguishing pre-existing test failures from regressions — assume the user invoked `/auto-do` from a green default branch; if tests fail mid-flow, stop and surface, don't try to attribute cause.

## See also

- `commands/plan.md`, `commands/plan-eng-review.md`, `commands/plan-design-review.md`, `commands/solution.md`, `commands/browse.md`, `commands/review-pr.md` — the underlying skills `/auto-do` orchestrates.
- `docs/plans/auto-do.md` — the approved plan and engineering review.
- `docs/solutions/auto-do.md` — the decided/in-progress/outcome record for this skill.
