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

1. **Pre-flight.** Inherit `/auto-do`'s pre-flight checks (git repo, dirty tree, `gh` auth, default branch capture, `gh pr ready --undo` mode detection). Plus fleet-specific:
   - Refuse to run on the default branch — caller must be on a `fleet/<slug>` control-plane branch (see "Control-plane branch" below).
   - Confirm `docs/fleet/<slug>.md` exists; if not, bail with instructions: "Author a manifest at `docs/fleet/<slug>.md` first — see manifest format below — then re-invoke." No stub creation in v0.1.

2. **Read + validate the manifest.** Parse the markdown table. Validate:
   - Required columns: `id`, `description`, `status`, `branch` (optional), `pr` (optional).
   - `status` ∈ `queued | running | done | failed | skipped`.
   - `description` text must not contain `|`, backticks, markdown link syntax `[...](...)`, or newlines. Reject the row with a clear error if any are present (table-rewrite safety).
   - `id` must be unique and slug-safe (kebab-case, lowercase ASCII alphanumerics + hyphens).
   - Row count with `status: queued` must be ≤ 5 (hard cap).
   - Compute and store the manifest's SHA-256 hash for tamper detection in step 6.

3. **Resumability check.** If any row is in `running` state from a prior crashed run, bail with manual-reset instructions: "N rows are stuck in `running`. Edit the manifest manually to reset them to `queued` (or mark `failed`/`skipped`), then re-invoke." v0.1 does not auto-reset; the user must intervene.

4. **Confirmation gate.** Surface via `AskUserQuestion`: "This fleet will run /auto-do <N> times sequentially. Each run can take 5–30 minutes and consumes LLM + CI budget. Proceed?" with options Run / Cancel. No cost estimation — it invites false confidence. Even in auto-mode, this gate fires unconditionally; fleet dispatch is the largest single decision the workshop ever makes.

5. **Branching is fixed.** v0.1 supports independent branching only — each subtask's `/auto-do` creates its own `auto-do/<row-id>` branch off the default branch and opens a PR targeting default. No `## Branching` section is consulted in the manifest. Epic-branch mode is deferred to v1.

6. **Dispatch loop.** For each row in `queued` order:
   - **Idempotency check.** Check if a branch named `auto-do/<row-id>` already exists locally or remotely. If so, surface via `AskUserQuestion`: "Branch already exists for row `<id>`. Skip, dispatch anyway, or cancel the fleet?" with options Skip / Dispatch / Cancel.
   - **Hash check.** Re-read the manifest from disk and compare its SHA-256 to the value captured in step 2. If changed, halt — "manifest edited mid-run, halting" — without writing anything further. Final status: `halted:manifest-tampered`.
   - Mark row `running`, write manifest **to disk only** (no commit, no push).
   - **Dispatch /auto-do.** Read `commands/auto-do.md` from `.claude/commands/` (project) then `~/.claude/commands/` (user) — same resolution pattern `/auto-do` itself uses for sub-skills. Apply its numbered steps with its auto-decision policy against `<description>` from the row. This is **orchestration-pattern reuse, not subroutine-call**; the same brittle coupling `/auto-do` already accepts for `/plan`, `/plan-eng-review`, etc.
   - **Outcome classification.** Match `/auto-do`'s final-report `Final status:` line to derive the terminal state:
     - `succeeded` → row `done`.
     - `failed:round-2-must-fix` | `failed:test-gate` | `failed:complexity-smell` → row `failed`.
     - Anything else (or `Final status:` line missing) → row `failed` with `error_summary: "unrecognised /auto-do report"`.
   - On `done`: capture `branch` and `pr` URLs into the manifest row in memory, write to disk only, continue.
   - On `failed`: write to disk, **halt the fleet**. Continue to step 8 (no further dispatch).

7. **Per-task PR header.** When `/auto-do` creates the PR for a subtask, `/auto-fleet` edits the PR body once to prepend a single `## Fleet context` line: `Part of fleet [<slug>](<manifest-link>) — see manifest for sibling status.` No sibling cross-linking, no final-status echo, no churn on later subtasks. The manifest is the only index.

8. **Final fleet report.** Append a `## Fleet outcome` section to the manifest:
   - Counts: `done` / `failed` / `skipped` / `queued`-remaining.
   - Links to all PRs created.
   - `Final status: succeeded | halted:round-2-failure | halted:test-gate | halted:complexity-smell | halted:manifest-tampered | halted:rate-limit | halted:user-cancel | halted:branch-collision-cancel`.
   - Update YAML key `last_updated` in the manifest frontmatter.
   - Commit `docs/fleet/<slug>.md` on the `fleet/<slug>` control-plane branch and push. **One commit per fleet run** — no per-transition pushes.

### Hard rules (must appear in skill body)

- Never push to default branch.
- Never `--force`-push, never `--no-verify`.
- Never merge any PR.
- Never run more than one `/auto-do` at once (serial only in v0.1).
- Never auto-slice the manifest.
- Never proceed past first failed subtask. (No `--keep-going` flag in v0.1.)
- Never silently re-run a `running` row — bail with manual-reset instructions.
- Never write to the manifest after detecting it was edited externally — bail.

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

`/auto-fleet` rewrites the table in place as it runs (in memory throughout; on disk between transitions; committed once at fleet end). The example above uses **genuinely independent subtasks** — v0.1 has no dependency model, so dependent rows produce undefined behaviour by design.

### Manifest constraints

- `description` text must not contain `|`, backticks, markdown link syntax `[...](...)`, or newlines (validated at step 2).
- `id` is the row identifier and is used to derive the `auto-do/<id>` branch name; must be slug-safe.
- `last_updated` is a YAML key in frontmatter, set by `/auto-fleet` on every disk-write.
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
