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

1. **Reads the underlying skill file from its install location.** Skills install to `~/.claude/commands/<skill>.md` (user scope) or `<repo>/.claude/commands/<skill>.md` (project scope) — not from the user's current working directory. Resolve the path by checking project scope first (`.claude/commands/<skill>.md`), then user scope (`$HOME/.claude/commands/<skill>.md`). If neither resolves, bail with: "/auto-do can't find `commands/<skill>.md` in `.claude/commands/` or `~/.claude/commands/`. Reinstall the workshop or check your `--user` vs `--project` scope."
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
- **Detect and capture the default branch**: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` (fallback `main`). Store as `<default>` for use in later steps (9 complexity re-check, 11 UI re-detection). Don't hardcode `main` anywhere downstream.
- **Verify `gh` version supports `gh pr ready --undo`** (used in step 12's round-2 safe-stop): `gh --version` must report ≥ 2.40.0. If older, the round-2 safe-stop falls back to `gh api -X PATCH repos/<owner>/<repo>/pulls/<n> -f draft=true`. Log the chosen mode.
- Derive `<slug>` from `$ARGUMENTS`:
  - Lift the validation rules from `commands/research.md`'s slug section: reject path separators / `..` / drive letters; reject filesystem-illegal characters and Windows reserved names; normalise to kebab-case (lowercase ASCII alphanumerics + hyphens, repeated hyphens collapsed, leading/trailing hyphens trimmed).
  - Cap at **60 chars** (headroom under git's remote-ref limit).
  - If the result is empty, fall back to `auto-do-<UTC YYYYMMDD-HHMM>`.
- If `auto-do/<slug>` already exists locally OR on the remote (`git ls-remote --heads origin auto-do/<slug>`), suffix `-2`, `-3`, …, capped at `-99` (bail if all are taken).
- **Branch selection:**
  - If current branch equals `<default>`: `git checkout -b auto-do/<slug>`.
  - Otherwise: check divergence with `git rev-list --count <default>..HEAD`. **If the count is 0** (current branch is at `<default>` or behind), reuse it. **If > 0** (current branch has unrelated commits ahead of `<default>`), do not reuse — `git checkout -b auto-do/<slug>` from `<default>` and proceed. Reusing a branch with unrelated commits would push them in the PR.
- Log: `default-branch: <default>`, `gh-pr-ready-mode: <flag | api-fallback>`, `branch: <branch>` to the auto-decision log.

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

If step 6 wrote `docs/solutions/<slug>.md`, advance it to `in-progress`:

- Append `## In progress` with branch name, commit range, and one paragraph on what was actually built.
- Update frontmatter: `status: in-progress`, add `started: <today>`.

If step 6 skipped (because `docs/solutions/` was missing), this step is also skipped — don't try to edit a file that doesn't exist. Log: `solution-doc-in-progress: skipped — step 6 also skipped`.

### 9. Pre-push verification

Before pushing, run **two** checks in this order:

1. **Test gate.** Detect and run the project's test command (`npm test`, `pnpm test`, `pytest`, `cargo test`, project Makefile target). Detection rules:
   - Prefer the command surfaced by the project's own `CLAUDE.md` if it documents one.
   - Otherwise, look for a top-level `package.json` with a `test` script, then `pyproject.toml`, then `Cargo.toml`, then `Makefile`.
   - **Skip watchers.** If a test command would run in watch mode by default, append the equivalent of `--run` / `--ci` / `CI=1` to force a single-pass run. If unsure, log `tests: skipped — could not detect a non-watch invocation` and continue (do not block on detection failure alone).
   - Log: `test-command: <detected | none>` plus the actual command run.
2. **Diff complexity re-check.** Recount the diff's affected files (`git diff <default>..HEAD --name-only | wc -l`, where `<default>` is the captured default branch from step 1). If the implemented diff exceeds 8 files (the complexity smell threshold), do not block — but log to the auto-decision log: `diff-complexity: <N> files (>8 — flag for human review)`. The human reviewer is the gate.

If the test gate fails, stop. Surface the failing output. Commits stay locally; nothing is pushed.

