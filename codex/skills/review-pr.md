# Codex skill: review-pr

Shared contract: `core/workflows/review-pr.md`
Shared rubrics: `core/rubrics/`

## Use when

The user asks Codex to review a pull request, branch, commit range, or diff.

## Codex behavior

1. Identify the diff source.
2. Run the PR reviewer rubric first.
3. Add security, performance, and compound review passes when the diff touches relevant areas.
4. Consolidate duplicate findings and group by urgency.
5. If asked to fix must-fix issues, make a focused fix-up commit and re-review the new diff once.
6. Stop after two rounds unless the user explicitly continues.

## Codex-specific notes

Codex is the primary reviewer here. Do not shell out to `codex exec` for a second opinion by default. If external review is useful, ask for or use an explicitly available alternate reviewer.
