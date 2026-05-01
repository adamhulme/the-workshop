---
description: Engineering manager-mode plan review — scope, architecture, code quality, tests, performance — with an optional independent Codex second opinion
argument-hint: [path/to/plan.md]
---

Review an engineering plan thoroughly before implementation begins. Walk the user through scope, architecture, code quality, tests, and performance — one issue at a time, with opinionated recommendations and explicit tradeoffs. Append findings to the plan file (or `TODOS.md` if no plan file is targeted).

User arguments: $ARGUMENTS

## Resolve the plan file

1. **If `$ARGUMENTS` is a path:** read it. Abort gracefully if the file does not exist.
2. **If `$ARGUMENTS` is empty:**
   - If `docs/plans/` exists and contains files, list the three most recently modified and ask: `Which plan to review? (paste path or filename)`. Default to the most recent on enter.
   - If `docs/plans/` does not exist, ask the user to paste the plan content inline or point at a path.
3. Confirm the resolved path back to the user before starting: `Reviewing <path>. Proceed? (y/n)`.

## Review preferences (use these to anchor recommendations)

- **DRY matters** — flag repetition aggressively.
- **Tests are non-negotiable** — too many tests beats too few.
- **Engineered enough** — not under (fragile, hacky), not over (premature abstraction).
- **Edge cases over speed** — thoughtfulness wins.
- **Explicit over clever.**
- **Right-sized diff** — smallest diff that cleanly expresses the change. Don't compress a necessary rewrite into a minimal patch; if the foundation is broken, say so.
- **Diagrams** — ASCII diagrams for non-trivial data flow, state machines, pipelines. Embed in code comments where the structure is non-obvious.

## Critical rule — how to ask questions

- **One issue = one question.** Never batch multiple issues into a single prompt.
- Describe the problem concretely with file/line references where possible.
- Present 2–3 options including "do nothing" where reasonable.
- For each option, state effort, risk, and maintenance burden in one line.
- Tie your recommendation to a specific preference above (DRY, explicit > clever, minimal diff, etc.).
- Label issues with NUMBER + LETTER (e.g., "3A", "3B").
- After each section, pause and confirm before moving on.

## Step 0 — Scope challenge

Before reviewing anything else, work through the plan with these questions and surface findings:

1. **What already exists?** What code already partially or fully solves each sub-problem? Can existing flows be reused instead of building parallel ones?
2. **Minimum viable change.** What is the smallest set of changes that achieves the stated goal? What could be deferred without blocking the core objective?
3. **Complexity smell.** If the plan touches more than 8 files or introduces more than 2 new classes/services, treat that as a smell. Challenge whether the same goal is achievable with fewer moving parts.
4. **Built-in vs custom.** For each architectural pattern, infrastructure component, or concurrency approach the plan introduces, ask: does the runtime/framework already provide this? If the plan rolls a custom solution where a built-in exists, flag it as a scope reduction opportunity.
5. **TODOS cross-reference.** Read `TODOS.md` if it exists. Are any deferred items blocking this plan? Could any be bundled in without expanding scope? Does this plan create new work that should be captured as a TODO?
6. **Distribution.** If the plan introduces a new artifact (CLI, library, container, mobile app), is the build/publish pipeline part of the plan? Code without distribution is code nobody can use.

If the complexity smell triggers (8+ files or 2+ new services), recommend a scope reduction explicitly: explain what's overbuilt, propose a minimal version, and ask the user before continuing. Otherwise, present Step 0 findings and proceed.

**Once scope is agreed, commit fully.** Do not re-argue for smaller scope during later sections.

## Section 1 — Architecture review

Evaluate:

- **Component boundaries.** Are modules cohesive? Do they leak responsibilities into one another?
- **Dependency direction.** Does data/control flow in one direction, or are there cycles? Are contracts (interfaces, DTOs) at the boundary, or are implementations leaking across?
- **Data flow.** Trace the critical paths. Where does input enter, what transforms it, where does it land? Are there bottlenecks, single points of failure, or scaling cliffs?
- **Failure scenarios.** For each new codepath or integration point, describe one realistic production failure (timeout, partial write, stale cache, race) and whether the plan accounts for it.
- **Diagram-worthy?** If a flow is non-trivial, recommend an ASCII diagram in the plan or in code comments.
- **Boring by default.** Is the plan spending an innovation token wisely, or reaching for novelty where boring tech would do?

**STOP.** For each issue found, ask the user one question at a time with options and a recommendation. Resolve all issues before moving on.

If no issues, say "Architecture: no issues found" and continue.

## Section 2 — Code quality review

Evaluate:

