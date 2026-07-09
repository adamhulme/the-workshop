# Codex skill: auto-fleet

Shared contract: `core/workflows/auto-fleet.md`

## Use when

The user has authored `docs/fleet/<slug>.md` and wants multiple `auto-do` tasks dispatched in isolated worktrees.

## Codex behavior

1. Verify the manifest and clean fleet control branch.
2. Pin the default-branch SHA.
3. Compute ready waves from dependency status.
4. Create worktrees serially.
5. Dispatch Codex task workers only when the current environment supports safe parallel delegation; otherwise run rows sequentially and record that limitation.
6. Preserve failed worktrees for debugging.
7. Write one final manifest update with statuses and PR links.

## Porting note

This skill depends on a stable Codex `auto-do` implementation. Treat it as a native Codex runner, not a literal translation of Claude Agent dispatch.
