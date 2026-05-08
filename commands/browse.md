---
description: Drive a visible browser via playwright-cli so the user can watch Claude verify changes or observe the app, capture the session as a research note. First-run --setup persists login state for reuse.
argument-hint: [--setup] [url] [scenario]
---

Drive a *visible* browser using `playwright-cli` (the token-efficient CLI companion to Playwright MCP). Snapshots and screenshots go to disk — not the context window — keeping token usage ~4x lower than the MCP server approach. Sessions land at `docs/research/interviews/<slug>.md` with screenshots alongside.

`/browse --setup` is the one-shot credential flow: log in once via the headed browser, the resulting storage state is persisted, every subsequent `/browse` reuses it. Claude never types or sees the user's password — the user logs in manually in the browser. The persisted storage state (cookies + localStorage = session credentials) lives at `<repo>/.claude/browse/storage-state.json`, which the skill auto-`.gitignore`s, so it stays on the user's machine and never lands in version control.

User arguments: $ARGUMENTS

## Argument parsing

- If `$ARGUMENTS` contains the literal token `--setup`, this is **credential setup mode** (step S below). The remaining tokens are interpreted as the login URL.
- Otherwise: the first whitespace-delimited token is treated as the **target URL** if it parses as one (`http://…`, `https://…`, or `localhost…`). The remainder is the **scenario**.
- If no URL token is present, the entire `$ARGUMENTS` is the scenario; Claude asks for the URL in step 2.
- Empty `$ARGUMENTS` → ask for both.

## Hard rules

- **Headed mode only.** This skill is for the user to *watch*. Always pass `--headed` to `playwright-cli` commands that launch a browser. If the environment cannot show a window (WSL with no DISPLAY, headless container, remote SSH without X-forwarding), bail with: "/browse needs a headed browser the user can see. Run from a desktop session."
- **Read-only by default.** Navigation, clicks on visibly-safe elements (links, tabs, accordions), typing into search boxes — all fine without confirmation. Form submissions, deletes, payments, anything POST-shaped, anything that mutates remote state — pause and confirm via `AskUserQuestion` per action.
- **Never log in for the user.** Setup mode opens the page; the user types the credentials. Claude does not see, request, or store passwords.
- **Stop on user say-so.** Reply with "stop", "done", or "save" inline to end the session — partial sessions still write a note marked `status: partial`. A hard cancel (`Ctrl+C`) kills the command before the write can happen, so no note lands; that's a fundamental limitation of slash-command execution and is documented in the degradations.
- **Never run dev servers.** If localhost is unreachable, bail — don't start `npm run dev` or equivalent.

## How playwright-cli is invoked

All browser interaction happens via Bash calls to `playwright-cli`. Key patterns:

- **Launch & navigate:** `playwright-cli open <url> --headed` (opens browser and navigates).
- **Navigate:** `playwright-cli goto <url>` (within an open session).
- **Understand the page:** `playwright-cli snapshot` — returns a text snapshot with element refs (e.g. `e15`). Read the snapshot file to understand page structure before acting. Snapshots stay on disk; only read them when you need to pick a target element.
- **Click:** `playwright-cli click <ref>` where `<ref>` is an element ref from a snapshot (e.g. `e15`), a CSS selector (`"#main > button"`), or a role selector (`"role=button[name=Submit]"`).
- **Type:** `playwright-cli type <text>` (into the focused editable element) or `playwright-cli fill <ref> <text>` (target a specific field).
- **Screenshot:** `playwright-cli screenshot --filename=<path>` — saves to disk. Never enters the context window.
- **Element screenshot:** `playwright-cli screenshot <ref> --filename=<path>`.
- **Key press:** `playwright-cli press <key>` (e.g. `Enter`, `Tab`, `ArrowDown`).
- **Tabs:** `playwright-cli tab-list`, `playwright-cli tab-new [url]`, `playwright-cli tab-select <index>`.
- **Storage state:** `playwright-cli state-save <filename>`, `playwright-cli state-load <filename>`.
- **Cookies:** `playwright-cli cookie-list`, `playwright-cli cookie-get <name>`, `playwright-cli cookie-set <name> <value> [--domain=...] [--path=...] [--sameSite=...]`.

**Token discipline:** prefer `snapshot` over `screenshot` for understanding page structure — snapshots are text and cheaper to read. Only capture screenshots for the research note or when visual verification matters. When reading a snapshot, read only the portion you need.

## Steps

### 1. Pre-flight

