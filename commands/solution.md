---
description: Create or advance a solution doc through its lifecycle (decided → in-progress → outcome)
argument-hint: <slug>
---

A solution doc lives at `docs/solutions/<slug>.md` and captures one piece of work through three stages: **decided** (the chosen direction with rationale), **in-progress** (what's actually shipping), **outcome** (what shipped, what to watch). One file per piece of work; the stage is tracked in frontmatter.

User arguments: $ARGUMENTS

## Steps

1. **Resolve and validate the slug.** Take `$ARGUMENTS` as the candidate slug. If empty, prompt: `What's the slug for this solution? (e.g. feature-flags-v1)`.

   Validate before using it as a path:
   - **Reject** if it contains path separators (`/`, `\`), `..` segments, or starts with `/`, `~`, or a Windows drive letter (e.g. `C:`). These would write outside `docs/solutions/`.
   - **Reject** characters that are illegal in filenames on common filesystems (newlines, NUL, `:`, `*`, `?`, `"`, `<`, `>`, `|`).
   - If the slug isn't already kebab-case (lowercase ASCII alphanumerics + hyphens), normalise: lowercase, replace runs of whitespace/underscores/punctuation with `-`, collapse repeated hyphens, trim leading/trailing hyphens. Show the normalised result and confirm: `Use slug <normalised>? (y / paste alternative)`.
   
   On rejection, ask the user for a clean slug and re-validate. Target path is then `docs/solutions/<slug>.md`.

2. **Confirm target directory.** If `docs/solutions/` is missing, mention `/init-workshop` and offer to create it inline.

3. **Determine mode.**
   - **File doesn't exist** → new doc, write at `decided` stage (step 4).
   - **File exists** → read its frontmatter `status` field, then prompt:
     - For `decided` or `in-progress`: `This doc is at status <X>. Advance to <next>, or update the existing <X> section in place? (advance/update)`.
     - For `outcome`: `This doc is already at outcome. Append a dated follow-up note? (y/n)`. On `n`, exit without changes.
   - Stage transitions are linear: `decided` → `in-progress` → `outcome`. There is no rewind via this skill — if a stage was advanced in error, fix the frontmatter manually before re-running.

4. **Decided stage** (new file). Prompt for or infer from context:
   - **Problem** — one paragraph
   - **Options considered** — 2–4 options, each with a one-line trade-off
   - **Chosen approach** — the path forward
   - **Rationale** — why this beats the alternatives
   
   Write the file with frontmatter:
   ```
   ---
   status: decided
   date: <YYYY-MM-DD>
   slug: <slug>
   ---
   ```
   Followed by `## Problem`, `## Options considered`, `## Chosen approach`, `## Rationale` sections.

5. **In-progress stage** (advance from decided). Append a `## In progress` section capturing:
   - Branch name (from `git rev-parse --abbrev-ref HEAD`)
   - Commit range or PR if discoverable
   - What's actually being built (refinements to the chosen approach)
   
   Update frontmatter: `status: in-progress`, add `started: <YYYY-MM-DD>`.

6. **Outcome stage** (advance from in-progress). Append an `## Outcome` section capturing:
   - PR link (resolved via `gh pr view --json url` if available)
   - What shipped (one-paragraph summary)
   - What to watch (metrics, edge cases, follow-ups)
   - **Plan-vs-reality drift** — compare against `## Chosen approach`. Note where execution diverged and why.
   
   Update frontmatter: `status: outcome`, add `shipped: <YYYY-MM-DD>`.

7. **Update in place** (when the user picks `update` instead of `advance` in step 3, or `y` to append a follow-up to an `outcome` doc).
   - Always preserve the existing frontmatter `status`, `slug`, and original `date`. Add or update `last_modified: <YYYY-MM-DD>`.
   - **`decided` doc** → ask which sections to revise (`Problem` / `Options considered` / `Chosen approach` / `Rationale` — multi-select). Replace only the chosen section bodies; leave untouched sections byte-for-byte unchanged. Do not change `status`.
   - **`in-progress` doc** → revise the `## In progress` section in place. Replace its body with the latest state, capturing any new commits/PRs since it was first written. Do not change `status`. Do not modify `## Problem` / `## Options considered` / `## Chosen approach` / `## Rationale` (decided-stage history is immutable from this stage).
   - **`outcome` doc, follow-up note** → append a new dated subsection `### Follow-up <YYYY-MM-DD>` under the existing `## Outcome` section. Do not modify earlier outcome content. Update `last_modified` only.

8. **Report.** Print the path, the new status, and suggested next move:
   - From `decided`: "Consider `/plan <slug>` to lock in the implementation plan."
   - From `in-progress`: "Run `/solution <slug>` again once shipped to capture the outcome."
   - From `outcome`: "Consider `/changelog` to surface this in the next release narrative."

## Degradations

- **No `docs/solutions/`** → suggest `/init-workshop`, offer inline `mkdir`.
- **Missing or malformed frontmatter on existing file** → treat as `decided`, prompt before overwriting frontmatter.
- **`gh` not installed or unauthenticated** → step 6 omits the PR link, falls back to commit hash.
- **Slug collision with unrelated content** → prompt before mutating.
