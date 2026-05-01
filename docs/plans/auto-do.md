---
status: approved
date: 2026-05-01
task: Add /auto-do — autonomous task runner that chains plan → review → implement → PR → review-pr without prompts, including a /browse verification pass when UI scope is touched
branch: feat/auto-do
---

# Plan: `/auto-do` — autonomous task runner for the workshop

## Context

The workshop ships a deliberately interactive set of skills: `/plan` asks for approval, `/plan-eng-review` walks one issue at a time, `/plan-design-review` scores 8 dimensions one prompt at a time, `/review-pr` gates on a single user choice. That's the right default — the user is the taste loop. But there's a real use case for the *non-interactive* sibling: a known-shape task the user wants run through the workshop's full pipeline without sitting at the keyboard.

Trigger for this work: the user asked for "a /auto-do mode which runs through the sequence of necessary commands (inc. design and eng review where required) without any user interaction. Create and review a PR but do not merge it." A second clarification followed: "this auto mode probably also needs a way to browse the app, how do we implement that, including creds setup. I have a plan for this somewhere" — which surfaced the headed-browser plan that became `/browse` (now shipped on `main` as of PR #16). With `/browse` shipped, `/auto-do` can compose with it for UI verification.

## User-locked decisions

- **No user interaction during the run.** Every gate the underlying skills would have raised gets an opinionated default. The decisions are logged in the PR body for auditability.
- **Design and eng review where required.** Eng review always runs. Design review runs only when UI scope is touched.
- **Creates and reviews a PR but does not merge.** The merge gate is the human's. `/auto-do` runs `/review-pr` (now with PR-comment posting per round) but stops before any merge action.
- **UI verification via `/browse` when applicable.** If UI scope is touched and `<repo>/.claude/browse/storage-state.json` exists (or the target is unauthenticated), run `/browse` after implementation as part of the verification pass. If creds aren't already set up, `/auto-do` notes the gap in the PR body and skips the browse pass — it does not run `/browse --setup` itself, since setup needs an interactive login.

## Approach

Add one new skill at `commands/auto-do.md`. The skill is markdown-only, like every other workshop skill — it orchestrates existing skills (`/plan`, `/plan-eng-review`, `/plan-design-review`, `/solution`, `/browse`, `/review-pr`) by following their steps with auto-decisions rather than re-implementing them. When those skills change, `/auto-do` benefits automatically.

Auto-decision policy (the core idea):

- Recommended option, when one is marked → take it.
- No recommended option, multiple choices → take the option that minimises diff and ties to a stated workshop principle (DRY, explicit > clever, edit-before-add, smallest viable change).
- Cross-model tension surfaced by Codex outside voice → take the safer side (more tests, narrower scope, documented assumption).
- TODO triage (eng review's A/B/C per item) → default A (add to TODOS.md). Build inline (C) only when the item is a *test gap* or a *regression test*, both non-negotiable per eng-review preferences.
- Round-1 review gate → "Address must-fix now (auto-push enabled)".
- Round-2 review with new must-fix → "Dump to TODOS.md and stop" (the cap is the point; human takes over).

## Hard safety rules

- **Never push to default branch.** If `HEAD == default`, derive `auto-do/<slug>` and `git checkout -b` before touching files.
- **Never `--force`, `--force-with-lease`, or `--no-verify`.**
- **Never merge the PR.** Even on a clean review.
- **Bail loudly on irrecoverable state.** Dirty working tree, missing `gh`, unresolved conflicts, failed test mid-implementation → stop.
- **Stop after round 2.** No round 3 — inherit `/review-pr`'s hard cap.
- **Stop on complexity smell.** If eng-review's scope challenge concludes the plan triggers the smell (>8 files or 2+ new services/classes), stop after eng review. Auto-do is for executable plans, not for re-planning.

## Skill body — what `commands/auto-do.md` will contain

Frontmatter:
```yaml
---
description: Autonomous task runner — plan → eng review (+ design review and /browse verification where required) → implement → PR → review-pr, no prompts. Stops before merge.
argument-hint: <task description>
---
```

Numbered steps:

1. **Pre-flight.** Repo check, dirty-tree check, default-branch detection, `gh auth status`, derive slug, branch off as `auto-do/<slug>` if currently on default. Bail on any failure.
2. **Plan.** Follow `commands/plan.md` autonomously. Persist to `docs/plans/<slug>.md` if `docs/plans/` exists; otherwise hold in conversation. Auto-link `docs/research/*` matches.
3. **Detect design scope.** Heuristic on `$ARGUMENTS` keywords (ui, screen, page, view, modal, button, form, layout, dashboard, theme, mobile, responsive, frontend, component, design, css, style) AND on the plan's affected file paths (`src/components`, `app/`, `pages/`, `templates/`, `views/`, `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.css`, `*.scss`).
4. **Design review (conditional).** If UI scope: follow `commands/plan-design-review.md` with auto-decisions (every dimension below 8 → "add the missing spec to the plan"; skip the variants step; skip Codex outside voice — eng-review's outside voice is sufficient).
5. **Eng review.** Follow `commands/plan-eng-review.md` with auto-decisions. Run Codex outside voice (it's the cross-model second opinion the workshop already invests in). Stop after this step if the complexity smell triggers.
6. **Solution doc — decided.** Equivalent of `/solution <slug>` at the `decided` stage. If `docs/solutions/` is missing, skip — and log the skip explicitly to the auto-decision log per the auditability rule (no silent skips).
7. **Implement.** Edit files per the (now-reviewed) plan. Stage and commit in logical chunks (`auto-do(<slug>): <imperative>`). Run the project's test command if detectable (`npm test`, `pnpm test`, `pytest`, `cargo test`, project Makefile). On test failure: stop. Regression tests added during step 5 are non-negotiable.
8. **Solution doc — in-progress.** Append `## In progress` with branch name, commit range, what was actually built. Update frontmatter `status: in-progress`, add `started`.
9. **UI verification via /browse (conditional).** If UI scope was detected AND `<repo>/.claude/browse/storage-state.json` exists (or the target URL is unauthenticated): follow `commands/browse.md` autonomously to drive the changed UI. Capture screenshots, write the session note. If storage state is missing on a non-localhost target: skip and note in the PR body — `/auto-do` does not run `/browse --setup` itself because setup is interactive.
10. **Push and create PR.** `git push origin HEAD:refs/heads/<branch>`, then `gh pr create` with a body that includes:
    - Heading `## auto-do output — review before merge`.
    - Links to plan, solution, and (if run) browse session note.
    - The full **Auto-decision log** (every prompt the underlying skills would have raised, and how `/auto-do` answered).
    - Eng review's `## Engineering Review` block (and design review's, if it ran).
11. **Review the PR.** Follow `commands/review-pr.md` with auto-decisions: round-1 gate → "Address must-fix now"; round-2 with must-fix → "Dump to TODOS.md and stop". The PR-comment posting per round (added in PR #16) gives the audit trail.
12. **Final report.** One block summarising task, branch, plan/solution paths, design+eng review counts, browse session (ran/skipped/why), commits, PR URL, review rounds, and the auto-decisions reference in the PR body. End with: "Human reviews PR. /auto-do does not merge."

## Critical files

- **New:** `commands/auto-do.md` — the skill body sketched above.
- **Modify:** `README.md` — add `/auto-do` to the **Skills shipped** table; add a "Want autonomous mode for a known-shape task?" entry to **Where to go next**.
- **Modify:** `CHANGELOG.md` — entry under `[Unreleased]`.

No new agents. No `install.sh` change (it auto-picks up `commands/*.md`).

## Auto-decision log structure (required in PR body)

Every auto-pick that would normally have been a user prompt is logged in the PR body:

- Plan approval — auto-approved.
- Slug — derived from task description.
- Design review — ran / skipped (with reason).
- Per dimension below 8 (design review) — patched in plan / deferred.
- Eng review per issue — recommended option taken / safer-side default (with one-line rationale).
- TODO triage — A (TODOS.md) / C (built inline because regression test).
- Browse verification — ran / skipped (with reason: no UI scope / no storage state for auth-gated host).
- Round-1 review gate — addressed must-fix now.
- Round-2 outcome — clean / dumped to TODOS.md.

Auditing is the price of autonomy. The log is what makes `/auto-do` reviewable rather than mysterious.

## Out of scope (intentional)

- Auto-merging the PR.
- `--force`-pushing or skipping hooks.
- Watching for new pushes / re-running on every commit.
- Re-planning when eng review surfaces architectural gaps — that's a human decision.
- Multi-PR sequencing for very large tasks — break the task up first, then `/auto-do` per piece.
- Running `/browse --setup` mid-flow — setup is interactive by nature; `/auto-do` notes the gap and continues.

## Verification

1. After `commands/auto-do.md` lands, run `bash install.sh --user` and confirm `~/.claude/commands/auto-do.md` is copied.
2. In a project with `docs/plans/` and `docs/solutions/` present (i.e. `/init-workshop` has been run) and `gh` authenticated, invoke `/auto-do <small task>` on a clean branch off `main`.
3. Confirm: a plan is drafted, the eng review runs (with Codex outside voice if `codex` is on PATH), the solution doc is written, the change is implemented and committed, a PR is created, and `/review-pr` runs against it. **Confirm the PR is not merged at the end.**
4. Confirm the PR body contains the Auto-decision log with every default that would have been a prompt.
5. Repeat with a UI-scoped task in a project that has Playwright MCP configured and `.claude/browse/storage-state.json` present → confirm a `/browse` session note lands at `docs/research/interviews/<slug>.md` and is referenced from the PR body.
6. Repeat with a UI-scoped task but *no* storage state → confirm `/auto-do` skips the browse pass and notes the gap in the PR body.
7. Repeat with a task that trips the complexity smell (>8 files) → confirm `/auto-do` stops after eng review with a clear message.
8. Repeat with a dirty working tree → confirm `/auto-do` bails in pre-flight.
9. Repeat with `HEAD` on `main` → confirm `/auto-do` creates `auto-do/<slug>` before touching files.

## Naming caveat

`/auto-do` does not collide with any known skill in `~/.claude/commands/` ecosystems the user has installed (gstack does not have an `/auto-do`). No rename guidance needed.

## Engineering Review — 2026-05-01 (auto-mode)

Run autonomously. Codex outside voice was dispatched and surfaced 17 findings. Consolidated below by disposition.

### NOT in scope

- Promoting `/auto-do` from a markdown skill to a deterministic runtime — Codex pushed for "make it real code or fail closed". The workshop's whole installation model is markdown-only; switching to code would break `install.sh` for one skill. The plan keeps it markdown and tightens the language around what "orchestrate" means.
- Distinguishing pre-existing test failure from regression — Codex flagged this as crude. The simpler fit is to assume the user invoked `/auto-do` from a clean working tree on a passing default branch; if tests fail mid-flow, stop and surface, don't try to be clever about cause attribution.
- Running design review's variants generation and Codex outside voice — Codex argued these are exactly the path that matters most for UI work. Auto-mode skips them deliberately to keep LLM cost bounded; the user can always run `/plan-design-review` interactively. Logged as an explicit auto-decision in the skill's policy section.
- Detecting the project's GitHub workflow flavour (CLI vs. app) — Codex flagged `gh pr create` as a dependency assumption. The workshop's optional-integrations table already documents `gh` as the supported path; no skill in this repo invents an alternative. Stays.

### Must fix in skill spec (folded into `commands/auto-do.md`)

1. **Reframe `/browse` verification — storage-state existence ≠ valid auth.** A file at `<repo>/.claude/browse/storage-state.json` could be expired or stale. The skill body must note: existence enables a *best-effort* verification pass; if the browse session detects a login redirect, log `browse: storage state expired — verification skipped` to the auto-decision log and continue. Don't bail.
2. **UI re-detection from the actual diff after implementation.** Initial detection (keyword + plan-affected paths) is brittle. After step 7 (implement) and before step 9 (browse), re-run the heuristic against the *actual* diff (`git diff main..HEAD --name-only`). If the implemented diff drops UI files, skip browse even if step 3 detected UI scope. If the implemented diff adds UI files step 3 missed, run browse anyway. Either way, log the discrepancy.
3. **Eng-review triage wording — must-fix items get fixed inline, not TODO'd.** The plan said "default A (TODOS.md)" without disambiguating severity. Tighten: must-fix → take the recommended fix option (which the eng-review skill already uses for "fix it inline"); should-fix → A (TODOS.md); follow-up → A (TODOS.md). Test gaps and regression tests stay non-negotiable C (build inline).
4. **Round 2 unsafe-stop behaviour.** The plan's "Dump to TODOS.md and stop" leaves an open PR with known blocking issues, which is the wrong end state. Tighten: when round 2 surfaces new must-fix items, `/auto-do` (a) posts the findings as a PR comment per the new `/review-pr` flow, (b) marks the PR as **draft** via `gh pr ready --undo`, (c) appends a blocking-status note to the PR body ("auto-do stopped at round 2 with N must-fix items — see review comment"), (d) writes the items to TODOS.md, (e) stops. Final status is explicitly a failed run, not silent.
5. **Test sequencing — run tests before push, not just before commit.** Per-commit tests are useful but auto-mode's "logical chunks" can interleave green and red commits. Tighten: at the end of step 7, run the project's full detected test command once. Bail on failure (don't push). Per-commit tests during step 7 are a soft check; the pre-push run is the authoritative gate.
6. **Branch naming hardening.** Specify: slug → kebab, max 60 chars (leaving headroom under git's 250-char remote-ref limit and most CI display limits), invalid char rejection per `commands/research.md`'s rules, collision suffix `-2` / `-3` if `auto-do/<slug>` already exists locally OR on the remote (`git ls-remote --heads origin auto-do/<slug>`).
7. **Log every skip explicitly to the auto-decision log.** "Skip silently if `docs/solutions/` is missing" conflicts with auditability. Skip behaviour stays (no `mkdir`-then-write speculation) but every skipped step gets a one-line entry: `solution-doc: skipped — docs/solutions/ not present`.
8. **Reword "follow X.md autonomously" to make the markdown-orchestration concrete.** A markdown skill cannot truly *call* another skill. The skill body must say: "Read `commands/<skill>.md` at the start of this step. Apply the auto-decision policy at every gate the skill body specifies. The dispatched LLM calls (Codex, pr-reviewer, etc.) run as the underlying skill describes." This makes the dependency on the underlying skills' shape explicit.
9. **Disclaim "no prompts" in the skill description.** Auto-mode means no prompts *from `/auto-do`*; external blockers (`gh auth`, MCP availability, dev-server reachability for `/browse`, signing hooks) still require a working environment. Frontmatter description tightened.

### Should fix in skill spec

- **Tighten the research auto-link policy.** Plan says "auto-link `docs/research/*` matches" without bounding noise. Tighten: only link files whose slug shares ≥2 non-stopword tokens with the task. Links go in the plan file's See-also section, not in the PR body.
- **PR #16 dependency cited concretely.** Codex flagged "PR #16 shipped /browse" + "PR #16 added review-pr-comment-posting" as suspicious. Verified via `git log origin/main`: PR #16 contains both `1ae1217` (add /browse) and `878e25b` (review-pr comment posting). Plan now cites both commit SHAs.

### Test gaps and regression risk

`/auto-do` is net-new — no existing behaviour to regress. The verification list in the plan covers happy-path, UI-with-creds, UI-without-creds, complexity smell, dirty tree, default-branch checkout. Add one more verification: confirm the Auto-decision log appears in the PR body (item 4 of the plan's verification list already implies this — make it explicit).

### Failure modes

| Failure | Test? | Error handling? | User sees? |
|---|---|---|---|
| Dirty working tree at invocation | Verification step 8 | Yes — pre-flight bail | "auto-do refuses to start with a dirty working tree." |
| `gh` not authenticated | Manual | Yes — pre-flight bail | "auto-do needs `gh auth status` to pass." |
| HEAD on default branch | Verification step 9 | Yes — pre-flight creates `auto-do/<slug>` | One-line note in the report |
| Test command fails mid-flow | Manual | Yes — step 7 stop | Last test output surfaced; commits intact, no push |
| Plan trips complexity smell | Verification step 7 | Yes — step 5 stop | Reasoning printed; no PR created |
| Storage state expired during /browse | Manual | Yes — log to auto-decision log, continue | Logged-out screenshots in the session note |
| Round 2 surfaces must-fix | Manual | Yes — PR marked draft, blocking comment, TODOs | Failed-run report; PR is draft, not merged |
| Branch name collision | Manual | Yes — suffix -2/-3 | Branch name in report |

No critical-gap failures (no-test-AND-no-handling-AND-silent).

### TODOs (logged as follow-ups)

- **Eventual smoke-test fixture for `/auto-do`** — running it against a public template repo with a known small task would catch regressions in the orchestration layer when underlying skills change. Cost: M. Value: medium.
- **Per-commit test soft-check + pre-push hard-check** — the current must-fix #5 simplifies to "test once at the end". A future iteration could add a fast per-commit lint / type-check while keeping the full test run as the pre-push gate.
- **Re-think eng review TODO triage policy if real runs accumulate too many TODOs.** Default A (TODOS.md) for should-fix is conservative — if /auto-do runs in practice produce TODOs faster than they're cleared, revisit and consider C (build inline) for some categories.

### Completion summary

```
Step 0 — Scope:        accepted as-is (1 skill, 0 new services, lean markdown orchestrator)
Architecture:          1 issue (storage-state-as-auth-proof), patched in skill spec
Code quality:          1 issue ("orchestrate" wording too loose), patched
Tests:                 4 issues (UI re-detect, triage wording, round 2 stop, test sequencing), patched
Performance:           N/A — markdown skill; LLM cost bounded by underlying skills
Outside voice:         ran (Codex), 17 findings consolidated
NOT in scope:          written above
Failure modes:         8 listed, 0 critical gaps
TODOs:                 3 logged as follow-ups
Unresolved:            none
```
