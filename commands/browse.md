---
description: Drive a visible browser via an MCP server so the user can watch Claude verify changes or observe the app, capture the session as a research note. First-run --setup persists login state for reuse.
argument-hint: [--setup] [url] [scenario]
---

Orchestrate an existing browser MCP (Playwright MCP recommended; Chrome DevTools MCP an alternative) to drive a *visible* browser. Sessions land at `docs/research/interviews/<slug>.md` with screenshots alongside.

`/browse --setup` is the one-shot credential flow: log in once via the headed browser, the storage state is saved, every subsequent `/browse` reuses it. No credentials are stored in env vars, the repo, or this skill.

User arguments: $ARGUMENTS

## Argument parsing

- If `$ARGUMENTS` contains the literal token `--setup`, this is **credential setup mode** (step S below). The remaining tokens are interpreted as the login URL.
- Otherwise: the first whitespace-delimited token is treated as the **target URL** if it parses as one (`http://…`, `https://…`, or `localhost…`). The remainder is the **scenario**.
- If no URL token is present, the entire `$ARGUMENTS` is the scenario; Claude asks for the URL in step 2.
- Empty `$ARGUMENTS` → ask for both.

## Hard rules

- **Headed mode only.** This skill is for the user to *watch*. If the active MCP cannot show a window (WSL with no DISPLAY, headless container, remote SSH without X-forwarding), bail with: "/browse needs a headed browser the user can see. Configure Playwright MCP with `--headed`, or run from a desktop session."
- **Read-only by default.** Navigation, clicks on visibly-safe elements (links, tabs, accordions), typing into search boxes — all fine without confirmation. Form submissions, deletes, payments, anything POST-shaped, anything that mutates remote state — pause and confirm via `AskUserQuestion` per action.
- **Never log in for the user.** Setup mode opens the page; the user types the credentials. Claude does not see, request, or store passwords.
- **Stop on user say-so.** "stop", "done", "save", or `Ctrl+C` ends the session. Partial sessions still write a note marked `status: partial`.
- **Never run dev servers.** If localhost is unreachable, bail — don't start `npm run dev` or equivalent.

## Steps

### 1. Pre-flight

- `git rev-parse --show-toplevel` — must be in a git repo. If not: bail with "/browse needs a git repo to anchor the research note. Run from inside one."
- Detect a browser MCP in the active toolset:
  - Look for tools matching `mcp__playwright__*` (Playwright MCP).
  - Or `mcp__chrome-devtools__*` / `mcp__chrome_devtools__*` (Chrome DevTools MCP).
  - If neither is found, print the **No MCP** block (below) and exit.
- Verify the MCP exposes the four required capabilities: navigate, click, type, screenshot. (Tool names vary by MCP — match by purpose, not exact name.) If a capability is missing, bail with: "MCP `<name>` is loaded but does not expose `<capability>`. Install full Playwright MCP (`npx @playwright/mcp@latest`) or upgrade your existing MCP."

#### No MCP block

Print this verbatim, then stop:

> No browser MCP detected. To use `/browse`, install Playwright MCP and add it to your Claude config.
>
> 1. Install: `npx @playwright/mcp@latest --version` (Node 18+ required).
> 2. Add to `~/.claude.json` (or your active Claude config) under `mcpServers`:
> ```json
> {
>   "mcpServers": {
>     "playwright": {
>       "command": "npx",
>       "args": [
>         "-y",
>         "@playwright/mcp@latest",
>         "--headed",
>         "--storage-state=.claude/browse/storage-state.json"
>       ]
>     }
>   }
> }
> ```
> 3. Restart Claude Code.
> 4. Re-run `/browse --setup <login-url>` to capture credentials, then `/browse <url> <scenario>`.
>
> Chrome DevTools MCP is an alternative but expects a pre-existing Chrome with remote-debugging enabled and exposes a different tool surface; Playwright MCP is recommended unless you already run DevTools MCP for other reasons.

### 2. Resolve the target URL

- If parsed from `$ARGUMENTS`, use it.
- Otherwise prompt the user inline: "What URL should I open? (e.g. `http://localhost:3000/dashboard`)" — this is free-text input, not a decision gate, so a prose prompt is fine.
- If the URL is a localhost address, attempt navigation via the MCP with a 5-second timeout. Treat any of these as unreachable: `net::ERR_CONNECTION_REFUSED`, `ERR_CONNECTION_RESET`, navigation timeout exceeded, or the MCP's equivalent connection-error response. On unreachable, bail: "Dev server unreachable at `<url>`. Start it (e.g. `npm run dev`) and re-run."
- If the URL uses HTTPS with a self-signed certificate, note this — Playwright MCP's `--ignore-https-errors` flag may be needed in the user's config; flag it once and continue.

### 3. Resolve the scenario

- If parsed from `$ARGUMENTS`, use it.
- Otherwise dispatch `AskUserQuestion`:
  - Question: "What's the scenario?"
  - Header: "Scenario"
  - Options:
    - "Verify a recent change (driven by `git diff`)"
    - "Walk a named user flow (paste via Other)"
    - "Just observe — no specific scenario"