- `git rev-parse --show-toplevel` — must be in a git repo. If not: bail with "/browse needs a git repo to anchor the research note. Run from inside one."
- Check that `playwright-cli` is available: run `playwright-cli --version`. If the command is not found, print the **No CLI** block (below) and exit.

#### No CLI block

Print this verbatim, then stop:

> `playwright-cli` not found. To use `/browse`, install it:
>
> ```
> npm install -g @playwright/cli@latest
> ```
>
> Then re-run `/browse`.

### 2. Resolve the target URL

- If parsed from `$ARGUMENTS`, use it.
- Otherwise prompt the user inline: "What URL should I open? (e.g. `http://localhost:3000/dashboard`)" — this is free-text input, not a decision gate, so a prose prompt is fine.
- Do **not** navigate yet — step 4 opens the browser, loads auth state, then navigates.

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
- **Derive a tentative slug now**, before screenshots are captured in step 5, so `<slug>-screenshots/` is a known path before you need it. Source: the scenario (preferred) or the URL path. Run the validation + normalisation rules from step 7's slug section (path-traversal reject, illegal-char reject, kebab-normalise, max 80, empty-slug fallback to `browse-<YYYYMMDD-HHMM>`). The user can revise it at step 7 — if they do, rename the screenshots directory before writing the note.

### 4. Open browser, load auth state, and navigate

- Open a blank browser: `playwright-cli open about:blank --headed`.
- If `<repo>/.claude/browse/storage-state.json` exists: load it via `playwright-cli state-load .claude/browse/storage-state.json`. Then restore session cookies: `state-load` silently drops cookies with `expires=-1` (session cookies). Read the JSON file, find any cookie with `expires` equal to `-1`, and re-set each one via `playwright-cli cookie-set <name> <value> --domain=<domain> --path=<path> --sameSite=<sameSite>`. Note in the session log: `storage-state: loaded`.
- If the file does not exist and the target URL is a known auth-gated host (heuristic: it's not localhost, and the path doesn't include `/login`, `/signin`, `/auth`), dispatch `AskUserQuestion`:
  - Question: "No saved storage state. Continue without auth, or stop and run `/browse --setup` first?"
  - Header: "No auth"
  - Options:
    - "Stop — I'll run `/browse --setup` first" *(Recommended)*
    - "Continue without auth (logged-out experience)"
- If localhost or already on a login page: continue silently — this is fine.
- Navigate to the target URL: `playwright-cli goto <url>`.
- If the URL is a localhost address, treat connection errors (`net::ERR_CONNECTION_REFUSED`, `ERR_CONNECTION_RESET`, navigation timeout) as unreachable. Bail: "Dev server unreachable at `<url>`. Start it (e.g. `npm run dev`) and re-run."
- If the URL uses HTTPS with a self-signed certificate, note this — the user may need to configure `ignoreHTTPSErrors` in `.playwright/cli.config.json`; flag it once and continue.

### 5. Drive the session

- Take an initial snapshot: `playwright-cli snapshot`. Read the snapshot to understand the page structure.
- **Detect storage-state expiry.** If storage state was loaded in step 4 but the snapshot shows a login page (heuristic: current URL contains `/login`, `/signin`, `/auth`, or the snapshot contains a login form), bail with: "Storage state appears expired. Re-run `/browse --setup` to refresh credentials."
- Capture an initial screenshot: `playwright-cli screenshot --filename=docs/research/interviews/<slug>-screenshots/00-initial.png`. See **Screenshots** below for naming rules.
- Walk the scenario. Before each step, narrate one short sentence so the watching user knows what's coming. Examples:
  - "Clicking the *Settings* tab."
  - "Typing into the search box: `queue depth`."
  - "Taking a screenshot of the alerts panel."
- After each meaningful step:
  1. Run `playwright-cli snapshot` to understand the new page state (read only the relevant portion).
  2. Capture a screenshot for the research note.
- **Destructive-action gate.** Before any of: form submit, delete, archive, send, pay, anything that issues a non-GET request the user might not intend — pause and ask via `AskUserQuestion`:
  - Question: "About to <action> on <URL>. Proceed?"
  - Header: "Destructive action"
  - Options: "Proceed" / "Skip this step" / "Stop the session"
- Listen for "stop" / "done" / "save" in user replies and end gracefully when received.

#### Screenshots

