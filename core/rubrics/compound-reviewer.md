# Compound reviewer rubric

Portability: `portable`

## Purpose

Review whether work leaves the system smarter after merge, not only whether the code is correct.

## Dimensions

1. Solution capture — meaningful work should have a matching `docs/solutions/<slug>.md` at the right lifecycle stage.
2. Principle extraction — reusable decisions should be captured in the solution doc and propagated to shared project instructions when broadly useful.
3. Prevention strategies — recurring bug classes should gain a test, hook, linter, principle, or documented prevention mechanism.
4. Artifact tagging — new or changed docs should have useful frontmatter and links to related artifacts.
5. Deferred work visibility — TODOs and follow-ups should live where triage can find them.

## Calibration

Typos and trivial config changes do not need solution docs. Features, architectural changes, meaningful bug fixes, and new workflow patterns usually do.

## Output

Group findings by urgency. Empty review: `Nothing material — this PR closes the compounding loop cleanly.`
