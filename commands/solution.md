---
description: Create or advance a solution doc through its lifecycle (decided → in-progress → outcome)
argument-hint: <slug>
---

A solution doc lives at `docs/solutions/<slug>.md` and captures one piece of work through three stages: **decided** (the chosen direction with rationale), **in-progress** (what's actually shipping), **outcome** (what shipped, what to watch). One file per piece of work; the stage is tracked in frontmatter.

User arguments: $ARGUMENTS

## Steps

1. **Resolve the slug.** Use `$ARGUMENTS` as the slug. If empty, prompt: `What's the slug for this solution? (e.g. feature-flags-v1)`. Target path is `docs/solutions/<slug>.md`.

2. **Confirm target directory.** If `docs/solutions/` is missing, mention `/init-workshop` and offer to create it inline.

3. **Determine mode.**
   - **File doesn't exist** → new doc, write at `decided` stage (step 4).
   - **File exists** → read its frontmatter `status` field, then prompt: `This doc is at status <X>. Advance to <next>, or update the existing stage in place? (advance/update)`.
     - `decided` → next is `in-progress`
     - `in-progress` → next is `outcome`
     - `outcome` → no further stage; prompt: `This doc is already at outcome. Append a follow-up note instead? (y/n)`.

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

7. **Report.** Print the path, the new status, and suggested next move:
   - From `decided`: "Consider `/plan <slug>` to lock in the implementation plan."
   - From `in-progress`: "Run `/solution <slug>` again once shipped to capture the outcome."
   - From `outcome`: "Consider `/changelog` to surface this in the next release narrative."

## Degradations

- **No `docs/solutions/`** → suggest `/init-workshop`, offer inline `mkdir`.
- **Missing or malformed frontmatter on existing file** → treat as `decided`, prompt before overwriting frontmatter.
- **`gh` not installed or unauthenticated** → step 6 omits the PR link, falls back to commit hash.
- **Slug collision with unrelated content** → prompt before mutating.