- **Module structure and naming.** Are names accurate? Do they match domain language? Are responsibilities clear from the name alone?
- **DRY violations.** Be aggressive. Flag any repeated logic, parallel-but-similar abstractions, or duplicated validation/mapping.
- **Refactoring opportunities.** Is there a "make the change easy, then make the easy change" refactor that should land first?
- **Error handling.** What's the failure model? Are errors handled at the right layer? Are silent failures possible?
- **Over- vs under-engineering.** Premature abstraction is just as bad as fragility. Call out either.
- **Stale diagrams.** If the change touches files with existing ASCII diagrams in comments, are those still accurate? Update them as part of this change.

**STOP.** One question per issue. Resolve all before moving on.

## Section 3 — Test review

Goal: every codepath added or modified has a test. The plan should be complete enough that tests are written alongside the feature, not deferred.

**Step 3a. Trace every codepath.**

For each new feature, service, endpoint, or component in the plan:
- Where does input come from? (params, props, DB, API)
- What transforms it? (validation, mapping, computation)
- Where does it go? (DB write, API response, side effect)
- What can go wrong at each step? (null, invalid input, network failure, empty collection)

**Step 3b. Map user flows and error states.**

Code coverage is not enough. For each user-facing change, think through:
- **User flows** — full sequence of actions touching this code (e.g., click → validate → API → success/failure screen).
- **Interaction edge cases** — double-click, navigate away mid-op, stale data submit, slow connection, concurrent tabs.
- **Error states the user sees** — clear message vs silent failure, recoverable vs stuck, no network, 500 from API, malformed server response.
- **Empty/zero/boundary** — zero results, 10000 results, single character, max-length input.

**Step 3c. Output an ASCII coverage diagram.**

Map every branch (code path AND user flow) against existing tests. Mark each as `[★★★ TESTED]`, `[★★ TESTED]`, `[★ TESTED]`, or `[GAP]`. Mark integration-worthy gaps as `[→E2E]` and LLM/prompt changes as `[→EVAL]`.

```
CODE PATHS                                            USER FLOWS
[+] src/services/billing.ts                           [+] Payment checkout
  └── processPayment()                                  ├── [★★★ TESTED] Complete purchase
      ├── [★★★ TESTED] happy + declined + timeout       ├── [GAP] [→E2E] Double-click submit
      └── [GAP]         Network timeout                 └── [GAP]         Navigate away mid-payment

COVERAGE: 3/7 paths tested  |  GAPS: 4 (1 E2E)
```

Quality:
- **★★★** — behaviour + edge cases + error paths
- **★★** — happy path only
- **★** — smoke check / "it renders"

**Step 3d. Regression rule (mandatory).**

If the plan modifies existing behaviour (not new code) and the existing test suite does not cover the changed path, **a regression test is added to the plan as a critical requirement.** No question asked. Regressions get the highest priority because they prove something broke.

**Step 3e. Add the missing tests to the plan.**

For each gap, add a test requirement to the plan: file to create, what to assert, unit vs integration vs eval. Be specific.

**STOP.** One question per remaining ambiguity. Resolve before moving on.

## Section 4 — Performance review

Evaluate:

- **N+1 queries** — loops issuing one query per iteration. Look for ORM lazy-loading patterns, especially in serialisation/mapping layers.
- **Hot paths** — what runs on every request? Every render? Are expensive operations cached, memoised, or moved off the hot path?
- **Memory** — are large collections materialised when streaming would do? Are subscriptions/timers cleaned up?
- **Caching opportunities** — what's safe to cache, what's the invalidation story?
- **Algorithmic complexity** — any O(n²) hiding in a `.find()` inside a `.map()`?

**STOP.** One question per issue. Resolve before moving on.

## Section 5 — Outside voice (optional)

After all sections complete, offer one independent second opinion. Ask:

> All review sections are complete. Want an independent Codex second opinion? Codex will challenge the plan for logical gaps, feasibility risks, and blind spots. Takes about 2 minutes. (Requires `codex` on PATH.)

If yes, dispatch Codex via `Bash` — **pipe the prompt via stdin** and use the gstack dispatch pattern. Don't pass the prompt as a positional arg; long prompts hang in some shells and trip arg-length limits.