- For "verify a recent change": run `git diff --name-only origin/HEAD..HEAD` (or fall back to `git diff HEAD~1..HEAD --name-only`) and surface the modified files, then ask which one's UI to focus on.

### 4. Load saved storage state (auth)

- If `<repo>/.claude/browse/storage-state.json` exists: the file is present, but whether the MCP is *actually* using it depends on whether the user's Claude config started Playwright MCP with `--storage-state=<path>`. The skill cannot introspect MCP startup args. Note in the session log: `storage-state: file present (assumed loaded)`. If step 5 then redirects to a login page on a non-localhost host, the assumption was wrong — see the storage-state-expiry path.
- If the file does not exist and the target URL is a known auth-gated host (heuristic: it's not localhost, and the path doesn't include `/login`, `/signin`, `/auth`), dispatch `AskUserQuestion`:
  - Question: "No saved storage state. Continue without auth, or stop and run `/browse --setup` first?"
  - Header: "No auth"
  - Options:
    - "Stop — I'll run `/browse --setup` first" *(Recommended)*
    - "Continue without auth (logged-out experience)"
- If localhost or already on a login page: continue silently — this is fine.

### 5. Drive the session

- Open the URL via the MCP. Wait for `domcontentloaded` (or MCP equivalent).
- **Detect storage-state expiry or misconfigured MCP.** If the page redirects to a login URL despite `storage-state: file present (assumed loaded)`, surface: "Storage state appears expired *or* your MCP wasn't started with `--storage-state=.claude/browse/storage-state.json`. Re-run `/browse --setup`, or check your Claude config matches the snippet in step 1." and stop.
- Capture an initial screenshot (step 0). See **Screenshots** below for the path/naming rule.
- Walk the scenario. Before each step, narrate one short sentence so the watching user knows what's coming. Examples:
  - "Clicking the *Settings* tab."
  - "Typing into the search box: `queue depth`."
  - "Taking a screenshot of the alerts panel."
- After each meaningful step, capture a screenshot.
- **Destructive-action gate.** Before any of: form submit, delete, archive, send, pay, anything that issues a non-GET request the user might not intend — pause and ask via `AskUserQuestion`:
  - Question: "About to <action> on <URL>. Proceed?"
  - Header: "Destructive action"
  - Options: "Proceed" / "Skip this step" / "Stop the session"
- Listen for "stop" / "done" / "save" in user replies and end gracefully when received.

#### Screenshots

- Directory: `docs/research/interviews/<slug>-screenshots/`. `mkdir -p` before saving.
- Naming: `NN-<step-name>.png` where `NN` is the zero-padded 2-digit step number (`00-initial.png`, `01-clicked-settings.png`, …) and `<step-name>` is kebab-case derived from your narration sentence.
- The MCP saves to disk if it supports a `path` parameter; otherwise capture the screenshot in-conversation and save via the file tool. Either way the resulting path is referenced in the markdown note.
- **Sensitive-data warning.** If the target hostname is a known production domain (heuristic: not localhost, not a `*.test`/`*.local` hostname, not a staging subdomain), print once: "⚠ Screenshots may capture credentials, tokens, or PII. Consider `.gitignore`-ing `docs/research/interviews/<slug>-screenshots/` if this session touches secrets."

### 6. Summarise

After the session ends:

- Draft a short narrative: what was done, what was observed (broken things, surprises, regressions, performance feel), and follow-ups worth a `/triage` or `/plan`.
- Use `### Insight:` blocks for findings to match the workshop's research format. Each block:
  ```
  ### Insight: <short name>
  **Quote**: "<UI text observed, error message, or one-line user-flow description>"
  **Implication**: <one sentence on what this means for the work>
  **Confidence**: <low | medium | high>
  ```

### 7. Persist the note

