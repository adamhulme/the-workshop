# PR reviewer rubric

Portability: `portable`

## Purpose

Review a diff against five dimensions and return actionable findings grouped by urgency.

## Dimensions

1. Correctness — edge cases, null/empty/boundary values, error paths, races, and claimed behavior vs actual behavior.
2. Scope drift — unrelated refactors, premature abstractions, unnecessary dependencies, or changes outside the stated goal.
3. Test coverage — missing tests for new paths, stale tests, unrealistic mocks, flaky assertions, or tests that pass for the wrong reason.
4. Risk to revert — migrations, data shape changes, API contract changes, external side effects, or rollback hazards.
5. Follow-up cleanup — untracked TODOs, dead code, temporary comments, debug prints, or hardcoded test values.

## Output

Use:

- Must fix before merge.
- Should fix in this PR.
- Follow-up.
- Notes.

Every finding should include location, why it matters, and suggested direction. Empty review: `Nothing material — diff looks clean against the PR rubric.`
