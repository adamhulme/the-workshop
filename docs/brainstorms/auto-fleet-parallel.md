---
date: 2026-05-04
slug: auto-fleet-parallel
topic: /auto-fleet v1 — true parallelism via git worktrees + Agent dispatch + declared dependencies
research: [docs/brainstorms/auto-fleet.md, docs/plans/auto-fleet.md, docs/solutions/auto-fleet.md]
---

> **Grounded in v0.1's compounding-loop trail.** The strategy-level brainstorm at `docs/brainstorms/auto-fleet.md` set v1 = "parallel with declared deps, concurrency cap default 3, no auto-slicing." This brainstorm is one level deeper: how do we *actually* achieve parallelism in an LLM-runtime markdown skill that has to coordinate N concurrent `/auto-do` invocations against a shared git repo?

## User

- **Wants 3× speedup on independent subtasks.** "Add request-logging to /users, /orders, /products routes" should finish in ~10 minutes wall-clock with three parallel `/auto-do`s, not 30 minutes serial.
- **Authors deps to express the actual task structure.** "Add Postgres extension, then migrate users table, then backfill orders" — a serial chain expressed in the manifest, no parallelism but no spurious failures from out-of-order dispatch.
- **Mixed parallel + serial within one fleet** is the most common shape: an infra-prep row that everything depends on, then K independent rows fanning out. v1 must support both shapes without forcing the user to split into multiple fleets.
- **Doesn't want to learn worktree mechanics.** "It just runs in parallel" is the contract; the worktrees-on-disk mechanism is implementation detail.
- **Wants the same observability as v0.1** — single fleet outcome at end, every PR linked from the manifest, every auto-decision logged.
- **Failure cascade must be obvious.** "Row 4 was skipped because row 2 failed" — the manifest has to make this readable, not just `blocked` with no explanation.
- **Trust budget tightens with concurrency.** Three parallel `/auto-do`s burning cost simultaneously is a bigger commitment than one serial dispatch. The confirmation gate at fleet start has to land harder.

## Ops

- **Git worktrees pollute the repo.** `.claude/auto-fleet/wt-<id>/` lives in the working tree (or close to it). On crash, orphan worktrees stay until `git worktree prune` or manual removal. Pre-flight detection + `--cleanup` flag matters.
- **`gh` API rate limit at 3× concurrency.** Three parallel `/auto-do`s each making ~5–10 `gh` calls (PR create, draft toggle, comment post, review-pr inline reads) means ~30 gh calls per wave. Secondary rate limit kicks in at 10/minute for some endpoints. Throttling? Or detect + back off?
- **CI burn.** Each subtask creates a PR with CI runs; three PRs land near-simultaneously on default branch and trigger three CI runs. Whoever pays for CI minutes notices.
- **Per-row branch creation parallelism is fine** — different ref names, no conflict at remote level.
- **Manifest-on-fleet-branch coordination is single-writer** — only main thread writes the manifest at step 8. Sub-agents only read their assigned row description. No locking needed.
- **Cleanup order matters.** Worktree → branch → manifest commit. If main thread crashes before cleanup, `git worktree list` shows orphans; `update.sh`-style mechanism could detect at next invocation.
- **Subagent context isolation.** Each parallel `/auto-do` runs as a `general-purpose` Agent — separate context, separate token budget. Their findings come back to main as text. No cross-pollination of state, which is good for correctness and bad for shared-context efficiency.

## Scope

