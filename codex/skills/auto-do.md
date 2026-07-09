# Codex skill: auto-do

Shared contract: `core/workflows/auto-do.md`

## Use when

The user asks Codex to run a bounded task end to end through plan, implementation, docs, PR, and review.

## Codex behavior

1. Refuse to start on a dirty working tree unless the user explicitly wants to incorporate existing changes.
2. Create a branch for the task.
3. Draft or load the plan and confirm scope when ambiguous.
4. Implement only the approved scope.
5. Run targeted checks.
6. Update `docs/solutions/<slug>.md` when the work creates reusable knowledge.
7. Create a PR when PR tooling is available.
8. Run the Codex `review-pr` skill once against the PR/diff.
9. Leave merging to the user.

## Stop conditions

Stop on ambiguity, failing tests that cannot be fixed in scope, unexpected broad refactors, missing PR tooling, or new round-two must-fix findings.
