# Consult workflow

Portability: `adapter-required`

## Purpose

Run a multi-perspective consultation against a project's persona team, surfacing genuine disagreement rather than a smoothed consensus.

## Inputs

- Question.
- Optional: single-persona quick mode, extra context file, explicit team path, focused group name, full-team override.

## Contract

1. Discover the team (`teams/<slug>/team.yaml` plus persona `.md` files); stop with a clear message if none is found.
2. Classify the question against the manifest's focused groups (or use the full team) and confirm the selected roster with the user before dispatching — this gate is required, not optional.
3. Run each selected persona's perspective independently; preserve separation between personas (parallel dispatch where the harness supports it, sequential otherwise).
4. Extract tensions: explicit disagreements and substantively different positions. Present a condensed positions summary, not full transcripts.
5. Checkpoint with the user: run rebuttals on the sharpest tension, take a directed follow-up, add context and re-run affected personas, or go straight to synthesis.
6. Synthesize in the user's-meeting-summary shape: per-persona position summaries, a tension map, rebuttal highlights (if any), the decision protocol's call if one exists, and an opinionated recommendation. Do not consensus-smooth genuine disagreement.
7. Offer to persist the synthesis as a research artifact.

## Output

On request, a consultation write-up (suggested default: `docs/research/consultations/<slug>.md`).

## Adapter notes

Parallel persona dispatch and the structured confirm/checkpoint gates are harness-specific (e.g. Claude's Agent tool and AskUserQuestion vs. Codex's native equivalents). Persona file format and `team.yaml` manifest shape are shared.
