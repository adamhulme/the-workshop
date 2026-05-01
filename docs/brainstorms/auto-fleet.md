---
date: 2026-05-01
slug: auto-fleet
topic: /auto-fleet — autonomous mode for tasks too large for a single /auto-do PR
research: []
---

> **Ungrounded.** No research files exist in `docs/research/` yet. This brainstorm is seeded from the just-shipped `/auto-do` work (`docs/solutions/auto-do.md`, `docs/plans/auto-do.md`) which is the direct antecedent — fleet is a generalisation of single-task auto mode to N subtasks.

## User

- The use case is a task that genuinely doesn't fit one PR — "convert all internal API routes to v2", "add telemetry to every public skill", "rename `Foo` across 40 packages with non-mechanical adjustments". The user wants to walk away and come back to N reviewable PRs landed in coherent shape.
- The end user is someone already comfortable with `/auto-do` for one task. Going from 1 → N changes the trust budget hugely; they have to read N PRs, not just one.
- Slicing is the hard part. If the user pre-slices, fleet is "loop with persistence" — useful but unambitious. If fleet auto-slices, trust shifts onto the LLM finding PR-sized chunks, which is the whole hard problem.
- Review burden inverts. `/auto-do` creates one PR-sized review; `/auto-fleet` creates N. Without dedup of findings across PRs (e.g. "the same lint issue across 8 PRs"), the human reviewer drowns.
- The trigger: parallelisation while the user is offline. But "parallel" only helps if chunks are independent; most large tasks have shared infra changes that must land first, which forces sequencing.
- A new user surface emerges: fleet mode is the closest the workshop gets to "AI does the engineering ticket". That changes who's tempted to run it (PMs, designers) — currently `/auto-do` trusts the user to read the diff; fleet might be invoked by people who can't.

## Ops

- N parallel `/auto-do` runs = N branches, N PRs, N CI runs. Cost scales linearly with N; the team's CI minutes might not be welcome.
- Coordination layer: someone tracks fleet state. `/auto-do` is stateless markdown. Fleet needs durable state (subtask manifest with status: queued / running / done / failed / blocked).
- `gh` API rate limits matter at N > ~5 in one account — rapid PR creation, comment posting, and draft conversions all chew the same budget. `/auto-do`'s round-2 GraphQL fallback path multiplies under fleet load.
- Branch graveyard: failed fleet runs leave open draft PRs. Cleanup story matters more than for single `/auto-do` (one failed PR is fine; eight is noise).
- Dispatch model: **serial** (one `/auto-do` at a time, trivial to resume, deterministic) vs **parallel** (faster, harder to coordinate, file-edit collisions if subtasks overlap). Parallel needs concurrency control or non-overlapping subtask scoping.
- Observability: a fleet run needs a glanceable summary — `docs/fleet/<slug>.md` or similar — listing subtask state, PRs, blockers. Per-task PR comments don't scale to "what's the whole fleet doing?".
- Branching strategy is a real fork: **epic branch** (N feature branches off it; PRs target epic; one merge-train at the end) vs **N independent branches off `main`** (each PR targets `main`; main churns more). Each has real costs — pick one and stick with it per fleet run.

## Scope

- **v0.1 — serial loop.** User pre-slices into N subtask descriptions in a manifest file. `/auto-fleet` runs `/auto-do` N times sequentially. No parallelism, no auto-slicing, no dependency graph. Pause on first must-fix. Resumable.
- **v1 — parallel with declared deps.** User declares subtask dependencies; fleet schedules respecting them. Concurrency cap (default 3) on parallel branches. Still no auto-slicing.
- **v2 — auto-slicing.** Fleet reads the task description, runs `/plan` on it, breaks into PR-sized chunks via file-count / surface-area heuristics. Most contentious step; defer.
- **Cut hardest.** Auto-slicing (v2) — keep it user-driven. The cost of a bad slice is N×`/auto-do` runs in the wrong shape.
- **Cut second-hardest.** Parallelism. A serial fleet with manifest persistence is ~80% of the value with ~20% of the coordination complexity.
- **Smallest viable thing.** A manifest file (`docs/fleet/<slug>.yaml` or `.md` table) listing subtasks; a runner that picks the next `queued` entry, dispatches `/auto-do` with that description, marks it `done` / `failed`, moves on. Honour the same hard rules as `/auto-do` (never merge, never force-push, never bypass hooks). Stop loudly on first round-2 failure.
- **Out of scope.** Fleet-level integration testing across all N PRs (separate problem). Auto-merge of any PR (still a human gate). Dependency auto-detection.

