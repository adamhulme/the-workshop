---
description: Develop a plan in plan-mode-like behaviour, then persist the approved result to docs/plans/
argument-hint: <task description>
---

Treat this command as a request to enter plan mode for the task. Explore the codebase, draft a plan, get user approval, then persist the approved plan to `docs/plans/<slug>.md` with frontmatter and back-links to relevant research.

User arguments: $ARGUMENTS

## How to ask questions

Every decision point in this skill — creating the folder, approving the plan, choosing the slug, resolving a slug collision — uses **`AskUserQuestion`**, not a trailing prose `(y/n)`. Trailing prose questions get buried under whatever you wrote above; `AskUserQuestion` surfaces a clean structured prompt with explicit options, and the user can type a custom answer via the auto-provided "Other" option.

**Don't use Claude Code's native plan mode tools (`EnterPlanMode` / `ExitPlanMode`)** for this skill. Their approval prompt is a second gate, and once `EnterPlanMode` is active, the `Write` at step 7 stays blocked until you `ExitPlanMode` — which re-prompts the user. Simulate plan-mode behaviour manually (read-only exploration, no file edits until step 7) and let step 4's `AskUserQuestion` be the single gate.

## Steps

1. **Confirm git context.** Run `git rev-parse --show-toplevel`. Abort if not in a git repo: "/plan needs a git repo to anchor the plan to a project."

2. **Confirm plan target.** If `docs/plans/` does not exist, dispatch `AskUserQuestion`:
   - Question: "`docs/plans/` doesn't exist in this repo. Create it now?"
   - Header: "Create folder"
   - Options:
     - "Create `docs/plans/` and continue" — `mkdir -p docs/plans` then proceed
     - "Cancel — run `/init-workshop` first" — exit gracefully, mention `/init-workshop`

3. **Simulate plan-mode behaviour manually.** With the user's `$ARGUMENTS` describing the task:
   - **Do not call `EnterPlanMode` or `ExitPlanMode`.** See the preamble — they introduce a second gate and `EnterPlanMode` blocks the `Write` at step 7.
   - Read relevant code, identify constraints, ask clarifying questions (use `AskUserQuestion` for any structured choices; freeform clarifications can stay inline), draft a numbered plan with critical files and verification steps.
   - Do not edit any files until step 7.

4. **Get approval.** Present the drafted plan inline, then dispatch `AskUserQuestion`:
   - Question: "Approve this plan and save it to `docs/plans/`?"
   - Header: "Approve plan"
   - Options:
     - "Approve and save" *(Recommended)*
     - "Revise — describe changes" — user describes edits via Other; iterate, then re-ask this question
     - "Discard" — stop without writing

5. **Derive a slug.**
   - Prefer the current branch name if it's descriptive (`feature/foo-bar` → `foo-bar`).
   - Otherwise derive a kebab-case slug from `$ARGUMENTS`.
   - Dispatch `AskUserQuestion`:
     - Question: "Save plan as `docs/plans/<derived-slug>.md`?"
     - Header: "Confirm slug"
     - Options:
       - "Save as `<derived-slug>`" *(Recommended)*
       - "Use a different slug" — user types alternative kebab-case slug via Other

6. **Handle slug collision.** Before writing, check if `docs/plans/<slug>.md` already exists. If yes, dispatch `AskUserQuestion`:
   - Question: "`docs/plans/<slug>.md` already exists. What should I do?"
   - Header: "Slug collision"
   - Options:
     - "Overwrite the existing file"
     - "Save with a different slug" — user types alternative via Other; loop back to step 6 if the new slug also collides

7. **Write the plan file.** Frontmatter:
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

8. **Add back-links.** Scan `docs/research/` and `docs/brainstorms/` for files whose slug shares keywords with the plan. If matches found, append a `## See also` section listing them as relative markdown links.

9. **Report.** Print the path written, the slug, and one suggestion: "Consider `/solution <slug>` to capture this as a decision once work begins, then again to record the outcome."

## Degradations

- **Not in a git repo** → step 1 abort.
- **`docs/plans/` missing and user picks Cancel in step 2** → exit gracefully, mention `/init-workshop`.
- **Slug collision** → step 6 prompts for unique slug or explicit overwrite.
- **No matching research/brainstorm files** → step 8 skips silently.
