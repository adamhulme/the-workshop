# Workshop core

Runtime-neutral workshop canon. These files describe the reusable workflow contracts, artifact schemas, and review rubrics that should behave the same whether a human invokes them from Claude Code, Codex, or another agent harness.

Adapters live outside this directory:

- `commands/` and `agents/` are the Claude Code adapter.
- `codex/skills/` and `codex/agents/` are the Codex adapter.

Keep durable rules here. Keep harness mechanics — slash-command names, structured question APIs, sub-agent invocation syntax, local config paths, and model names — in the adapter files.
