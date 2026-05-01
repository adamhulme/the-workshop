---
description: Autonomous fleet runner — dispatches /auto-do per row in a user-authored manifest at docs/fleet/<slug>.md, halts on first failure, persists state in the manifest itself. v0.1 is serial-only with a 5-subtask hard cap, independent branching, and no merging. The fleet's own commits live on a fleet/<slug> control-plane branch the user must create off the default branch before invoking.
argument-hint: <slug>
---

The fleet sibling of `/auto-do`. Where `/auto-do` runs one task end-to-end, `/auto-fleet` runs N tasks sequentially from a user-authored manifest, dispatching `/auto-do` per row and persisting state (`status`, `branch`, `pr`) back into the manifest. v0.1 is intentionally thin: a serial dispatcher, not a planner, not a parallelism engine, never auto-merging.

User arguments: $ARGUMENTS

## What v0.1 is (and isn't)

- **Is** — a serial loop that reads `docs/fleet/<slug>.md`, dispatches `/auto-do` per `queued` row, marks the row `done` or `failed`, halts on first failure, writes one commit at the end on a `fleet/<slug>` control-plane branch.
- **Is not** — a planner. The manifest is user-authored; `/auto-fleet` does not produce subtasks. No `--keep-going`, no `--max-tasks`, no epic-branch mode, no `--resume`, no auto-stub creation. These are all v1+ concerns.

## How `/auto-fleet` orchestrates `/auto-do`

Same pattern `/auto-do` uses for `/plan`, `/review-pr`, etc. — markdown skill orchestrating a sibling markdown skill via file-read at runtime. Brittle coupling acknowledged.

