---
status: in-progress
date: 2026-05-01
started: 2026-05-01
slug: browse
---

## Problem

The workshop has no way for Claude to drive a visible browser. Every other skill produces or consumes text artefacts; nothing lets Claude verify a UI change, walk a user flow, or just observe an app's current state. Without it, the compounding loop has a blind spot: research and plans can describe a UI, solutions can record what shipped, but no skill can confirm the thing actually works in a browser.

A second, related gap surfaced in the engineering review: any browser-driving skill in a real codebase will hit auth-gated pages immediately. Without a credential strategy, the skill is useful only on public marketing pages.

## Options considered

1. **Skill that orchestrates an existing browser MCP (Playwright MCP / Chrome DevTools MCP).** Single markdown file. No new code ships. Depends on the user having the MCP configured in their Claude config. Auth handled via Playwright's `storageState` mechanism — one-shot login, persisted state, reusable across runs. **Trade-off:** depends on the MCP being installed and on Playwright MCP's `--storage-state` flag being honoured at startup; not all MCPs expose this.

2. **Bundle a Playwright launcher script with `install.sh`.** Workshop ships its own browser binding via Node + Playwright. Self-contained, no MCP dependency. **Trade-off:** breaks the workshop's "skills are markdown only, no code ships" principle. Adds a runtime dependency (Node, Playwright install). Materially expands `install.sh`.

3. **Defer browser support entirely.** Compounding loop has a known blind spot but every skill stays markdown-only. **Trade-off:** kills the user's `/auto-do` use case (the trigger that surfaced this work). Bad option — the user explicitly asked for it.

## Chosen approach

**Option 1.** Add `commands/browse.md` that orchestrates Playwright MCP (primary) or Chrome DevTools MCP (alternative-with-caveats). Two modes:

- `/browse --setup` — first-time auth. Drives a headed browser, asks the user to log in manually, then captures Playwright's `storageState` at `<repo>/.claude/browse/storage-state.json`.
- `/browse [url-or-scenario]` — normal driving. Reuses the saved storage state if present. Captures screenshots under `docs/research/interviews/<slug>-screenshots/`. Writes the session note to `docs/research/interviews/<slug>.md`.

Skill body inherits from `commands/research.md` for slug hardening and frontmatter quoting. Defaults to read-only navigation; destructive actions (form submit, delete, payment) require per-action `AskUserQuestion` confirmation. Bails cleanly on missing MCP, missing capabilities (no screenshot tool), unreachable URL, or non-git project.

## Rationale

- **Markdown-only constraint preserved.** The workshop's whole installation model is `cp commands/*.md ~/.claude/commands/`. Option 2 would have broken that for one skill.
- **Auth is solved by deferring to Playwright.** Playwright's `storageState` is the standard, well-understood pattern. The skill describes it; the MCP implements it. We don't roll our own auth.
- **The user's actual use case (`/auto-do`) needs this skill to exist before it can compose with it.** Shipping `/browse` first, then layering `/auto-do` on top, is the cleanest sequence.
- **Codex's outside voice surfaced 25 issues** in the eng review; the must-fix list (auth, destructive guardrails, sensitive-data warning, MCP-capability check, slug hardening, frontmatter quoting, headed-mode requirement, concrete setup snippet) is folded into the skill spec rather than deferred. The "should fix" and "follow-up" items go to TODOs.
- **The `/browse` name collides with gstack's `browse` skill.** Kept anyway per user direction. README documents the collision; gstack users can rename locally.

## In progress

**Branch:** `feat/browse` (off `main`)

**What's actually being built** (refines `## Chosen approach`):

- `commands/browse.md` — the skill body. Two modes (`--setup` vs normal), four hard rules (headed mode only, read-only by default, never log in for the user, never auto-start dev servers), nine numbered steps for normal mode plus a Step S for credential setup. Slug validation and frontmatter quoting copied verbatim from `commands/research.md`. Screenshots saved under `docs/research/interviews/<slug>-screenshots/NN-<step>.png`. The MCP setup snippet in step 1 is the source of truth for the recommended Playwright MCP config — it pins `--headed` and `--storage-state=.claude/browse/storage-state.json`.
- `docs/plans/headed-browser.md` — the original plan plus a full **Engineering Review — 2026-05-01 (auto-mode)** block. Codex outside voice surfaced 25 issues; 14 were folded into the skill spec as must-fix items, 3 went to follow-ups (TODOs).
- `README.md` — `/browse` added to the **Skills shipped** table, surfaced in the **Where to go next** bullets, and Playwright MCP added to the **Optional integrations** table.
- `CHANGELOG.md` — entry under `[Unreleased]` describing the skill, the credential setup flow, and the gstack naming caveat.

**Out of scope for this branch** (deferred per the eng review):

- The `interviews/` taxonomy concern — `/browse` writes there per the original approved plan; revisit after a few real sessions to see if it pollutes customer-interview lookups.
- Pinning a specific Playwright MCP version range — the skill notes "tested with current latest" until the MCP's release cadence is clearer.
- A smoke-test fixture for `/browse --setup` against a public no-auth page (e.g. httpbin) — manual verification per the plan's checklist for now.

**Next:** push, `gh pr create`, run `/review-pr` autonomously per `auto mode` — and stop before merge.
