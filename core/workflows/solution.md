# Solution workflow

Portability: `portable`

## Purpose

Capture one piece of work as it moves from decision to execution to outcome, so the next agent inherits the lesson rather than only the diff.

## Inputs

- Solution slug or task name.
- Optional related plan, PR, issue, or research artifact.

## Lifecycle

- `decided` — decision and rationale are known; implementation may not have started.
- `in-progress` — implementation details, surprises, and current state are being captured.
- `outcome` — shipped or abandoned; what worked, what did not, and reusable principles are recorded.

## Output

Write or update `docs/solutions/<slug>.md` with:

- frontmatter: `title`, `date`, `status`, `category`, `tags`, optional `related_plan`, `related_pr`.
- problem.
- decision.
- rationale and alternatives.
- implementation notes.
- outcome.
- reusable principle.
- prevention strategy, or `none`.
- follow-ups.

## Gates

- Ask before creating the file when the slug is ambiguous.
- Ask before adding a broadly reusable principle to shared project instructions.

## Rules

Do not force every tiny typo fix into a solution doc. Use one when the work creates reusable knowledge, resolves a meaningful ambiguity, or prevents a recurring problem.