1. **Read `commands/auto-do.md` from its install location.** Project scope first (`.claude/commands/auto-do.md`), then user scope (`$HOME/.claude/commands/auto-do.md`). If neither resolves, bail with: "/auto-fleet can't find `commands/auto-do.md` in `.claude/commands/` or `~/.claude/commands/`. Reinstall the workshop."
2. **Apply `/auto-do`'s numbered steps inline** with its auto-decision policy. Pass the row's `description` as `$ARGUMENTS`. **Override `/auto-do` step 1's slug derivation** to use the row's `id` verbatim (so the resulting branch is exactly `auto-do/<id>` — the same branch `/auto-fleet`'s idempotency check looks for).
3. **Read `/auto-do`'s `Final status:` line** from its final report to classify the row's terminal state (see step 6 outcome classification).

## Auto-decision policy

`/auto-fleet` itself takes the following defaults at every gate it raises. (`/auto-do` applies its own policy when invoked; `/auto-fleet` does not override.)

- **Idempotency gate (existing branch)** → `Skip`. A pre-existing `auto-do/<id>` branch most likely means the row already ran; skipping is safer than re-dispatching.
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

### Manifest constraints (validated at step 2)

- `slug` in frontmatter **must equal** `$ARGUMENTS` (the slug `/auto-fleet` was invoked with).
- `description` text must not contain `|`, backticks, markdown link syntax `[...](...)`, or newlines. Naive table rewriting is unsafe with these characters; reject the row with a clear error.
- `id` must be unique within the manifest and slug-safe (kebab-case, lowercase ASCII alphanumerics + hyphens, ≤ 50 chars).
- `status` must be one of `queued | running | done | failed | skipped`.
- Row count where `status == queued` must be **≤ 5** (hard cap, no flag override).
- `last_updated` is a YAML key in frontmatter; `/auto-fleet` writes its value as an ISO-8601 timestamp on every disk-write.

### Manifest state machine

```
                ┌──────┐
   ┌──────────► │ done │
   │            └──────┘
   │
[queued] ──► [running] ─┐
   │            ▲       │
   │            │       ├─► [failed]   (halts the fleet)
   │            │       │
   │            │       └─► [skipped]  (idempotency-gate skip)
   │            │
   │   manual-reset only (v0.1: edit the file)
   └────────────┘
```

## Control-plane branch

`/auto-fleet` operates only on a `fleet/<slug>` branch the user creates off default before invoking. Step 1 refuses to run on the default branch. The fleet branch holds **only the manifest** — no code changes — and is never merged. It is the durable record of the fleet run.

Subtask branches (`auto-do/<row-id>`) are created off the **default branch**, not the fleet branch, by `/auto-do` itself. Their PRs target default. The fleet branch and the subtask branches are siblings, not stacked. This separates the control plane (manifest) from the data plane (code).

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
- Count rows where `status == queued`. Must be `> 0` (else "no queued work, exiting") and `<= 5` (else "hard cap exceeded — break this fleet up").
- Compute SHA-256 of the manifest's full byte contents. Store in memory as `<initial-hash>` for step 6's tamper detection.

### 3. Resumability check

- If any row has `status == running`, bail without modifying anything: "<N> rows are stuck in `running` state from a prior run. Edit `docs/fleet/<slug>.md` manually to reset them to `queued` (or mark `failed`/`skipped`), then re-invoke. v0.1 does not auto-reset."

### 4. Confirmation gate

Surface via `AskUserQuestion`:

- **Question**: "This fleet will run /auto-do <N> times sequentially. Each run can take 5–30 minutes and consumes LLM + CI budget. Proceed?"
- **Header**: "Confirm fleet dispatch"
- **Options**:
  - "Run" *(Recommended)*
  - "Cancel"

On Cancel: append `Final status: halted:user-cancel` to a fresh `## Fleet outcome` section in the manifest, write to disk, commit + push (single commit), exit.

### 5. Branching is fixed

No question is asked here. v0.1 supports independent branching only — each subtask's `/auto-do` creates `auto-do/<id>` off `<default>` and opens a PR targeting `<default>`. Epic-branch mode is deferred to v1.

### 6. Dispatch loop

For each row in `queued` order (table order):

1. **Idempotency check.** Run `git branch --list auto-do/<id>` AND `git ls-remote --heads origin auto-do/<id>`. If either is non-empty, surface via `AskUserQuestion`:
   - **Question**: "Branch `auto-do/<id>` already exists. Skip this row, dispatch anyway, or cancel the fleet?"
   - **Header**: "Idempotency gate"
   - **Options**: "Skip *(Recommended)*" — mark row `skipped`, continue / "Dispatch anyway" — proceed to the next bullet / "Cancel" — halt fleet with `Final status: halted:branch-collision-cancel`.

2. **Hash check.** Re-read `docs/fleet/<slug>.md` from disk. Compute SHA-256. Compare to `<initial-hash>` from step 2. **If different**, halt without writing anything: append `Final status: halted:manifest-tampered` to a `## Fleet outcome` section in memory only, then bail with the message: "Manifest was edited externally during this run. The fleet has been halted to prevent clobbering your edits. Inspect `docs/fleet/<slug>.md`, reset row states manually, and re-invoke."

3. **Mark row `running`.** Update the table row in memory; update `last_updated` in the frontmatter. Write the manifest to disk only — **no `git commit`, no `git push`**.

4. **Recompute hash.** Capture the post-write hash as the new `<initial-hash>` for the next iteration's check (so subsequent iterations only halt on edits between iterations, not on /auto-fleet's own writes).

5. **Dispatch `/auto-do`.** Read `commands/auto-do.md` from `.claude/commands/` (project) then `~/.claude/commands/` (user). Execute its numbered steps inline with its auto-decision policy, against `<description>` from the row, with this **explicit override**: `/auto-do` step 1's slug derivation produces `<id>` verbatim (do not re-derive from the description). The resulting branch is `auto-do/<id>`; the resulting PR targets `<default>`.

6. **Outcome classification.** Read `/auto-do`'s final report. Match its `Final status:` line:
   - `Final status: succeeded` → row state `done`. Capture `branch = auto-do/<id>` and `pr = <pr-url>` into the row.
   - `Final status: failed:round-2-must-fix` | `failed:test-gate` | `failed:complexity-smell` → row state `failed`. Capture whichever of `branch`/`pr` exist into the row; the rest stay blank.
   - Anything else, or `Final status:` line missing → row state `failed` with note "unrecognised /auto-do report" appended to the manifest's outcome section.

