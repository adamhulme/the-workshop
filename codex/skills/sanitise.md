# Codex skill: sanitise

Shared contract: `core/workflows/sanitise.md`

## Use when

The user asks to prepare a repo or path for public release by removing private/client/internal references.

## Codex behavior

1. Read the configured denylist and replacement map.
2. Run deterministic string/regex scans before LLM-style judgment.
3. Apply known replacements automatically when safe.
4. Ask before novel replacements.
5. Write an audit note to `docs/solutions/`.

## Porting note

Prefer a runtime-neutral config path such as `.workshop/sanitise/` or document the local user path explicitly. Do not hard-code `.claude` in Codex instructions.
