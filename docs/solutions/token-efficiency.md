---
status: outcome
date: 2026-05-07
started: 2026-05-07
shipped: 2026-05-07
slug: token-efficiency
category: tooling
tags: [token-efficiency, hooks, context-management, developer-experience]
---

## Problem

Sessions hit organisation-imposed token limits well before the work is done. The root causes are scattered — verbose output, full-file reads when 50 lines would suffice, code blocks quoted back when the user already has the file open, unbounded tool output flooding the context window. No single fix addresses all of them, and the existing CLAUDE.md / skill system had no token-awareness at all.

Trigger: user reported frequent session-limit hits and asked for "quirky but efficient ideas to reduce token consumption."

## Options considered

A brainstorm surfaced 10 ideas across two axes (input vs output tokens) and rated them on impact, effort, and quirkiness. The full brainstorm lives in conversation context (not persisted — it was a live ideation session, not a `/brainstorm` artefact). The top 3 by impact-to-effort ratio:

1. **No-Quote Rule** — a CLAUDE.md directive: never quote code blocks back, reference `path:line` instead. Zero implementation cost, saves 500–2K output tokens/session. **Trade-off:** occasionally less readable when discussing code without the file open.

2. **Grunt Mode** — a `/grunt` command that switches Claude to structured shorthand for the session (`✎`/`🔍`/`✓`/`⚠`/`✗` grammar). Saves ~60–80% of output tokens. **Trade-off:** output is terser than some users prefer; session-scoped so must be re-invoked each session.

3. **Diff-Only Vision** — a PreToolUse hook on Read that warns when reading large files without `offset`/`limit`, combined with a CLAUDE.md directive to grep-before-read. Saves ~50–80% on file reads. **Trade-off:** adds a hook dependency; occasional false positives on files that genuinely need full reads (configs, short-ish files near the 200-line threshold).

Remaining 7 ideas (Bonsai skill pruning, TL;DR hook, Skill Layering, Rosetta Protocol, Two-Token Review, Context Checkpoint, The Accountant) deferred — higher effort or narrower impact.

## Chosen approach

All three top ideas, implemented together as complementary layers:

- **Always-on layer** (CLAUDE.md) — three directives that apply every session without invocation: reference-don't-paste, grep-before-read, trim-tool-output.
- **Opt-in layer** (`/grunt`) — aggressive terse mode for users actively managing token budgets.
- **Automated layer** (`diet-read.sh` hook) — machine enforcement of read hygiene, firing before every Read tool call.

## Rationale

- **Layered approach compounds.** Each mechanism catches what the others miss — CLAUDE.md directives shape behaviour, the hook catches when the directive is forgotten, and `/grunt` compresses what the other two can't touch (output verbosity).
- **Zero-friction baseline.** The always-on CLAUDE.md rules have no downside and no activation cost. Users who never invoke `/grunt` or install the hook still benefit.
- **The hook has no dependencies.** Initial implementation used `jq` for JSON parsing — broke immediately on a system without it. Rewritten to bash-native `grep`/`sed`. Hooks must assume nothing about the target environment beyond bash.
- **Grunt mode is session-scoped by design.** Persisting terse mode across sessions via CLAUDE.md modification was considered and rejected — it's too invasive for a toggle, and different tasks want different verbosity levels.

## In progress

**Branch:** `feat/token-efficiency` (off `main`)

**What's being built:**

- `CLAUDE.md` — new `## Token efficiency` section between `## Coding philosophy` and `## Learned principles`.
- `commands/grunt.md` — new skill file, ~50 lines. Session-scoped toggle with response grammar table and hard constraints.
- `hooks/diet-read.sh` — new hook script, ~20 lines of logic. PreToolUse hook for Read; bash-native JSON parsing; warns on files >200 lines read without offset/limit.
- `install.sh` — extended `install_dir` to accept file extension parameter; added `install_dir hooks sh` with `chmod +x`; updated summary message with hook setup instructions.
- `update.sh` — extended `ALLOWED_RE` to include `hooks/*.sh` for manifest pruning.

## Outcome

**PR:** [#27](https://github.com/adamhulme/the-workshop/pull/27) — on `feat/token-efficiency`.

**What shipped:**

- `CLAUDE.md` — three always-on token efficiency directives (reference-don't-paste, grep-before-read, trim-tool-output).
- `commands/grunt.md` — terse output toggle with structured shorthand grammar. `/grunt` on, `/grunt off` off.
- `hooks/diet-read.sh` — PreToolUse hook for Read. No `jq` dependency (bash-native parsing). Handles JSON `null` values. Self-documenting setup instructions in file header.
- `install.sh` — `install_dir` now accepts a file extension parameter; hooks are installed with `+x` permission; summary message includes hook setup guidance.
- `update.sh` — `ALLOWED_RE` extended to prune hooks alongside commands and agents.

**Plan-vs-reality drift:**

- The hook initially used `jq` for JSON parsing. First test run failed — `jq` wasn't installed. Rewrote to bash-native `grep`/`sed` in the same session. This validated the "zero-dependency hooks" principle before it was even articulated.
- JSON `null` handling was missed in the first pass. `"offset": null` was treated as non-empty, silently skipping the warning. Added a null-filter to the `extract` function after the second test round.

**What worked:**

- **Brainstorm-then-filter was the right shape.** Generating 10 ideas and scoring them on impact/effort/quirkiness before implementing any produced a better top-3 than jumping to the first good idea would have. The scoring matrix made the trade-offs explicit.
- **Testing the hook immediately caught both issues.** The `jq` dependency and the `null` handling bug were found in seconds because the test cases were run before committing. For hooks especially — which run in arbitrary environments — testing on the actual system is non-negotiable.
- **Layered mechanisms with different activation costs.** Always-on (CLAUDE.md) → opt-in (command) → automated (hook) gives users three levels of engagement without requiring any of them.

**What didn't:**

- **Assumed `jq` availability.** Wrote the hook with `jq` first because it was the "obvious" JSON parsing tool, then had to rewrite. For workshop hooks that ship to arbitrary environments, should have started with bash-native parsing.
- **The null-handling edge case.** Claude Code sends `null` for unset optional Read parameters. The initial `grep` extract treated `null` as a non-empty string. This is a class of problem — JSON values that look truthy to bash string tests but are semantically absent.

**Reusable principle:**

1. Zero-dependency hooks — hook scripts that ship to arbitrary environments must parse with bash builtins only. External tools (`jq`, `python`, `node`) may not exist on the target system. The input shapes for Claude Code hooks are simple enough that `grep`/`sed` suffice.
2. Layered reduction beats single-mechanism — multiple complementary mechanisms at different activation costs (always-on directives, opt-in modes, automated enforcement) compound better than one aggressive approach. Each layer catches what the others miss without requiring user buy-in for all of them.

**Prevention:**

- **For the `jq` class of issue:** a CLAUDE.md principle ("hooks must be zero-dependency") would catch this at authoring time. Worth adding.
- **For the null-handling class:** the `extract` helper in `diet-read.sh` now filters `null` explicitly. Future hooks that copy this pattern inherit the fix. No systemic prevention needed beyond the pattern being visible.

### System TODO

- The deferred brainstorm ideas (Bonsai, Skill Layering, Context Checkpoint, The Accountant) remain viable for a future pass if token limits continue to bite. No formal tracking needed — they live in the conversation that triggered this work.

## See also

- No `docs/plans/` or `docs/brainstorms/` for this slug — the brainstorm was in-conversation, and the scope was small enough to skip a formal plan.