7. **Per-task PR header.** If a PR was created (the `pr` field is set), edit its body **once** to prepend a single line: `## Fleet context\n\nPart of fleet [<slug>](<manifest-url>) — see manifest for sibling status.\n\n` (where `<manifest-url>` is the GitHub URL of `docs/fleet/<slug>.md` on the `fleet/<slug>` branch). No sibling cross-linking. No final-status echo. Use `gh pr edit <pr> --body-file <tmp>`.

8. **Write manifest to disk** with the row's new state (`done` or `failed`). Update `last_updated`. **No commit, no push** — those happen once at step 8.

9. **If row state is `failed`**, halt the dispatch loop. Continue to step 8 (final report) immediately.

### 7. Implicit — handled in step 6

(No standalone step 7. Per-task PR header is item 6.7 inside the dispatch loop.)

### 8. Final fleet report

- Append `## Fleet outcome` to the manifest with:
  - Row-state counts: `<done> done / <failed> failed / <skipped> skipped / <remaining> queued-remaining`.
  - `PRs created:` followed by a markdown bullet list of every PR URL captured in this run.
  - `Final status:` exactly one of `succeeded` (all rows `done`), `halted:round-2-failure` (a row failed at `failed:round-2-must-fix`), `halted:test-gate`, `halted:complexity-smell`, `halted:manifest-tampered`, `halted:branch-collision-cancel`, `halted:user-cancel`.
  - `Fleet auto-decisions:` followed by a bullet list of every gate `/auto-fleet` raised (idempotency, confirmation, hash) and how it answered. (`/auto-do`'s own log lives in each PR body — do not duplicate.)
- Update `last_updated`.
- Commit `docs/fleet/<slug>.md` on the `fleet/<slug>` branch with message `/auto-fleet <slug>: <Final status>`.
- Push: `git push --set-upstream origin fleet/<slug>` (idempotent; safe to repeat).
- **One commit per fleet run** — no per-transition pushes.

### 9. Final report to the user

Print to the user:

- The fleet's `Final status:`.
- Counts of `done` / `failed` / `skipped` / `queued-remaining`.
- The list of PRs created (URLs).
- The control-plane branch (`fleet/<slug>`) and where the manifest lives.
- If halted: the specific reason and what manual action is needed (e.g. "edit the manifest to reset `running` rows" or "investigate the round-2-must-fix on PR <url>").

## Failure modes summary

| Trigger | Behaviour | `Final status:` |
|---------|-----------|-----------------|
| Dirty working tree | Bail at step 1 before any change | n/a (no manifest update) |
| On default branch | Bail at step 1 | n/a |
| Manifest missing | Bail at step 1 | n/a |
| Manifest invalid (description has `\|`, etc.) | Bail at step 2 | n/a |
| > 5 queued rows | Bail at step 2 | n/a |
| Stuck `running` rows | Bail at step 3 | n/a |
| User cancels at confirmation gate | Halt and write outcome | `halted:user-cancel` |
| Branch collision, user cancels | Halt and write outcome | `halted:branch-collision-cancel` |
| Manifest tampered mid-run | Halt without writing | `halted:manifest-tampered` (in-memory only) |
| Subtask round-2 must-fix | Halt at end of dispatch | `halted:round-2-failure` |
| Subtask test gate | Halt at end of dispatch | `halted:test-gate` |
| Subtask complexity smell | Halt at end of dispatch | `halted:complexity-smell` |
| All subtasks `done` | Normal completion | `succeeded` |

## Known v0.1 limitations

- No `--resume` flag; crashed runs require manual manifest reset.
- No `--keep-going`; first failure halts the fleet.
- No `--max-tasks` override; cap is hard at 5.
- No epic-branch mode; subtask PRs always target the default branch.
- Manifest data model is intentionally thin (`id`, `description`, `status`, `branch`, `pr`); no retry counts, timestamps, or error-detail columns. Revisit after first three real runs.
- `gh` rate-limit / forked-repo / protected-branch failures bubble up as `/auto-do` failures and halt the fleet; `/auto-fleet` does not handle them specially in v0.1.
- See `docs/plans/auto-fleet.md` Engineering Review block for the full deferred-items list.
