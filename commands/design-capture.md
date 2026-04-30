---
description: Document an existing application's design system into DESIGN.md, surfacing inconsistencies and validating the recommended approach with the user
---

Read the running app's frontend, surface design inconsistencies and accidental drift, validate the recommended approach with the user, then write `DESIGN.md` as the project's design source of truth.

This skill captures **what already exists** in an app. For greenfield design from scratch, use a from-the-ground-up design skill (such as gstack's `design-consultation`).

User arguments: $ARGUMENTS

## Steps

1. **Confirm git context.** Run `git rev-parse --show-toplevel`. Abort if not in a git repo.

2. **Detect the app's frontend.** Look for common roots: `apps/web/`, `web/`, `client/`, `frontend/`, `src/components/`, `src/pages/`. List candidates and ask: `Which directory is the app's frontend? (pick one or paste a path)`.

3. **Survey the design surface.** Dispatch the `code-archaeologist` agent — or use Glob/Grep/Read directly — to catalogue:
   - **Tokens** — colour values (hex, rgb, CSS vars), spacing values, font-size scale, font families, border radii, shadows.
   - **Typography** — heading levels actually used, font-family/-weight/-size combinations.
   - **Components** — shared components and their variants (buttons, inputs, modals, tables, cards).
   - **Patterns** — recurring layouts (forms, lists, detail pages, empty states, error states).
   - **Routes/pages** — top-level pages and their purpose.

4. **Surface inconsistencies.** From the survey, identify drift:
   - Multiple non-token colour values used in the same context.
   - Inconsistent spacing (`12px`, `16px`, `1rem`, `var(--space-md)` all in similar positions).
   - Multiple button or input variants that look like accidental forks.
   - Mixed typography scales.
   - Components reimplemented in multiple places.
   
   Rank inconsistencies by severity (impact × frequency). Present the top 5–10 with file:line citations.

5. **Consult the user on each inconsistency.** For each one, ask:
   - `Is this intentional? (yes / no / partially)`
   - `If unifying, which is canonical? (A / B / something else)`
   - `Document as a known exception, or as a fix-it follow-up?`
   
   Capture answers.

6. **Validate the recommended approach.** Synthesise the design system from survey + answers. Present a draft:
   - Tokens (canonical set)
   - Typography (rules)
   - Components (canonical variants)
   - Patterns (recurring shapes)
   - Known inconsistencies (with planned resolutions or "intentional" tag)
   
   Ask: `Approve this synthesis to write to DESIGN.md? (y / n / paste edits)`. Iterate until approved.

7. **Write `DESIGN.md`.** Default location is the repo root; ask the user if a different path is desired. Sections:
   - **Overview** — one paragraph on what this app is, who uses it.
   - **Tokens** — canonical values for colour, spacing, typography scale, radius, shadow.
   - **Typography** — usage rules (when to use which heading level, body style).
   - **Components** — canonical variants with example usage and the files they live in.
   - **Patterns** — recurring layouts with rationale.
   - **Known inconsistencies** — list with planned resolutions or "intentional" tag.

8. **Report.** Print the path written, count of canonical tokens captured, count of inconsistencies documented, and a suggestion: "Consider `/solution fix-design-drift` to plan the resolution of the inconsistencies you flagged as fix-its."

## Degradations

- **No detectable frontend root** → ask the user to paste a path.
- **User disagrees with synthesis** → iterate on the draft until approved; do not write `DESIGN.md` until they sign off.
- **`CLAUDE.md` absent** → write `DESIGN.md` standalone; don't auto-create `CLAUDE.md` (that's `/init-workshop`'s job).
- **Repo too large for full survey** → focus on the top-level routes and the most-imported shared components; explicitly note what was sampled vs. fully surveyed in the DESIGN.md "Overview" section.