- **Smallest viable v1.** Worktrees + serial-within-wave parallelism (run K rows at once, wait for all K, then next wave). No incremental scheduling (slot frees → dispatch next ready row). Wave-based is simpler; incremental is faster; default to wave for v1.
- **DAG depth.** Multi-parent `depends_on` (comma-separated row ids) is enough for the realistic shapes. Don't ship full DAG-edge syntax (`needs:` / `provides:` etc) — that's overengineered.
- **`--max-parallel=N` flag.** Default 3 (matches the brainstorm). Hard ceiling 5. The cap is the point — protects against cost runaway.
- **Hard cap on N rows.** v0.1 was 5; with parallelism + deps making higher N more useful, raise to 10 (still well under what real fleet runners do). Frame as a v1 guard rail; revisit at v1.5.
- **File-overlap detection: not in v1.** User responsibility. Document as v1.5+ feature. (Two parallel rows touching the same file would conflict at PR review time anyway; not /auto-fleet's job to detect.)
- **Worktree lifecycle: tied to row.** Created when row dispatched, removed when row reaches terminal state. Worktree path is `.claude/auto-fleet/wt-<slug>-<id>/` (slug + id makes it unique even if multiple fleets run in parallel — though v1 doesn't support that).
- **New row state: `blocked`.** Set when a `depends_on` parent failed (transitively). The fleet doesn't dispatch blocked rows; they appear as `blocked` in the final manifest with a "blocked by: <id>" annotation in the Fleet outcome section.
- **Cascade behavior.** When row A fails, all rows with `A` in `depends_on` (transitively) become `blocked`. Other rows continue (parallel branches don't fail-fast across the fleet — only along the failed dep tree).
- **Out of scope.** Auto-slicing (still v2+). Epic branching (still v2+). `--keep-going` flag (cascade-block IS the productive-mode escape hatch — don't need a flag). Cross-PR review-finding dedup. File-overlap detection. Dynamic per-slot scheduling (wave-based only in v1).

## Risk

- **Orphan worktrees on crash.** A `/auto-fleet` process crash mid-wave leaves K worktrees on disk. Pre-flight should detect + offer cleanup (`AskUserQuestion`: clean up N orphan worktrees?). Worst case, manual `git worktree remove --force` + delete the dir.
- **Race in `gh pr create`.** Three concurrent calls to `gh pr create` could hit secondary rate limit. Throttling within main thread: stagger Agent dispatches by 5s? Or detect 403 + retry with backoff? v1 keeps it simple — dispatch at once, surface the rate-limit failure as `failed:rate-limit` row state if it happens, treat as a `failed` row (cascade-block dependents).
- **Cost runaway.** 3× `/auto-do` running simultaneously = 3× LLM cost burning. Plus the parent /auto-fleet's coordination context. Plus 3× CI minutes. Budget-gate at fleet start fires harder; the confirmation prompt must surface the parallelism factor explicitly.
- **Partial-failure complexity.** With deps + cascade-block, the user has to mentally reason about "row 4 blocked, row 5 parallel-tree-untouched, row 6 succeeded, row 7 failed." Final fleet outcome must surface all four states clearly with the cascade chain ("blocked by row 2").
- **Worktree storage state.** `/browse`'s `storage-state.json` lives at `.claude/browse/storage-state.json` — relative to the repo root, NOT inside a worktree. Two parallel `/auto-do`s both running `/browse` would share the same storage state file. Probably fine (Playwright reuses the same file), but worth flagging.
- **Cycle detection at parse.** `depends_on` chains can form cycles. Reject at step 2 with a clear error. Tarjan or Kahn or just BFS-from-each-node — any standard algorithm.
- **Subagent /auto-do context budget.** Each `/auto-do` agent runs ~10–30k tokens of context (skill bodies, plan, eng review, implementation). With 3 parallel, that's 90k tokens of dispatched context per wave. Manageable but worth knowing.
- **Skill drift compounded.** v0.1's known watch-list (auto-do internals changing breaks /auto-fleet's overrides) becomes worse — now Agent-dispatched /auto-dos run /auto-do without main-thread attention. If /auto-do's contract drifts, a parallel wave silently produces broken results. CI for the contract? Or at least a smoke fixture that runs /auto-fleet against a real /auto-do.
- **`--max-parallel` overcommit.** User passes `--max-parallel=5` on a 4-core machine running other things. Performance tanks. v1 doesn't detect or warn — out of scope; document.

## Tensions

- **Wave-based scheduling vs incremental.** Wave is simpler (dispatch all ready rows in current wave, wait for all to finish, then next wave). Incremental is more parallel (when slot K frees, dispatch the next ready row immediately). Wave is the v1 default; incremental is v1.5 if real usage shows wave is too slow on long-tailed waves.
- **`depends_on` as comma-separated string vs YAML list.** String is simpler in a markdown table cell. List requires YAML serialization in the cell, which fights table parsing. Pick string.
- **Failure cascade default vs `--keep-going`.** v0.1 was strict halt-on-first-failure; v1 with deps changes the default. Cascade-block (mark dependents blocked, continue with parallel-tree rows) IS the productive-mode behavior — no `--keep-going` flag needed.
- **Worktree path inside `.claude/` vs separate dir.** `.claude/auto-fleet/wt-*/` keeps worktrees out of `docs/` and `commands/`. They're already gitignored if `.claude/` is gitignored. But putting them inside `.claude/` blurs the line between "agent state" and "git worktree" — probably fine, but worth noting.
- **Hard cap on N raise from 5 to 10 vs stay at 5.** Higher N is the whole point of v1; otherwise why parallelize? But cap protects against cost runaway. 10 is a reasonable middle ground; the budget gate at fleet start surfaces the actual cost.
- **DAG depth in v1 vs single-parent only.** Multi-parent (comma-separated depends_on) is barely more complex than single-parent. Ship multi-parent.
- **Dispatch-staggering vs all-at-once.** Stagger dispatches by 5s to avoid `gh pr create` rate limit spike vs dispatch all at once and accept rate-limit failures. v1 dispatches all at once; rate-limit failures become row failures. Stagger is v1.5 if needed.
- **Branch coordination across parallel /auto-do runs.** Each `/auto-do` creates `auto-do/<id>` off `<default>`. Two parallel agents both branch from `<default>`'s current SHA — fine, no conflict. Each pushes to its own remote ref — fine. PR creation parallel — fine, with rate-limit caveat. The serial bottleneck is when a row's PR merges to default mid-fleet (it doesn't — /auto-fleet never auto-merges). So default branch is stable for the fleet's lifetime; safe.