### 10. Push and create PR

- `git push --set-upstream origin <branch>` — set upstream explicitly so `/review-pr`'s round-1 fix-up push in step 12 doesn't trip its "Branch has no remote yet" `AskUserQuestion` gate.
- Write the PR body to a temp file (`gh pr create --body-file <path>`) — inline `--body` is brittle for large multiline content with backticks, code fences, and quotes, and `--body-file` makes the body editable from disk for later updates by step 11. Body must include:
  - Heading `## auto-do output — review before merge`.
  - Links to `docs/plans/<slug>.md` and `docs/solutions/<slug>.md` (if written).
  - The full **Auto-decision log** (see structure below).
  - The eng review's `## Engineering Review` block (from `docs/plans/<slug>.md`).
  - The design review's `## Design Review` block, if step 4 ran.
  - A placeholder `## /browse verification` section that step 11 fills in (or step 11 marks "skipped" with a reason). The placeholder is added now so the PR body has a stable structure; step 11 updates the file and runs `gh pr edit <n> --body-file <path>` to apply it.
- Capture the PR URL.

### 11. UI verification via /browse (conditional)

Re-detect UI scope from the **actual** diff (`git diff <default>..HEAD --name-only`, where `<default>` is captured from step 1) — initial detection from step 3 may have been wrong. If the implemented diff has UI files, run the verification pass even if step 3 missed it; if the diff has no UI files despite step 3 detecting UI scope, skip and log the discrepancy.

When the verification pass runs:

- Check `<repo>/.claude/browse/storage-state.json`. If the target URL is auth-gated AND no storage state exists, **skip**: log `browse: skipped — no storage state for <url>; run /browse --setup once to enable next-time UI verification` to the auto-decision log and to the PR body's `## /browse verification` section. `/auto-do` does NOT run `/browse --setup` — setup is interactive by nature.
- **"Auth-gated" is not "non-localhost".** Local apps fronted by an auth proxy or that mirror prod auth need storage state too. The check: if the target URL responds with a redirect to a login path, OR if `<repo>/.claude/browse/storage-state.json` exists (signalling the user previously decided this app needed auth), treat as auth-gated regardless of host. Pure localhost dev servers without observed auth proceed without storage state.
- If storage state exists OR the target is genuinely unauthenticated, read `commands/browse.md` from the resolved install location (per the **How `/auto-do` orchestrates** section) and execute it inline with these auto-decisions:
  - Target URL: derived from the project's dev URL config (`package.json` `scripts.dev` port, or `CLAUDE.md` if it documents one). If no dev URL is discoverable, skip and log.
  - Scenario: "Verify the change introduced by this PR" — feed the diff filenames as context.
  - Destructive-action gate: ANY destructive action surfaces and stops the verification pass. `/auto-do` does not auto-confirm destructive actions — log `browse: stopped at destructive-action gate on <action>; manual verification needed`.
- If `/browse` detects a login redirect despite storage state being present, log `browse: storage state expired — verification skipped` and continue. Don't bail.
- After the browse pass (or skip), update the PR body's `## /browse verification` section (edit the body file written in step 10, then `gh pr edit <n> --body-file <path>`).

### 12. Review the PR

Read the resolved `review-pr.md` skill file (per the **How `/auto-do` orchestrates** section). Execute inline with these auto-decisions:

