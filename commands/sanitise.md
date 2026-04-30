---
description: Pre-publish gate. Scan a path for client/internal references via hybrid denylist + LLM detection.
argument-hint: [<path>] [--dry-run]
---

Scan files for tokens that shouldn't appear in a public-bound repo: client names, employer names, internal repo names, team member names, customer references, internal URLs. Two passes:

1. **Denylist regex** against `~/.claude/workshop/denylist.txt`. Known replacements auto-fix; unknown matches prompt.
2. **LLM scan** over the remainder. Novel proper nouns get flagged and (on user approval) added to the denylist for next time.

The denylist is a compounding artefact: every run that finds something new makes the next run faster.

User arguments: $ARGUMENTS

## Steps

1. **Resolve path.** Default to `.` if no path given. If a `--dry-run` flag is present, set dry-run mode (run both passes but never apply changes).

   Resolve the path safely before scanning:
   - Run `git rev-parse --show-toplevel` to find the repo root. Abort if not in a git repo: `/sanitise rewrites files; it needs a repo root to anchor the scan.`
   - Convert `<path>` to an absolute, resolved path (follow symlinks; collapse `..`).
   - **If the resolved path is outside the repo root**, do not scan by default. Print the resolved path and ask: `Path resolves outside the repo root (<repo>). Scan and mutate files at <resolved> anyway? (type "yes-outside-repo" to confirm, anything else cancels)`. Cancel on anything other than the literal token. This is the only place `/sanitise` ever rewrites outside the repo.
   - Verify the path exists after resolution.

2. **Load the denylist and replacements.**
   - Read `~/.claude/workshop/denylist.txt` (one token per line; lines starting with `#` are comments).
   - Read `~/.claude/workshop/replacements.txt` (format: `bad-token => good-replacement`, one per line). **If this file does not exist, treat it as an empty replacement set — do not create it now.** It is created lazily in step 3 when the user supplies the first replacement to persist.
   - If the denylist file doesn't exist, `mkdir -p ~/.claude/workshop`, create a skeleton denylist with a comment header explaining the format, then continue with an empty token set.

3. **Pass 1 — denylist regex.** For each text file under `<path>`, skipping `.git/`, `node_modules/`, `dist/`, `build/`, and binaries:
   - Grep case-insensitively for each denylist token.
   - For each hit:
     - **Known replacement exists** → auto-fix without prompting. Log `[auto] <file>:<line>: <token> → <replacement>`.
     - **No known replacement** → show 3 lines of context, suggest a generic alternative, ask `apply / skip / paste replacement`. Apply the user's choice. If they paste a replacement, offer to add `<token> => <replacement>` to `replacements.txt` for future runs. If `~/.claude/workshop/replacements.txt` does not yet exist, create it (with a comment header documenting the format) before appending — this is the lazy-create path noted in step 2.

4. **Pass 2 — LLM scan over remainder.** For each text file (post-Pass-1):
   - Read the file content.
   - Identify any remaining proper nouns, internal-system names, customer references, or team-specific jargon that look client-internal but aren't on the denylist.
   - For each finding:
     - Show context, ask `apply / skip / paste replacement`.
     - On apply, also ask `Add <token> to the denylist for next time? (y/n)`. On `y`, append to `~/.claude/workshop/denylist.txt`; if a replacement was supplied, append the pair to `replacements.txt`.

5. **Audit trail (only if changes were made).** Write `docs/solutions/sanitisation-<YYYY-MM-DD>.md` with:
   - Frontmatter: `status: outcome`, `date`, `slug: sanitisation-<date>`.
   - Summary: total tokens replaced, files touched, source breakdown (denylist vs LLM).
   - Per-file change list: `<file>:<line>: <before> → <after>`.
   - Denylist additions made during the run.
   
   If no changes were made, write nothing — print a clean-bill-of-health summary to the console only.

6. **Report.** Print: total files scanned, denylist tokens applied, LLM findings confirmed, items skipped, denylist additions, audit path (if any).

## Degradations

- **Denylist file missing** → create at `~/.claude/workshop/denylist.txt` with a comment header documenting the format, continue with an empty list.
- **Replacements file missing** → treat as an empty set; create lazily on first user-supplied replacement (see step 3). A clean machine running `/sanitise` for the first time should not fail.
- **Path resolves outside the repo root** → require the literal `yes-outside-repo` confirmation token (see step 1). Anything else cancels without scanning.
- **Not in a git repo** → step 1 abort. The skill rewrites files and refuses to run without a repo root to anchor the scan.
- **`--dry-run` flag** → run both passes; print findings; never edit files; do not write an audit trail.
- **`docs/solutions/` missing and changes were made** → suggest `/init-workshop`; offer inline `mkdir -p docs/solutions/` so the audit trail can land.
- **Path empty / no text files** → no-op exit with a clear message.
