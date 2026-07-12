# Auto-do workflow

Portability: `native-rewrite`

## Purpose

Run a known-shape task end to end: plan, review the plan, implement, document the solution, create a PR, verify, and run a bounded PR review.

## Preconditions

- Clean working tree.
- Authenticated PR tooling when PR creation is required.
- A discoverable test or verification command, or an explicit skip recorded in the PR.

## Default stages

1. Derive a safe slug and branch.
2. Create or reuse an approved plan.
3. Run engineering review and design review when UI scope is touched.
4. Implement only the approved scope.
5. Run targeted tests and checks.
6. Create or update a solution doc.
7. Create a PR.
8. Run browser/UI verification when applicable and configured.
9. Run bounded PR review.
10. Stop for human merge.

## Autonomous policy

Every automatic choice must be logged in the PR body or final report. If the task becomes ambiguous, risky, larger than the approved plan, or dependent on an installed integration that is not ready, stop rather than silently expanding scope or changing providers.

## Adapter notes

Do not share a single implementation between runtimes. This workflow is an orchestration contract; Claude and Codex should each implement it with native planning, editing, sub-agent, and PR mechanics.
