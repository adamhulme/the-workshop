---
status: outcome
date: 2026-07-09
started: 2026-07-09
shipped: 2026-07-09
slug: workshop-runtime-split
category: architecture
tags: [multi-runtime, codex, install-sh, compounding-artefacts]
---

## Problem

The workshop's skills, agents, and rubrics were written entirely as Claude Code artefacts (`commands/*.md`, `agents/*.md`, `CLAUDE.md`, `install.sh`/`update.sh` targeting `~/.claude/`). Adding support for a second agent harness (Codex) needed a home for the doctrine and workflow contracts that should behave identically regardless of which harness invokes them, without forcing Codex to pretend it has Claude Code's slash-command/sub-agent mechanics.

## Options considered

1. **Lowest-common-denominator prompt dump.** One generic instruction set both runtimes read verbatim. **Trade-off:** loses each runtime's native mechanics (Claude's `AskUserQuestion`, sub-agent dispatch; Codex's own idioms) — everything degrades to the intersection of both harnesses' capabilities.
2. **Codex-only prompt translation.** Hand-translate each Claude command into a Codex-flavoured prompt with no shared source. **Trade-off:** two independent copies of every workflow's logic from day one — drift is immediate and undetectable.
3. **Full parity rewrite.** Port every Claude command/agent to Codex before shipping anything. **Trade-off:** blocks shipping on completing 19 workflow ports; several (`auto-do`, `auto-fleet`, `review-pr`) need harness-native orchestration that doesn't translate directly.
4. **Hybrid: shared `core/` canon + native adapters (chosen).** Extract the runtime-neutral contract for each workflow into `core/workflows/*.md` and `core/rubrics/*.md`. Each runtime (`commands/`+`agents/`+`CLAUDE.md` for Claude, `codex/skills/`+`codex/agents/` for Codex) adapts that contract to its own mechanics. A `core/workflows/compatibility-matrix.md` classifies each workflow's port difficulty (`portable` / `adapter-required` / `native-rewrite` / `personal-template`) so porting is a lookup, not a re-litigated question each time.

## Chosen approach

Option 4. Concretely:

- `core/` holds the portable contract (inputs, gates, output shape, rules) for each workflow and rubric — the source of truth adapters should not redefine.
- `WORKSHOP.md` holds runtime-neutral doctrine (coding philosophy, artifact conventions, learned principles) that both `CLAUDE.md` and Codex's own instruction file mirror so it auto-loads in each harness.
- `codex/skills/` and `codex/agents/` are the initial Codex adapter, covering the `portable` and most `adapter-required` workflows from the compatibility matrix.
- `install.sh`/`update.sh` became runtime-aware (`--claude`/`--codex`/`--both`), with per-runtime manifests and prune allowlists so updating one runtime's files can never touch the other's.

## Rationale

- Native adapters over lowest-common-denominator: `docs/solutions/browse.md` and prior work already established that harness-specific mechanics (structured questions, sub-agent dispatch) are worth keeping rather than flattening to what both harnesses can do.
- A compatibility matrix over a full rewrite: makes "should this be ported, and how" a lookup instead of a fresh judgment call for every future workflow, and lets partial adapter coverage ship without pretending it's complete.
- Per-runtime manifests in `install.sh`/`update.sh`: preserves the existing "never trust manifest-supplied paths for `rm`" safety invariant under added complexity rather than weakening it — the prune allowlist just gained a nested-path case it initially got wrong (see below).

## Outcome

PR: [#32](https://github.com/adamhulme/the-workshop/pull/32) — `codex/analyze-claude-code-skills-repository` → `main`.

What shipped: `core/` (11 workflow contracts + 8 rubrics + compatibility matrix), `codex/skills/` (13 skills) and `codex/agents/` (8 reviewer/investigator prompts), `WORKSHOP.md`, and multi-runtime `install.sh`/`update.sh`.

### Plan-vs-reality drift

- The compatibility matrix promised shared contracts ("share four-lens contract", "share git/PR synthesis contract", etc.) for `brainstorm`, `changelog`, `consult`, `design-capture`, `sanitise`, and `triage`, but the first cut of `core/workflows/` didn't actually include those six files — the corresponding `codex/skills/*.md` cited either a too-generic fallback (`core/workflows/artifact-conventions.md`) or, in `design-capture`'s case, the wrong rubric entirely (`core/rubrics/design-plan-reviewer.md`, a plan-review rubric with no relation to documenting an existing app's design system). `/review-pr` round 1 caught this via three independent reviewers; the six missing core files were written and the citations corrected as part of addressing must/should-fix findings.
- `CLAUDE.md`'s banner claimed cross-runtime doctrine "now lives in `WORKSHOP.md`," but `CLAUDE.md` still carried the full doctrine verbatim while `WORKSHOP.md` independently restated a shorter, differently-worded version with an empty "Learned principles" stub. Resolved by making `WORKSHOP.md` the canonical text (fully populated, matching `CLAUDE.md`'s substance) and marking `CLAUDE.md`'s copy as an explicit mirror that must stay in sync — `CLAUDE.md` can't just point elsewhere since Claude Code only auto-loads that one file.
- The new Codex prune-allowlist regex in `update.sh` (needed to support nested `core/**/*.md` paths, unlike the old single-segment Claude allowlist) accepted `..` as a valid path-segment character sequence, which defeated the prune step's own safety invariant — a poisoned local manifest could have caused `rm -f` to delete files outside the install target. Fixed with an explicit per-segment `.`/`..` rejection before any prune decision.

### What worked

- The compatibility matrix as a design artefact: reviewers cited it approvingly as the mechanism that makes "should this be ported" a lookup rather than a re-litigated question — worth keeping as the model for any future runtime addition.
- Per-runtime manifest scoping in `install.sh`/`update.sh`: no cross-runtime pruning bugs surfaced in review — only the same-runtime traversal issue above.

### What didn't

- Shipping the compatibility matrix's *aspirations* ("share X contract") without shipping the actual `core/` files it promised — the matrix described a state the repo hadn't reached yet, and nothing caught the gap until manual review.
- Introducing a second file (`WORKSHOP.md`) that's supposed to be "the" canonical doctrine without actually making it canonical on day one — it shipped as a shorter, independently-drifted paraphrase of `CLAUDE.md` rather than the other way around.

### Reusable principle

**A promise in a matrix/index file (compatibility matrix, README table, adapter list) is a claim, not documentation — verify the referenced artefact exists before merging, the same way a broken link would be caught.** Applies to any future `core/workflows/*.md` addition or Codex skill port.

### Prevention

None automated yet. A future `/review-pr` or CI check could grep every `Shared contract: ` line in `codex/skills/*.md` against the existence of the referenced `core/` file, and flag matrix rows whose `Current file` or implied `core/` counterpart doesn't exist — logged as a follow-up rather than implemented inline here.

### System TODO

- A lint/CI check validating `codex/skills/*.md` "Shared contract" references resolve to real files, and that `core/workflows/compatibility-matrix.md` rows have a matching `core/workflows/*.md` file when the strategy column implies one.
- Backlinks from touched `commands/*.md` files to their `core/workflows/*.md` counterparts (deferred — see `TODOS.md`).

## See also

None — no prior `docs/plans/` or `docs/brainstorms/` entry exists for this work; it landed directly as a PR.
