---
status: approved
date: 2026-05-04
task: Ship /auto-fleet v1 — parallel dispatch via git worktrees + Agent-based /auto-do invocations + declared dependencies (depends_on column, dispatch-ordering only) + cascade-block on dep failure
branch: feat/auto-fleet-parallel
---

## Goal

Ship `/auto-fleet` v1 — true parallel dispatch over a user-authored manifest with declared dispatch-ordering dependencies. v0.1 was a serial dispatcher; v1 keeps the same shape (manifest at `docs/fleet/<slug>.md`, control-plane branch `fleet/<slug>`, `/auto-do` per row) and adds:

1. **`depends_on` column** in the manifest — comma-separated row ids declaring multi-parent **dispatch-ordering** dependencies. ⚠ See "What deps are not" below — they do **not** carry code from parent to child. v1's branching model is independent (subtask PRs target `<default>` independently); without merging parents, dependents don't see parent code.
2. **Wave-based parallel dispatch** — each wave runs all currently-ready rows up to a concurrency cap. Each row gets its own git worktree at `.claude/auto-fleet/wt-<slug>-<id>/` (detached HEAD pinned to a base SHA captured at fleet start). Each row's `/auto-do` runs as a `general-purpose` Agent inside its worktree.
3. **Cascade-block on dep failure** — when row A fails, every row whose `depends_on` chain reaches A becomes `blocked` (transitive). Other rows in unrelated parallel branches continue.
4. **`--max-parallel=N` flag** — concurrency cap. Default 3, ceiling 5.
5. **Hard cap on N rows raised from 5 → 10**.
6. **New row state `blocked`** added to the enum.

The brainstorm at `docs/brainstorms/auto-fleet-parallel.md` worked through the design tensions; this plan locks in the choices. The eng-review block at the end records the Codex outside-voice findings (19 items) and how each was folded.

### What deps are NOT (read this first)

`depends_on` in v1 is **dispatch-ordering only**. It does not:

- Carry parent code to child branches. v1's branching model creates each row's `auto-do/<id>` branch off `<default>` (or its pinned SHA) independently. If row B depends on row A and A's PR isn't merged, B starts from a tree without A's changes.
- Imply parent merges before child dispatches. v1 never auto-merges; the human gate stays.
- Detect file overlap between sibling rows. If A and B touch the same file, they collide at PR review time, not at dispatch time.

What it *does*: `/auto-fleet` won't dispatch B until A reaches `succeeded` (or is `skipped`). Useful when:

