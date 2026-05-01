---
status: in-progress
date: 2026-05-01
started: 2026-05-01
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

- The auto-decision policy (recommended option taken; safer side on cross-model tension; TODO triage defaults to A; round-1 review gate auto-takes "Address must-fix now"; round-2 with new must-fix auto-takes "Dump to TODOS.md and stop").
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

**Next:** push, `gh pr create`, run `/review-pr` autonomously per `auto mode` — and stop before merge, including the new round-comment posting per round and the round-2 draft-PR safe-stop if any must-fix items remain.
