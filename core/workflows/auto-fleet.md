# Auto-fleet workflow

Portability: `native-rewrite`

## Purpose

Dispatch multiple autonomous tasks from a manifest in isolated worktrees, with dependency-aware waves and a fleet-level status artifact.

## Manifest

Default path: `docs/fleet/<slug>.md`.

Rows should include at least:

- id.
- task description.
- status.
- dependencies.
- branch or PR result.
- failure class or notes.

## Rules

1. The manifest is user-authored; the fleet runner is not a planner.
2. Dependencies are dispatch-ordering unless the runtime explicitly supports stacked branches.
3. Worktrees isolate working trees, not all git refs; create and clean them carefully.
4. Failed child tasks should block dependents but not unrelated rows.
5. Preserve failed worktrees for debugging unless the user asks to clean them.
6. Record a final manifest update atomically at the end of the run.

## Adapter notes

Port after the runtime has a stable `auto-do` implementation. Parallel dispatch, timeout enforcement, and cancellation semantics must be native to the runtime.
