# Triage workflow

Portability: `adapter-required`

## Purpose

Sweep the available inboxes — `todos/`/`TODOS.md`, open PR review comments, and an issue tracker queue — and surface the highest-leverage next moves.

## Inputs

None required. Each source degrades independently if its connector is unavailable.

## Contract

1. Always read `todos/`/`TODOS.md`.
2. Pull open PR review comments for the current branch when a code-host connector is available, distinguishing resolved from unresolved threads where the connector supports it.
3. Pull an assigned issue-tracker queue when a connector is configured.
4. Categorise every item as exactly one of: Correctness, Scope, Cleanup, Blocked.
5. Score each on cost (effort), value (what it unblocks), and decay (does waiting make it worse); rank by leverage.
6. Report per-source counts, per-category counts, and the top 3 items across all sources with rationale and a suggested next move.
7. If a source's connector is unavailable, say so explicitly rather than silently omitting it.

## Adapter notes

PR-comment retrieval and issue-tracker retrieval depend on harness-specific connectors (CLI, MCP, or API). Substitute the native equivalent per runtime, but preserve the categorisation, scoring, and top-3 output shape.
