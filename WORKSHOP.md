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

- Simplest fit wins.
- Readability beats cleverness.
- Prefer editing existing files over adding new ones when the existing file is the right home.
- Stay in scope.
- Ask explicitly at meaningful decision points.
- Do not add defensive machinery for impossible internal cases; validate real boundaries.

## Learned principles

Add broadly reusable principles here when they should guide both Claude and Codex. Runtime-specific lessons may remain in the corresponding adapter instructions.
