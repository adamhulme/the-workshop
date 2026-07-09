# Plan workflow

Portability: `adapter-required`

## Purpose

Develop an implementation plan before editing code, grounded in current repository state and any relevant workshop artifacts.

## Inputs

- Task description.
- Optional related files, issue IDs, research notes, or design constraints.

## Context to inspect

1. Existing plans in `docs/plans/` for similar tasks.
2. Relevant `docs/research/`, `docs/brainstorms/`, and `docs/solutions/` artifacts.
3. Repository instructions and learned principles from the active runtime plus the shared workshop conventions.
4. Current code paths likely to change.

## Gates

- Ask before creating `docs/plans/` if missing.
- Ask for approval before writing the plan.
- Ask before overwriting or replacing an existing plan slug.

## Output

Write `docs/plans/<slug>.md` with:

- frontmatter: `title`, `date`, `status`, `tags`, optional `related_research`.
- task summary.
- constraints and learned principles that apply.
- numbered implementation steps.
- files likely to change.
- verification plan.
- open questions or rejected alternatives.

## Adapter notes

Adapters should use their native structured-question mechanism. Avoid double approval gates: the plan workflow has one approval gate before writing.
