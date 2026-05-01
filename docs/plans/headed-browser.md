---
status: approved
date: 2026-04-30
task: Add a /browse skill that drives a visible browser via an MCP server and writes the session as a research note
branch: workshop-phase-3
---

# Plan: `/browse` — headed browser skill for the workshop

## Context

The workshop is a markdown-only skills collection installed via `install.sh` (copies `commands/*.md` and `agents/*.md` into `~/.claude/`). It has no application of its own and no browser tooling. The user wants a skill so that, in any project where the workshop is installed, Claude can drive a *visible* browser the user can watch — to test recent changes or just observe app state — and have those sessions feed the compounding-artefact loop.

User-locked decisions (from clarifying questions):
- **Mechanism**: assume an MCP browser server is configured (Playwright MCP or Chrome DevTools MCP). No launcher script, no `install.sh` changes.
- **Surface**: a single command, `/browse`.
- **Artefact integration**: sessions write a structured note to `docs/research/`.

## Approach

Add one new skill at `commands/browse.md` following the conventions of `commands/research.md` and `commands/plan.md` (YAML frontmatter, numbered `## Steps`, `## Degradations`). The skill orchestrates an existing browser MCP — it does not ship browser code.

The skill is MCP-agnostic in the body (it asks Claude to use "whichever browser MCP is available"), but documents Playwright MCP as the recommended setup because it has the broader tool surface (click, type, navigate, screenshot, evaluate). Chrome DevTools MCP is listed as an alternative for users who prefer Google's official server.

Sessions land at `docs/research/interviews/<slug>.md` — using `interviews/` because a UI walkthrough is closer to a user-facing observation log than to background `context/`. Frontmatter follows the same shape as other workshop artefacts: `type`, `date`, `target`, `scenario`.

## Skill body — what `commands/browse.md` will contain

Frontmatter:
```yaml
---
description: Drive a visible browser so the user can watch Claude test changes or observe the app, and capture the session as a research note.
argument-hint: [scenario or URL]
---
```

Steps (numbered, prose):

1. **Confirm browser MCP is available.** Look for a browser MCP server in the active tools (e.g. `mcp__playwright__*`, `mcp__chrome-devtools__*`). If none, print setup instructions for Playwright MCP (`npx @playwright/mcp@latest`) and Chrome DevTools MCP, then stop.

2. **Confirm target URL.** Use `$ARGUMENTS` if it looks like a URL or scenario. Otherwise read `CLAUDE.md` / `package.json` for a dev URL. If still unknown, ask. If the URL is local and unreachable, ask whether to proceed anyway (dev server may need to be started by the user — never auto-run dev servers).

3. **Confirm the scenario.** What is Claude doing — verifying a recent change (`git diff`-driven), walking a named user flow, or just observing? If unclear, ask.

4. **Drive the browser.** Use the browser MCP tools to open the URL with the headed window visible, then execute the scenario step by step. Narrate what you're about to do *before* each step so the watching user can follow. Capture screenshots at key moments via the MCP's screenshot tool.

5. **Summarise.** After the session (or on user "stop"), draft a research note: what was done, what was observed (broken things, surprises, regressions), follow-ups worth a `/triage` or `/plan`.

6. **Persist.** Derive a slug from the scenario or URL. Confirm: `Save as docs/research/interviews/<slug>.md? (y / paste alternative slug)`. On collision, prompt for a unique slug or explicit overwrite.

7. **Write the file.** Frontmatter:
   ```yaml
   ---
   type: ui-walkthrough
   date: <YYYY-MM-DD>
   target: <URL>
   scenario: <one-line>
   branch: <current branch if not main>
   ---
   ```
   Body: narrative, observations (bulleted), screenshot references if any, follow-ups.

8. **Report.** Print the path written and a one-line next step (`/triage` for follow-ups, `/plan` for a fix worth scoping).

Degradations:
- No browser MCP → step 1 abort with setup instructions.
- Dev URL unreachable → ask user; never auto-start a dev server.
- User stops mid-session → still write a partial note marked `status: partial`.
- Slug collision → prompt for unique slug or explicit overwrite.

