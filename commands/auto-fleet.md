---
description: Autonomous fleet runner — dispatches /auto-do per row in a user-authored manifest at docs/fleet/<slug>.md, halts on first failure, persists state in the manifest itself. v0.1 is serial-only with a 5-subtask hard cap, independent branching, and no merging. The fleet's own commits live on a fleet/<slug> control-plane branch the user must create off the default branch before invoking.
argument-hint: <slug>
---

The fleet sibling of `/auto-do`. Where `/auto-do` runs one task end-to-end, `/auto-fleet` runs N tasks sequentially from a user-authored manifest, dispatching `/auto-do` per row and persisting state (`status`, `branch`, `pr`) back into the manifest. v0.1 is intentionally thin: a serial dispatcher, not a planner, not a parallelism engine, never auto-merging.

User arguments: $ARGUMENTS

## What v0.1 is (and isn't)

- **Is** — a serial loop that reads `docs/fleet/<slug>.md`, dispatches `/auto-do` per `queued` row, halts on first failure, and writes one commit at the end on a `fleet/<slug>` control-plane branch. Row state lives **in memory** during the run; a single disk write + commit + push happens at fleet end (or at any halt).
- **Is not** — a planner. The manifest is user-authored; `/auto-fleet` does not produce subtasks. No `--keep-going`, no `--max-tasks`, no epic-branch mode, no `--resume`, no auto-stub creation. These are all v1+ concerns.

## How `/auto-fleet` orchestrates `/auto-do`

Same pattern `/auto-do` uses for `/plan`, `/review-pr`, etc. — markdown skill orchestrating a sibling markdown skill via file-read at runtime. Brittle coupling acknowledged.

