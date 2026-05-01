---
status: outcome
date: 2026-05-01
started: 2026-05-01
shipped: 2026-05-01
slug: auto-do
---

## Problem

The workshop's skills are deliberately interactive — `/plan` asks for approval, `/plan-eng-review` walks one issue at a time, `/review-pr` gates on a single user choice. That's the right default when the user is at the keyboard. But there's a real second mode: a known-shape task the user wants run through the entire pipeline (plan → review → implement → PR → review-pr) without sitting through every prompt.

Trigger from the user: "Add a /auto-do mode which runs through the sequence of necessary commands (inc. design and eng review where required) without any user interaction. Create and review a PR but do not merge it." A second clarification followed: "this auto mode probably also needs a way to browse the app, how do we implement that, including creds setup. I have a plan for this somewhere" — surfacing the headed-browser plan that became `/browse`, now shipped on `main` (PR #16). With `/browse` available, `/auto-do` can compose with it for UI verification.

## Options considered

1. **Meta-skill that orchestrates the existing skills with auto-decisions.** One markdown file at `commands/auto-do.md`. Reads `commands/<skill>.md` for each underlying skill and follows its steps inline, applying an auto-decision policy at every prompt. **Trade-off:** depends on the underlying skills staying stable in shape; if they restructure, `/auto-do`'s "follow them" instruction may drift. Mitigated by the workshop's mostly-stable skill conventions (numbered steps, `AskUserQuestion` gates).

2. **A separate runtime that reads skill files and executes them programmatically.** Ships a Node/Python launcher that parses skill files and feeds steps to the model with auto-decision overrides. **Trade-off:** breaks the "skills are markdown only" principle. Adds a runtime dependency. Materially expands `install.sh`. Wrong fit.

3. **Inline every underlying skill into `auto-do.md`.** No orchestration — copy-paste the relevant steps from `/plan`, `/plan-eng-review`, etc. into one self-contained skill. **Trade-off:** breaks DRY catastrophically. When `/plan-eng-review` changes, `/auto-do` doesn't. Two sources of truth for every step.

4. **Defer entirely.** Manual interactive flow stays the only mode. **Trade-off:** no — the user explicitly asked for autonomous mode, and there's a real use case (known-shape tasks the user wants run while away from the keyboard).

## Chosen approach

**Option 1.** Add `commands/auto-do.md` as a thin orchestrator. The skill body specifies:

- The auto-decision policy (recommended option taken; safer side on cross-model tension; TODO triage defaults to A for should-fix and follow-up, while must-fix items are fixed inline; round-1 review gate auto-takes "Address must-fix now"; round-2 with new must-fix takes the underlying skill's "Dump to TODOS.md and stop" and *layers* the safe-stop on top — commit the TODOS.md edit, push, convert the PR to draft via `gh pr ready --undo` or the API fallback, post a blocking PR comment, and append a `Final status: failed:round-2-must-fix` section to the PR body).
- A pre-flight that bails on dirty tree, missing `gh`, or being on the default branch (in which case it creates `auto-do/<slug>` and switches before touching files).
- A design-scope detector (keyword + file-path heuristic) that conditionally runs `/plan-design-review`.
- A test-failure stop — never commits broken tests.
- A complexity-smell stop after eng review — `/auto-do` is for executable plans, not for re-planning.
- A `/browse` verification pass when UI scope was touched AND `<repo>/.claude/browse/storage-state.json` exists (or the target is unauthenticated). Skips silently and notes the gap if no creds; never runs `/browse --setup` itself because setup is interactive by nature.
- A required Auto-decision log in the PR body — every prompt the underlying skills would have raised, plus how `/auto-do` answered. This is what makes the run reviewable.
- Hard rules: never push to default, never `--force` / `--no-verify`, never merge.

## Rationale

- **Markdown-only constraint preserved.** Same reason as `/browse` — the workshop's whole installation model is `cp commands/*.md`. Option 2 would have broken that.
- **DRY against the existing skills.** Option 3 would have created two sources of truth for every step in `/plan-eng-review` and `/review-pr`. When those skills change, `/auto-do` benefits automatically — that's the compounding loop working as intended.
- **The user's stated constraints map directly to a few opinionated defaults.** "No interaction" + "design and eng review where required" + "create and review a PR but don't merge" + "browse with creds setup" all reduce to: an orchestrator with a documented auto-decision policy, plus the conditional `/browse` step.
- **`/browse` shipping first was the right sequencing.** `/auto-do` couldn't compose with a non-existent skill. PR #16 unblocked this work.
- **The Auto-decision log is non-negotiable.** Auditing is the price of autonomy. Without it, a `/auto-do` run is mysterious — the user can't tell what taste calls were taken on their behalf.
- **The `/browse` step degrades to "skipped" when creds aren't set up.** Running `/browse --setup` mid-`auto-do` is impossible (it requires the user to manually log in via the browser). Noting the gap in the PR body lets the user run setup once and re-run `/auto-do` for full UI verification next time.

## Out of scope (intentional, restated from the plan)

- Auto-merging the PR.
- `--force`-pushing or skipping hooks.
- Watching for new pushes / re-running on every commit.
- Re-planning when eng review surfaces architectural gaps — that's a human decision.
- Multi-PR sequencing for very large tasks — break the task up first, then `/auto-do` per piece.
- Running `/browse --setup` mid-flow.

## In progress

**Branch:** `feat/auto-do` (off `main`)

**What's actually being built** (refines `## Chosen approach`):

- `commands/auto-do.md` — the orchestrator. 13 numbered steps plus an explicit Auto-decision policy section, How-it-orchestrates section (read each underlying skill's file at runtime, apply defaults inline), and an Auto-decision log structure that the PR body must include. Codex outside voice surfaced 17 findings during eng review; 9 must-fix and 2 should-fix items are folded into the skill body (auth-state-as-best-effort, UI re-detection from diff, eng-review triage wording, round-2 unsafe-stop replaced with draft + blocking comment + TODOs, pre-push test gate as authoritative, branch-name hardening, explicit skip-logging, "orchestrate" reframed as "read file and apply defaults", "no prompts" disclaimer).
- `docs/plans/auto-do.md` — the plan plus a full **Engineering Review — 2026-05-01 (auto-mode)** block. Includes failure-modes table, TODOs, and completion summary.
- `README.md` — `/auto-do` added to the **Skills shipped** table and the **Where to go next** bullets.
- `CHANGELOG.md` — entry under `[Unreleased]` describing the orchestration shape, the hard safety rules, and the round-2 draft-PR behaviour.

**Out of scope for this branch** (deferred per the eng review):

- Distinguishing pre-existing test failure from regression — assume green default branch on invocation.
- Switching the workshop to a code runtime — markdown-only stays.
- Running design-review variants and Codex outside voice during the design pass — auto-mode keeps LLM cost bounded; users wanting deeper coverage can run `/plan-design-review` interactively.

## Outcome

**PR:** [#18](https://github.com/adamhulme/the-workshop/pull/18) — merged in `cf68bef` on 2026-05-01.

**What shipped:**

- `commands/auto-do.md` — the orchestrator. 13 numbered steps; an Auto-decision policy section that maps every underlying-skill prompt to an opinionated default (recommended option taken; safer side on cross-model tension; eng-review must-fix → fix inline, should/follow-up → TODOS.md; design dimensions below 8 → patch in plan; round-1 review gate → "Address must-fix now"; round-2 with new must-fix → "Abort" the underlying skill and run /auto-do's safe-stop on top); a How-it-orchestrates section that resolves underlying skills from `.claude/commands/<skill>.md` (project) then `~/.claude/commands/<skill>.md` (user); and a 22-entry Auto-decision log structure that the PR body must include.
- `docs/plans/auto-do.md` — the plan plus the full **Engineering Review — 2026-05-01 (auto-mode)** block. Codex outside voice surfaced 17 findings; 9 must-fix and 2 should-fix folded into the skill body, 3 logged as follow-up TODOs.
- `README.md`, `CHANGELOG.md` — Skills shipped table, Where to go next bullets, [Unreleased] entry naming the orchestration shape, hard safety rules, and round-2 draft-PR behaviour.
- `TODOS.md` — gained a "## Review findings — 2026-05-01 (PR #18, /auto-do)" section with 4 follow-up items (branch suffix cap, slug timezone, PR #16 SHA-pin removal, manual verification harness).

**Plan-vs-reality drift:**

- Two rounds of `/review-pr` ran on the PR. Round 1 (Codex + pr-reviewer in parallel) surfaced **4 must-fix and 7 should-fix items** that the plan and skill spec missed: skill-path hardcoding (installed skills live at `~/.claude/commands/`, not `commands/`), branch-divergence check before reusing a non-default branch, the round-2 must-fix `AskUserQuestion` override, and the first-push gate override. The plan's eng-review section had been thorough on the *content* of `/auto-do` but missed these *integration* details with the underlying skills it orchestrates. All addressed inline in commit `79f0c58`.
- Round 2 (Codex re-review on the fix-up diff) surfaced **1 must-fix and 2 should-fix items**: the API fallback for converting a PR to draft was wrong (REST `PATCH /pulls` does not support `draft=true` — must use the GraphQL `convertPullRequestToDraft` mutation; the previous fallback would have silently 422'd, leaving a round-2-failed PR mergeable, which is the exact safety failure the safe-stop is supposed to prevent), the round-2 underlying-skill option choice was wrong ("Dump to TODOS.md and stop" duplicated /auto-do's own TODOS write — switched to "Abort"), and the branch-divergence escape command lacked an explicit `<default>` start-point. All addressed inline in commit `24c0580`. Hard cap held — no round 3.
- The post-merge solution-doc-advance pattern is now consistent with how `/browse` closed out: a small chore branch (`chore/auto-do-outcome`) with just the doc edit, kept off any feature branch.

**What to watch:**

- **Markdown orchestration drift.** `/auto-do` reads each underlying skill's file at runtime and applies an auto-decision policy. If `/plan`, `/plan-eng-review`, `/plan-design-review`, `/solution`, `/browse`, or `/review-pr` restructure their `AskUserQuestion` gates, `/auto-do`'s explicit overrides (round-1 gate, round-2 gate, first-push gate) need updating. The compounding-loop benefit is real — when those skills change shape the orchestrator inherits the new content for free — but the gate-override list is the brittle part. Worth a watch-list comment in the underlying skills, or a CI check that greps for unhandled `AskUserQuestion` invocations across the dispatched-from-/auto-do call paths.
- **First real run.** Verification was entirely manual in the plan. The first time a user actually runs `/auto-do "tiny task"` against a real project will surface integration issues no amount of skill-spec review catches — for example, whether the underlying skills' `AskUserQuestion` invocations actually come through cleanly in the orchestrated flow, whether the auto-decision log lands in the PR body intact, whether `gh pr ready --undo` works on the user's `gh` version. Logged as a follow-up TODO; worth scheduling a one-off agent in 2 weeks to do this run and report results.
- **`gh` version split.** The skill pre-flight requires `gh ≥ 2.40` for the `--undo` flag, with a GraphQL fallback path for older versions. Real users on locked-down `gh` installs may hit the fallback regularly. Watch issue reports for "convertPullRequestToDraft" failures.
- **Underlying skill changes.** The bundled `/review-pr` round-comment posting (PR #16) and `/auto-do`'s reliance on it are now both on `main`. Future changes to either need to consider the orchestration contract.

**Follow-ups in `TODOS.md`:**

- Branch-name suffix loop bound at `-99` (currently bounded; revisit if real usage hits the cap).
- Slug fallback timezone is documented as UTC; could be dropped if the collision-suffix path proves sufficient.
- PR #16 SHA-pin removed from the skill body during review; provenance now reads "added in PR #16".
- Manual verification fixture — running `/auto-do "tiny task"` against a public template repo to catch command-path drift and PR-body shape regressions.
