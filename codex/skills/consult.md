# Codex skill: consult

Shared contract: `core/workflows/consult.md`

## Use when

The user wants multiple perspectives from a project persona team.

## Codex behavior

1. Locate `teams/<slug>/team.yaml` and persona files.
2. Read relevant context files named by the user.
3. Run persona perspectives independently where the environment supports parallel work; otherwise run them sequentially and preserve separation.
4. Surface disagreements, run targeted rebuttals for material conflicts, and synthesize without erasing dissent.
5. Ask before expanding scope or cost.