- Directory: `docs/research/interviews/<slug>-screenshots/`. `mkdir -p` before saving.
- Naming: `NN-<step-name>.png` where `NN` is the zero-padded 2-digit step number (`00-initial.png`, `01-clicked-settings.png`, …) and `<step-name>` is kebab-case derived from your narration sentence.
- Screenshots are saved to disk via `playwright-cli screenshot --filename=<path>` — they never enter the context window.
- **Sensitive-data warning.** If the target hostname is a known production domain (heuristic: not localhost, not a `*.test`/`*.local` hostname, not a staging subdomain), print once: "Screenshots may capture credentials, tokens, or PII. Consider `.gitignore`-ing `docs/research/interviews/<slug>-screenshots/` if this session touches secrets."

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
  - **Empty-slug fallback.** If normalisation produces an empty string (punctuation-only inputs, root URLs, etc.), substitute `browse-<YYYYMMDD-HHMM>` so the resulting filename and screenshots directory are non-degenerate.
  - If the user revised the slug at step 3 vs the slug used for screenshots, rename `docs/research/interviews/<old-slug>-screenshots/` to `docs/research/interviews/<new-slug>-screenshots/` before writing the note.
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
storage_state: "loaded"   # or "none" if no auth was used
branch: "<current branch if not main and not detached>"   # omit otherwise
---
```

Body:

1. One-paragraph narrative.
2. `## Observations` — bulleted list, citing screenshot paths inline. The note lives at `docs/research/interviews/<slug>.md`, so screenshot paths are relative to that directory: `- Settings tab loaded with 3 panels visible (![](<slug>-screenshots/02-settings.png))`.
3. `## Insights` — the `### Insight:` blocks from step 6.
4. `## Follow-ups` — bulleted list of suggested next moves with the suggested skill (`/triage`, `/plan <slug>`, `/research`).

### 9. Close & report

- Close the browser: `playwright-cli close`.
- Print:
  - Note path written.
  - Screenshot directory path and file count.
  - Session status (`complete` / `partial`).
  - Storage-state mode (`loaded` / `none`).
  - Suggested next step: "`/triage` if follow-ups need ranking, `/plan <slug>` if a fix is worth scoping."

## Step S — Credential setup (`/browse --setup`)

Triggered when `$ARGUMENTS` contains `--setup`. Behaviour:

1. Pre-flight as in step 1 (require `playwright-cli`).
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
4. Open the browser at the login URL: `playwright-cli open <url> --headed`.
5. Print: "Browser opened. Log in manually. When fully logged in (you can see your authenticated app state), reply with `saved` here."
6. Wait for the user's `saved` reply. Once received, save the storage state: `playwright-cli state-save .claude/browse/storage-state.json`.
7. Verify `.claude/browse/storage-state.json` exists and is non-empty (`{"cookies":[…]}` shape, not the empty `{}`). If empty: the user may not have completed login before triggering save; surface the file size and ask whether to retry.
8. Report: "Storage state saved to `.claude/browse/storage-state.json` (<size> bytes). Future `/browse` runs will reuse it. Re-run `/browse --setup` if the session expires."

## Degradations

- **`playwright-cli` not installed** → step 1 prints the No CLI block and exits.
- **Not in a git repo** → step 1 bail.
- **Localhost dev server unreachable** → step 2 bail with "start your dev server and retry".
- **Session cookies dropped by `state-load`** → `playwright-cli state-load` restores localStorage and persistent cookies but silently drops session cookies (`expires=-1`). Step 4 compensates by reading the JSON and re-setting them via `cookie-set`.
- **Storage state expired** → step 5 detection (redirect to login page after loading state) bails with re-setup instruction.
- **User stops mid-session** → step 6 still drafts a note marked `status: partial` and writes it.
- **User hard-cancels (Ctrl+C)** → no note written; session is lost. This is a fundamental limitation of slash-command execution.
- **Slug collision** → step 7 prompts overwrite / append-timestamped / new-slug.
- **No `docs/research/interviews/`** → step 7's `mkdir -p` creates it.
- **WSL / remote with no display** → step 1 bail, since headed mode is required.

## Naming caveat

`/browse` collides with the gstack toolkit's `browse` skill. If both are installed under `~/.claude/commands/`, slash-command resolution is ambiguous and depends on filesystem ordering. Workarounds for users with both:

- Install the workshop with `--project` scope so its `/browse` lives at `./.claude/commands/browse.md` and only resolves in this repo.
- Rename the file locally (`mv ~/.claude/commands/browse.md ~/.claude/commands/observe.md`) — slash command names follow the filename.

The workshop ships as `/browse` to match the docs/plans and because most users won't have gstack.

## See also

- `commands/research.md` — the slug-validation and frontmatter-quoting patterns reused here.
- `docs/plans/headed-browser.md` — the approved plan and its engineering review.
- `docs/solutions/browse.md` — the decision and outcome record for this skill.
