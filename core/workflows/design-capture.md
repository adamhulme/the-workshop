# Design capture workflow

Portability: `portable`

## Purpose

Document an existing application's actual design system into `DESIGN.md` — what exists today, not a greenfield design.

## Inputs

- The app's frontend root (ask if not obviously detectable).

## Contract

1. Statically survey the frontend for tokens (colour, spacing, typography scale, radius, shadow), component variants, recurring layout patterns, and top-level routes.
2. From the survey, identify drift: multiple non-token values doing the same job, near-duplicate component variants, mixed typography scales, reimplemented components.
3. Rank inconsistencies by severity (impact × frequency) and present the top ones with file citations.
4. For each inconsistency, ask the user: is it intentional, which variant is canonical if unifying, and whether to record it as a known exception or a fix-it follow-up.
5. Synthesize a draft design system from the survey plus the user's answers and get explicit approval before writing.

## Output

Write `DESIGN.md` at the repo root (or a user-specified path) with sections: Overview, Tokens, Typography, Components, Patterns, Known inconsistencies.

## Adapter notes

Static-survey tooling (glob/grep vs. a dedicated investigator agent) and the approval-gate mechanism are harness-specific.