## Risk

- **Blast radius.** N PRs created back-to-back could spam reviewers. Per-task review is fine; fleet PRs need a "fleet header" linking back to a parent fleet doc so reviewers see scope at a glance.
- **Failure cascading.** If subtask 3 introduces a subtle bug that subtasks 4–10 build on, the fleet has polluted 8 PRs, not 1. Default-pause on first must-fix mitigates; default-continue does not.
- **Hard to reverse.** Eight PRs all merging on green CI but breaking together at integration. Fleet-level integration testing is its own rabbit hole; without it, "all green individually" can still ship a broken main.
- **Race conditions in parallel mode.** Two fleet members editing the same file would collide via merge conflicts. Concurrency cap + non-overlapping scopes (declared up front) is the only sane v1; auto-detected file-overlap blocks are v2 territory.
- **Cost runaway.** A misconfigured fleet burns budget faster than any other workshop tool. Need a hard cap — `--max-tasks` and a budget gate before dispatch (e.g. "this fleet will create 12 PRs and run ~36 reviews — proceed?"). Confirm via `AskUserQuestion` even in auto mode, since this is the largest single decision the workshop ever makes.
- **Trust collapse.** One bad `/auto-do` is annoying. Ten bad ones in a row would break the user's trust in the whole compounding loop. The default has to be: pause the fleet on the first round-2 failure, not push through.
- **Unknowns.** How `/auto-do` behaves when the working tree is in a state created by an unrelated subtask that just merged. Whether `/review-pr`'s round-comment posting survives at fleet scale. Whether storage-state for `/browse` survives N runs without re-auth.
- **Skill drift compounded.** `/auto-do`'s known watch-list ("if the underlying skills restructure their `AskUserQuestion` gates, /auto-do's overrides need updating") becomes N times worse — fleet calls `/auto-do` which calls all the others. One brittle gate breaks every subtask.

## Tensions

- **User wants parallelism for speed; Ops wants serialism for predictability.** Resolving: ship serial-only in v0.1, add parallel with a low concurrency cap (≤3) in v1. Don't try to satisfy both on day one.
- **User probably expects auto-slicing from "fleet"; Risk wants user-driven slicing.** The word "fleet" implies dispatch, not slicing. Resolving: explicitly scope `/auto-fleet` as a *dispatcher*, not a *planner*. The user (or `/plan`) produces the manifest; `/auto-fleet` runs it. Auto-slicing is a separate skill (`/auto-slice`?) — don't bundle.
- **User wants one merge event for the whole fleet; Ops wants per-task review (smaller, safer merges).** Resolving: pick a branching strategy per fleet via `AskUserQuestion` at start (epic branch with stacked PRs vs independent PRs to main). Don't pretend there's one right answer.
- **User wants high N (20+ parallel for huge refactors); Ops/CI wants low N (≤3 to stay sane).** Resolving: hard cap at 3 in v1; raise only with explicit `--max-parallel` flag and a separate budget gate.
- **Scope wants v0.1 = serial loop with manifest; the user might read "fleet" and expect something more ambitious.** Resolving: be honest in the README and skill body — "v0.1 is a sequential dispatcher. It is not a planner, not a parallelism engine, and not auto-merging." Manage expectations early so the first real run doesn't disappoint.
- **Markdown-only constraint vs durable fleet state.** A manifest with mutable status fields wants to be a database row, not a markdown file. Resolving: lean markdown anyway — the fleet manifest is just a markdown table the runner rewrites in place. Same compromise the rest of the workshop already lives with. If it bites at N > 50, revisit; until then, ergonomics beats correctness.
- **Pause-on-first-must-fix (safe) vs continue-and-collect-failures (productive).** The default has to be pause — trust collapse from cascading failures is worse than slow fleet runs. A `--keep-going` flag can exist for users who actively want the productive mode, but it's opt-in.
