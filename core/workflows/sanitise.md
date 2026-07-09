# Sanitise workflow

Portability: `adapter-required`

## Purpose

Pre-publish gate: scan a path for client/internal references (client names, employer names, internal repo/system names, team member names, internal URLs) before it goes public.

## Inputs

- Path to scan (default: repo root).
- Optional dry-run mode (report only, never mutate).

## Contract

1. Resolve the path safely: anchor to the repo root, follow symlinks, collapse `..`. Require explicit confirmation before scanning or mutating anything outside the repo root.
2. **Pass 1 — denylist regex.** Match known tokens; auto-apply known replacements; prompt for unknown matches (apply / skip / provide replacement). Persist new replacements for future runs.
3. **Pass 2 — LLM scan.** Over the remainder, flag proper nouns or internal jargon the denylist missed; same apply/skip/replace prompt, with an offer to add confirmed hits to the denylist.
4. Never mutate files in dry-run mode.
5. When changes are made, write an audit trail; when nothing changes, report a clean bill of health instead.

## Output

Audit trail at `docs/solutions/sanitisation-<date>.md` (summary, per-file change list, denylist additions) — only written when changes were made.

## Adapter notes

The denylist/replacements config path is harness-specific. Do not hard-code a Claude-only path (e.g. `~/.claude/workshop/`); each adapter documents or generalises its own config location (e.g. `.workshop/sanitise/`).
