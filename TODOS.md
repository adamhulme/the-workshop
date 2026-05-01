# TODOs

## Review findings — 2026-05-01 (PR #21, /auto-fleet)

PR #21 (`feat/auto-fleet`). Round 1 review by Codex CLI + `pr-reviewer` agent in parallel. 5 must-fix items addressed inline; the should-fix and follow-up items below are deferred.

### Should fix

- **`docs/plans/auto-fleet.md` Verification section** — no manual smoke fixture exercises the round-2-must-fix → `halted:round-2-failure` path, which is the most consequential failure mode. Add a sixth fixture: a 2-row manifest where the second subtask is deliberately misconfigured to fail at `/review-pr`'s round 2 gate (e.g. has a known-bad assertion that `pr-reviewer` will flag must-fix on round 1, with a fix-up that introduces a regression Codex catches on round 2). Verify the fleet halts cleanly with `Final status: halted:round-2-failure` and the prior subtask's PR is untouched.
- **`docs/brainstorms/auto-fleet.md:22, :36`** — brainstorm still uses `done` in row state taxonomy. Round-1 fold-in claimed the rename was applied "across skill body, plan, manifest constraints, state machine, failure modes, and counts" but missed the brainstorm. Either rename in place, or add a one-line "post-decision: state names landed as `succeeded`/`failed`/`skipped`" note at the top of the brainstorm. Brainstorms are pre-decision artefacts so retroactive renaming distorts the record; the post-decision note is probably the cleaner choice.

### Follow-up

- **Manifest fixture pack** (`tests/fixtures/fleet/*.md`) — a small directory of valid + invalid manifest examples for manual smoke validation when changes touch step 2. Catches table-parse regressions. Already on the eng-review TODO list; reaffirmed by Codex round 1.
- **`docs/plans/auto-fleet.md` engineering-review TODO list** — Codex round 1 noted the plan promises follow-ups will be added to `TODOS.md` "when committed" but the round-1 fix-up commit didn't track them. This commit (round 2 fix-up for PR #21) addresses the point by writing the round-1 review's should-fix and follow-up items here. Remaining eng-review TODOs (rate-limit smoke, push-rejection handling, manifest data-model revisit, first-real-run smoke, gh permission/fork/protected-branch coverage) carry forward — bring them into this file when `/auto-fleet` actually ships.

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

