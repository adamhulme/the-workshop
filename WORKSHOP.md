# Workshop shared instructions

This file is runtime-neutral. Claude Code, Codex, and any future agent harness should read it as the shared workshop canon. Runtime-specific files such as `CLAUDE.md` may add local mechanics, but should not redefine these conventions.

## Artifact conventions

Use the shared artifact paths from `core/workflows/artifact-conventions.md`:

- `docs/research/` for source material.
- `docs/brainstorms/` for ideation.
- `docs/plans/` for approved plans.
- `docs/solutions/` for decision, execution, and outcome records.
- `docs/changelog.md` for release narrative.
- `todos/` or `TODOS.md` for triageable follow-ups.

## Runtime adapters

- Claude Code adapter: `commands/`, `agents/`, `CLAUDE.md`, `.claude/` install targets.
- Codex adapter: `codex/skills/`, `codex/agents/`, and this shared instruction file.
- Shared canon: `core/`.

## Coding philosophy

This is the canonical text. Runtime adapters (`CLAUDE.md`, Codex's own instruction file) mirror it verbatim so it loads automatically in each harness — keep both in sync when editing here.

- **Simplest fit wins.** Solutions match the scope. No premature abstractions, no design for hypothetical futures.
- **Readability over cleverness.** Names should make comments unnecessary. Comments are for **why**, not what.
- **Edit before adding.** Prefer modifying an existing file over creating a new one; new files only when nothing existing fits.
- **Stay in scope.** One idea per change. Drop unrelated findings in a triageable follow-up location instead of bundling them in.
- **Ask explicitly at meaningful decision points.** Use each runtime's structured-question mechanism rather than a trailing prose `(y/n)` prompt.
- **Don't add what wasn't asked.** No defensive machinery for impossible internal cases; validate real boundaries (user input, external APIs), not internal callers.

## Learned principles

Principles and prevention strategies extracted from shipped work, broadly reusable across runtimes. Runtime-specific lessons may remain in the corresponding adapter instructions instead.

- **Zero-dependency hooks.** Hook scripts that ship to arbitrary environments must parse with bash builtins only (`grep`/`sed`/parameter expansion). External tools (`jq`, `python`, `node`) may not exist on the target system. *(from docs/solutions/token-efficiency.md, 2026-05-07)*
- **Layered reduction beats single-mechanism.** Multiple complementary mechanisms at different activation costs (always-on directives, opt-in modes, automated enforcement) compound better than one aggressive approach. Each layer catches what the others miss. *(from docs/solutions/token-efficiency.md, 2026-05-07)*

<!-- Add new principles above this line. -->