## Critical files

- **New**: `commands/browse.md` — the skill body sketched above. Mirror the format of `commands/research.md` and `commands/plan.md`.
- **Modify**: `README.md` — add `/browse` to whatever inventory of commands the README maintains, with a one-line description.

No changes to `install.sh` (it copies all `commands/*.md` automatically). No new agent. No tools/launcher script.

## Naming caveat

`/browse` collides with gstack's `browse` skill (visible in the available-skills list of users who also use gstack). Slash-command resolution between two ecosystems installed under `~/.claude/commands/` would be ambiguous. Alternatives worth considering at save time: `/dogfood`, `/walk`, `/observe`, `/watch`. The file slug for *this* plan stays `headed-browser` regardless.

## Out of scope

- Shipping any executable code (Node, Python, shell launcher).
- Modifying `install.sh`.
- Auto-starting dev servers.
- Adding a new agent type — `/browse` is a command-shaped skill, not an agent.
- Authoring an MCP server. Use whatever the user already has.

## Verification

1. After `commands/browse.md` lands, run `bash install.sh --user` and confirm `~/.claude/commands/browse.md` is copied.
2. In a project with Playwright MCP configured (`npx @playwright/mcp@latest` in `~/.claude.json` or equivalent), invoke `/browse https://localhost:3000` (or a real dev URL).
3. Confirm: a Chrome window appears visibly, Claude narrates, drives the page, captures screenshots, then asks where to save the note.
4. After save, confirm `docs/research/interviews/<slug>.md` exists with the expected frontmatter and body.
5. Repeat with no MCP configured → confirm the skill prints setup instructions and exits cleanly without driving anything.
6. Repeat with a slug that already exists → confirm the prompt offers overwrite vs new-slug.

## Engineering Review — 2026-05-01 (auto-mode)

Run autonomously. Codex outside voice was dispatched; ~25 findings consolidated below and grouped by disposition.

### NOT in scope

- Auto-starting dev servers — out of scope; if localhost is unreachable the skill bails with a "start your dev server and retry" message rather than the plan's original "proceed anyway" wording.
- Renaming `/browse` to avoid the gstack collision — kept as `/browse` per user direction (`ship /browse first`). README documents the collision; users on gstack can rename locally.
- Switching the output bucket from `docs/research/interviews/` to `sessions/` — kept as `interviews/` per the plan's existing decision. Logged to follow-ups.
- Pinning a specific Playwright MCP version — skill body names a tested version range; full pinning is a future hardening pass.

### What already exists

- `commands/research.md` — slug-validation hardening (path-traversal reject, illegal-char reject, kebab normalisation, max length) and frontmatter-quoting pattern. Lifted verbatim into `/browse`.
- `git rev-parse --show-toplevel` repo-root detection — reused.
- `AskUserQuestion` for structured gates per CLAUDE.md — reused for the destructive-action and credential-setup confirmations.

### Must fix in skill spec (folded into `commands/browse.md`)

