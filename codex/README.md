# Codex adapter

Codex-native workshop instructions. These files adapt the shared contracts in `core/` for Codex sessions without depending on Claude Code slash-command mechanics.

## Layout

- `codex/skills/` — Codex task playbooks corresponding to workshop workflows.
- `codex/agents/` — Codex reviewer/investigator role prompts corresponding to shared rubrics.

## Adapter rule

If a rule is durable across runtimes, put it in `core/`. If it names Codex execution mechanics, local Codex paths, delegation behavior, or final-response conventions, keep it here.