```bash
PLAN_PATH="path/to/your/plan.md"   # set to the resolved plan file
TMPF=$(mktemp)
TMPERR=$(mktemp)
{
  cat <<'PROMPT_HEAD'
You are a brutally honest technical reviewer examining a development plan that has
already been through a multi-section review. Your job is NOT to repeat that review.
Find what it missed: logical gaps, unstated assumptions, overcomplexity (is there a
fundamentally simpler approach?), feasibility risks, missing dependencies or sequencing
issues, strategic miscalibration. Be direct. Be terse. No compliments. Just the
problems. Cap output at 800 words.

THE PLAN:

PROMPT_HEAD
  cat "$PLAN_PATH"
} > "$TMPF"

_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
codex exec --skip-git-repo-check \
  -C "$_REPO_ROOT" \
  -s read-only \
  -c 'model_reasoning_effort="high"' \
  --enable web_search_cached \
  - < "$TMPF" 2>"$TMPERR"

# Surface any stderr (auth errors, timeouts) to the user before cleanup
[ -s "$TMPERR" ] && cat "$TMPERR" >&2
rm -f "$TMPF" "$TMPERR"
```

Why this pattern (borrowed from gstack):
- **Stdin piping** (`-` positional + `< "$TMPF"`) avoids shell argument length limits and quote-escaping breakage on long plans.
- **`-C "$_REPO_ROOT"`** anchors codex to the repo so it can read project files if needed.
- **`-s read-only`** sandboxes codex so it can't accidentally edit anything.
- **`model_reasoning_effort="high"`** is the sweet spot: thorough enough for review work, faster than the default `xhigh` which can hang on big prompts.
- **`--enable web_search_cached`** lets codex pull in current best practices when relevant.
- **Stderr capture** surfaces auth failures and timeouts cleanly; users see "run `codex login`" instead of a silent hang.
- **Cap output at 800 words** in the prompt — keeps codex from generating a 4000-word essay you have to skim.

If `codex` is not on PATH, fall back to an `Agent` call with `subagent_type: general-purpose` and the same prompt body.

Present Codex's output verbatim under an `OUTSIDE VOICE (Codex):` header. Surface any disagreements with earlier review findings as `CROSS-MODEL TENSION:` blocks — present both sides neutrally and ask the user to decide. Do not auto-incorporate outside voice findings; the user approves each one.

If the user skips outside voice, note "Outside voice skipped" and continue.

## Required outputs

Append these sections to the plan file (or write them to a fresh `## Engineering Review` block at the end):

### NOT in scope

List work that was considered and explicitly deferred, with a one-line rationale per item. This section MUST exist — even if it's just one bullet — so deferred work is visible to anyone reading the plan later.

### What already exists

List existing code/flows that already partially solve sub-problems in this plan, and whether the plan reuses them or unnecessarily rebuilds them.

### Failure modes

For each new codepath in the test diagram, list one realistic production failure mode and whether: (1) a test covers it, (2) error handling exists, (3) the user sees a clear error or a silent failure. Flag any failure mode with no test AND no error handling AND silent behaviour as a **critical gap**.

### TODOs

For each potential follow-up surfaced during the review, ask the user one question at a time:
- **What** — one line.
- **Why** — concrete problem solved or value unlocked.
- **Pros / cons** — one line each.
- **Context** — enough that someone picking this up in 3 months understands.
- **Depends on** — any prerequisites.

Options per TODO: A) add to `TODOS.md` · B) skip — not valuable enough · C) build it now in this PR.

Never silently append vague bullets. A TODO without context is worse than no TODO.

### Completion summary

End with a one-block summary the user can scan in 10 seconds:

```
Step 0 — Scope: <accepted as-is | reduced per recommendation>
Architecture:   <N> issues found, <M> resolved
Code quality:   <N> issues found, <M> resolved
Tests:          diagram produced, <N> gaps identified, <K> regression tests added
Performance:    <N> issues found, <M> resolved
Outside voice:  <ran | skipped>
NOT in scope:   written
Failure modes:  <N> critical gaps flagged
TODOs:          <N> proposed, <K> added, <M> built inline, <L> skipped
Unresolved:     <list any decisions the user moved past without picking>
```

## Persisting the report

- **If the resolved plan is in `docs/plans/`:** append the review block to that file under `## Engineering Review` (or replace an existing block of that name).
- **If the resolved plan is elsewhere or pasted inline:** append the review block to `TODOS.md` at the project root, prefixed with `## Engineering Review — <plan name> — <YYYY-MM-DD>`. Create `TODOS.md` if it doesn't exist.

## Unresolved decisions

If the user moves past an `AskUserQuestion`-style prompt without picking, record it under "Unresolved decisions" in the completion summary. Never silently default to an option.

## Degradations

- **No plan file found** → ask the user to paste the plan content inline.
- **Plan is empty or trivial** → say so and ask whether to proceed (the review is meant for substantive plans).
- **Outside voice agent fails or times out** → note "Outside voice unavailable" and continue.
