---
status: decided
date: 2026-05-01
slug: auto-fleet
---

## Problem

`/auto-do` (PR #18, merged 2026-05-01) ships single-task autonomous mode — chain `/plan` → eng/design review → implement → PR → `/review-pr` for one task. There's a real second use case it doesn't cover: a known-shape task that's too large for one PR. "Add request-logging to /users, /orders, /products routes." "Add telemetry to every public skill." "Convert N internal API endpoints to v2." The user wants to walk away and come back to N reviewable PRs in coherent shape.

Today the only way is manually chaining `/auto-do` invocations from a notebook of subtasks the user keeps in their head. There's no persistent state, no resumability after a crash, no fleet-level halt-on-failure, and no single record of what got dispatched. The compounding-loop benefit of the workshop falls off at multi-PR scope.

## Options considered

1. **Thin markdown dispatcher orchestrating `/auto-do` via a user-authored manifest.** Single skill file (`commands/auto-fleet.md`); manifest at `docs/fleet/<slug>.md`; serial loop dispatching `/auto-do` per row; status persisted in the manifest itself. Trade-off: markdown-as-state-machine is fragile; relies on `/auto-do` staying stable in shape. Same brittle coupling `/auto-do` already accepts for `/plan`, `/plan-eng-review`, `/review-pr`.

2. **Code-runtime fleet runner.** Ships a Node or Python launcher that parses manifests and dispatches `/auto-do` programmatically, with first-class hooks for retries, parallelism, dependency graphs. Trade-off: breaks the workshop's markdown-only installation principle (`cp commands/*.md`); adds a runtime dependency to `install.sh`; materially expands what users have to trust.

3. **Inline every underlying skill into `auto-fleet.md`.** No orchestration — copy-paste relevant steps from `/auto-do`, `/plan`, `/review-pr` etc. into one self-contained skill. Trade-off: catastrophic DRY violation; two sources of truth for every step. When `/auto-do` changes, `/auto-fleet` doesn't.

4. **Defer entirely.** No fleet skill. Document the manual chaining pattern in `/auto-do`'s README and let users loop in their head. Trade-off: no persistence, no observable state, no fleet-level halt — and the user explicitly asked for fleet mode in the brainstorm trigger ("`/auto-fleet` mode for large tasks").

## Chosen approach

**Option 1, with the simpler-v0.1 scope landed via Codex outside-voice review.**

v0.1 is a serial dispatcher: reads a user-authored manifest at `docs/fleet/<slug>.md`, runs `/auto-do` per row in queue order, halts on first failure, and writes a single commit at the end on a dedicated `fleet/<slug>` control-plane branch.

Non-negotiable v0.1 constraints (from `docs/plans/auto-fleet.md` post-eng-review and the round-1 fix on PR #21):

- **Hard cap = 5 subtasks** per run. No flag override. Framed as a v0.1 guard rail (mainstream fleet runners — multi-gitter, OpenRewrite, SWE-bench — have no cap or run hundreds), not a permanent design point.
- **Stop on first failure.** No `--keep-going` flag. Aligns with Argo / GHA matrix / Make / Bazel / Temporal child-workflow defaults.
- **Independent branching only.** Each subtask's `/auto-do` creates its own `auto-do/<row-id>` branch off the default branch and opens a PR targeting default. Epic-branch mode is deferred to v1.
- **Markdown-only.** No code ships. Manifest is a markdown table; an *agent-tooling* idiom unusual among mainstream fleet runners (which prefer YAML/JSON), kept deliberately so the manifest lives next to other workshop docs.
- **Control-plane branch (`fleet/<slug>`).** Holds only the manifest; never merged; resolves the "never push to default" vs "commit + push manifest" contradiction.
- **In-memory state during the dispatch loop; single disk write at fleet end.** Round-1 Codex review on PR #21 caught that writing `running` to disk before dispatching `/auto-do` would dirty the working tree and halt every subtask at its own pre-flight (P0). Fix: hold all row state in memory; write + commit + push **once** at step 8 after explicit `git checkout fleet/<slug>` (P1, branch-leak fix).
- **SHA-256 hash check on manifest.** Captured at fleet start; checked at each iteration's start AND once more at step 8 before writing. External edits halt cleanly with `Final status: halted:manifest-tampered` rather than silently clobbering user edits.
- **Idempotency check** before each dispatch — checks branch existence (local + remote) AND prior PR state via `gh pr list --head auto-do/<id> --state all`. Surfaces `Skip` *(Recommended)* / `Dispatch anyway` / `Cancel` via `AskUserQuestion`. Catches stale branches from closed/merged PRs as well as currently-running ones.
- **Outcome classification keyed off explicit strings.** `/auto-do`'s `Final status:` line strings (`succeeded`, `failed:round-2-must-fix`, `failed:test-gate`, `failed:complexity-smell`) drive the manifest row state. Anything unrecognised → `failed` with `Final status: halted:unrecognised-auto-do-report`.
- **State names follow industry convention.** `queued | running | succeeded | failed | skipped` matches Argo Workflows / Temporal / GitHub Actions; `succeeded` pairs with `failed` more cleanly than the original `done`.

`/auto-fleet` orchestrates `/auto-do` the same way `/auto-do` orchestrates `/plan` etc. — read `commands/auto-do.md` from `.claude/commands/` (project) or `~/.claude/commands/` (user), apply its numbered steps with its auto-decision policy. The brittle coupling is acknowledged in both the plan and the skill body.

## Rationale

- **Markdown-only constraint preserved.** Same reason as `/browse` and `/auto-do` — the workshop's whole installation model is `cp commands/*.md`. Option 2 would have broken that and introduced a runtime dependency to `install.sh` for one skill. Option 1 keeps the model intact even though Codex correctly pointed out (finding #1) that the LLM-as-runtime is itself a runtime; that's the trade-off the workshop already lives with.

- **DRY against the existing skills.** Option 3 would have created two sources of truth for every step in `/auto-do`. When `/auto-do` changes shape, `/auto-fleet` benefits automatically — that's the compounding loop working as intended. Option 1 inherits this directly.

- **Simpler-v0.1 wins on trust.** Codex's review surfaced 24 findings; the unifying recommendation (drop `--keep-going`, `--max-tasks`, epic branching, sibling PR cross-linking, per-transition pushes, stub manifest creation, auto-resumability) was accepted because:
  - Trust collapse from cascading bad PRs is the largest risk; default-pause is the only safe default. `--keep-going` is a v1 concern after real fleet usage builds confidence.
  - A 5-subtask hard cap is small enough that "break the task into multiple smaller fleets" is reasonable advice; users who want more haven't earned the right to ask yet (no real fleet usage data exists).
  - Independent-branching is the smallest decision space; epic-branch mode would force creation/target/update/conflict/topology questions that v0.1 doesn't need to answer.
  - Per-transition pushes create N pushes per fleet plus collide with `/auto-do`'s own commits. One commit per fleet run on a dedicated control-plane branch is dramatically simpler.

- **Dedicated control-plane branch.** Resolves the contradiction Codex flagged (#5): "never push to default" + "commit + push manifest update" only works if the manifest lives on a branch that isn't default. The `fleet/<slug>` branch holds only the manifest, is never merged, and is the durable record of the fleet run. Subtask branches are siblings off default, not stacked.

- **Hash check replaces "undefined behaviour."** Codex was right (#18) that "user is expected not to edit the manifest mid-run; if they do, behaviour is undefined" was silent data loss waiting to happen on an explicitly user-visible file. SHA-256 hash check halts cleanly with `halted:manifest-tampered` rather than clobbering. Cheap to implement; high integrity payoff.

- **Outcome classification keyed off `/auto-do`'s `Final status:` strings.** Codex flagged this as hand-wavy (#8); the resolution is to make it explicit and brittle on purpose — `/auto-do` already writes these strings, and they form a contract `/auto-fleet` can rely on. The alternative (LLM interprets the report) is strictly worse.

- **Sequencing.** `/auto-do` shipping first (PR #18) was the prerequisite. `/auto-fleet` couldn't compose with a non-existent skill. Same sequencing reason as `/browse` shipping before `/auto-do`.

- **Brainstorm tensions resolved cleanly.** The brainstorm landed seven explicit tensions (User wants parallelism; Ops wants serialism; etc.). The simpler-v0.1 scope resolves all seven by deferring to v1: serial only, no auto-slicing, default-pause, low N hard cap, dispatcher-not-planner. The plan and eng review carried that scoping forward without re-litigating.

- **Round-1 review (PR #21) caught two real bugs and confirmed the design against prior art.** The Codex GitHub bot found a P0 (writing `running` to disk before dispatching `/auto-do` dirties the working tree and breaks every subtask's pre-flight) and a P1 (no checkout-back to `fleet/<slug>` between iterations would leak control-plane writes onto subtask branches). The fix — hold all state in memory during the dispatch loop, single disk write + commit + push at step 8 — was independently validated by a survey of mainstream fleet runners (multi-gitter, OpenRewrite, jscodeshift, Argo Workflows, GitHub Actions matrix, SWE-bench harness). None persist mid-run state to the same artifact the sub-task reads from. Same survey drove three additional fold-ins: rename `done` → `succeeded` (Argo / Temporal / GHA convention), expand idempotency to include prior-PR check (catches stale branches from closed/merged PRs), and frame the hard cap of 5 as a v0.1 guard rail rather than a fundamental design decision. Full details in the plan's **Round-1 review** subsection.
