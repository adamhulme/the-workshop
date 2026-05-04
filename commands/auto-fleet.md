---
description: Autonomous fleet runner v1 — wave-based parallel dispatch over a user-authored manifest at docs/fleet/<slug>.md, with declared dispatch-ordering dependencies, cascade-block on failure, per-row git worktree isolation, and a 60-minute per-row timeout. v1 raises the row cap to 10 and adds a --max-parallel=N concurrency cap (default 3, ceiling 5). Backward compatible with v0.1 manifests (no depends_on column). The fleet's own commits live on a fleet/<slug> control-plane branch the user must create off the default branch before invoking.
argument-hint: <slug> [--max-parallel=N]
---

The fleet sibling of `/auto-do`. Where `/auto-do` runs one task end-to-end, `/auto-fleet` runs N tasks (now in parallel waves) from a user-authored manifest, dispatching `/auto-do` per row inside its own git worktree. v1 adds declared dispatch-ordering dependencies and cascade-block on failure; v0.1 manifests (without a `depends_on` column) continue to work unchanged.

User arguments: $ARGUMENTS

## What v1 is (and isn't)

- **Is** — a wave-based parallel dispatcher that reads `docs/fleet/<slug>.md`, computes a ready set per wave (rows whose deps are all `succeeded` or `skipped`), creates a git worktree per ready row (detached HEAD on a pinned base SHA), and dispatches up to `--max-parallel` `/auto-do` instances **in parallel** as `general-purpose` Agent calls. Cascade-blocks dependents when a parent fails. Single commit at the end on a `fleet/<slug>` control-plane branch.
- **Is NOT** — a planner. Manifest is user-authored. Dependencies are **dispatch-ordering only** — the dependent's branch is created off `<default>`'s pinned SHA, NOT off the parent's branch. If your task needs parent code in the child branch, **don't use deps in v1**: split into multiple sequential `/auto-fleet` runs (with manual merges between), or wait for v2's epic-branch mode.
- v1 has no `--keep-going`, no `--max-tasks`, no epic-branch mode, no `--resume`, no auto-stub creation, no auto-slicing. These are v1.5+ / v2+ concerns. Cascade-block IS the productive-mode behaviour — failures don't halt the whole fleet, only their dependents.

## What `depends_on` is NOT (read this if you're using deps)

- It does **not** carry parent code into the child's branch. Each row's `auto-do/<id>` branch is created off `<default>`'s pinned SHA at fleet start. Until parent PRs are merged, dependents don't see parent code.
- It does **not** detect file overlap between sibling rows. Two siblings touching the same file collide at PR review time, not at dispatch time.
- It does **not** imply auto-merge. v1 never merges any PR.

What it **does**: `/auto-fleet` won't dispatch row B until row A reaches `succeeded` (or is `skipped`). Useful when:

- B's task description references A's *concept* even though the *code* is independent (e.g. "add release-notes for the dep bumps A/B/C made").
- Reviewer-flow ordering: review A's PR before B's gets opened, even if their branches don't touch the same files.
- Trust-budget pacing: if A fails, the user wants to inspect before B runs.

The example in the **Manifest format** section uses three independent dependency-bumps fanning out, then a release-notes row that depends on all three — code-independent but ordering-meaningful. That's the shape deps are good for.

## How `/auto-fleet` v1 orchestrates `/auto-do`

`/auto-fleet` is the **scheduler** running in main thread. Each parallel `/auto-do` is a **sub-agent** running in its own git worktree.

Per dispatch:

