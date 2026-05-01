# TODOs

## Review findings — 2026-05-01

PR #16 (`feat/browse`). Round 1 review by Codex CLI + `pr-reviewer` agent in parallel. Must-fix items addressed inline; should-fix and follow-up items captured below.

### Should fix in this PR (round 1 deferred)

- **commands/browse.md:71** — Self-signed-HTTPS-cert note is speculative; the skill cannot detect cert errors before navigation. Either fold into the unreachable-URL bail at `:70` or delete.
- **commands/browse.md:85** — Auth-gated host heuristic (`/login`/`/signin`/`/auth` path check) conflicts with the storage-state expiry detection at `:93`: a user who runs `/browse https://app.example.com/login` intentionally hits the heuristic-skip and then trips the "expired" path on the same URL. Tighten or remove.
- **commands/browse.md:85** — The auth-gated host heuristic itself is speculative (URL pattern doesn't reliably indicate auth). Simplest fit: if no storage state exists on a non-localhost host, prompt once. No heuristic needed. Pairs with the finding above.
- **commands/browse.md:181-183** — `--setup` step S/6 tells the user to reply `saved`, but the actual context-close instruction is missing from the printed copy at `:180`. Either commit to "Playwright MCP exposes a `storage_state.save` tool — call it" (and bail if not present) or expand `:180` to tell the user how to trigger context close.
- **commands/browse.md:36** — The required-MCP-capability check says "Tool names vary by MCP — match by purpose, not exact name" but gives no concrete example mapping. For Playwright MCP, list the actual tool names (`mcp__playwright__browser_navigate`, `_click`, `_type`, `_take_screenshot` — verify exact names against current Playwright MCP) so the check is mechanical rather than interpretive.
- **commands/browse.md:171** — Step S/4 asks the user to confirm MCP config because it "can't introspect", but step 1 already detected the MCP. Tighten this to a concrete check or document the manual prerequisite up front so the awkward "we can't introspect" wording can be dropped.

### Follow-up

- **commands/browse.md:91** — `git diff origin/HEAD..HEAD` is a weak proxy for "recent change". Prefer current branch's upstream or merge-base with default branch.
- **docs/plans/headed-browser.md:25** — Plan summary says MCP-agnostic ("use whichever") but the implemented skill privileges Playwright MCP and routes setup through its `--storage-state` flag specifically. Update the plan summary or mark as superseded.
- **docs/solutions/browse.md:51** — Says skill "notes 'tested with current latest'" but `commands/browse.md` does not contain that language. Either add a note in the skill body or remove the reference here.
- **README.md:109** — Promises persisted `storageState` reuse on every subsequent run, but reuse depends on the user's MCP config matching the skill's setup snippet exactly. Soften the wording or cross-reference the prerequisite.
- **commands/browse.md:205** — No smoke-test fixture or scripted validation exists for skill markdown invariants (date placeholders, paths, storage-state wording). Manual verification per the plan's checklist for now; a fixture would catch path drift like the one fixed in round 1.
- **docs/solutions/browse.md** — Once PR #16 merges, advance the solution doc to `outcome` per the workshop convention. Run `/changelog` afterwards.
- **README.md:199** — `<slug>(-screenshots)/` notation is novel and the parenthetical is ambiguous. Consider rephrasing to "the note plus a sibling screenshots dir" or similar.

## Review findings — 2026-05-01 (PR #18, /auto-do)

PR #18 (`feat/auto-do`). Round 1 review by Codex CLI + `pr-reviewer` agent in parallel. Must-fix and should-fix items addressed inline in commit `<round-1-fixup>`; follow-up items captured here.

### Follow-up

- **commands/auto-do.md** (branch suffix loop) — Step 1's `auto-do/<slug>-2`, `-3`, … suffix logic is now bounded at `-99`. Past that the skill bails. If real usage ever hits this cap, revisit.
- **commands/auto-do.md** (slug fallback timezone) — Empty-slug fallback uses `auto-do-<UTC YYYYMMDD-HHMM>`. The "UTC" qualifier is documented in the skill body; if real usage shows the collision-suffix path is enough on its own, the explicit timezone could be dropped.
- **commands/auto-do.md** (PR #16 SHA-pinning) — Removed the `878e25b` SHA reference; "added in PR #16" is sufficient provenance and SHAs go stale.
- **docs/plans/auto-do.md** — Verification list is entirely manual. A smoke fixture (e.g. running `/auto-do "tiny task"` against a public template repo with a known small change) would catch command-path drift and PR-body shape regressions.

