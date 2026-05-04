---
status: decided
date: 2026-05-04
slug: auto-fleet-parallel
---

## Problem

`/auto-fleet` v0.1 (PR #21, merged 2026-05-01) shipped as a serial dispatcher. The strategy-level brainstorm (`docs/brainstorms/auto-fleet.md`) had always set v1 = "parallel with declared deps, concurrency cap default 3, no auto-slicing" — the productivity story is that 3× speedup on independent subtasks is the actual reason fleets are useful at all. v0.1 was the smallest viable thing; v1 is what users actually want.

The hard implementation question: how does an LLM-runtime markdown skill achieve concurrent execution of N `/auto-do` instances against a shared git repo? Single working tree means single HEAD; two parallel `/auto-do`s checking out different branches collide. And declared dependencies between rows (so users can author "do A before B") need a scheduler that respects them, with a sane behaviour when parents fail.

## Options considered

1. **Wave-based parallelism via git worktrees + Agent dispatch.** Each ready row gets its own git worktree at `.claude/auto-fleet/wt-<slug>-<id>/` (detached HEAD on a pinned base SHA). `/auto-fleet` creates the worktree + the row's `auto-do/<id>` branch in main thread, then dispatches K parallel `Agent` tool calls (subagent_type: `general-purpose`), each running `/auto-do` inside its assigned worktree. Main thread schedules the next wave when all K return. Concurrency cap via `--max-parallel=N` (default 3, ceiling 5). Trade-off: substantial new infrastructure (worktree lifecycle, base-SHA pinning, sub-agent dispatch protocol, failure classification, cascade-block algorithm). Worktrees do not isolate `.git/refs` / `config.lock`; concurrency hazards exist and need to be managed.

2. **Pseudo-parallel — declared deps + smart serial scheduling.** Add `depends_on` column for ordering, but execute serially. Failure cascade-blocks dependents but doesn't fleet-halt; other branches proceed. Trade-off: no actual speedup; just smarter serial execution. Much smaller scope (~150 lines added vs ~600). Doesn't deliver the brainstorm's "parallel" promise.

3. **Pseudo-parallel — deps for documentation only.** `depends_on` column lands but `/auto-fleet` doesn't enforce ordering; just documents intent. Trade-off: cheapest implementation but barely different from v0.1.

4. **Defer entirely.** v0.1 stays the only mode. Trade-off: leaves the productivity story unfinished.

## Chosen approach

**Option 1 — wave-based parallelism via worktrees + Agent dispatch.**

Confirmed by user via `AskUserQuestion` after surfacing the scope choice. The brainstorm's stated v1 = "parallel + deps." Anything less doesn't deliver the value users actually want from a fleet runner.

The Codex outside-voice review on the plan (19 findings) reshaped substantial parts of the implementation but didn't change the choice between Options 1–4. Specifically:

- **`depends_on` reframed as dispatch-ordering only.** Codex flagged that under v1's independent-branching model, dependent rows don't see parent code (parents aren't merged when children dispatch). Deps remain useful for ordering (don't dispatch B until A done) and for trust-budget pacing, but the original "dashboard depends on routes" example was invalid. Replaced with a code-independent fan-out example (three dependency bumps + a changelog row). v2 with epic-branch mode will deliver real code-level deps.
- **Worktree creation pinned to a base SHA captured at fleet start.** `git worktree add --detach <path> <base-sha>` — not `<default>` as a branch reference. Two worktrees can't both check out `<default>` as a branch; detached-HEAD checkouts of the same SHA work fine.
- **`/auto-fleet` creates the row's `auto-do/<id>` branch inside the worktree** before dispatching `/auto-do`, instead of relying purely on prompt-overrides. `/auto-do`'s existing step 1 logic ("if rev-list 0 → reuse it") then works without modification. `/auto-do` itself stays unchanged.
- **Failure classification** introduced: `task` (the task itself failed quality), `infra` (rate limit / git lock / sub-agent timeout / worktree-create error — re-runnable), `protocol-violation` (the `RESULT:` line missing or unparseable from the sub-agent). Cascade-block applies to all classes; the user can re-author and re-run infra-classified rows without conflating with task quality.
- **Failed-row worktrees preserved on disk** for debugging, not force-removed.
- **`skipped` parents count as `succeeded` for scheduling** so dependents don't wait forever.
- **Per-row 60-minute timeout** — hung sub-agents become `failed:timeout` (failure_class: infra).
- **Backward compatible.** Manifests without a `depends_on` column run as v0.1 would (all rows independent). Existing v0.1 fleets are not broken.
- **Concurrency cap = 5 ceiling, default 3.** Stayed at brainstorm's defaults despite Codex pushing for 4 (to reserve headroom for main-thread coordination). Real-world cap test will tell us if 5 is too aggressive.
- **Hard cap on N rows raised from 5 → 10.** Parallelism makes higher N actually useful.
- **Markdown-only constraint preserved.** Codex's foundational critique (#20: "this much scheduler logic deserves a code runtime") was disagreed with — workshop principle stands. The LLM is the runtime; the markdown is the program. v1 is more complex than v0.1 under the same substrate.

## Rationale

- **Brainstorm's promise honoured.** The v0.1 → v1 → v2 ladder was always: serial → parallel + deps → auto-slicing. Cutting parallelism out of v1 (Option 2 or 3) would have broken the user's stated goal and the multi-week roadmap.
- **Wave-based scheduling beats incremental for v1.** Wave dispatches all ready rows up to the cap, waits for all to finish, then schedules the next wave. Simpler than per-slot scheduling (where slot-K-frees → dispatch-next-ready); deterministic; easier to reason about for crash recovery and the user-facing report. Long-tailed waves (one slow row blocking 4 fast ones) are a v1.5 concern.
- **Worktrees are the standard answer to parallel git ops on a single repo.** The git worktree manual explicitly recommends them for "multiple feature branches simultaneously." The hazards Codex flagged (`.git/refs` / `config.lock` contention) are real but well-trodden — existing CI matrix runners use this pattern. v1 mitigates by serialising the brittle ops (worktree create + branch create) in main thread before dispatching parallel agents.
- **Codex's "dispatch-ordering only" reframing is honest.** v1's independent-branching model genuinely cannot deliver code-level deps without merging parents. Pretending otherwise (the dashboard example) sets users up to fail. v1 ships with explicit warnings about what deps are good for and what they're not. Users with code-level dep needs split into multiple sequential `/auto-fleet` runs (with manual merges between) or wait for v2.
- **Failure classification matters because trust matters.** v0.1's halt-on-first-failure gave a clean trust story but made the fleet useless when any row failed. v1's cascade-block-but-continue lets the user salvage value from partial successes. Distinguishing infra failures from task failures lets the user re-run the rate-limit-failures without re-litigating the task quality of the whole row — significant for cost and trust.
- **Failed-row worktree preservation is a small behavioural cost for big debugging value.** v0.1 had nothing to debug — fleet halted, branches/PRs were the artifacts. v1's parallel cascading-failures world produces a richer set of partial states; preserving the worktree on `failed` rows lets the user `cd` in and inspect what `/auto-do` actually did. Successful rows' worktrees are removed normally (no value preserved).
- **Backward compat with v0.1 manifests is cheap.** Treating missing `depends_on` column as "all rows independent" means a v0.1 fleet runs unchanged under v1 — just with parallel dispatch if the cap is high enough. No migration step. Codex pushed for this and it's the right call.
- **Per-row timeout was the lowest-cost fix to a real risk.** A hung sub-agent freezing a wave forever is a real failure mode; 60 min is generous for `/auto-do` (which typically takes 5–30 min) but bounded enough to fail loudly. No flag in v1; can become configurable later.
- **The "markdown-only" disagreement with Codex is the same call as v0.1.** A code runtime would be cleaner for the scheduler logic, no question. But the workshop's installation model is `cp commands/*.md`; introducing a runtime is a much larger architectural shift. The LLM-as-runtime trade-off is the workshop's foundational bet; v1 doubles down on it. If real usage shows the bet was wrong, that's a workshop-wide pivot, not a v1 patch.
