# Codex skill: browser verification

Shared contract: `core/workflows/browser-verification.md`

## Use when

The user asks Codex to verify a UI flow, inspect a running app, or capture browser-observed research.

## Codex behavior

1. Use the browser/control tools available in the current Codex environment.
2. Keep authentication state local and gitignored.
3. Treat navigation and safe read-only clicks as allowed.
4. Ask before destructive or state-changing actions.
5. Save notes under `docs/research/interviews/` and screenshots when useful.
6. Report verification results in the final response or PR body.
