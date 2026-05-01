---
status: approved
date: 2026-05-01
task: Ship /auto-fleet v0.1 — a serial dispatcher that reads a user-authored manifest and runs /auto-do per subtask, halting on first failure
branch: chore/auto-do-outcome
---

## Goal

Ship `/auto-fleet` v0.1 — a serial dispatcher that reads a user-authored fleet manifest and runs `/auto-do` per subtask. Persists state in the manifest itself. Not a planner, not a parallelism engine, never auto-merging. **Halts on first failure** in v0.1 (no productive-mode flag).

The brainstorm (`docs/brainstorms/auto-fleet.md`) surfaced the core scoping decision: fleet is a *dispatcher*, not a *planner*. v0.1 honours that strictly. The Codex outside-voice review (see Engineering Review block at the end of this file) tightened the scope further.

## Constraints (non-negotiable)

- **Markdown-only.** No code ships. Manifest is a markdown table at `docs/fleet/<slug>.md` rewritten in place by `/auto-fleet`. Same compromise the rest of the workshop already lives with. Acknowledged limitation: orchestration is software regardless of substrate; the LLM is the runtime, same as `/auto-do`.
- **Serial only in v0.1.** One `/auto-do` running at any time. No parallelism, no concurrency cap, no scheduler.
- **No auto-slicing.** The manifest is user-authored. `/auto-fleet` does not produce subtask descriptions; it does not create stub manifests in v0.1.
- **Stop on first failure.** No `--keep-going` flag in v0.1. Trust collapse from cascading bad PRs is the larger risk; productive-mode is a v1 concern.
- **Hard cap = 5 subtasks per run.** No flag override. If a fleet needs more, break the task into multiple smaller fleets.
- **Never merge.** Per-PR review remains a human gate. Same `/auto-do` rules apply transitively.
- **Independent branching only in v0.1.** Each subtask PR targets the default branch. Epic-branch mode is deferred to v1.

## Numbered steps (the skill body)

1. **Pre-flight.** Inherit `/auto-do`'s pre-flight checks (git repo, dirty tree, `gh` auth, default branch capture, `gh pr ready --undo` mode detection). Plus fleet-specific, in this order:
   - Derive `<slug>` from `$ARGUMENTS` first (kebab-case validation, ≤ 50 chars). All later steps refer to `<slug>` by the derived value, never `$ARGUMENTS` raw.
   - Refuse to run on the default branch; require current branch == `fleet/<slug>`.
   - Verify the fleet branch is rooted on `<default>`: `git rev-list --count <default>..HEAD` must be 0. (Mirrors `/auto-do`'s divergence guard. Bail otherwise; the user re-creates the branch from `<default>` and re-invokes.)
   - Confirm `docs/fleet/<slug>.md` exists; if not, bail. No stub creation in v0.1.

2. **Read + validate the manifest.** Parse the markdown table. Validate:
   - Frontmatter `slug` must equal the derived `<slug>` from step 1 (not `$ARGUMENTS` raw).
   - Header row must enumerate exactly these columns in order: `id`, `description`, `status`, `branch`, `pr`. (`branch` and `pr` cells may be empty for `queued` rows; the columns themselves are required.)
   - `status` ∈ `queued | running | succeeded | failed | skipped`. (Names follow Argo Workflows / Temporal / GitHub Actions convention; `succeeded` pairs with `failed`.)
   - `description` text must not contain `|`, backticks, markdown link syntax `[...](...)`, or newlines. Reject the row with a clear error if any are present (table-rewrite safety).
   - `id` must be unique and slug-safe (kebab-case, lowercase ASCII alphanumerics + hyphens).
   - Row count with `status: queued` must be ≤ 5 (hard cap).
   - Compute and store the manifest's SHA-256 hash for the single tamper check at step 8. (No per-iteration re-read during the dispatch loop — `/auto-do` switches the working tree to `auto-do/<id>` off `<default>`, where the fleet manifest doesn't exist; mid-loop re-reads would always fail.)

3. **Resumability check.** If any row is in `running` state from a prior crashed run, bail with manual-reset instructions: "N rows are stuck in `running`. Edit the manifest manually to reset them to `queued` (or mark `failed`/`skipped`), then re-invoke." v0.1 does not auto-reset; the user must intervene.

4. **Confirmation gate.** Surface via `AskUserQuestion`: "This fleet will run /auto-do <N> times sequentially. Each run can take 5–30 minutes and consumes LLM + CI budget. Proceed?" with options Run / Cancel. No cost estimation — it invites false confidence. Even in auto-mode, this gate fires unconditionally; fleet dispatch is the largest single decision the workshop ever makes.

