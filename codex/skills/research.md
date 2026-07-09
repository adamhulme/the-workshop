# Codex skill: research

Shared contract: `core/workflows/research.md`

## Use when

The user provides a URL, issue, document, transcript, local file, or pasted material that should become reusable context.

## Codex behavior

1. Fetch or read the source with available Codex tools.
2. If a connector is unavailable, ask the user to paste the source.
3. Distinguish direct source facts from inference.
4. Write the structured note under `docs/research/context/` or `docs/research/interviews/`.
5. Include frontmatter and `### Insight:` blocks.

## Connector notes

Do not use Claude MCP tool names. Use the connectors available in the current Codex environment, or fall back to paste-in source.