1. **Main thread** creates the worktree (`git worktree add --detach <path> <base-sha>`) and the row's branch (`git -C <path> checkout -b auto-do/<id>`) — sequentially, one row at a time within a wave, before any sub-agent dispatch (worktrees do not isolate `.git/refs` or `config.lock`; concurrent git ops there race).
2. **Main thread** dispatches K parallel sub-agents in a single message (K Agent tool calls, all `subagent_type: general-purpose`). Each agent's prompt directs it to `cd` into its assigned worktree, read `commands/auto-do.md` from project (`<repo>/.claude/commands/auto-do.md`) or user (`$HOME/.claude/commands/auto-do.md`) scope, and execute its numbered steps with its auto-decision policy. The slug is fixed to the row's `<id>` (skip `/auto-do` step 1's slug derivation and collision-suffix logic — the branch is already created). The row's `description` is passed as `$ARGUMENTS` to `/auto-do`.
3. **Sub-agent** runs `/auto-do` in its worktree end-to-end. `/auto-do`'s existing step 1 logic ("if `git rev-list --count <default>..HEAD` is 0 → reuse current branch") works correctly because `/auto-fleet` already pre-created the branch from `<base-sha>`. No `/auto-do` change required.
4. **Sub-agent** finishes by emitting a single machine-parsable RESULT line in its last text response: `RESULT: status=<token> branch=<auto-do/<id>> pr=<url-or-empty>`. The `<token>` is `/auto-do`'s `Final status:` line value (`success`, `failed:round-2-must-fix`, etc).
5. **Main thread** waits for all K sub-agents in the wave to return, parses each RESULT line, classifies row outcomes, runs cascade-block over the dependency graph, removes worktrees for `succeeded` rows (preserves them for `failed` rows), then computes the next wave's ready set and dispatches again.

The brittle coupling on `/auto-do`'s `Final status:` token strings is the same one v0.1 accepted; v1 adds a parsable RESULT-line protocol around it for clean machine extraction.

## User gates and recommended options

v1 has **no non-interactive mode**. Every `AskUserQuestion` `/auto-fleet` raises is shown to the user; the skill never auto-picks an option.

- **Orphan-cleanup gate (step 1)** → options `Clean up *(Recommended)* / Continue with orphans / Cancel`. Fires only if pre-flight detects orphan worktrees or in-flight PRs from prior crashed fleets.
- **Idempotency gate (step 6)** → options `Skip *(Recommended)* / Dispatch anyway / Cancel`. Fires per-row when a prior `auto-do/<id>` branch or PR exists.
- **Confirmation gate (step 4)** → options `Run *(Recommended)* / Cancel`. Fires unconditionally before any wave dispatch.
- **No other gates.** Resumability bails (manual reset only). Branching is fixed. Hash mismatch halts. No additional `AskUserQuestion`.

## Hard safety rules

- **Never push to the default branch.** Pre-flight refuses to run on the default branch.
- **Never `--force`, `--force-with-lease`, or `--no-verify`.**
- **Never merge any PR.**
- **Never run more than `--max-parallel` `/auto-do` instances at once.** Default 3, ceiling 5.
- **Never dispatch a row whose `depends_on` parents aren't all `succeeded` or `skipped`.**
- **Never auto-slice the manifest.** Manual authoring only.
- **Never silently re-run a `running` row.** Bail with manual-reset instructions.
- **Never write to the manifest after detecting external edits** (SHA-256 hash check at step 8).
- **Never write to the manifest mid-fleet.** All row-state transitions are in-memory until step 8.
- **Never force-remove a `failed` row's worktree at fleet end.** Preserve on disk for debugging; user removes manually after inspection.
- **Never delete subtask branches (`auto-do/<id>`) or PRs.** They live independently of `/auto-fleet`.

## Manifest format

Path: `docs/fleet/<slug>.md`. The user authors this file before invoking `/auto-fleet`.

```markdown
---
slug: dependency-bumps
created: 2026-05-04
last_updated:
---

## Subtasks

| id          | description                                            | status | depends_on                       | branch | pr |
|-------------|--------------------------------------------------------|--------|----------------------------------|--------|----|
| bump-foo    | Bump the foo dependency in package.json to v2.x        | queued |                                  |        |    |
| bump-bar    | Bump the bar dependency in package.json to v3.x        | queued |                                  |        |    |
| bump-baz    | Bump the baz dependency in package.json to v1.5.x      | queued |                                  |        |    |
| changelog   | Add release-notes entry summarising the dep bumps      | queued | bump-foo, bump-bar, bump-baz     |        |    |
```

This example is **code-independent**: three parallel bumps in wave 1, then a release-notes row in wave 2 that references the bumps in prose without needing their code in its branch. That's the kind of dep v1 supports cleanly.

> **A note on the format.** Markdown-table-with-frontmatter is an *agent-tooling* idiom; mainstream fleet runners (multi-gitter, OpenRewrite, Argo Workflows, GitHub Actions matrix) use YAML or JSON. The choice here is deliberate — the manifest lives next to other markdown docs in `docs/`. The trade-off is fragile parsing (hence the description-text constraints below) and awkward programmatic validation.

### Manifest constraints (validated at step 2)

- `slug` in frontmatter **must equal** the slug derived from `$ARGUMENTS`.
- Header row must enumerate the columns in one of the supported orders:
  - **v0.1 schema** (still supported): `id`, `description`, `status`, `branch`, `pr`. All rows treated as having empty deps.
  - **v1 schema**: `id`, `description`, `status`, `depends_on`, `branch`, `pr`.
- `id` regex: `^[a-z][a-z0-9-]{0,39}$` (≤ 40 chars, kebab-case, starts with letter, no path separators, Windows-safe). Must be unique within the manifest.
- `description` text must not contain `|`, backticks, markdown link syntax `[...](...)`, or newlines (table-rewrite safety).
- `status` must be one of `queued | running | succeeded | failed | skipped | blocked`. (Names follow Argo Workflows / Temporal / GitHub Actions convention.)
- `depends_on` cell (when column present): empty (no deps) or comma-separated row ids. Whitespace allowed around ids; no other characters. Each id must reference another row in the manifest (forward-ref check).
- The `depends_on` graph must be acyclic (cycle detection at parse).
- Row count where `status == queued` must be `<= 10` (v1 hard cap; v0.1 was 5). The cap is a v1 guard rail; mainstream fleet runners are unbounded.
- `last_updated` is a YAML key in frontmatter; `/auto-fleet` writes its value at the single fleet-end disk-write.

### Manifest state machine

v1 holds `running` **in memory only** — the manifest on disk transitions directly from `queued` to a terminal state at fleet end (step 8).

```
                     ┌───────────┐
   ┌───────────────► │ succeeded │ ◄── dispatch-loop wave classifier
   │                 └───────────┘
   │
[queued] ──► (running, in memory) ─┬─► [failed]   (cascades to dependents)
   │              ▲                │
   │              │                ├─► [skipped]  (idempotency gate)
   │              │                │
   │              │                └─► [blocked]  (depends_on parent failed)
   │
   │     manual-reset only (v1: edit the file)
   └──────────────┘
```

`succeeded` AND `skipped` both unblock dependents. `blocked` rows are not retried within the same fleet run.

## Control-plane branch

Same as v0.1. `/auto-fleet` operates only on a `fleet/<slug>` branch the user creates off the default branch before invoking. Step 1 refuses to run on the default branch. The fleet branch holds **only the manifest** — no code changes — and is never merged. Subtask branches (`auto-do/<id>`) are siblings off the default branch's pinned SHA, not stacked.

## Worktree management

v1 uses one git worktree per dispatched row, isolating each `/auto-do`'s working tree.

- **Path**: `.claude/auto-fleet/wt-<slug>-<id>/` per dispatched row. Slug + id keeps worktrees uniquely named.
- **Creation**: `git worktree add --detach <path> <base-sha>` where `<base-sha>` is the SHA of `<default>` captured once at step 1 (pinning protects against `<default>` advancing mid-fleet). Then immediately `git -C <path> checkout -b auto-do/<id>` to create the row's branch on top of the detached HEAD.
- **Sequential creation in main thread.** Worktrees do not isolate `.git/refs` / `config.lock`; concurrent `git worktree add` from parallel agents would race. `/auto-fleet` creates worktrees serially before dispatching the parallel agents.
- **Lifetime — `succeeded` rows**: `git worktree remove --force <path>` then `rm -rf <path>` at end of wave.
- **Lifetime — `failed` rows**: **preserved on disk** for debugging. The user-facing report at step 9 surfaces the path. The user runs `git worktree remove --force <path>` manually after inspection.
- **Lifetime — `skipped` rows**: never had a worktree (skipped before dispatch).
- **Cleanup on crash**: orphan worktrees detected at next `/auto-fleet` invocation (step 1 pre-flight); offered for cleanup via `AskUserQuestion`.
- **`.claude/auto-fleet/` directory**: must be covered by `.gitignore` (typically via `.claude/` itself); pre-flight bails if not, instructing the user to add it on a separate commit before re-invoking. `/auto-fleet` does not auto-modify `.gitignore` (would dirty the tree mid-fleet).
- **Untracked-runtime-state limitation**: worktrees inherit only tracked files. `.env`, `node_modules`, virtualenvs, build artifacts are NOT carried. v1 ships against the contract "your `/auto-do` runs in a fresh checkout of `<default>`." Tasks requiring local runtime state are not v1-eligible.

## Scheduler (wave-based, deterministic)

```
base_sha = git rev-parse <default>     # pinned at step 1, used for all worktrees
while any row.status == queued:
  ready = [r for r in queued_rows
           if all(parents[r].status in ('succeeded', 'skipped'))]
  if not ready: break    # all queued rows are blocked or have unsatisfied deps
  wave = ready[:max_parallel]    # first K in manifest order
  for row in wave:               # sequential, in main thread
    git worktree add --detach .claude/auto-fleet/wt-<slug>-<id> <base_sha>
    git -C .claude/auto-fleet/wt-<slug>-<id> checkout -b auto-do/<id>
  results = parallel-Agent-dispatch(wave)   # single message, K Agent tool calls
  for row, result in zip(wave, results):
    classify row.outcome (succeeded / failed)
    if row.failed:
      cascade_block(row.id, all_rows)       # mark descendants as blocked
      # leave failed row's worktree on disk
    else:
      git worktree remove --force <row's worktree>
end
```

## Failure classification

Each `failed` row gets a `failure_class` field captured in memory and surfaced at step 8:

- **`task`** — `/auto-do` returned a `failed:round-2-must-fix` / `failed:test-gate` / `failed:complexity-smell` / `failed:ambiguity` `Final status:`. The task itself failed quality.
- **`infra`** — sub-agent timeout (60 min), worktree-create failure, branch-create failure, `gh` rate limit (HTTP 403/429 / "secondary rate limit" body), git lock contention. Re-runnable; not a task quality signal.
- **`protocol-violation`** — sub-agent's last response missing or unparseable `RESULT:` line. The `/auto-do` contract was violated; investigate manually before re-running.

Cascade-block applies regardless of class — a failed parent blocks its descendants. The class lets the user re-author the row appropriately (re-run for `infra`, fix-and-re-run for `task`, debug for `protocol-violation`).

## Cascade-block algorithm (BFS, deterministic)

When a row fails:

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
          queue.append(r.id)    # transitive
  for r in rows:
    if r.id in to_block:
      r.status = 'blocked'
      r.blocked_by = failed_row_id
```

Diamond deps (A → B,C → D, A fails) → D `blocked` once with `blocked_by: A` (B, C reachable via cascade from A). When B fails but C succeeds, both feeding D, D blocks via B.

`blocked_by` is in-memory annotation surfaced in `## Fleet outcome` at step 8 (no manifest column).

## Steps

### 1. Pre-flight

- `git rev-parse --show-toplevel` — must be in a repo. Bail if not.
- `git status --porcelain` — must be empty. Bail with: "/auto-fleet refuses to start with a dirty working tree. Commit, stash, or revert first."
- `gh auth status` — must pass. Bail.
- Detect default branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` (fallback `main`). Store as `<default>`.
- **Pin `<base-sha> = git rev-parse <default>`.** All worktrees in this fleet's lifetime use this SHA. Protects against `<default>` advancing mid-fleet.
- Verify `gh` version supports `gh pr ready --undo` (transitively, via `/auto-do`'s round-2 safe-stop).
- **Parse `$ARGUMENTS` into `<slug>` + flags before any normalisation.** Split on whitespace. The first non-flag token is `<slug>` (raw, before kebab-case normalisation); subsequent tokens matching `--max-parallel=<int>` are flags. Reject any other token with: `"unrecognised argument '<token>'; expected <slug> [--max-parallel=N]"`.
- **Derive `<slug>`** from the captured slug token using kebab-case validation (lowercase, replace whitespace/punctuation with `-`, collapse repeated hyphens, trim, reject path separators / illegal filename chars). Cap at 50 chars. All later steps refer to `<slug>` by this derived value.
- **Refuse to run on the default branch.** Bail unless current branch == `fleet/<slug>` (using derived slug).
- **Verify the fleet branch is rooted on `<default>` and contains only manifest commits.** Run `git diff <default>..HEAD --name-only`. The set of changed paths must be empty or exactly `{docs/fleet/<slug>.md}`. Bail otherwise.
- **Capture `--max-parallel=N`.** Default `N = 3`. Reject if N is non-integer or outside `[1, 5]` with: `"--max-parallel must be an integer in [1, 5]; got <value>"`.
- **Verify `.claude/auto-fleet/` is gitignored.** If `.claude/` is already in `.gitignore`, it's covered. Otherwise bail with: `"add .claude/auto-fleet/ to .gitignore (and commit on a separate change first); /auto-fleet won't auto-modify .gitignore mid-fleet because that would dirty the working tree and break step 8's manifest commit."` Also bail if a tracked `.claude/auto-fleet/` directory already exists.
- **Orphan reconciliation.** Run `git worktree list --porcelain` filtered for paths under `.claude/auto-fleet/`. Run `gh pr list --state open --json number,headRefName,url --jq '[.[] | select(.headRefName | startswith("auto-do/"))]'` (literal `--head` matching does NOT pattern-match in `gh`; the post-filter via `jq` is the correct approach). If either is non-empty, surface via `AskUserQuestion`:
  - **Question**: "Detected N orphan worktrees (from fleets: `<slugs-parsed-from-paths>`) and M open `auto-do/*` PRs from prior runs. Clean up worktrees before continuing? (PRs are NOT auto-closed — review/close them manually.)"
  - **Header**: "Orphan cleanup"
  - **Options**:
    - "Clean up worktrees *(Recommended only if no failed-row debugging is in progress)*" — `git worktree remove --force <path>` for each orphan, then report.
    - "Continue with orphans *(Recommended if any orphan path matches a fleet whose manifest has `failed` rows)*" — leave worktrees in place; preserves debugging state from prior `failed` rows.
    - "Cancel" — exit; user investigates manually.
- Confirm `docs/fleet/<slug>.md` exists in the working tree. If missing, bail with manual-author instructions.

### 2. Read + validate the manifest

- Read `docs/fleet/<slug>.md`. Parse YAML frontmatter (must include keys: `slug`, `created`, `last_updated`).
- Verify frontmatter `slug == <slug>` (derived). Bail on mismatch.
- Locate the `## Subtasks` section. Parse the markdown table.
- **Detect schema variant by header row**:
  - If header is `id | description | status | branch | pr` → v0.1 schema; treat all rows as having empty deps. Continue.
  - If header is `id | description | status | depends_on | branch | pr` → v1 schema; parse the `depends_on` column.
  - Anything else → bail with "manifest header row must be the v0.1 or v1 schema; got `<header>`."
- For each row, validate:
  - `id` matches `^[a-z][a-z0-9-]{0,39}$`. Reject otherwise.
  - `id` is unique within the manifest.
  - `description` has no `|`, backticks, markdown link syntax, or newlines.
  - `status` ∈ `queued | running | succeeded | failed | skipped | blocked`.
  - `depends_on` (if present): empty OR comma-separated valid ids. Each id must exist as another row's id (forward-ref check).
- **Cycle detection.** Build the dep graph (DAG). If any cycle exists, reject with `"manifest dep cycle detected: <cycle>"`.
- Count rows where `status == queued`. Must be `> 0` (else "no queued work, exiting") and `<= 10` (else "v1 hard cap of 10 exceeded — break this fleet up").
- Compute SHA-256 of the manifest's full byte contents. Store as `<initial-hash>` for the single tamper check at step 8.

### 3. Resumability check

- If any row has `status == running`, bail without modifying anything: "<N> rows are stuck in `running` state from a prior run or external edit. Edit `docs/fleet/<slug>.md` manually to reset them to `queued` (or mark `failed`/`skipped`), then re-invoke. v1 does not auto-reset."
- If any row has `status == failed` or `status == blocked`, bail with: "<N> rows are in terminal failure states (`failed`/`blocked`) on disk. v1 does not re-dispatch terminal-state rows mid-fleet. Edit `docs/fleet/<slug>.md` manually to reset them to `queued` (to retry) or `skipped` (to skip and proceed), then re-invoke. (If you re-author and want cascade-block semantics on fresh failures, reset to `queued` — the dispatch loop will produce the cascade naturally.)"
- Pre-existing `succeeded` and `skipped` rows are accepted as already-done; they unblock dependents per the scheduler's normal logic.

### 4. Confirmation gate

- Compute `<min-waves>` = depth of the DAG (the longest path through the dep graph). For a fleet with no deps, 1.
- Surface via `AskUserQuestion`:
  - **Question**: "This fleet will run /auto-do up to <N> times across at least <min-waves> waves (more if cascade-blocking occurs) with up to <max-parallel> concurrent dispatches. Each row can take 5–60 min; minimum wall-clock if all ready rows succeed: ~<min-waves × 15> min. LLM + CI budget is multiplied by parallelism. Proceed?"
  - **Header**: "Confirm fleet dispatch"
  - **Options**: `Run *(Recommended)*` / `Cancel`.
- On Cancel: hold `Final status: halted:user-cancel` in memory and continue to step 8.

### 5. Branching is fixed

No question is asked here. v1 supports independent branching only — each subtask's `auto-do/<id>` branch is created off `<base-sha>`; PRs target `<default>`. Epic-branch mode is deferred to v2.

### 6. Wave-based dispatch loop

For each wave until termination:

1. **Compute the ready set.** Rows whose `status == queued` AND every parent's `status` ∈ `{succeeded, skipped}`. Take first up to `--max-parallel` in manifest order.

2. **Per-row idempotency check** (one at a time, in main thread). Run `git branch --list auto-do/<id>` AND `git ls-remote --heads origin auto-do/<id>`. Run `gh pr list --head auto-do/<id> --state all --json number,state,url --jq '.'`. Capture two flags: `local_exists` ∈ `{true, false}` (from `git branch --list`) and `remote_exists` ∈ `{true, false}` (from `git ls-remote --heads`). If any of `local_exists` / `remote_exists` / PR is non-empty, surface via `AskUserQuestion`:
   - **Question**: "Branch `auto-do/<id>` already exists (prior PR: `<state-or-none>`). Skip, dispatch anyway, or cancel?"
   - **Header**: "Idempotency gate"
   - **Options**:
     - "Skip *(Recommended)*" — mark row `skipped` in memory, capture prior `pr` URL if any, remove from this wave's selection.
     - "Dispatch anyway" — proceed; the existing branch will be reused (`/auto-do`'s `rev-list 0 → reuse it` logic). Step 6.3 below handles branch reuse vs creation per `local_exists`.
     - "Cancel" — set `Final status: halted:branch-collision-cancel`, break out of scheduler, jump to step 8.

3. **Sequential worktree + branch creation** (still in main thread, before any sub-agent dispatch). For each row in the wave's surviving selection:
   - `git worktree add --detach .claude/auto-fleet/wt-<slug>-<id> <base-sha>`. If this fails (e.g. another worktree already exists at the path), classify the row as `failed` with `failure_class: infra`, cascade-block its dependents, skip dispatch for this row.
   - **Branch placement** — depends on whether `auto-do/<id>` already exists locally and/or remotely (captured during the idempotency check; for rows that didn't trigger the gate, both flags are `false`):
     - **Neither local nor remote exists**: `git -C <path> checkout -b auto-do/<id>` creates the branch from the just-detached HEAD at `<base-sha>`.
     - **Local exists** (regardless of remote — only reachable via "Dispatch anyway"): `git -C <path> checkout auto-do/<id>` checks out the existing local branch into the worktree. Branch tip may differ from `<base-sha>` — user's explicit reuse choice.
     - **Remote-only exists** (only reachable via "Dispatch anyway" with `local_exists=false && remote_exists=true`): `git fetch origin auto-do/<id>` then `git -C <path> checkout -b auto-do/<id> --track origin/auto-do/<id>`. Tracks the remote branch so subsequent pushes target it; the worktree's HEAD lands at the remote branch's tip, not at `<base-sha>`. This is the "stale remote from a prior crashed run" path the user explicitly chose to resume.
     - On any failure (branch checked out in another worktree, fetch error, conflicting refs), classify the row as `failed` with `failure_class: infra`, cascade-block, skip.
   - On success, mark the row `running` in memory.

4. **Parallel sub-agent dispatch.** Single message containing K `Agent` tool calls (subagent_type: `general-purpose`). Each agent's prompt:
   - Working directory: the worktree path. Agent must `cd` to it before any operation.
   - Pre-conditions: clean working tree; current branch is `auto-do/<id>`; divergence from `<default>` is 0; this is a fresh detached-then-branched checkout, so no untracked runtime state (`.env`, `node_modules`, etc.) is present.
   - Task: read `commands/auto-do.md` from `.claude/commands/auto-do.md` (project) then `~/.claude/commands/auto-do.md` (user). Execute its numbered steps inline with its auto-decision policy.
   - Slug override: skip `/auto-do` step 1's slug-derivation and collision-suffix logic. Use `<id>` as the slug verbatim. The branch is already created.
   - Argument: `<description>` from this row passed as `$ARGUMENTS` to `/auto-do`.
   - **Per-row timeout: best-effort, not enforced by the runtime.** Agent tool calls have no caller-side timeout primitive in v1's runtime; main thread cannot strictly cap a hung sub-agent. Each agent's prompt SHOULD include "if your wall-clock exceeds 60 min, emit `RESULT: status=failed:timeout branch=auto-do/<id> pr=` and exit" so a self-aware sub-agent self-classifies. A genuinely runaway sub-agent will block the wave indefinitely; the user must cancel manually (Esc / Ctrl-C). Documented v1 limitation; runtime-enforced timeout is a v1.5+ feature.
   - **RESULT-line protocol.** The agent's last text response MUST include at least one line of the form: `RESULT: status=<token> branch=<auto-do/<id>> pr=<url-or-empty>`. The `<token>` is `/auto-do`'s `Final status:` line value verbatim. **If multiple `RESULT:` lines appear, the LAST one wins** (LLM sub-agents may echo the protocol while explaining what they're going to do; only the final emission counts). Missing `RESULT:` line entirely or unparseable last RESULT line → main thread classifies the row as `failed` with `failure_class: protocol-violation`.

5. **Wait for all K sub-agents to complete.** Main thread blocks until every agent returns. Self-classified `failed:timeout` rows (per the 60-min self-policing prompt above) come back through the same RESULT line as any other terminal status; runaway sub-agents that don't self-classify will block the wave indefinitely and require manual cancellation. v1 limitation.

6. **Per-row outcome classification** (parse each agent's RESULT line):
   - `status=success` → row state `succeeded`. Capture branch + PR URL.
   - `status=failed:round-2-must-fix` | `failed:test-gate` | `failed:complexity-smell` | `failed:ambiguity` → row `failed`; `failure_class: task`.
   - Self-classified `status=failed:timeout` (sub-agent hit its 60-min self-policing limit) → row `failed`; `failure_class: infra`.
   - Worktree/branch create error during step 6.3 → row `failed`; `failure_class: infra`.
   - Anything else, RESULT line missing, or unparseable → row `failed`; `failure_class: protocol-violation`. Capture first 200 chars of the agent's response into the row's annotation (surfaced at step 8).

7. **Cascade-block.** For each row that ended `failed` in this wave, run the cascade-block algorithm: BFS over the inverted dep graph, mark all `queued` descendants as `blocked` with `blocked_by: <failed-row-id>`. (See **Cascade-block algorithm** above.)

8. **Worktree teardown per row.**
   - `succeeded`: `git worktree remove --force <path>` then `rm -rf <path>`.
   - `failed`: leave worktree on disk; capture path for the user-facing report.

9. **Loop.** If any rows are still `queued` and their parents are all `succeeded`/`skipped`, run the next wave. Otherwise terminate the scheduler and continue to step 8.

### 7. (No standalone step 7.)

Per-task PR-body fleet-context headers are deferred to step 8 so `<manifest-url>` resolves after the manifest is pushed.

### 8. Final fleet report

This is the only place `/auto-fleet` writes to disk, commits, and pushes. Single commit per fleet run.

1. **Verify the working tree is clean before any disk action.** Main thread should still be on `fleet/<slug>` (it never `cd`s into worktrees; only sub-agents do). Run `git status --porcelain` on the main worktree. If non-empty, bail without checkout / write / commit / push: "Main thread's working tree is unexpectedly dirty. Cannot safely commit fleet manifest. Investigate manually." (Sub-agent worktrees are still on disk for failed rows; their dirtiness doesn't affect main.)
2. **Confirm we're on `fleet/<slug>`.** `git symbolic-ref --short HEAD` must equal `fleet/<slug>`. If somehow not, attempt `git checkout fleet/<slug>` (with the dirty-tree guard above).
3. **Final hash check before writing.** Re-read `docs/fleet/<slug>.md` from disk and compute SHA-256. If it differs from `<initial-hash>` from step 2, bail without writing: "Manifest was edited externally during this run. Refusing to clobber. Inspect and reset manually if needed." (User-facing report only; no manifest update.)
4. **Compose the final manifest in memory:**
   - Rewrite the `## Subtasks` table to reflect each row's terminal state. Preserve the schema variant the user authored (v0.1 vs v1).
   - Append a `## Fleet outcome` section with:
     - **Counts**: `<succeeded> succeeded / <failed> failed / <skipped> skipped / <blocked> blocked / <remaining> queued-remaining`.
     - **Wave breakdown**: one line per wave: `Wave 1: 3 dispatched (rows X, Y, Z); 2 succeeded, 1 failed (Y, failure_class: task)`.
     - **Cascade-block report**: per blocked row: `Row D blocked: depends on row B which failed (failure_class: task).`
     - **Failed-row debugging hints**: per failed row whose worktree was preserved: `Row B's worktree preserved at .claude/auto-fleet/wt-<slug>-B/ for inspection. Run `git worktree remove --force` after debugging.`
     - **Unrecognised /auto-do reports** (if any): `### Unrecognised /auto-do report — <id>` subsection with first 200 chars of the agent's response.
     - **PRs created** as a markdown bullet list of every PR URL.
     - **`Final status:`** exactly one of:
       - `succeeded` — every queued row reached `succeeded` or `skipped`; no `failed`, no `blocked`, no queued-remaining.
       - `halted:partial-failures` — at least one row ended `failed` or `blocked`. Includes scheduler ran-to-completion-with-failures.
       - `halted:user-cancel`, `halted:branch-collision-cancel`, `halted:manifest-tampered`, `halted:dirty-tree` — early exits before scheduler ran (same semantics as v0.1).
     - **`Fleet auto-decisions:`** bullet list of every gate `/auto-fleet` raised (orphan-cleanup, idempotency per-row, confirmation) and how the user answered.
   - Update YAML key `last_updated` in frontmatter to current ISO-8601 timestamp.
5. **Single disk write** to `docs/fleet/<slug>.md`.
6. **Single commit**: `git add docs/fleet/<slug>.md && git commit -m "/auto-fleet <slug>: <Final status>"`.
7. **Single push**: `git push --set-upstream origin fleet/<slug>`. If rejected (branch protection, lost permissions), the local commit is preserved; report the rejection clearly; **per-task PR-body header step below is skipped** (manifest URL would 404).
8. **Per-task PR-body fleet-context headers** (deferred from step 6 so `<manifest-url>` resolves). For each row whose `pr` is set (`succeeded` rows + skipped rows that captured a prior PR), edit the PR body once to prepend: `## Fleet context\n\nPart of fleet [<slug>](<manifest-url>) — see manifest for sibling status.\n\n` where `<manifest-url>` is the GitHub URL of `docs/fleet/<slug>.md` on the now-pushed `fleet/<slug>` branch. Use `gh pr edit <pr> --body-file <tmp>`. Skip if step 8.7 was rejected.

### 9. Final report to the user

Print:

- The fleet's `Final status:`.
- Counts by row state.
- Wave breakdown (one line per wave).
- Cascade-block summary if any.
- PRs created (URLs).
- The control-plane branch (`fleet/<slug>`) and where the manifest lives on GitHub.
- **Failed-row worktree paths** for any rows that need manual inspection + cleanup.
- If halted: the specific reason and what manual action is needed.

## Failure modes summary

| Trigger | Behaviour | `Final status:` |
|---------|-----------|-----------------|
| Dirty working tree at start | Bail at step 1 before any change | n/a |
| On default branch | Bail at step 1 | n/a |
| Branch name not `fleet/<slug>` | Bail at step 1 | n/a |
| `fleet/<slug>` has commits ahead of `<default>` touching files other than the manifest | Bail at step 1 (divergence guard) | n/a |
| Tracked `.claude/auto-fleet/` directory | Bail at step 1 | n/a |
| `--max-parallel` outside `[1, 5]` | Bail at step 1 | n/a |
| Manifest missing | Bail at step 1 | n/a |
| Manifest invalid (id regex / desc / cycle / forward-ref / column count) | Bail at step 2 | n/a |
| Manifest frontmatter `slug` mismatch | Bail at step 2 | n/a |
| > 10 queued rows | Bail at step 2 | n/a |
| Stuck `running` rows on disk | Bail at step 3 | n/a |
| Pre-existing `failed` or `blocked` rows on disk | Bail at step 3 (manual reset to `queued` or `skipped`) | n/a |
| User cancels at confirmation gate | Halt; continue to step 8 | `halted:user-cancel` |
| Branch collision, user cancels | Halt; continue to step 8 | `halted:branch-collision-cancel` |
| Worktree-create fails for a row | Row `failed` (failure_class: infra); cascade-block dependents; continue | scheduler runs to termination |
| Branch-create fails for a row | Row `failed` (failure_class: infra); cascade-block dependents; continue | scheduler runs to termination |
| Sub-agent self-reports `failed:timeout` (60-min self-policing) | Row `failed:timeout` (failure_class: infra); cascade-block dependents; continue | scheduler runs to termination |
| Sub-agent runs away without self-reporting | Wave blocks indefinitely; user cancels manually (v1 limitation) | n/a |
| Sub-agent RESULT line missing/unparseable | Row `failed` (failure_class: protocol-violation); cascade-block dependents; continue | scheduler runs to termination |
| Subtask round-2 must-fix | Row `failed` (failure_class: task); cascade-block dependents; continue | scheduler runs to termination |
| Subtask test gate | Row `failed` (failure_class: task); cascade-block dependents; continue | scheduler runs to termination |
| Subtask complexity smell | Row `failed` (failure_class: task); cascade-block dependents; continue | scheduler runs to termination |
| Subtask `/auto-do` ambiguity | Row `failed` (failure_class: task); cascade-block dependents; continue | scheduler runs to termination |
| `gh` rate limit during a sub-agent's `gh pr create` | Row `failed` (failure_class: infra typically; depends on how `/auto-do` reports); cascade-block dependents; continue | scheduler runs to termination |
| Manifest tampered externally during run | Detected at step 8 hash check; refuses to clobber | `halted:manifest-tampered` (user-facing report only) |
| Main thread's working tree dirty at step 8 | Bail at step 8 before checkout/write | `halted:dirty-tree` (user-facing report only) |
| Final push rejected (branch protection, perms) | Local commit preserved; per-task PR-header step skipped | reported as the fleet's `Final status:` plus a separate "push rejected" line |
| All rows `succeeded` or `skipped`, no `failed`, no `blocked` | Normal completion | `succeeded` |
| At least one row ended `failed` or `blocked` | Scheduler ran to termination | `halted:partial-failures` |

## Known v1 limitations

- No `--resume` flag; crashed runs require manual manifest reset + worktree cleanup (orphan reconciliation at next pre-flight helps).
- No `--keep-going` flag — cascade-block IS productive-mode.
- No `--max-tasks` override — cap is hard at 10 queued rows.
- No epic-branch mode; subtask PRs always target the default branch's pinned SHA. **`depends_on` is dispatch-ordering only**, NOT code-deps.
- No file-overlap detection between parallel rows (v1.5+).
- No incremental scheduling (slot-frees-dispatch-next vs wave-based) (v1.5+).
- No dispatch-staggering (wave dispatches all rows at once; rate-limit failures become row-level `failure_class: infra`).
- No concurrent-fleet protection (no lock file). Behaviour undefined if two `/auto-fleet` invocations run in parallel.
- Per-row timeout is **self-policing only** in v1: each sub-agent's prompt instructs it to self-emit `failed:timeout` after 60 min wall-clock. The runtime cannot enforce this from main thread (Agent tool calls have no caller-side timeout primitive); a runaway sub-agent that ignores the self-policing instruction will block the wave until the user cancels manually. Runtime-enforced per-row timeout is a v1.5+ feature.
- **Untracked runtime state** (`.env`, `node_modules`, virtualenvs, build artifacts) is NOT carried into worktrees. v1 only suits `/auto-do` tasks runnable in a fresh checkout.
- Manifest is markdown-table-with-frontmatter; mainstream fleet runners use YAML/JSON. Documented limitation.
- Single-writer manifest at step 8; mid-run hash-tamper detection has no recovery path beyond "refuse to clobber and exit."
- Crashed runs lose in-memory scheduler state. PRs/branches/worktrees persist; orphan reconciliation at next invocation is the cleanup path.
- Manifest data model is intentionally thin (`id`, `description`, `status`, `depends_on`, `branch`, `pr`); no retry counts, started/finished timestamps, or error-detail columns.
- See `docs/plans/auto-fleet-parallel.md` Engineering Review block for the full deferred-items list.
