# Artifact conventions

Portability: `portable`

## Purpose

Every meaningful task should leave a durable artifact that future sessions can reuse instead of rediscovering context.

## Canonical paths

- `docs/research/` — source material that fuels future work.
- `docs/research/interviews/` — structured interview or observation notes.
- `docs/research/context/` — product, market, technical, Jira, Confluence, web, or pasted context.
- `docs/brainstorms/` — multi-perspective ideation.
- `docs/plans/` — approved implementation plans.
- `docs/solutions/` — decision, execution, and outcome records.
- `docs/changelog.md` — release narrative synthesized from merged work.
- `todos/` or `TODOS.md` — triageable follow-ups.

## Rules

1. Prefer updating the canonical artifact over scattering notes in ad-hoc files.
2. Use frontmatter when an artifact has status, date, tags, source, participant, or category metadata.
3. Link artifacts forward and backward when one informed another.
4. If a workflow creates follow-up work, place it where triage can find it.
5. Runtime-specific memories should point to these paths rather than redefining them independently.
