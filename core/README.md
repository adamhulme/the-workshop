# Workshop core

Runtime-neutral workshop canon. These files describe the reusable workflow contracts, artifact schemas, and review rubrics that should behave the same whether a human invokes them from Claude Code, Codex, or another agent harness.

Adapters live outside this directory:

- `commands/` and `agents/` are the Claude Code adapter.
- `codex/skills/` and `codex/agents/` are the Codex adapter.

Keep durable rules here. Keep harness mechanics — slash-command names, structured question APIs, sub-agent invocation syntax, local config paths, and model names — in the adapter files.

## Known gap: one-directional linking

`codex/skills/*.md` cite their `core/workflows/*.md` contract. `commands/*.md` (the Claude adapter) do not yet cite the same files — they predate this split and carry their full contract inline. Until that's fixed, editing a `commands/*.md` workflow can silently drift from its `core/` counterpart with nothing to catch it. Tracked in `TODOS.md`.
