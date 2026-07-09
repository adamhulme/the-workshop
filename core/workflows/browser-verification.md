# Browser verification workflow

Portability: `adapter-required`

## Purpose

Use a visible or inspectable browser session to verify UI changes, observe user flows, and capture the session as reusable research.

## Modes

- `setup` — persist authentication state locally after the user logs in manually.
- `verify` — navigate, observe, and interact with safe UI elements.

## Safety

Read-only interactions are allowed by default. Any action that mutates remote state, submits a form, pays, deletes, sends, archives, or otherwise has side effects requires an explicit gate.

## Output

- Research note under `docs/research/interviews/<slug>.md`.
- Screenshots under a sibling screenshots directory when useful.
- Verification summary in the PR or final response.

## Adapter notes

Storage paths, browser tools, and auth-state formats are runtime-specific. Keep session credentials out of version control.
