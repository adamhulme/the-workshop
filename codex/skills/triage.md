# Codex skill: triage

Shared contract: `core/workflows/triage.md`

## Use when

The user asks what to do next or wants inboxes swept.

## Codex behavior

1. Inspect `todos/` and `TODOS.md`.
2. Inspect open PR comments when `gh` is available.
3. Inspect issue tracker queues when connectors are available.
4. Rank the top moves by leverage, urgency, unblock value, and risk.
5. If an inbox is unavailable, report the limitation instead of hiding it.