1. **Read `commands/auto-do.md` from its install location.** Project scope first (`.claude/commands/auto-do.md`), then user scope (`$HOME/.claude/commands/auto-do.md`). If neither resolves, bail with: "/auto-fleet can't find `commands/auto-do.md` in `.claude/commands/` or `~/.claude/commands/`. Reinstall the workshop."
2. **Apply `/auto-do`'s numbered steps inline** with its auto-decision policy. Pass the row's `description` as `$ARGUMENTS`. **Override `/auto-do` step 1's slug derivation** to use the row's `id` verbatim (so the resulting branch is exactly `auto-do/<id>` — the same branch `/auto-fleet`'s idempotency check looks for).
3. **Read `/auto-do`'s `Final status:` line** from its final report to classify the row's terminal state (see step 6 outcome classification).

## Auto-decision policy

`/auto-fleet` itself takes the following defaults at every gate it raises. (`/auto-do` applies its own policy when invoked; `/auto-fleet` does not override.)

- **Idempotency gate (existing branch / PR)** → `Skip`. A pre-existing `auto-do/<id>` branch (or any PR for it) most likely means the row already ran; skipping is safer than re-dispatching.
- **Confirmation gate (step 4)** → fires unconditionally; user always approves dispatch. Even in auto-mode-from-/auto-do, fleet dispatch is the largest single decision the workshop ever makes.
- **No other gates.** Resumability bails (manual reset only), branching is fixed, hash mismatch halts. There are no additional `AskUserQuestion` decision points.

## Hard safety rules

- **Never push to the default branch.** Pre-flight refuses to run on the default branch.
- **Never `--force`, `--force-with-lease`, or `--no-verify`.**
- **Never merge any PR.**
- **Never run more than one `/auto-do` at once.** Serial only in v0.1.
- **Never auto-slice the manifest.** Manual authoring only.
- **Never proceed past first failed subtask.** No `--keep-going`.
- **Never silently re-run a `running` row.** Bail with manual-reset instructions.
- **Never write to the manifest after detecting external edits.** SHA-256 hash check.
- **Never write to the manifest mid-fleet.** All row-state transitions are in-memory until the final report (step 8). Writing mid-fleet would dirty the working tree on the `fleet/<slug>` branch and cause `/auto-do`'s pre-flight (`git status --porcelain` must be empty) to bail before any subtask runs.

## Manifest format

Path: `docs/fleet/<slug>.md`. The user authors this file before invoking `/auto-fleet`.

```markdown
---
slug: api-logging
created: 2026-05-01
last_updated:
---

## Subtasks

| id            | description                                          | status | branch | pr |
|---------------|------------------------------------------------------|--------|--------|----|
| users-log     | Add request-logging middleware to /users routes      | queued |        |    |
| orders-log    | Add request-logging middleware to /orders routes     | queued |        |    |
| products-log  | Add request-logging middleware to /products routes   | queued |        |    |
```

> **A note on the format.** Markdown-table-with-frontmatter is an *agent-tooling* idiom (used by skills, agent prompt formats); mainstream fleet runners (multi-gitter, OpenRewrite, Argo Workflows, GitHub Actions matrix) use YAML or JSON. The choice here is deliberate — the manifest lives next to other markdown docs in `docs/`, renders cleanly when reviewed in any markdown viewer, and is easy for humans to edit. The trade-off is that table parsing is fragile (hence the description-text constraints below) and the manifest is awkward to validate programmatically.

### Manifest constraints (validated at step 2)

- `slug` in frontmatter **must equal** `$ARGUMENTS` (the slug `/auto-fleet` was invoked with).
- `description` text must not contain `|`, backticks, markdown link syntax `[...](...)`, or newlines. Naive table rewriting is unsafe with these characters; reject the row with a clear error.
- `id` must be unique within the manifest and slug-safe (kebab-case, lowercase ASCII alphanumerics + hyphens, ≤ 50 chars).
- `status` must be one of `queued | running | succeeded | failed | skipped`. (Names follow Argo Workflows / Temporal / GitHub Actions convention; `succeeded` pairs with `failed`.)
- Row count where `status == queued` must be **≤ 5**. This is a v0.1 guard rail — small enough that "break the task into multiple smaller fleets" is the recommended escape — not a permanent design point. Mainstream fleet runners (multi-gitter, OpenRewrite, SWE-bench harness) have no cap or run hundreds; v0.1 keeps blast radius small until real usage justifies raising it.
- `last_updated` is a YAML key in frontmatter; `/auto-fleet` writes its value as an ISO-8601 timestamp once at fleet end.

### Manifest state machine

v0.1 holds `running` **in memory only** — the manifest on disk transitions directly from `queued` to a terminal state (`succeeded` / `failed` / `skipped`) at fleet end. Writing `running` to disk mid-fleet would dirty the working tree and prevent `/auto-do`'s pre-flight from passing.

```
                  ┌───────────┐
   ┌────────────► │ succeeded │
   │              └───────────┘
   │
[queued] ──► (running, in memory) ─┐
   │                ▲              │
   │                │              ├─► [failed]   (halts the fleet)
   │                │              │
   │                │              └─► [skipped]  (idempotency-gate skip)
   │                │
   │      manual-reset only (v0.1: edit the file)
   └────────────────┘
```

## Control-plane branch

`/auto-fleet` operates only on a `fleet/<slug>` branch the user creates off default before invoking. Step 1 refuses to run on the default branch. The fleet branch holds **only the manifest** — no code changes — and is never merged. It is the durable record of the fleet run.

Subtask branches (`auto-do/<row-id>`) are created off the **default branch**, not the fleet branch, by `/auto-do` itself. Their PRs target default. The fleet branch and the subtask branches are siblings, not stacked. This separates the control plane (manifest) from the data plane (code).

When `/auto-do` returns, the working tree is on `auto-do/<id>`. The dispatch loop **stays on whatever branch `/auto-do` left it on** between iterations (no checkout-back), because no disk write happens between iterations. Step 8 is the only place we write to the manifest, and it explicitly checks out `fleet/<slug>` first.

## Steps

### 1. Pre-flight

- `git rev-parse --show-toplevel` — must be in a repo. Bail if not.
- `git status --porcelain` — must be empty. Bail with: "/auto-fleet refuses to start with a dirty working tree. Commit, stash, or revert first."
- `gh auth status` — must pass. Bail with: "/auto-fleet needs `gh` authenticated; run `gh auth login` and retry."
- Detect and capture the default branch: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` (fallback `main`). Store as `<default>`.
- **Refuse to run on the default branch.** Current branch must be `fleet/<slug>` where `<slug>` matches `$ARGUMENTS`. Bail with: "/auto-fleet must run on a `fleet/<slug>` branch off `<default>`. Create one with `git checkout -b fleet/<slug> <default>` and re-invoke."
- Verify `gh` version supports `gh pr ready --undo` (used transitively by `/auto-do`'s round-2 safe-stop). Same check `/auto-do` does; record the chosen mode.
- Derive `<slug>` from `$ARGUMENTS` using the same kebab-case validation `/auto-do` uses. Cap at 50 chars (manifest path length headroom).
- Confirm `docs/fleet/<slug>.md` exists. If missing, bail with: "Author a manifest at `docs/fleet/<slug>.md` first — see manifest format in `commands/auto-fleet.md` — then re-invoke." No stub creation in v0.1.

### 2. Read + validate the manifest

- Read `docs/fleet/<slug>.md`. Parse YAML frontmatter (must include keys: `slug`, `created`, `last_updated`).
- Verify frontmatter `slug == $ARGUMENTS`. Bail on mismatch.
- Locate the `## Subtasks` section. Parse the markdown table beneath it.
- For each row, validate the constraints listed under **Manifest constraints** above. Reject any invalid row with a clear error naming the specific violation; do not partially proceed.
- Count rows where `status == queued`. Must be `> 0` (else "no queued work, exiting") and `<= 5` (else "v0.1 hard cap of 5 exceeded — break this fleet up").
- Compute SHA-256 of the manifest's full byte contents. Store in memory as `<initial-hash>` for tamper detection. The hash is captured **once** and never recomputed during the run, because `/auto-fleet` does not write to disk between iterations.

### 3. Resumability check

- If any row has `status == running`, bail without modifying anything: "<N> rows are stuck in `running` state from a prior run or external edit. Edit `docs/fleet/<slug>.md` manually to reset them to `queued` (or mark `failed`/`skipped`), then re-invoke. v0.1 does not auto-reset." (Note: in v0.1 this state should never appear from `/auto-fleet`'s own writes, since `running` is in-memory only — but a manual edit or future `--resume` could leave it on disk.)

### 4. Confirmation gate

Surface via `AskUserQuestion`:

- **Question**: "This fleet will run /auto-do <N> times sequentially. Each run can take 5–30 minutes and consumes LLM + CI budget. Proceed?"
- **Header**: "Confirm fleet dispatch"
- **Options**:
  - "Run" *(Recommended)*
  - "Cancel"

On Cancel: hold `Final status: halted:user-cancel` in memory and continue to step 8 (which writes + commits + pushes).

### 5. Branching is fixed

No question is asked here. v0.1 supports independent branching only — each subtask's `/auto-do` creates `auto-do/<id>` off `<default>` and opens a PR targeting `<default>`. Epic-branch mode is deferred to v1.

### 6. Dispatch loop

For each row in `queued` order (table order). All state changes during this loop are **in memory only** — no disk writes, no commits, no pushes happen until step 8.

1. **Idempotency check.** Run `git branch --list auto-do/<id>` and `git ls-remote --heads origin auto-do/<id>` to detect the branch. Also run `gh pr list --head auto-do/<id> --state all --json number,state,url --jq '.'` to detect any prior PR for that branch (open, closed, or merged). If any of these are non-empty, surface via `AskUserQuestion`:
   - **Question**: "Branch `auto-do/<id>` already exists (prior PR: `<state-or-none>`). Skip this row, dispatch anyway, or cancel the fleet?"
   - **Header**: "Idempotency gate"
   - **Options**:
     - "Skip *(Recommended)*" — mark row `skipped` in memory, continue the loop. Capture the prior `pr` URL (if any) into the row.
     - "Dispatch anyway" — proceed to the next bullet. (`/auto-do` will still bail at its own pre-flight if the branch state is unsuitable.)
     - "Cancel" — set `Final status: halted:branch-collision-cancel` in memory, break out of the loop, continue to step 8.

2. **Hash check.** Re-read `docs/fleet/<slug>.md` from disk. Compute SHA-256. Compare to `<initial-hash>` from step 2. **If different**, set `Final status: halted:manifest-tampered` in memory, break out of the loop, continue to step 8 — but step 8 will detect the tamper itself and **refuse to write**, so the on-disk manifest stays as the user left it. Surface this clearly to the user.

3. **Mark row `running` in memory only.** Update the in-memory table; do **not** write to disk. (Writing mid-fleet would dirty the working tree and prevent `/auto-do`'s pre-flight from passing.)

4. **Dispatch `/auto-do`.** Read `commands/auto-do.md` from `.claude/commands/` (project) then `~/.claude/commands/` (user). Execute its numbered steps inline with its auto-decision policy, against `<description>` from the row, with this **explicit override**: `/auto-do` step 1's slug derivation produces `<id>` verbatim (do not re-derive from the description). The resulting branch is `auto-do/<id>`; the resulting PR targets `<default>`. `/auto-do` leaves the working tree on `auto-do/<id>` when it returns; `/auto-fleet` does not switch back between iterations (the next iteration's `/auto-do` step 1 will branch from `<default>` correctly via its own branch-selection logic — see `commands/auto-do.md` step 1 "branch selection").

5. **Outcome classification.** Read `/auto-do`'s final report. Match its `Final status:` line:
   - `Final status: succeeded` → row state `succeeded`. Capture `branch = auto-do/<id>` and `pr = <pr-url>` into the row in memory.
   - `Final status: failed:round-2-must-fix` | `failed:test-gate` | `failed:complexity-smell` → row state `failed`. Capture whichever of `branch`/`pr` exist into the row; the rest stay blank. Set the fleet's `Final status:` to `halted:round-2-failure` / `halted:test-gate` / `halted:complexity-smell` accordingly.
   - Anything else, or `Final status:` line missing → row state `failed` with note "unrecognised /auto-do report" attached. Set the fleet's `Final status:` to `halted:unrecognised-auto-do-report`.

6. **Per-task PR header.** If a PR was created (the `pr` field is set), edit its body **once** to prepend the line: `## Fleet context\n\nPart of fleet [<slug>](<manifest-url>) — see manifest for sibling status.\n\n` (where `<manifest-url>` is the GitHub URL of `docs/fleet/<slug>.md` on the `fleet/<slug>` branch). No sibling cross-linking. No final-status echo. Use `gh pr edit <pr> --body-file <tmp>`.

7. **If row state is `failed`**, break out of the dispatch loop. Continue to step 8 immediately.

### 7. (Removed)

Per-task PR header was previously a separate step; it now lives as item 6 inside the dispatch loop. No standalone step 7.

### 8. Final fleet report

This is the only place `/auto-fleet` writes to disk, commits, and pushes. Single commit per fleet run.

1. **Switch back to the fleet branch.** Run `git checkout fleet/<slug>`. (The last `/auto-do` likely left the working tree on `auto-do/<id>`; we must return to the control-plane branch before any disk write.) Because `/auto-fleet` held all state in memory during the dispatch loop, the fleet branch's working tree is clean — no merge / stash / restore is needed.
2. **Final hash check before writing.** Re-read `docs/fleet/<slug>.md` from disk and compute SHA-256. If it differs from `<initial-hash>` from step 2, halt without writing and without committing — the on-disk manifest stays as the user left it. Print: "Manifest was edited externally during this run. The fleet has been halted to prevent clobbering your edits. Inspect `docs/fleet/<slug>.md` and reset row states manually if needed." Exit. (When this fires, the fleet's outcome lives only in the user-facing report from step 9; nothing on disk records the run. v0.1 limitation.)
3. **Compose the final manifest in memory:**
   - Rewrite the `## Subtasks` table to reflect each row's terminal state (`succeeded` / `failed` / `skipped` / `queued`-remaining for rows after a halt).
   - Append a `## Fleet outcome` section with:
     - Row-state counts: `<succeeded> succeeded / <failed> failed / <skipped> skipped / <remaining> queued-remaining`.
     - `PRs created:` followed by a markdown bullet list of every PR URL captured in this run (including any captured by the idempotency-gate skip path).
     - `Final status:` exactly one of `succeeded` (all rows `succeeded`), `halted:round-2-failure`, `halted:test-gate`, `halted:complexity-smell`, `halted:unrecognised-auto-do-report`, `halted:manifest-tampered` (for the in-memory case where step 6's hash check fired but step 8's didn't), `halted:branch-collision-cancel`, `halted:user-cancel`.
     - `Fleet auto-decisions:` followed by a bullet list of every gate `/auto-fleet` raised (idempotency, confirmation, hash) and how it answered. (`/auto-do`'s own log lives in each PR body — do not duplicate.)
   - Update YAML key `last_updated` in frontmatter to the current ISO-8601 timestamp.
4. **Single disk write** to `docs/fleet/<slug>.md`.
5. **Single commit**: `git add docs/fleet/<slug>.md && git commit -m "/auto-fleet <slug>: <Final status>"`.
6. **Single push**: `git push --set-upstream origin fleet/<slug>`. If the push is rejected (branch protection, lost permissions), the local commit is preserved on `fleet/<slug>`; surface the rejection clearly so the user can push manually or unblock.

### 9. Final report to the user

Print to the user:

- The fleet's `Final status:`.
- Counts of `succeeded` / `failed` / `skipped` / `queued-remaining`.
- The list of PRs created (URLs).
- The control-plane branch (`fleet/<slug>`) and where the manifest lives on GitHub.
- If halted: the specific reason and what manual action is needed (e.g. "edit the manifest to reset `running` rows" or "investigate the round-2-must-fix on PR <url>").

## Failure modes summary

| Trigger | Behaviour | `Final status:` |
|---------|-----------|-----------------|
| Dirty working tree | Bail at step 1 before any change | n/a (no manifest update) |
| On default branch | Bail at step 1 | n/a |
| Manifest missing | Bail at step 1 | n/a |
| Manifest invalid (description has `\|`, etc.) | Bail at step 2 | n/a |
| > 5 queued rows | Bail at step 2 | n/a |
| Stuck `running` rows on disk | Bail at step 3 | n/a |
| User cancels at confirmation gate | Halt; continue to step 8 | `halted:user-cancel` |
| Branch collision, user cancels | Halt; continue to step 8 | `halted:branch-collision-cancel` |
| Manifest tampered (detected mid-loop) | Break loop; step 8's hash check refuses to write | `halted:manifest-tampered` (user-facing report only; no manifest update) |
| Subtask round-2 must-fix | Halt at end of dispatch | `halted:round-2-failure` |
| Subtask test gate | Halt at end of dispatch | `halted:test-gate` |
| Subtask complexity smell | Halt at end of dispatch | `halted:complexity-smell` |
| `/auto-do` returns unrecognised report | Halt at end of dispatch | `halted:unrecognised-auto-do-report` |
| Final commit push rejected | Local commit preserved; user does manual push | `succeeded` (or whatever the fleet ran with); the push failure is reported separately |
| All subtasks `succeeded` | Normal completion | `succeeded` |

## Known v0.1 limitations

- No `--resume` flag; crashed runs require manual manifest reset.
- No `--keep-going`; first failure halts the fleet.
- No `--max-tasks` override; cap is hard at 5.
- No epic-branch mode; subtask PRs always target the default branch.
- Manifest data model is intentionally thin (`id`, `description`, `status`, `branch`, `pr`); no retry counts, started/finished timestamps, or error-detail columns. Revisit after first three real runs.
- **Progress is in-memory only during a run.** The on-disk manifest shows rows as `queued` until the fleet completes (or halts at step 8). A user peeking at the manifest mid-fleet sees stale state. A separate per-row results file outside the manifest (option-(b) in the research notes — `runs/<run-id>.json`) is the v1 path if observability becomes a real ask.
- **Crashed runs lose in-memory state.** A `/auto-fleet` process crash between dispatches leaves the manifest unchanged on disk; previously-completed rows revert to `queued`. The idempotency gate catches re-dispatching of already-completed rows on next invocation (it sees the existing branch + PR and recommends `Skip`), but the user must manually mark already-succeeded rows as `succeeded` if they care about a clean record.
- **`gh` rate-limit / forked-repo / protected-branch failures** bubble up as `/auto-do` failures and halt the fleet; `/auto-fleet` does not handle them specially in v0.1. A push rejection at step 8.6 is reported but not retried.
- See `docs/plans/auto-fleet.md` Engineering Review block for the full deferred-items list.
