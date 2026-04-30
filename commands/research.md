---
description: Synthesise external context (Jira, Confluence, web, files, pasted text) into structured docs/research/ entries
argument-hint: <jira-id|url|file-path> [--type=interview|context]
---

Pull source material from a tool, page, or file; convert it into the workshop's structured `### Insight:` format; write it to `docs/research/`.

User arguments: $ARGUMENTS

## Steps

1. **Confirm git context.** Run `git rev-parse --show-toplevel`. Abort if not in a git repo.

2. **Confirm research target.** If `docs/research/` does not exist, mention `/init-workshop` and offer to create the `interviews/` and `context/` subdirs inline.

3. **Detect source type from $ARGUMENTS.**
   - Matches a Jira issue ID pattern (e.g. `PROJ-123`) → Jira mode.
   - Matches a Confluence URL or numeric page ID → Confluence mode.
   - Starts with `http://` or `https://` → web mode.
   - Existing file path → file mode.
   - Empty → ask the user to paste source text inline.
   - Ambiguous → ask the user to clarify.

4. **Fetch the source.**
   - **Jira**: use `mcp__claude_ai_Atlassian_Rovo__getJiraIssue` to fetch summary, description, comments, linked issues. If the MCP is not available, ask the user to paste the issue content.
   - **Confluence**: use `mcp__claude_ai_Atlassian_Rovo__getConfluencePage`. Fall back to paste if the MCP is unavailable.
   - **Web URL**: use `WebFetch` to retrieve and convert to markdown.
   - **File**: read the path directly.
   - **Pasted text**: use what the user provided.

5. **Determine output type.**
   - If `--type=interview` is set, or the source is recognisably an interview transcript, target `docs/research/interviews/<participant-slug>.md` with the README's interview frontmatter (`participant`, `date`, `focus`).
   - Otherwise target `docs/research/context/<slug>.md` with frontmatter (`source`, `date`, `topic`).
   - Confirm the target path with the user before writing.

6. **Synthesise insights.** Read the fetched content and produce structured `### Insight:` blocks:
   ```
   ### Insight: <short name>
   **Quote**: "<verbatim or near-verbatim line from source>"
   **Implication**: <one sentence on what this means for the work>
   **Confidence**: <low | medium | high | n/m source consensus>
   ```
   Aim for 3–8 insights per source. Fewer high-quality insights beats many weak ones.

7. **Write the file.** Order: frontmatter, a one-paragraph "Source summary", then the `### Insight:` blocks. Include the source URL/issue ID/file path in the frontmatter so future skills can trace the lineage.

8. **Report.** Print the path written, the number of insights synthesised, and a suggestion: "Consider `/brainstorm <topic>` to expand on this, or `/plan <task>` if a direction is already clear."

## Degradations

- **Atlassian MCP not configured** → fall back to paste-only input; mention the MCP only once per session.
- **WebFetch fails (404, blocked, etc)** → ask the user to paste the content manually.
- **No `docs/research/`** → suggest `/init-workshop`, offer inline `mkdir -p docs/research/{interviews,context}`.
- **Source has no extractable insights** → write the summary only, note "no structured insights extracted" in the file body so future readers know it was a deliberate skip.
