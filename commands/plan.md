---
description: Develop a plan in plan-mode-like behaviour, then persist the approved result to docs/plans/
argument-hint: <task description>
---

Treat this command as a request to enter plan mode for the task. Explore the codebase, draft a plan, get user approval, then persist the approved plan to `docs/plans/<slug>.md` with frontmatter and back-links to relevant research.

User arguments: $ARGUMENTS

## Steps

1. **Confirm git context.** Run `git rev-parse --show-toplevel`. Abort if not in a git repo: "/plan needs a git repo to anchor the plan to a project."

2. **Confirm plan target.** If `docs/plans/` does not exist, mention `/init-workshop` then prompt: `Create docs/plans/ now and continue? (y/n)`. On `y`, `mkdir -p docs/plans`.

3. **Enter plan-mode behaviour.** With the user's `$ARGUMENTS` describing the task:
   - If you can request Claude Code's native plan mode (e.g. via ExitPlanMode availability), do so.
   - Otherwise behave as if in plan mode: read relevant code, identify constraints, ask clarifying questions, draft a numbered plan with critical files and verification steps. Do not edit any files except the eventual plan output below.

4. **Get approval.** Present the drafted plan and ask: `Approve this plan to save? (y to save / n to discard / paste edits to revise).` Iterate on edits until approved.

5. **Derive a slug.**
   - Prefer the current branch name if it's descriptive (`feature/foo-bar` → `foo-bar`).
   - Otherwise derive a kebab-case slug from `$ARGUMENTS`.
   - Confirm: `Save plan as docs/plans/<slug>.md? (y / paste alternative slug)`.
   - On collision with an existing file, prompt to choose between overwrite and a new slug.

6. **Write the plan file.** Frontmatter:
   ```
   ---
   status: approved
   date: <YYYY-MM-DD>
   task: <one-line summary of $ARGUMENTS>
   branch: <current branch if not main>
   source: <issue/PR ID if discoverable from branch name, else omit>
   ---
   ```
   Followed by the approved plan body verbatim.

7. **Add back-links.** Scan `docs/research/` and `docs/brainstorms/` for files whose slug shares keywords with the plan. If matches found, append a `## See also` section listing them as relative markdown links.

8. **Report.** Print the path written, the slug, and one suggestion: "Consider `/solution <slug>` to capture this as a decision once work begins, then again to record the outcome."

## Degradations

- **Not in a git repo** → step 1 abort.
- **`docs/plans/` missing and user declines to create** → exit gracefully, mention `/init-workshop`.
- **Slug collision** → prompt for unique slug or explicit overwrite.
- **No matching research/brainstorm files** → step 7 skips silently.