- B's task description references A's *concept* even though the *code* is independent (e.g. "add docs for the new endpoint A introduces" — even if B's branch starts from `<default>`, the user wants A to ship first).
- Reviewer-flow ordering matters (review A's PR before B's gets opened, even if their branches don't touch the same files).
- Trust-budget pacing: if A fails, the user wants to inspect before B runs.

If your task genuinely needs parent code in child branches, **don't use deps in v1**. Either split into multiple sequential `/auto-fleet` runs (with manual merges between), or wait for v2's epic-branch mode.

## Constraints (non-negotiable for v1)

Inherited from v0.1 (`docs/plans/auto-fleet.md`):

- Markdown-only — no code ships. The skill body grows; no runtime is added.
- Never push to default branch. Never `--force`, never `--no-verify`, never merge.
- Manifest is markdown table at `docs/fleet/<slug>.md`. Single commit per fleet run on `fleet/<slug>` control-plane branch.
- SHA-256 hash check on the manifest (single check at step 8).
- `/auto-do` orchestration via file-read at runtime; brittle-coupling acknowledged.

New for v1:

- **Wave-based scheduling, not incremental.** Each wave dispatches all ready rows (up to `--max-parallel`), waits for all to finish, then schedules the next wave.
- **All-at-once dispatch within a wave.** No staggering. Rate-limit / git-lock failures from concurrent ops become **transient infra failures** (see "Failure classification" below) — distinct from task failures.
- **Worktree per dispatched row, with pinned base SHA.** Path: `.claude/auto-fleet/wt-<slug>-<id>/`. Created via `git worktree add --detach <path> <base-sha>` where `<base-sha>` is `<default>`'s SHA captured at fleet start (pinning protects against `<default>` advancing mid-fleet).
- **`/auto-fleet` creates the row's branch inside the worktree** before dispatching `/auto-do`: `git -C <path> checkout -b auto-do/<id>`. `/auto-do` then sees a clean working tree on a non-default branch with divergence 0 — its existing step 1 logic ("if rev-list 0, reuse it") works without modification.
- **Untracked-runtime-state contract.** v1 worktrees inherit only tracked files. If `/auto-do` requires `.env` / `node_modules` / virtualenvs / generated artifacts to run, the user is responsible for ensuring those exist in each worktree (or for picking tasks that don't need them). Documented limitation; v1 ships against "your repo's `/auto-do` can run in a fresh checkout of `<default>`."
- **Per-row timeout: 60 minutes.** A sub-agent that hasn't returned in 60 min is treated as a `failed:timeout` row (cascade-blocks dependents). Configurable later via flag if needed.
- **Cascade-block, not fleet-halt.** Failure of row A blocks dependents transitively but doesn't halt the rest of the fleet's parallel branches.
- **Skipped rows count as succeeded for scheduling.** A `skipped` parent doesn't block its dependents; the user explicitly chose skip and the dependents proceed.
- **Failure classification** (new for v1):
  - **Task failure** — `/auto-do` returned a `failed:*` `Final status:`. Counts as the row failing; cascade-blocks dependents.
  - **Transient infra failure** — git lock contention (`index.lock`, `packed-refs.lock`), `gh` rate limit (HTTP 403/429 + secondary-rate-limit body), network timeout reaching gh, sub-agent timeout (60 min), worktree-creation failure. v1 treats these as task failures *for the row that hit them* (so dependents cascade-block) but explicitly tags the row's outcome with `failure_class: infra` in the Fleet outcome section so the user can re-author the row and re-run without conflating it with task quality.
- **Failed-row worktree preservation.** When a row fails, `/auto-fleet` does **not** force-remove its worktree. The worktree stays on disk for inspection (`ls .claude/auto-fleet/wt-<slug>-<id>/`). Successful rows' worktrees are removed at fleet end. Documented in the user-facing report.
- **Concurrent fleets are out of scope** but `/auto-fleet` does not enforce. If two run at once, behaviour is undefined. v1.5 may add a lock file at `.claude/auto-fleet/lock`.

## Numbered steps (the skill body)

Major changes vs v0.1 are in steps 1 (orphan reconciliation + base SHA pinning), 2 (manifest schema + cycle/forward-ref check + row-id regex), 6 (wave-based dispatch with worktree + branch creation by `/auto-fleet`), and the new cascade-block algorithm. Other steps mostly pass through.

1. **Pre-flight.** Same as v0.1 plus:
   - Capture `<base-sha> = git rev-parse <default>` once and use this SHA for all worktree creations across the fleet (pinning, not the branch ref).
   - **Orphan reconciliation.** Run `git worktree list --porcelain` filtered for paths under `.claude/auto-fleet/`. Also run `gh pr list --head 'auto-do/*' --state open --json number,headRefName,url` to surface in-flight PRs from prior crashed fleets. If either is non-empty, surface via `AskUserQuestion`: "N orphan worktrees and M open PRs from prior /auto-fleet runs detected. Clean up worktrees before continuing? (PRs are left untouched — review/close manually.)" with options "Clean up worktrees *(Recommended)*" / "Continue with orphans" / "Cancel".
   - Capture `--max-parallel=N` from `$ARGUMENTS` (default 3, ceiling 5; reject if outside `[1, 5]`).
   - Confirm `.claude/auto-fleet/` is in `.gitignore` (or the parent `.claude/` is). If not, append it. Bail if the user has a tracked `.claude/auto-fleet/` directory (unusual; protects against accidentally committing worktree contents).

2. **Read + validate the manifest.** Same as v0.1 plus:
   - **Header row** must enumerate exactly: `id`, `description`, `status`, `branch`, `pr` (in v0.1 order) OR `id`, `description`, `status`, `depends_on`, `branch`, `pr` (with depends_on inserted). Backward-compatible: if `depends_on` column is missing, treat all rows as having empty deps.
   - `depends_on` cell content (when present): empty (no deps) or comma-separated list of row ids (whitespace allowed around ids). No other characters. Each id must exist as another row's `id` (forward-ref check).
   - **Cycle detection.** Build the dep graph; reject with a clear error naming the cycle if any exists.
   - **Row id regex**: `^[a-z][a-z0-9-]{0,39}$` (40 chars max, kebab-case starting with a letter, no path separators, no Windows-reserved chars). Reject otherwise.
   - `status` enum extended: `queued | running | succeeded | failed | skipped | blocked`.
   - Hard cap on `queued`-row count: `<= 10` (v0.1 was 5).
   - Compute manifest SHA-256 once; store `<initial-hash>` for the single tamper check at step 8.

3. **Resumability check.** Same as v0.1.

4. **Confirmation gate.** Updated wording:
   - **Question**: "This fleet will run /auto-do up to <N> times across at least <min-waves> waves (more if cascade-blocking occurs) with up to <max-parallel> concurrent dispatches. Each row can take 5–60 min; minimum wall-clock if all ready rows succeed: ~<min-waves × 15> min. LLM + CI budget is multiplied by parallelism. Proceed?"
   - **Options**: "Run *(Recommended)* / Cancel".
   - `<min-waves>` = depth of the dependency DAG (number of levels). For a fleet with no deps, 1.

5. **Branching is fixed.** Same as v0.1 — each subtask's `auto-do/<id>` branch is created off `<default>`'s pinned SHA; PRs target `<default>`.

6. **Wave-based dispatch loop.** This is the major v1 change.

   The scheduler loops until either (a) all `queued` rows are in a terminal state, or (b) no rows are ready (all queued rows are `blocked` or have unsatisfied non-`succeeded`/non-`skipped` parents).

   **Per wave:**

   1. **Compute the ready set.** A row is *ready* iff: its `status == queued`, all its `depends_on` ids are in row state `succeeded` OR `skipped` (skip is treated the same as succeeded for scheduling). From the ready set, take the first up to `--max-parallel` rows in manifest order.
   2. **Per-row idempotency check** (same as v0.1) for each row in the wave's selection. Skip-recommendation handling: if the user picks Skip, that row's state goes to `skipped` in memory; it's removed from this wave's dispatch list. Its dependents become eligible in the next wave (skip counts as succeeded for scheduling).
   3. **Create worktree + branch per row.** Inside the main thread, **sequentially** for each row in the wave (serialise these git operations — worktrees do not isolate `.git/refs` / `config.lock`):
      - `git worktree add --detach .claude/auto-fleet/wt-<slug>-<id> <base-sha>` (detached HEAD pinned to fleet's base SHA).
      - `git -C .claude/auto-fleet/wt-<slug>-<id> checkout -b auto-do/<id>` (create the row's branch in its worktree).
   4. **Dispatch in parallel via Agent calls.** Single message containing K `Agent` tool calls (subagent_type: `general-purpose`), one per row. Each agent's prompt includes:
      - Working directory: the worktree path. The agent must `cd` to it before any operation.
      - Pre-conditions already satisfied: working tree is clean, current branch is `auto-do/<id>` (just created), divergence from `<default>` is 0. `/auto-do`'s step 1 should pass through these checks without modification.
      - Task: read `commands/auto-do.md` from project or user scope; execute its numbered steps with its auto-decision policy. Override step 1's slug derivation to use `<id>` verbatim (skip the description-based slug and the collision-suffix logic; the branch is already created).
      - `<description>` from the row passed as `$ARGUMENTS` to `/auto-do`.
      - **Per-row timeout: 60 minutes.** If the agent hasn't returned in 60 min, treat the row as `failed:timeout` (transient infra failure class).
      - **Report-back protocol** (machine-parsable): the agent's last text response must include a single line of the form `RESULT: status=<token> branch=<auto-do/<id>> pr=<url-or-empty>`. The `<token>` is `/auto-do`'s `Final status:` line value (`success`, `failed:round-2-must-fix`, etc). Main thread parses this line; if missing, the row is `failed` with `failure_class: protocol-violation`.
   5. **Wait for all K agents to complete.** Main thread blocks on the parallel-dispatch message.
   6. **Outcome classification per row** (same matcher as v0.1, plus new `failure_class`):
      - `success` → row state `succeeded`. Capture branch + PR url.
      - `failed:round-2-must-fix` / `failed:test-gate` / `failed:complexity-smell` → row `failed`; `failure_class: task`.
      - `failed:ambiguity` → row `failed`; `failure_class: task`.
      - Anything else, or RESULT line missing → row `failed`; `failure_class: protocol-violation`.
      - Sub-agent timeout → row `failed`; `failure_class: infra`.
      - Worktree-create / branch-create / `gh` rate-limit / git-lock failures during wave setup → row `failed`; `failure_class: infra`.
   7. **Cascade-block.** For each row that ended `failed` in this wave: compute the set of descendants (BFS over inverted dep graph); for each descendant whose status is `queued`, set status to `blocked` and capture `blocked_by: <id>` in the in-memory row state (surfaced in `## Fleet outcome` at step 8, not in a manifest column).
   8. **Worktree teardown per row.**
      - `succeeded` rows: `git worktree remove --force <path>` then `rm -rf <path>`.
      - `failed` rows: **leave worktree on disk** for the user's debugging. Surface paths in the user-facing report. The user must run `git worktree remove --force <path>` manually after inspection.
      - `skipped` rows: never had a worktree created for them.
   9. **Loop.** Run the next wave if any rows remain `queued` and have all deps `succeeded`/`skipped`. Otherwise terminate.

7. **(No standalone step 7.)** Per-task PR-body fleet-context headers happen at step 8.

8. **Final fleet report.**
   - Working-tree cleanliness check before checkout (now explicitly: main thread should still be on `fleet/<slug>` since it never `cd`s into worktrees; verify with `git symbolic-ref --short HEAD`). If somehow not on `fleet/<slug>`, attempt `git checkout fleet/<slug>` with the v0.1 dirty-tree guard.
   - Final hash check (single point; same as v0.1).
   - Compose the manifest with `## Fleet outcome` including:
     - Counts: `<succeeded> succeeded / <failed> failed / <skipped> skipped / <blocked> blocked / <remaining> queued-remaining`.
     - **Wave breakdown**: "Wave 1: 3 dispatched (rows X, Y, Z); 2 succeeded, 1 failed."
     - **Cascade-block report**: "Row D blocked: depends on row B which failed (failure_class: task)."
     - **Failed-row debugging hints**: "Row B's worktree preserved at `.claude/auto-fleet/wt-<slug>-B/` for inspection."
     - **Unrecognised /auto-do reports** (if any): `### Unrecognised /auto-do report — <id>` subsection with first 200 chars of the report.
     - PRs created.
     - `Final status:`.
     - `Fleet auto-decisions:`.
   - Single disk write → single commit → single push.
   - **Per-task PR-body fleet-context headers** (deferred from step 6 so `<manifest-url>` resolves). For each row whose `pr` is set, prepend `## Fleet context\n\nPart of fleet [<slug>](<manifest-url>) — see manifest for sibling status.\n\n`. Skip if push was rejected.
   - **`Final status:` calculus** (revised for v1):
     - `succeeded` iff every queued row reached a terminal non-failure state (`succeeded`, `skipped`) AND no `failed` AND no `blocked` AND no `queued`-remaining.
     - `halted:partial-failures` iff any row ended `failed` OR any row ended `blocked` (cascading from a failure). This replaces v0.1's `halted:round-2-failure` etc — those become row-level `failure_class: task` reasons surfaced inside the Fleet outcome, not fleet-level statuses.
     - `halted:user-cancel`, `halted:branch-collision-cancel`, `halted:manifest-tampered`, `halted:dirty-tree` — same as v0.1 (early exits before scheduler ran).

### Cascade-block algorithm (BFS, deterministic)

```
def cascade_block(failed_row_id, rows):
  to_block = set()
  queue = [failed_row_id]
  while queue:
    parent = queue.pop()
    for r in rows:
      if r.status == 'queued' and parent in r.depends_on:
        if r.id not in to_block:
          to_block.add(r.id)
          queue.append(r.id)  # transitive
  for r in rows:
    if r.id in to_block:
      r.status = 'blocked'
      r.blocked_by = failed_row_id
```

Diamond deps (A → B,C → D, and A fails) correctly produces D blocked once with `blocked_by: A` (B and C reachable via the cascade from A). When B fails but C succeeds and both feed D, D is blocked via B (visited first).

## Manifest format (v1 update)

`docs/fleet/<slug>.md`:

```markdown
---
slug: dependency-bumps
created: 2026-05-04
last_updated:
---

## Subtasks

| id          | description                                            | status | depends_on    | branch | pr |
|-------------|--------------------------------------------------------|--------|---------------|--------|----|
| bump-foo    | Bump the foo dependency in package.json to v2.x       | queued |               |        |    |
| bump-bar    | Bump the bar dependency in package.json to v3.x       | queued |               |        |    |
| bump-baz    | Bump the baz dependency in package.json to v1.5.x     | queued |               |        |    |
| changelog   | Add release-notes entry summarising the dep bumps     | queued | bump-foo, bump-bar, bump-baz |  |  |
```

This example exercises every v1 feature with **code-independent** rows: three independent bumps fan out in parallel (wave 1), then `changelog` waits for all three to dispatch successfully before its turn (wave 2). `changelog`'s task is to write release notes describing the bumps — it doesn't need the bumps' code in its branch (it only references PR numbers in prose). This is the kind of dispatch-ordering dep that `/auto-fleet` v1 supports cleanly.

⚠ The original draft used a "pg-ext → users-log → dashboard" example where dashboard "wires logging dashboard to read all three routes" — that's invalid for v1 because dashboard's branch wouldn't contain the routes' code (the parent PRs aren't merged when dashboard dispatches). **Don't use deps when the child needs parent code in its branch** — split into multiple sequential `/auto-fleet` runs (with manual merges between), or wait for v2's epic-branch mode.

### Manifest constraints (v1 additions)

- `depends_on` column: optional. If absent, all rows have empty deps (v0.1 manifests work unchanged).
- `depends_on` cell: empty or comma-separated row ids. Whitespace allowed around ids.
- Cycle: any cycle in the `depends_on` graph rejects the manifest with a clear error.
- Forward refs: every id in `depends_on` must exist as another row's id.
- `id` regex: `^[a-z][a-z0-9-]{0,39}$`.
- `status` enum: `queued | running | succeeded | failed | skipped | blocked`.
- Cap raised: `queued`-row count `<= 10`.

## Worktree management

- **Path**: `.claude/auto-fleet/wt-<slug>-<id>/`. Slug + id keeps worktrees uniquely named.
- **Creation**: `git worktree add --detach <path> <base-sha>` — fresh detached HEAD off the fleet's pinned `<base-sha>` (captured once at step 1). Then immediately `git -C <path> checkout -b auto-do/<id>` to create the row's branch.
- **Sequential creation** (within main thread, before parallel dispatch). Worktrees do not isolate `.git/refs` / `config.lock`; concurrent `git worktree add` from parallel agents would race. v1 creates worktrees serially in the main thread before dispatching the parallel agents.
- **Lifetime**: created at the start of each wave for each ready row; removed at end of wave for `succeeded` rows; **preserved on disk** for `failed` rows (debugging).
- **Cleanup on succeeded**: `git worktree remove --force <path>` then `rm -rf <path>`.
- **Cleanup on failed**: explicit user action (skill body's user-facing report shows the path).
- **Cleanup on crash**: orphan worktrees detected at next `/auto-fleet` invocation (step 1 pre-flight).
- **`.claude/auto-fleet/` directory**: auto-added to `.gitignore` if not already covered.
- **Untracked-runtime-state limitation**: worktrees inherit only tracked files. `.env` / `node_modules` / virtualenvs / build artifacts are NOT copied. Documented v1 limitation.

## Scheduler (wave-based, deterministic)

```
while any row.status == queued:
  ready = [r for r in queued_rows
           if all(parents[r].status in ('succeeded', 'skipped'))]
  if not ready: break
  wave = ready[:max_parallel]    # first K in manifest order
  for row in wave:                # serially in main thread
    git worktree add --detach .claude/auto-fleet/wt-<slug>-<id> <base-sha>
    git -C ... checkout -b auto-do/<id>
  results = parallel-Agent-dispatch(wave)  # single message, K Agent tool calls
  for row, result in zip(wave, results):
    classify row.outcome (succeeded / failed / failure_class)
    if row.failed:
      cascade_block(row.id, all_rows)  # mark descendants as blocked
    if row.succeeded:
      git worktree remove --force <path>
    # row.failed: leave worktree on disk
end
```

## Critical files

- **Edit**: `commands/auto-fleet.md` — substantial. v0.1's serial dispatch loop becomes wave-based parallel; new sections for worktree management, scheduler, cascade-block, failure classification; manifest constraints updated; pre-flight gains orphan reconciliation + base-SHA pinning.
- **Edit**: `README.md` — `/auto-fleet` row in Skills shipped table mentions parallelism + deps; Where-to-go-next bullet updated; manifest example updated; the "deps don't carry code" caveat surfaced.
- **Edit**: `CHANGELOG.md` — `[Unreleased]` v1 entry.
- **Edit**: `docs/plans/auto-fleet.md` — v0.1 plan stays; add a "v1 supersedes" note at the top pointing here.
- **Verify (no edit expected)**: `commands/auto-do.md` — v1 doesn't require any change. The override prompt (slug = `<id>`, skip collision-suffix) handles the contract; `/auto-do`'s existing branch-selection logic ("rev-list 0 → reuse it") works correctly when `/auto-fleet` pre-creates the branch.

## Verification

- **Manual smoke fixtures** (mirrors v0.1's checklist, expanded):
  - **Happy parallel** (no deps): 3 independent rows in 1 wave, all succeed → 3 PRs created, manifest closes with `succeeded`.
  - **Happy DAG**: the 4-row example from the manifest format section. Wave 1: 3 bumps in parallel. Wave 2: changelog. All succeed → manifest closes with `succeeded`.
  - **Cascade-block**: 4-row DAG; bump-foo fails. Expect bump-foo = `failed`, changelog = `blocked` with `blocked_by: bump-foo` annotation in Fleet outcome. bump-bar + bump-baz proceed in parallel and (if they succeed) are `succeeded`. Final status: `halted:partial-failures`.
  - **Cycle detection**: manifest with A → B → A; expect bail at step 2 with cycle error.
  - **Forward-ref miss**: `depends_on: nonexistent` → bail at step 2.
  - **Backward-compat**: a v0.1 manifest (no `depends_on` column) runs as serial-fleet equivalent.
  - **Skipped scheduling**: row A's idempotency-gate fires (branch exists from a prior run); user picks Skip; row B (`depends_on: A`) dispatches in next wave (skipped counts as succeeded).
  - **Orphan worktree pre-flight**: pre-create a worktree under `.claude/auto-fleet/wt-test/`; invoke `/auto-fleet`; expect cleanup offer.
  - **`--max-parallel=1`**: forces serial-within-wave; should still work.
  - **`--max-parallel=6`**: should reject (over ceiling).
  - **Failed-row worktree preservation**: row fails; expect worktree on disk after fleet end; user-facing report points to it.
  - **Sub-agent timeout**: row's task is a no-op that sleeps 65 minutes; expect `failed:timeout` (failure_class: infra) at the 60-minute boundary.
- **Manifest fixture pack** (carry forward TODO from v0.1; gains valid + invalid examples for v1's new schema).

## Out of scope (intentional)

- Auto-slicing the manifest (still v2+).
- Epic-branch mode / stacked PRs (still v2+) — v1 explicitly does not deliver code-level deps.
- File-overlap detection between parallel rows (v1.5+).
- Incremental scheduling (slot-frees-dispatch-next vs wave-based) — v1.5+.
- Dispatch-staggering to avoid `gh pr create` rate-limit spikes — v1.5+.
- Concurrent `/auto-fleet` invocations + lock file — v1.5+.
- `--keep-going` flag (cascade-block IS productive-mode; no flag needed).
- `--resume` flag (still manual reset only).
- Cross-PR review-finding dedup (`/review-fleet` separate skill).
- Auto-merge of any PR (always human gate).
- Per-row timeout configuration (60 min hardcoded; flag in v1.5 if needed).
- Untracked-state copy/symlink into worktrees (v1 contract: "your `/auto-do` runs in a fresh checkout").

## See also

- [Brainstorm: /auto-fleet (strategy)](../brainstorms/auto-fleet.md)
- [Brainstorm: /auto-fleet-parallel (v1 implementation)](../brainstorms/auto-fleet-parallel.md)
- [Plan: /auto-fleet v0.1](./auto-fleet.md)
- [Solution: /auto-fleet v0.1](../solutions/auto-fleet.md)

---

## Engineering Review — 2026-05-04

Reviewer: `/plan-eng-review` (Adam, in auto-mode) + Codex outside-voice (`codex-cli 0.128.0`).

Codex returned 19 findings against the original v1 plan draft. Most are sharp; the most material reshaped the plan substantially. Summary of what was applied vs. disagreed:

### Applied (must-fix folded into plan body)

- **Codex #1 — `depends_on` is semantically fake under independent branches.** The original "dashboard → users-log → pg-ext" example was invalid: dashboard's branch starts from `<default>` and doesn't contain the route code. Fold: tightened the contract — deps are **dispatch-ordering only**, never code-deps. Replaced the example with a code-independent fan-out (three dependency bumps + a changelog row). Added explicit "What deps are NOT" subsection. Documented that v1 doesn't deliver code-level deps (epic-branch is v2).
- **Codex #2 — `git worktree add <path> <default>` checks out the branch.** Two worktrees can't both check out `<default>`. Fold: switched to `git worktree add --detach <path> <base-sha>` with `<base-sha>` pinned at fleet start.
- **Codex #3 — `/auto-do` change probably required.** Original plan said no `/auto-do` change. Fold: instead of relying purely on prompt-overrides at dispatch time, `/auto-fleet` now creates the row's `auto-do/<id>` branch *inside* the worktree before dispatch (`git -C <path> checkout -b auto-do/<id>`). `/auto-do`'s existing step 1 logic ("if rev-list 0 → reuse it") then works correctly without modification. `/auto-do` itself stays unchanged.
- **Codex #4 — Worktrees do not isolate `.git/refs`/`config.lock`.** Real concurrency hazard. Fold: serialise critical git ops (worktree create + branch create) in main thread before dispatching the parallel agents. Document the contention class as a known infra-failure mode.
- **Codex #5 — Worktrees don't carry untracked runtime state.** Real for repos with `.env` / `node_modules` / virtualenvs. Fold: explicit v1 contract — "`/auto-do` must be runnable in a fresh checkout of `<default>`." Documented limitation; copy/symlink solutions deferred to v1.5+.
- **Codex #6 — Row IDs lack a safe regex/length cap.** Fold: `^[a-z][a-z0-9-]{0,39}$` (40 chars max, kebab-case starting with a letter, no path separators, Windows-safe).
- **Codex #7 — Force-removing failed worktrees destroys debugging state.** Fold: `succeeded` rows' worktrees are removed at fleet end; `failed` rows' worktrees are **preserved on disk** for inspection. The user-facing report surfaces the paths; the user runs `git worktree remove --force` manually after inspection.
- **Codex #8 — Transient infra failures conflated with task failures.** Rate limits, git locks, network errors, sub-agent timeouts shouldn't be treated identically to "the task itself failed quality." Fold: introduced a `failure_class` field captured per failed row. Values: `task` (`/auto-do` returned `failed:*`), `infra` (worktree-create / branch-create / `gh` rate-limit / git-lock / sub-agent timeout), `protocol-violation` (RESULT line missing or unparseable). Cascade-block still applies (a failed parent of any class blocks dependents), but the user can re-author and re-run infra-classified failures without conflating with task quality.
- **Codex #9 — No timeout / hung-agent policy.** Fold: per-row 60-minute timeout. Hung sub-agents → `failed:timeout` with `failure_class: infra`.
- **Codex #10 — In-memory state lost on crash, but PRs/branches/worktrees persist.** Fold: pre-flight orphan reconciliation now also runs `gh pr list --head 'auto-do/*' --state open` to surface in-flight PRs from prior crashed fleets. Worktree cleanup is offered; PRs are surfaced for manual review/close (not auto-closed). v1's crash-recovery story is still "manual reset" — proper resumability is v1.5+.
- **Codex #11 — `skipped` parents break the scheduler.** Original plan said dependents stay `queued` indefinitely if a parent is `skipped`. Fold: scheduler treats `skipped` the same as `succeeded` — dependents proceed. This matches user intent (skip means "user explicitly decided this row is done"; dependents shouldn't wait forever).
- **Codex #12 — Final-status calculus inconsistent.** Fold: tightened. `succeeded` iff (no failed rows AND no blocked rows AND no queued-remaining). `halted:partial-failures` iff (any failed or blocked). Row-level reasons (`failed:test-gate`, `failed:round-2-must-fix`, etc) are captured in the Fleet outcome subsections per row, not as fleet-level statuses. Old v0.1-style `halted:test-gate` / `halted:round-2-failure` etc are gone at the fleet level; they live as row reasons.
- **Codex #13 — Blocked annotations have no schema.** Fold: `blocked_by: <id>` is captured in-memory and surfaced in the `## Fleet outcome` section's cascade-block report subsection. The manifest table itself stays well-typed (no new column).
- **Codex #15 — `.claude/auto-fleet/` worktree path risk.** Fold: pre-flight ensures `.claude/auto-fleet/` is in `.gitignore` (or covered by `.claude/`); appends if not. Bails if the user has a tracked `.claude/auto-fleet/` directory.
- **Codex #17 — Mandatory `depends_on` column hard-fails v0.1 manifests.** Fold: backward-compat — `depends_on` column is optional; if absent, all rows have empty deps and v1 runs them as v0.1 would.
- **Codex #18 — Confirmation gate `<waves>` estimate misleading.** Fold: rewrote as "minimum wall-clock if all ready rows succeed; more if cascade-blocking occurs." `<min-waves>` = depth of the dep DAG.
- **Codex #19 — PR/branch extraction from subagent reports underspecified.** Fold: introduced an explicit machine-parsable RESULT line that each sub-agent must include in its last response: `RESULT: status=<token> branch=<auto-do/<id>> pr=<url-or-empty>`. Missing or unparseable RESULT line → `failed` with `failure_class: protocol-violation`.

### Applied as TODOs (deferred)

- **Codex #14 — No concurrency lock for fleets.** v1 does not enforce single-fleet-at-a-time. v1.5 may add `.claude/auto-fleet/lock`. Captured.
- **Codex #16 — Manifest hash check at step 8 has no recovery path.** True. By the time the hash check fires, PRs may already exist. v1 refuses to clobber and exits with a clear message; the user manually reconciles. Real recovery (e.g. amend the in-memory state into the user's edits) is v1.5+. Documented.

### Disagreed

- **Codex #20 — "Markdown-only is the wrong constraint for this much scheduler logic."** Same foundational critique as v0.1's Codex review. Workshop principle stands: the LLM is the runtime; the markdown is the program. v1 is more complex than v0.1, but the substrate is the same. Acknowledged the tension in the Constraints section. *Cross-model tension preserved, not resolved at the plan level.*

### NOT in scope (carry-forward + v1 additions)

- Auto-slicing — v2+.
- Epic-branch / stacked PRs — v2+ (would deliver real code-level deps).
- File-overlap detection — v1.5+.
- Incremental (slot-based) scheduling — v1.5+.
- Dispatch-staggering — v1.5+.
- Concurrent fleets + lock file — v1.5+.
- Per-row timeout flag — v1.5+ if needed.
- Untracked-state copy/symlink into worktrees — v1.5+.
- Auto-merge — never v1; always human gate.

### TODOs (carry forward to TODOS.md on first commit)

- **`/auto-fleet` v1 first-real-run smoke** — running a 4-row DAG fleet against a public template repo. Schedule one-off agent ~2 weeks after ship.
- **Manifest fixture pack** — gains v1 schema examples (cycle, forward-ref miss, mixed deps, etc).
- **Lock file** for concurrent-fleet protection.
- **Mid-fleet manifest hash recovery** path (v1.5+).

### Completion summary

```
Step 0 — Scope:   Full v1 (per user's AskUserQuestion); deps reframed as dispatch-ordering-only after Codex #1
Architecture:     5 issues found (Codex #1, #2, #3, #4, #15), 5 resolved
Code quality:     6 issues found (#5, #6, #7, #8, #11, #13), 6 resolved
Tests:            12 manual smoke fixtures listed (8 new for v1 features)
Performance:      3 issues found (#4 contention, #16 hash-check, #19 protocol), 3 resolved (one as documented limitation)
Outside voice:    ran (Codex 0.128.0); 19 findings; 17 folded into plan, 2 → TODOs, 1 disagreed (Codex #20)
NOT in scope:     written
Failure classes:  introduced — task / infra / protocol-violation
TODOs:            4 carried forward to TODOS.md on first commit
Unresolved:       none — all decisions taken under auto-mode auto-decision policy
```
