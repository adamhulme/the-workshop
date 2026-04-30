---
description: Multi-perspective ideation across four fixed lenses (user, ops, scope, risk), grounded in docs/research/
argument-hint: <topic>
---

Generate a brainstorm doc that examines a topic from four perspectives, surfaces tensions where they disagree, and lands as a structured artefact in `docs/brainstorms/`. Pulls relevant research first so the brainstorm is grounded.

User arguments: $ARGUMENTS

## Steps

1. **Confirm git context.** Run `git rev-parse --show-toplevel`. Abort if not in a git repo.

2. **Confirm brainstorm target.** If `docs/brainstorms/` does not exist, mention `/init-workshop` and offer to create it inline.

3. **Gather grounding material.** Search `docs/research/interviews/` and `docs/research/context/` for files whose slug or content shares keywords with `$ARGUMENTS`. Read up to 5 most-relevant files. Surface the matched files to the user before generating: `Found <N> relevant research files. Include them as grounding? (y/n/list)`. Skip if none found.

4. **Generate the four-lens analysis.** For the topic in `$ARGUMENTS`, produce one section per lens. Each section is 4–8 bullets, drawing on the research files where possible.

   - **User** — what does this change for the person using it? What problem does it solve, what new friction does it introduce, who is the actual end user?
   - **Ops** — what does this change for the team running, deploying, supporting, monitoring it? Migrations, backfills, alerting, runbooks, on-call.
   - **Scope** — is this the smallest thing that solves the problem? What could be cut without losing the core value? What's a v0.1 vs v1 vs v2 split?
   - **Risk** — what could break? What's the blast radius? What's hard to reverse? Where are the unknowns?

5. **Surface tensions.** Add a `## Tensions` section that explicitly names where the lenses disagree. Don't smooth them — name them. Example: "User wants <X>, Ops wants <Y>, these conflict because <Z>."

6. **Derive and validate a slug.** Take the slug from `$ARGUMENTS` or by asking the user.

   Validate before using it as a path:
   - **Reject** if it contains path separators (`/`, `\`), `..` segments, or starts with `/`, `~`, or a Windows drive letter (e.g. `C:`). These would write outside `docs/brainstorms/`.
   - **Reject** characters that are illegal in filenames on common filesystems (newlines, NUL, `:`, `*`, `?`, `"`, `<`, `>`, `|`).
   - If the slug isn't already kebab-case (lowercase ASCII alphanumerics + hyphens), normalise: lowercase, replace runs of whitespace/underscores/punctuation with `-`, collapse repeated hyphens, trim leading/trailing hyphens. Show the normalised result and confirm: `Use slug <normalised>? (y / paste alternative)`.

   On rejection, ask the user for a clean slug and re-validate. Then confirm: `Save brainstorm as docs/brainstorms/<slug>.md? (y / paste alternative)`. Handle collision by prompting.

7. **Write the file.** Frontmatter:
   ```
   ---
   date: <YYYY-MM-DD>
   slug: <slug>
   topic: <one-line summary>
   research: [<paths to grounding files>]
   ---
   ```
   Followed by sections: `## User`, `## Ops`, `## Scope`, `## Risk`, `## Tensions`.

8. **Report.** Print path written, count of grounding research files, count of tensions surfaced, and a suggestion: "Consider `/plan <slug>` to lock in a direction, or `/solution <slug>` to capture the chosen path with rationale."

## Degradations

- **No `docs/brainstorms/`** → suggest `/init-workshop`, offer inline `mkdir`.
- **No research files exist yet** → generate the brainstorm from scratch, note "ungrounded" in the file body.
- **Topic too narrow for four-lens treatment** → still produce all four sections; sections that genuinely have no material write `none — this lens doesn't apply because <reason>`.
- **Slug collision** → prompt for unique slug or explicit overwrite.