5. **Branching is fixed.** v0.1 supports independent branching only — each subtask's `/auto-do` creates its own `auto-do/<row-id>` branch off the default branch and opens a PR targeting default. No `## Branching` section is consulted in the manifest. Epic-branch mode is deferred to v1.

6. **Dispatch loop.** For each row in `queued` order. **All state changes during the loop are in-memory only** — no disk writes, no commits, no pushes happen until step 8. The dispatch loop also does **not** re-read the manifest from disk: `/auto-do` switches the working tree to `auto-do/<id>` (off `<default>`), where `docs/fleet/<slug>.md` doesn't exist. Hash check is single-shot at step 8. Per-task PR-body edits also wait until step 8, after the manifest is pushed and `<manifest-url>` resolves.
   - **Idempotency check.** Check branch existence (local + remote) AND prior PR state via `gh pr list --head auto-do/<id> --state all`. If any are present, surface via `AskUserQuestion`: "Branch `auto-do/<id>` already exists (prior PR: `<state-or-none>`). Skip, dispatch anyway, or cancel?" with options `Skip *(Recommended)* / Dispatch anyway / Cancel`.
   - Mark row `running` **in memory only**.
   - **Dispatch /auto-do.** Read `commands/auto-do.md` from `.claude/commands/` (project) then `~/.claude/commands/` (user). Apply its numbered steps with its auto-decision policy against `<description>` from the row, with the explicit override that step 1's slug derivation produces `<id>` verbatim. **Orchestration-pattern reuse, not subroutine-call.** `/auto-do` will leave the working tree on `auto-do/<id>` when it returns.
   - **Outcome classification.** Match `/auto-do`'s final-report `Final status:` line (its emitted token is `success`, not `succeeded` — see `commands/auto-do.md:212`):
     - `success` → row state `succeeded`. Capture `branch = auto-do/<id>` and `pr = <pr-url>` into the row in memory.
     - `failed:round-2-must-fix` → row `failed`; fleet `Final status: halted:round-2-failure`.
     - `failed:test-gate` → row `failed`; fleet `Final status: halted:test-gate`.
     - `failed:complexity-smell` → row `failed`; fleet `Final status: halted:complexity-smell`.
     - `failed:ambiguity` → row `failed`; fleet `Final status: halted:auto-do-ambiguity`. (Preserves the actionable signal from `/auto-do`'s "fail closed on ambiguity" exit.)
     - Anything else (or `Final status:` line missing) → row `failed` with first 200 chars of the actual report captured to the row's note; fleet `Final status: halted:unrecognised-auto-do-report`.
   - On `failed`: break out of the loop. Continue to step 8 (no further dispatch).

7. *(No standalone step 7 — per-task PR-body edits are deferred to step 8 so `<manifest-url>` resolves after the fleet branch is pushed.)*

8. **Final fleet report.** This is the only place `/auto-fleet` writes to disk, commits, and pushes.
   - **Working-tree cleanliness check before checkout.** Run `git status --porcelain` while still on `auto-do/<id>` (or whatever branch the last `/auto-do` left us on). If non-empty, bail without checkout / write / commit / push: the in-memory fleet state is lost; user investigates manually. Round-1 Codex finding on PR #21: a crashed `/auto-do` can leave dirty / untracked state that would otherwise contaminate the manifest commit.
   - **Switch back to the fleet branch.** Run `git checkout fleet/<slug>`. Working tree is clean by construction (manifest wasn't touched on disk during the loop).
   - **Final hash check before writing.** Re-read `docs/fleet/<slug>.md` from disk and compute SHA-256. If it differs from step 2's `<initial-hash>`, refuse to clobber: bail without writing or committing; fleet outcome lives only in the user-facing report. v0.1 limitation.
   - **Compose the final manifest in memory:** rewrite the `## Subtasks` table; append `## Fleet outcome` with counts, PRs created, `Final status:`, `Fleet auto-decisions:`; update YAML key `last_updated`.
   - **Single disk write → single commit → single push.** `git push --set-upstream origin fleet/<slug>`. If rejected, local commit preserved; report clearly; per-task PR-body edits below are skipped.
   - **Per-task PR-body fleet-context headers** (deferred from step 6 so `<manifest-url>` resolves). For each row whose `pr` is set, edit the PR body once to prepend `## Fleet context\n\nPart of fleet [<slug>](<manifest-url>) — see manifest for sibling status.\n\n`. Skip if push was rejected.
   - **One commit per fleet run** — no per-transition pushes.

   `Final status:` is exactly one of: `succeeded`, `halted:round-2-failure`, `halted:test-gate`, `halted:complexity-smell`, `halted:auto-do-ambiguity`, `halted:unrecognised-auto-do-report`, `halted:manifest-tampered`, `halted:branch-collision-cancel`, `halted:user-cancel`.

### Hard rules (must appear in skill body)

- Never push to default branch.
- Never `--force`-push, never `--no-verify`.
- Never merge any PR.
- Never run more than one `/auto-do` at once (serial only in v0.1).
- Never auto-slice the manifest.
- Never proceed past first failed subtask. (No `--keep-going` flag in v0.1.)
- Never silently re-run a `running` row — bail with manual-reset instructions.
- Never write to the manifest after detecting it was edited externally — bail.
- Never write to the manifest mid-fleet. All row-state transitions are in-memory until step 8. (The round-1 Codex review on PR #21 found the original "write `running` to disk before dispatching `/auto-do`" flow would dirty the working tree and halt every subtask at its own pre-flight. In-memory-only state during the dispatch loop is the only correct approach.)

### Manifest state machine

`running` is held **in memory only**; the manifest on disk transitions directly from `queued` to a terminal state at fleet end (step 8). Writing `running` to disk mid-fleet would dirty the working tree and prevent `/auto-do`'s pre-flight from passing.

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

### Auto-decision log strategy

Each `/auto-do` writes its own auto-decision log into its own PR body. `/auto-fleet` does **not** duplicate — the fleet manifest links to each PR; the PR body has the per-task decision log. Single source of truth, no churn.

## Manifest format (the user-authored input)

`docs/fleet/<slug>.md`:

```markdown
---
slug: api-logging
created: 2026-05-01
last_updated:
---

## Subtasks

| id            | description                                            | status | branch | pr |
|---------------|--------------------------------------------------------|--------|--------|----|
| users-log     | Add request-logging middleware to /users routes        | queued |        |    |
| orders-log    | Add request-logging middleware to /orders routes       | queued |        |    |
| products-log  | Add request-logging middleware to /products routes     | queued |        |    |
```

`/auto-fleet` rewrites the table at fleet end (in memory throughout the dispatch loop; single disk write + commit + push at step 8). The example above uses **genuinely independent subtasks** — v0.1 has no dependency model, so dependent rows produce undefined behaviour by design.

### Manifest constraints

- `description` text must not contain `|`, backticks, markdown link syntax `[...](...)`, or newlines (validated at step 2).
- `id` is the row identifier and is used to derive the `auto-do/<id>` branch name; must be slug-safe.
- `last_updated` is a YAML key in frontmatter, set by `/auto-fleet` at the single fleet-end disk-write.
- The manifest hash is captured at fleet start; any external edit during a run halts the fleet (step 6 hash check).
- The user is expected not to edit the manifest mid-run; if they do, the hash check halts the fleet rather than clobbering. (In contrast to v0.1's previous "undefined behaviour" wording — Codex was right that this needed real protection.)

## Control-plane branch

`/auto-fleet` operates only on a `fleet/<slug>` branch the user creates off the default branch before invoking. Pre-flight refuses to run on the default branch. The fleet branch holds **only the manifest** — no code changes. It is never merged; it is the durable record of the fleet run.

Subtask branches (`auto-do/<row-id>`) are created off **default**, not the fleet branch, by `/auto-do` itself. Their PRs target default. The fleet branch and the subtask branches are siblings, not stacked. This separates the control plane (manifest history) from the data plane (code changes), preventing fleet bookkeeping commits from interleaving with `/auto-do` commits.

## Critical files

- **New:** `commands/auto-fleet.md` — the orchestrator skill body.
- **New:** `docs/fleet/.gitkeep` — make the directory real so `docs/fleet/<slug>.md` writes don't fail on a fresh clone.
- **Edit:** `README.md` — `/auto-fleet` row in **Skills shipped** table; **Where to go next** bullet; manifest-format example block; control-plane-branch convention paragraph.
- **Edit:** `CHANGELOG.md` — `[Unreleased]` entry naming v0.1 scope, the serial constraint, the manifest format, the hard rules, the v0.1 omissions (`--keep-going`, `--max-tasks`, epic branching).
- **Edit:** `commands/auto-do.md` — one-liner under "How to orchestrate" noting that `/auto-fleet` invokes it the same way; `/auto-do` does not need fleet-awareness.
- **Verify (no edit expected):** `install.sh` — confirm copying `commands/*.md` still works; `docs/fleet/` should not be in the install copy path.

## Eng-review intent

This plan was reviewed against `/plan-eng-review` on 2026-05-01 with Codex outside-voice. See the **Engineering Review** block at the end of this file. The review surfaced 24 findings; the simpler-v0.1 scope reduction Codex recommended (drop `--keep-going`, `--max-tasks`, epic branching, sibling cross-linking, per-transition pushes, stub creation, auto-resumability) was applied to the plan body above.

## Verification

- **Manual smoke fixtures.** Run `/auto-fleet` against a public template repo with these scenarios (each its own manifest):
  - **Happy:** 2 independent subtasks, both succeed → both PRs created, manifest closes with `succeeded`.
  - **Forced-failure:** 2 subtasks, second deliberately misconfigured to fail at `/auto-do`'s test gate → fleet halts at subtask 2, manifest records `halted:test-gate`, subtask 1's PR is untouched.
  - **Manifest-tampering:** edit the manifest externally during a run → fleet halts with `halted:manifest-tampered`.
  - **Branch collision:** pre-create `auto-do/<row-id>` before invocation → idempotency gate fires.
  - **Empty manifest:** no rows in `queued` → bails at step 4 ("no queued work").
- **Manifest fixture pack** is captured as a TODO (Engineering Review block); a small set of valid + invalid manifest examples for future smoke validation, not blocking v0.1.

## Out of scope (intentional)

- Parallelism, concurrency caps, dependency declarations (deferred to v1).
- Auto-slicing the manifest (v2; likely a separate skill).
- Fleet-level integration testing across all N PRs (separate concern, separate skill).
- Auto-merge of any PR (always a human gate).
- Cross-PR review-finding dedup (separate `/review-fleet` idea).
- Editing the manifest mid-run as a supported flow — hash check halts; manual reset only.
- The `--keep-going` and `--max-tasks` flags (cut for v0.1; reconsider for v1 once real fleet usage lands).
- `--resume` flag for crashed runs (manual reset only).
- Stub manifest creation (manual authoring only).
- Epic-branch mode (independent only in v0.1).

## See also

- [Brainstorm: /auto-fleet](../brainstorms/auto-fleet.md)
- [Solution: /auto-do](../solutions/auto-do.md)
- [Plan: /auto-do](./auto-do.md)

---

## Engineering Review — 2026-05-01

Reviewer: `/plan-eng-review` (Adam, in auto-mode) + Codex outside-voice (`codex-cli 0.128.0`).

### Step 0 — Scope challenge

- **What already exists.** `/auto-do` (PR #18, merged in `cf68bef`) implements full single-task orchestration. `/review-pr` handles its round-2 safe-stop; `/browse` handles UI verification — both inherited transitively. The plan correctly *reuses* these via the same orchestration-pattern read of `commands/<skill>.md`. No parallel implementations being rolled.
- **Minimum viable change.** 1 new skill file + 1 `.gitkeep` + 3 file edits (README, CHANGELOG, auto-do.md one-liner). 5 file changes total, well under the 8-file complexity smell threshold.
- **Built-in vs custom.** Serial loop is a markdown instruction; no scheduler. Manifest is a markdown table, not a database. Consistent with workshop convention.
- **TODOS cross-reference.** The /auto-do "manual verification harness" follow-up (`TODOS.md` line 35) is directly compounded by /auto-fleet — fleet-level verification multiplies the same gap. Captured below as a TODO. No deferred items block /auto-fleet.
- **Distribution.** `install.sh` already copies `commands/*.md`. Covered.
- **Verdict.** Scope right-sized as originally drafted; Codex's recommendation pushed it tighter still. Applied.

### Section 1 — Architecture

Issues identified and folded into the plan body:

- **1A. PR-body sibling cross-linking creates O(N²) churn.** Originally each PR's `## Fleet context` listed siblings progressively, requiring re-edits of all earlier PRs as later ones land. Fold: drop sibling cross-linking entirely; PRs link to manifest only; manifest is the index. *Tied to: minimal diff, explicit > clever.*
- **1B. Per-transition manifest commit + push creates noisy history and hits gh rate limits.** Fold: write to disk between transitions; commit + push **once** at fleet end (or on halt). One commit per fleet run.
- **1C. Control-plane branch was undefined.** "Never push to default" + "commit + push manifest" are contradictory unless the manifest lives elsewhere. Fold: dedicated `fleet/<slug>` control-plane branch off default, holds only the manifest, never merged. Subtask branches are siblings, not stacked.
- **1D. gh API rate limits.** Treated as a halt condition like round-2 failure. New `Final status: halted:rate-limit` added.
- **1E. State-machine diagram added** (ASCII, embedded in the skill body) since the manifest row's lifecycle is non-trivial.

### Section 2 — Code quality

- **2A. DRY against /auto-do's pre-flight.** `/auto-fleet` runs its own pre-flight; `/auto-do` runs its own per-subtask. Accept the duplication — independent contracts, robust whether dispatched from a fleet or invoked directly. Optimising couples `/auto-fleet` to `/auto-do` internals.
- **2B. Outcome classification was hand-wavy** (Codex finding). Fold: in step 6, define exact `Final status:` line strings `/auto-do` reports for each terminal state, and key off those. Anything unrecognised → `failed` with `error_summary: "unrecognised /auto-do report"`. Brittle, but explicit, and tightly coupled to a contract `/auto-do` already implements.
- **2C. "User edits manifest mid-run = undefined" is silent data loss** (Codex finding). Fold: SHA-256 hash captured at fleet start; re-checked before each disk write. External edit halts with `halted:manifest-tampered`. Never silent.
- **2D. Manifest table parsing fragility** (Codex finding). Descriptions containing `|`, backticks, markdown link syntax, or newlines break naive table rewriting. Fold: validate at step 2; reject with clear error.
- **2E. Frontmatter wording imprecision** (Codex finding). "Last updated line in frontmatter" was wrong; YAML key is `last_updated`. Fixed.
- **2F. Idempotency was undefined** (Codex finding). Fold: before dispatching a `queued` row, check if `auto-do/<row-id>` branch already exists locally or remotely; if so, surface skip/dispatch/cancel via AskUserQuestion.

### Section 3 — Tests

This is a markdown skill; the "tests" are LLM-following-instructions plus manual smoke. No unit tests possible.

#### Coverage diagram

```
SKILL PATHS                                    USER FLOWS
[+] commands/auto-fleet.md                     [+] /auto-fleet <slug>
  ├── Step 1 (pre-flight + manifest exists)      ├── [GAP] 2-subtask happy path
  ├── Step 2 (parse + validate + hash)           ├── [GAP] subtask 2 round-2-fails → halt
  ├── Step 3 (resumability bail)                 ├── [GAP] manifest tampered mid-run
  ├── Step 4 (confirmation gate)                 ├── [GAP] gh rate-limit hit
  ├── Step 5 (branching is fixed)                ├── [GAP] empty manifest
  ├── Step 6 (dispatch loop)                     ├── [GAP] running-state resume bail
  │   ├── idempotency check                      ├── [GAP] branch-collision idempotency
  │   ├── hash check                             ├── [GAP] description with `|` rejected
  │   ├── outcome classification                 └── [GAP] description with `[link](url)` rejected
  ├── Step 7 (PR fleet-context header)
  └── Step 8 (final report + commit)

COVERAGE: 0/12 paths tested  |  GAPS: 9 (all manual smoke fixtures)
```

All gaps. v0.1 covers via the manual smoke fixtures listed in the **Verification** section. Mirrors `/auto-do`'s posture; not introducing new automated-test infra.

#### Regression rule

`/auto-fleet` is new work. The single-line edit to `commands/auto-do.md` (one bullet under "How to orchestrate") is documentary and does not change `/auto-do`'s behaviour. No regression test required.

### Section 4 — Performance

- **4A. Manifest re-parse on every transition** — microsecond work; not a real concern. No action.
- **4B. gh CLI invocations per subtask** (~5/subtask × 5 subtasks = ~25 gh calls/run, plus fleet-level halt-comments). Covered by 1D rate-limit halt detection. No further action.
- **4C. PR-body cross-linking churn** addressed via 1A (dropped).

### Section 5 — Outside voice (Codex)

Ran `codex exec --skip-git-repo-check` against the plan. Codex returned 24 findings. Summary of what was applied vs. disagreed:

**Applied (must-fix folded into plan body):**

- **Codex #2** — `/auto-do` is not a callable subroutine; "apply steps verbatim" is semantic drift. Fold: re-worded as "orchestration-pattern reuse, not subroutine-call" with explicit acknowledgement of the brittle coupling.
- **Codex #3** — Pathing inconsistent (`commands/<skill>.md` vs `.claude/commands/<skill>.md`). Fold: clarified — repo source-of-truth is `commands/auto-fleet.md`; runtime resolution is `.claude/commands/` then `~/.claude/commands/`.
- **Codex #4** — Branching strategy underspecified. Fold: dropped epic-branch mode entirely; v0.1 is independent only.
- **Codex #5** — "Never push to default" vs "commit + push manifest" contradiction. Fold: control-plane branch (`fleet/<slug>`).
- **Codex #6** — Per-transition commits noisy; collide with `/auto-do`. Fold: commit only at fleet end + on halt.
- **Codex #8** — Outcome classification hand-wavy. Fold: explicit `Final status:` string match (see 2B).
- **Codex #9** — No idempotency definition. Fold: pre-dispatch branch-existence check (see 2F).
- **Codex #11** — Markdown table parsing fragile. Fold: description-text constraints validated at step 2 (see 2D).
- **Codex #12** — Frontmatter wording imprecise. Fold: YAML key `last_updated`, not "Last updated:" line.
- **Codex #13** — `created: 2026-05-15` future-dated. Fixed: `2026-05-01`.
- **Codex #14** — `--max-tasks` flag defeats the "hard cap". Fold: dropped flag; cap is hard at 5.
- **Codex #15** — Budget gate cannot estimate cost. Fold: gate doesn't pretend; just confirms.
- **Codex #17** — Example subtasks are sequentially dependent (migrate /users, /orders, then update SDK). Fold: replaced with genuinely independent subtasks (per-route logging middleware).
- **Codex #18** — "User expected not to edit; undefined" is weak. Fold: SHA-256 hash check (see 2C).
- **Codex #19** — Stub creation underdefined. Fold: dropped stub creation entirely; bail with manual-authoring instructions.
- **Codex #20** — Sibling cross-linking is backwards. Fold: dropped (see 1A).
- **Codex #21** — Final fleet outcome in each PR body is unnecessary churn. Fold: dropped.
- **Codex #25** — Simpler v0.1 recommendation. Fold: applied as the unifying scope reduction across the above. The plan body now matches Codex's "simpler v0.1" shape.

**Applied as TODOs (deferred):**

- **Codex #7** — Manifest row data model thin (one branch + one pr, no retry/draft state, no started/finished timestamps). TODO: revisit data model after first real fleet run.
- **Codex #10** — No stale-state validation before resume. v0.1 bails on `running` rows; resume isn't implemented. TODO: when v1 adds `--resume`, add `gh pr view <pr>` validation per row.
- **Codex #22** — Permission/forked-repo/protected-branch coverage missing. TODO: capture as a known limitation in the skill body's "Hard rules" → bails if `gh` calls fail.
- **Codex #23** — Manual smoke against template repo not enough; need crash/resume, push rejection, etc. Fold: enriched the **Verification** section with five specific scenarios (happy, forced-failure, manifest-tamper, branch-collision, empty-manifest).
- **Codex #24** — Fixture tests for manifest parse/rewrite. TODO: capture a manifest fixture pack (valid + invalid examples) for future smoke validation.

**Disagreed:**

- **Codex #1** — "Markdown-only conflicts with the plan; orchestration is software, doing this as a prose slash command is pretending it isn't." This is a foundational critique that applies equally to `/auto-do`, which already shipped under the same constraint. The LLM is the runtime; the markdown is the program. Workshop principle wins. Acknowledged the limitation in the **Constraints** section rather than re-litigating the foundation. *Cross-model tension: surface but don't resolve at the plan level.*
- **Codex #16** — "`--keep-going` + serial dependencies = stacking broken builds." Resolved orthogonally by dropping `--keep-going` entirely (Codex #25). No longer relevant to v0.1.

### NOT in scope

- Parallelism, concurrency caps, dependency declarations — v1.
- Auto-slicing the manifest — v2 / separate skill.
- `--keep-going`, `--max-tasks`, `--resume` flags — v1 once real usage justifies them.
- Stub manifest creation — manual authoring only in v0.1.
- Epic-branch mode — v1.
- Cross-PR review-finding dedup — separate `/review-fleet` skill if ever needed.
- Auto-merge of any PR — always a human gate.
- Editing the manifest mid-run as a supported flow — hash check halts.

### What already exists

- `/auto-do` (`commands/auto-do.md`) — full orchestration; `/auto-fleet` reuses by reading the file at runtime and applying its steps. Brittle coupling acknowledged; same trade-off `/auto-do` already accepts for `/plan` etc.
- `/review-pr` round-2 safe-stop — inherited transitively via `/auto-do`. `/auto-fleet` keys off `Final status:` strings to classify outcomes.
- `/browse` UI verification — inherited transitively via `/auto-do`. No fleet-level browse step.
- Skill-resolution pattern (`.claude/commands/` then `~/.claude/commands/`) — copied from `/auto-do`.
- Markdown-only installation pattern (`install.sh` copies `commands/*.md`) — `/auto-fleet` fits without modification.
- Slug validation pattern (kebab-case, ASCII alphanumerics + hyphens) — copied from `/research`, `/plan`, `/auto-do`.

### Failure modes

| Codepath | Failure | Test? | Error handling? | User sees? | Critical gap? |
|----------|---------|-------|-----------------|------------|---------------|
| Step 1 pre-flight | On default branch | manual smoke | bail with clear message | yes | no |
| Step 2 manifest validation | Description has `|` | manual smoke | reject row with clear error | yes | no |
| Step 3 resume bail | Stuck `running` row | manual smoke | bail with manual-reset instructions | yes | no |
| Step 6 idempotency | `auto-do/<id>` branch exists | manual smoke | AskUserQuestion gate | yes | no |
| Step 6 hash check | Manifest tampered mid-run | manual smoke | halt with `halted:manifest-tampered` | yes | no |
| Step 6 dispatch | `/auto-do` returns unrecognised report | manual smoke | classify as `failed`, halt | yes | no |
| Step 6 dispatch | gh API rate-limit hit | not directly tested | halt with `halted:rate-limit` | yes | **yes** — assumed but not verified manually in v0.1 |
| Step 8 final commit | Push rejected (e.g. branch-protection on `fleet/<slug>`) | not directly tested | TODO | unclear | **yes** — not handled |

Two critical gaps captured as TODOs: rate-limit halt path needs a real manual smoke (it's hypothesised); push-rejection on the fleet branch is not handled.

### TODOs

The following follow-ups are captured for after `/auto-fleet` v0.1 ships. Each will be added to `TODOS.md` when the work is committed.

- **Manual rate-limit smoke fixture.** Construct a scenario that triggers gh secondary rate limit during a fleet run; verify `halted:rate-limit` lands cleanly. *Why: critical failure mode currently only hypothesised. Depends on: `/auto-fleet` shipping.*
- **Push-rejection on `fleet/<slug>` branch.** Step 8's commit + push assumes the fleet branch can be pushed. Branch-protection rules on `fleet/*` could reject. Skill should either bail with a clear message or fall back to "manifest written locally; push manually." *Why: silent push failure leaves the fleet outcome undocumented remotely. Depends on: `/auto-fleet` shipping.*
- **Manifest fixture pack.** A small directory of valid + invalid manifest examples (`tests/fixtures/fleet/*.md`) used for manual smoke validation when changes touch step 2. *Why: catches table-parse regressions. Depends on: `/auto-fleet` shipping.*
- **Manifest data-model revisit.** v0.1's row schema (`id`, `description`, `status`, `branch`, `pr`) may prove thin once real fleet runs surface retry/draft/timestamp needs. Revisit after the first three real fleet runs. *Why: data model is hard to evolve once the manifest format is documented. Depends on: real usage data.*
- **`/auto-fleet` first-real-run smoke.** Like `/auto-do`'s analogous TODO — running `/auto-fleet` against a real public template repo with three independent subtasks. Schedule one-off agent ~2 weeks after ship. *Why: skill-spec review doesn't catch integration issues. Depends on: `/auto-fleet` shipping.*
- **`gh` permission / fork / protected-branch coverage.** Document explicitly which `gh` failures are bail-conditions; surface a clear error. *Why: production users on locked-down `gh` configs will hit these. Depends on: `/auto-fleet` shipping.*

### Completion summary

```
Step 0 — Scope:   accepted, then reduced per Codex #25 (simpler v0.1)
Architecture:     5 issues found, 5 resolved (1A–1E folded into plan)
Code quality:     6 issues found, 6 resolved (2A–2F folded into plan)
Tests:            diagram produced, 9 gaps identified (all manual smoke), 0 regression tests required
Performance:      3 issues found, 3 resolved (no real concerns)
Outside voice:    ran (Codex 0.128.0); 24 findings; 18 folded into plan, 5 → TODOs, 2 disagreed (Codex #1 and #16)
NOT in scope:     written
Failure modes:    2 critical gaps flagged → TODOs (rate-limit smoke, push-rejection handling)
TODOs:            6 proposed, 6 added (deferred to TODOS.md on first commit)
Unresolved:       none — all decisions taken under auto-mode auto-decision policy
```

---

## Round-1 review (Codex on PR #21) + web-research fold-in — 2026-05-01

After PR #21 was opened, the Codex GitHub bot's automated review surfaced **2 must-fix bugs** in the dispatch loop. The user also asked for a survey of existing fleet-runner patterns to inform the fix; an Agent dispatched to research multi-gitter, OpenRewrite, Argo Workflows, GitHub Actions matrix, jscodeshift, SWE-bench harness, and related tools returned several alignment recommendations. Both were folded into the skill body.

### Bugs caught by Codex

- **P0 — dirty-tree before /auto-do dispatch.** Step 6 originally wrote the manifest to disk as `running` *before* dispatching `/auto-do`. But `/auto-do`'s pre-flight requires a clean working tree (`git status --porcelain` must be empty); every dispatch would have halted immediately. The fleet could not have executed even one row.
- **P1 — branch leak between iterations.** After `/auto-do` returns the working tree is on `auto-do/<id>`. The plan had no instruction to switch back to `fleet/<slug>` before later manifest writes; control-plane commits would have leaked onto subtask branches and into subtask PRs, violating the documented control-plane / data-plane separation.

### Fix that resolves both

- **Hold all row state in memory during the dispatch loop.** No disk writes between iterations.
- **Single disk write + commit + push at step 8** after explicitly checking out `fleet/<slug>` (since `/auto-do` left us on `auto-do/<id>`).
- **Final hash check at step 8** before writing — if the manifest was tampered with externally during the run, refuse to clobber.

This trades **mid-run observability** (the on-disk manifest now shows `queued` until fleet completion) for **correctness** (P0 dirty-tree blocker resolved) and **simplicity** ("one commit per fleet run" becomes literal). Mid-run observability is a v1 ask if it ever surfaces from real usage.

### Research fold-ins from the survey of existing fleet runners

The Agent surveyed multi-gitter (lindell), OpenRewrite, Argo Workflows DAG mode, GitHub Actions matrix, jscodeshift, SWE-bench harness, Renovate, Temporal child workflows, claude-code-action idempotency patterns, and tick-md as a markdown-task-format example. Recurring patterns and recommendations applied:

- **`done` → `succeeded` rename.** Argo / Temporal / GitHub Actions all use `succeeded` paired with `failed`. `done` is non-standard. Renamed across skill body, plan, manifest constraints, state machine, failure modes, and counts.
- **Idempotency: also check PR state, not just branch.** Most surveyed tools check both. A stale `auto-do/<id>` branch from a closed/merged PR would otherwise block re-runs forever. Step 6's idempotency check now also runs `gh pr list --head auto-do/<id> --state all` and surfaces the prior PR state in the AskUserQuestion prompt.
- **In-memory state during run is the right call.** No surveyed tool persists "running" state mid-flight to the same artifact the sub-task reads from. CLI fleet runners (multi-gitter, jscodeshift, OpenRewrite) all keep state in process memory and write a summary at exit. Single commit at fleet end matches this convention. Confirms the P0 fix is aligned with prior art.
- **Halt-on-first-failure default is standard.** Argo, GHA matrix, Make, Bazel, Temporal child workflows. Confirms the v0.1 default; `--continue-on-error` is a v1 escape hatch if asked.
- **Hard cap of 5 framed as a v0.1 guard rail.** Mainstream fleet runners have no cap or run hundreds (multi-gitter unbounded, SWE-bench hundreds, GHA matrix capped at 256). v0.1's cap of 5 is unusually tight and is now described as "a guard rail until real usage justifies raising it" rather than a fundamental design point.
- **Markdown-table manifest acknowledged as unusual.** Every surveyed fleet runner uses YAML or JSON; markdown-table is an *agent-tooling* idiom (skills, agent prompt formats). Kept anyway because the manifest lives next to other markdown docs in `docs/`, but flagged as a deliberate trade against tooling-friendliness in the skill body.

### Unresolved

- **`halted:rate-limit` outcome.** Originally listed as a possible final-status string. The round-1 fix replaced it with `halted:unrecognised-auto-do-report` and removed the explicit rate-limit halt path. Reasoning: rate-limit failures bubble up as `/auto-do` failures already; `/auto-fleet` doesn't need to detect them separately. The "rate-limit smoke" TODO from the eng review remains as a manual-verification gap; the explicit `halted:rate-limit` status is dropped from v0.1.
- **Push-rejection on `fleet/<slug>` at step 8.** Now explicitly handled: local commit is preserved, the rejection is reported clearly so the user can push manually. Demoted from "critical gap" to "documented limitation"; the manual push escape is the v0.1 answer.