- Derive a slug from the scenario (preferred) or URL path. Validate before using as a path:
  - **Reject** if it contains path separators (`/`, `\`), `..` segments, or starts with `/`, `~`, or a Windows drive letter (`C:`). These would write outside `docs/research/`.
  - **Reject** characters illegal on common filesystems: newlines, NUL, `:`, `*`, `?`, `"`, `<`, `>`, `|`, plus Windows reserved names (`CON`, `PRN`, `AUX`, `NUL`, `COM[1-9]`, `LPT[1-9]`).
  - Normalise to kebab-case: lowercase ASCII alphanumerics + hyphens. Replace runs of whitespace/underscores/punctuation with `-`, collapse repeated hyphens, trim leading/trailing hyphens. Truncate to 80 characters.
  - If normalisation altered the input, dispatch `AskUserQuestion`:
    - Question: "Use slug `<normalised>`?"
    - Header: "Slug"
    - Options:
      - "Use this slug" *(Recommended)*
      - "I'll paste a different slug (Other)"
- Confirm target via `AskUserQuestion`: "Save as `docs/research/interviews/<slug>.md`?" with options: "Save" / "Save under a different slug (Other)".
- On collision with an existing file, ask: overwrite / append timestamped subsection / pick a new slug.
- `mkdir -p docs/research/interviews` before write.

### 8. Write the file

Frontmatter (all string values double-quoted; embedded `"` escaped as `\"`):

```yaml
---
type: ui-walkthrough
date: "<today's date in YYYY-MM-DD>"
target: "<URL>"
scenario: "<one-line scenario summary>"
slug: "<slug>"
status: complete   # or "partial" if user stopped mid-session
storage_state: "file present (assumed loaded)"   # or "none" if no auth was used
branch: "<current branch if not main and not detached>"   # omit otherwise
---
```

Body:

1. One-paragraph narrative.
2. `## Observations` — bulleted list, citing screenshot paths inline. The note lives at `docs/research/interviews/<slug>.md`, so screenshot paths are relative to that directory: `- Settings tab loaded with 3 panels visible (![](<slug>-screenshots/02-settings.png))`.
3. `## Insights` — the `### Insight:` blocks from step 6.
4. `## Follow-ups` — bulleted list of suggested next moves with the suggested skill (`/triage`, `/plan <slug>`, `/research`).

### 9. Report

Print:
- Note path written.
- Screenshot directory path and file count.
- Session status (`complete` / `partial`).
- Storage-state mode (`loaded` / `none`).
- Suggested next step: "`/triage` if follow-ups need ranking, `/plan <slug>` if a fix is worth scoping."

## Step S — Credential setup (`/browse --setup`)

Triggered when `$ARGUMENTS` contains `--setup`. Behaviour:

1. Pre-flight as in step 1 (require Playwright MCP — Chrome DevTools MCP doesn't expose a comparable storage-state pattern; bail if Playwright MCP isn't loaded).
2. Resolve the login URL from `$ARGUMENTS` (the non-`--setup` token); ask if absent.
3. `mkdir -p .claude/browse` at the repo root. The directory should be `.gitignore`-d:
   - Read existing `.gitignore`. If `.claude/browse/` is not listed, append it under a new section heading `# /browse — never commit storage state`.
   - If no `.gitignore` exists, dispatch `AskUserQuestion` before creating:
     - Question: "No `.gitignore` exists. Create one with `.claude/browse/` listed?"
     - Header: "Gitignore"
     - Options:
       - "Create `.gitignore`" *(Recommended)*
       - "Use `.git/info/exclude` instead"
       - "Skip — I'll handle it manually"
4. Confirm the user's Claude config has Playwright MCP started with `--storage-state=.claude/browse/storage-state.json`. If not (heuristic: tell the user we can't introspect their config but the path needs to match), print the snippet from step 1's **No MCP** block, ask the user to update their config, then exit with: "Update `~/.claude.json`, restart Claude Code, then re-run `/browse --setup <url>`."
5. With config confirmed, drive the headed browser to the login URL via the MCP. Print: "Browser opened. Log in manually. When fully logged in (you can see your authenticated app state), reply with `saved` here."
6. Wait for the user's `saved` reply. Once received:
   - Use the MCP's storage-state-export tool if available (Playwright MCP exposes one in some versions). Otherwise, instruct the user to close the browser via the MCP — Playwright writes the storage state on context close per the `--storage-state` startup flag.
   - Verify `<repo>/.claude/browse/storage-state.json` exists and is non-empty. If not, surface an error with the likely cause (MCP doesn't honour the flag, or browser was force-killed before close).
7. Report: "Storage state saved to `.claude/browse/storage-state.json`. Future `/browse` runs will reuse it. Re-run `/browse --setup` if the session expires."

## Degradations

- **No browser MCP** → step 1 prints the No MCP block and exits.
- **MCP missing required capability** → step 1 bails with the missing-capability message.
- **Not in a git repo** → step 1 bail.
- **Localhost dev server unreachable** → step 2 bail with "start your dev server and retry".
- **Storage state expired** → step 5 detection bails with re-setup instruction.
- **User stops mid-session** → step 6 still drafts a note marked `status: partial` and writes it.
- **User hard-cancels (Ctrl+C)** → no note written; session is lost. This is a fundamental limitation of slash-command execution.
- **Slug collision** → step 7 prompts overwrite / append-timestamped / new-slug.
- **No `docs/research/interviews/`** → step 7's `mkdir -p` creates it.
- **WSL / remote with no display** → step 1 bail, since headed mode is required.

## Naming caveat

`/browse` collides with the gstack toolkit's `browse` skill. If both are installed under `~/.claude/commands/`, slash-command resolution is ambiguous and depends on filesystem ordering. Workarounds for users with both:

- Install the workshop with `--project` scope so its `/browse` lives at `./.claude/commands/browse.md` and only resolves in this repo.
- Rename the file locally (`mv ~/.claude/commands/browse.md ~/.claude/commands/observe.md`) — slash command names follow the filename.

The workshop ships as `/browse` to match the docs/plan and because most users won't have gstack.

## See also

- `commands/research.md` — the slug-validation and frontmatter-quoting patterns reused here.
- `docs/plans/headed-browser.md` — the approved plan and its engineering review.
- `docs/solutions/browse.md` — the decision and outcome record for this skill.
