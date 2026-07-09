# Research workflow

Portability: `adapter-required`

## Purpose

Turn external or pasted source material into structured, reusable context under `docs/research/`.

## Inputs

- Jira issue, Confluence page, web URL, local file, transcript, or pasted text.
- Optional type: `interview` or `context`.

## Retrieval

Adapters may use MCP tools, browser/web fetch tools, shell commands, or paste prompts. If a connector is unavailable, ask the user for pasted source rather than inventing details.

## Output

For context notes, write `docs/research/context/<slug>.md`.

For interviews or observation sessions, write `docs/research/interviews/<participant-or-session-slug>.md`.

Use frontmatter for source, date, type, participants, and tags. Prefer structured `### Insight:` blocks with:

- evidence or quote when available.
- implication.
- confidence.
- related artifacts or follow-ups.

## Rules

Cite source locations when possible. Separate source facts from model inference. Do not over-summarize away dissent or uncertainty.