- Pass the PR number from step 10.
- Round 1 (Codex + pr-reviewer in parallel) runs as the underlying skill describes. `/review-pr`'s round-comment posting puts the consolidated findings on the PR for the audit trail.
- At the round-1 user gate (`AskUserQuestion` in `/review-pr` step 4): auto-pick **"Address must-fix now (auto-push enabled)"**.
- During the round-1 fix-up auto-push, `/review-pr`'s step 6 may dispatch its first-push `AskUserQuestion` ("Branch has no remote yet"). Step 10 of `/auto-do` already pushed with `--set-upstream`, so this gate should not fire. If it does (upstream lost between steps 10 and 12 for some reason): auto-pick **"Push and create remote branch"**.
- Round 2 (Codex re-review) runs.
- **Round-2 outcomes:**
  - **Clean:** print "Round 2 clean.", proceed to the report.
  - **New must-fix items:** the underlying `/review-pr` posts the round-2 findings as a PR comment then dispatches its round-2 `AskUserQuestion` ("Address now / Dump to TODOS.md / Abort"). Auto-pick **"Dump to TODOS.md and stop"** for the underlying skill, then `/auto-do` adds the safe-stop layering on top:
    1. Append the round-2 findings to `TODOS.md` under `## Review findings — <YYYY-MM-DD>` per the existing convention. **Stage and commit this**: `git add TODOS.md && git commit -m "auto-do(<slug>): round-2 findings deferred to TODOS.md"`. Then `git push origin HEAD:refs/heads/<branch>` so the PR has the promised TODOs and the working tree stays clean.
    2. Convert the PR to draft so it cannot be merged accidentally:
       - If `gh-pr-ready-mode: flag` (set in step 1, `gh` ≥ 2.40): `gh pr ready --undo <n>`.
       - If `gh-pr-ready-mode: api-fallback`: `gh api -X PATCH repos/<owner>/<repo>/pulls/<n> -f draft=true`.
    3. Post a blocking comment: `gh pr comment <n> --body "auto-do: round 2 surfaced N new must-fix items. PR converted to draft. Items committed to TODOS.md (commit <sha>). Human attention needed."`
    4. Edit the PR body to append a `## Final status: failed:round-2-must-fix` section (use `gh pr edit <n> --body-file <path>` against the body file from step 10).
    5. Stop. No round 3.

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

The links logged as `research-back-links` count entries that landed in the plan file's `## See also` section. They are **not** copied into the PR body itself — only the count is reported here, and the audit chain points to the plan file.

A "non-stopword token" (used in step 2's research-link heuristic) is a token of length ≥ 3 that is not in: `the, and, for, with, this, that, into, from, onto, your, our, my, a, an, of, to, in, on, by, is, it, be`.

Required entries (in order):

- `default-branch: <name>` (from step 1).
- `gh-auth: passed` (from step 1).
- `gh-pr-ready-mode: <flag | api-fallback>` (from step 1).
- `branch: <name>` (from step 1).
- `plan: <path | in-conversation only>` (from step 2).
- `research-back-links: <N | none>` (from step 2 — count of links in the plan's See-also section).
- `ui-scope-initial: <detected | none>` (from step 3).
- For each design-review dimension below 8: `design:<dimension>: <patched-in-plan | deferred>`.
- `design-review-outside-voice: skipped — auto-mode`.
- For each eng-review issue: `eng-review:<section>:<issue>: <recommended | safer-side: <rationale>>`.
- For each TODO triage decision: `eng-review:todo:<item>: <A | C-test-gap | C-regression>`.
- `solution-doc-decided: <written | skipped — <reason>>` (from step 6).
- `solution-doc-in-progress: <written | skipped — step 6 also skipped>` (from step 8).
- `test-command: <command run | none — could not detect>` (from step 9).
- `tests: <passed | failed | skipped — <reason>>` (from step 9).
- `diff-complexity: <N files>` (from step 9).
- `pr-url: <url>` (from step 10).
- `pr-status: <ready | draft>` (from step 10/12 — initially `ready`, becomes `draft` if step 12 round-2 safe-stop fires).
- `ui-scope-final: <detected-from-diff | none>` (from step 11).
- `storage-state-path: <path | none>` (from step 11).
- `browse: <ran:<note-path> | skipped:<reason>>` (from step 11).
- `review-r1-gate: address-must-fix-now` (from step 12).
- `review-r1-first-push: <not-fired | push-and-create>` (from step 12).
- `review-r2: <clean | failed: N must-fix>` (from step 12).
- `final-status: <success | failed:round-2-must-fix | failed:test-gate | failed:complexity-smell | failed:ambiguity>` (from step 13; `failed:complexity-smell` exits at step 5 before any PR is created — log to console + the run's solution doc rather than a PR body).

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