1. **Auth/storageState support** — first-time `/browse --setup` drives a headed login session; subsequent `/browse` invocations reuse `<repo>/.claude/browse/storage-state.json`. Skill body documents the required Playwright MCP startup flag (`--storage-state=<path>`) and degrades cleanly if the MCP doesn't expose it.
2. **Destructive-action guardrail** — `/browse` defaults to read-only navigation. Any form submission, delete, payment, or POST-shaped action requires per-action `AskUserQuestion` confirmation.
3. **Sensitive-data policy** — explicit warning in the skill body that screenshots may capture tokens/PII; recommend `.gitignore` for `.claude/browse/` and for the screenshots directory if the target app handles secrets.
4. **Headed mode required, not just "visible"** — skill body specifies `--headed` (or MCP equivalent) and notes WSL/remote-only environments can't satisfy this.
5. **Pin Playwright MCP as the primary supported MCP** — Chrome DevTools MCP listed as alternative-with-caveats (different tool surface, expects pre-existing Chrome). No more "use whichever".
6. **Concrete setup instructions** — when no MCP is found, skill prints a complete Claude config snippet for Playwright MCP (`mcpServers` entry with `command`, `args`, `--storage-state` flag, recommended version).
7. **`$ARGUMENTS` parsing rule** — explicit: first whitespace-delimited token is the URL if it parses as one (`http://` / `https://` / `localhost`), remainder is the scenario. `--setup` flag triggers credential setup mode.
8. **Slug validation hardening** — lifted verbatim from `commands/research.md`. Reject path separators, `..`, drive letters, illegal characters; normalise to kebab; max 80 chars.
9. **Repo-root detection** — `git rev-parse --show-toplevel`. All paths resolve relative to it. Non-git projects: bail with friendly message.
10. **Directory creation** — `mkdir -p docs/research/interviews` and `mkdir -p .claude/browse` (the latter only when `--setup` is used).
11. **Frontmatter quoting** — wrap URL, scenario, and branch values in double quotes; escape embedded quotes. Drop the `branch:` line on detached HEAD or when the branch name needs heavyweight YAML quoting.
12. **Screenshot location and naming** — saved under `docs/research/interviews/<slug>-screenshots/NN-<step>.png` (zero-padded, kebab step name). Markdown references them by relative path.
13. **Required MCP capabilities check** — skill verifies `navigate`, `click`, `type`, and `screenshot` tool equivalents are exposed before driving. If any are missing, bail cleanly rather than mid-session.
14. **Localhost unreachable** — replace plan's "proceed anyway" with: ask the user to start their dev server and retry, then exit. Don't drive against an unreachable URL.

### Should fix in skill spec

- Non-git project handling — bail with a "/browse needs a git repo to anchor the research note" message.
- Detached HEAD / `master` / unusual branch names — handled by the frontmatter-quoting rule above.
- README collision note — added to the README's commands inventory.

### Test gaps and regression risk

`/browse` is net-new: no existing behaviour to regress. No automated test suite for skills exists in the workshop. Verification is manual per the plan's existing checklist. No regression tests required.

### Failure modes

| Failure | Test? | Error handling? | User sees? |
|---|---|---|---|
| No MCP installed | Manual (verify step 5) | Yes — step 1 abort | Setup instructions |
| MCP missing `screenshot` capability | Manual | Yes — required-capability check | "MCP exposes navigate but not screenshot — install full Playwright MCP" |
| Storage state expired (logged out mid-session) | Manual | Yes — detected on login-page redirect | "Storage state appears expired. Re-run `/browse --setup`." |
| User requests destructive action | Manual | Yes — AskUserQuestion gate | Per-action confirmation |
| Localhost dev server down | Manual | Yes — bail with retry message | "Dev server unreachable at <url>. Start it and retry." |
| Screenshots contain secrets | N/A — operator concern | Documented in skill body | Warning printed once per session if the target hostname suggests prod |

No critical-gap failures (no-test-AND-no-handling-AND-silent).

### TODOs (added to follow-ups)

- **`interviews/` taxonomy follow-up** — re-evaluate after a few `/browse` sessions whether they pollute customer-interview lookups. Candidate: introduce `docs/research/sessions/`. Cost: S. Value: low until pollution is observed.
- **Pin Playwright MCP version** — replace "tested with X.Y" prose with a concrete pinned range when the MCP's release cadence is clearer. Cost: S. Value: medium (avoids silent breakage from MCP changes).
- **Verification harness** — most workshop skills are verified by running them; consider a smoke-test fixture that runs `/browse --setup` against a public test page (e.g. httpbin) without secrets. Cost: M. Value: medium.

### Completion summary

```
Step 0 — Scope:        accepted as-is (1 skill, 1 README mod, 0 new services)
Architecture:          1 issue found (no auth/session policy), patched in skill spec
Code quality:          1 issue (slug hardening), patched by lifting from /research
Tests:                 N/A — no automated suite exists; manual verification per plan
Performance:           N/A — markdown skill; performance lives in the MCP
Outside voice:         ran (Codex), 25 findings consolidated
NOT in scope:          written above
Failure modes:         6 listed, 0 critical gaps
TODOs:                 3 logged as follow-ups
Unresolved:            none
```
