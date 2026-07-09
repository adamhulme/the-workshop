# Codex skill: plan

Shared contract: `core/workflows/plan.md`

## Use when

The user asks for an implementation plan, design plan, migration plan, or wants analysis before code edits.

## Codex behavior

1. Stay read-only until the user approves the plan or explicitly asks you to implement.
2. Inspect relevant files with targeted shell commands.
3. Read relevant workshop artifacts from `docs/research/`, `docs/brainstorms/`, `docs/plans/`, and `docs/solutions/`.
4. Present a concise plan with verification steps and open questions.
5. If asked to persist the plan, write `docs/plans/<slug>.md` using the core plan output shape.
6. If the plan needs a decision, ask one explicit question rather than burying multiple prompts in prose.

## Codex-specific notes

Do not refer to Claude `EnterPlanMode`, `ExitPlanMode`, or `AskUserQuestion`. Use Codex's normal planning and user-input flow.
