# TODOs

## Review findings — 2026-05-22 (PR #30, /start-day + /end-day)

Round 1 review by Codex CLI, pr-reviewer, and compound-reviewer in parallel. 3 must-fix items addressed inline; the following should-fix and follow-up items are deferred.

### Should fix

- **`commands/start-day.md:27` fetch before path validation** — runs `git -C <path> fetch` before checking if the path exists or is a git repo, so missing repos emit errors before the intended skip/warn flow. Fix: move the path/git-repo validation before the fetch. *(Codex)*
- **`commands/end-day.md:37`, `commands/start-day.md:50` merged-branch check uses local `main`** — should check `origin/main` (or `origin/master`) instead of local `main` after fetching, since local default branch may be stale or absent. *(Codex)*
- **`commands/start-day.md:76` "branch gone" uncomputable** — snapshot stores branch names but not enough remote/local existence context to detect deleted branches. Either store more metadata or drop the "branch gone" delta from the diff step. *(Codex)*
- **`commands/start-day.md:77-78` commit count uncomputable** — example says "3 new commits" but no instruction to run `git rev-list <old-hash>..HEAD --count`. Either add the instruction or drop the count from the example. *(flagged by 2 reviewers)*
- **`commands/end-day.md:7`, `commands/start-day.md:7` `$ARGUMENTS` declared but never used** — every other command that declares it actually uses it. Either remove the line or define accepted arguments (e.g. `--skip-notes`, `--skip-goals`). *(pr-reviewer)*
- **CLAUDE.md: sentinel-delimiter principle** — the `<!-- SECTION:START/END -->` pattern for idempotent file merging is reusable. Should be captured in CLAUDE.md's Learned Principles once the solution doc reaches outcome stage. *(compound-reviewer)*
- **TODOS.md: deferred work visibility** — plan documents deferrals (scheduled capture via `/schedule`, weekly summaries v2, project auto-discovery) that are not tracked where `/triage` can find them. Items: (1) scheduled end-of-day capture (v2), (2) weekly summaries / trend detection (v2), (3) project auto-discovery if hardcoded repos change. *(compound-reviewer)*

### Follow-up

- **`docs/plans/daily-workflow-capture.md:16` plan data model lacks sentinels** — the example format in the plan doesn't show the HTML comment sentinels that the implemented skills require. Plan and implementation disagree. *(Codex)*
- **`commands/start-day.md:87` Jira integration has no verification path** — the Jira MCP integration degrades gracefully but has no smoke test or manual verification step. *(Codex)*

## Review findings — 2026-05-04 (PR #22 round 2, /auto-fleet v1)

Round 2 of `/review-pr` on PR #22. 2 new must-fix items addressed inline (`Dispatch anyway` remote-only branch handling; worktree-management section's stale `.gitignore` reference). 2 should-fix plan-drift items folded inline alongside (plan referenced the pre-fix `gh pr list --head 'auto-do/*'` and the auto-modify-`.gitignore` flow; both updated to match the round-1 fixes). The following should-fix and follow-up items are deferred.

### Should fix

- **`commands/auto-fleet.md:216` multi-token slug regression** — v0.1 normalised whitespace in `$ARGUMENTS` to `-` (so `api logging` became `api-logging`). v1's new parser splits on whitespace and takes the first non-flag token as the slug, rejecting a multi-word input. Backward-compat regression. Fix: take all tokens before the first `--`-prefixed token as the slug (joined, then kebab-case normalised); tokens at/after `--` are flags. *(Codex round 2)*
- **`commands/auto-fleet.md:222` orphan prompt missing row ids** — Pre-flight surfaces fleet *slugs* parsed from worktree paths but not row *ids*; users can't tell which failed-row worktree they're about to delete. Surface both. *(Codex round 2)*
- **`commands/auto-fleet.md:292` self-timeout prompt isn't actionable** — Sub-agents don't have a runtime wall-clock primitive. The current "if your wall-clock exceeds 60 min, emit `failed:timeout`" instruction reads as a polite suggestion an LLM-runtime can't reliably honour. Either drop the timeout entirely (own up to "v1 has no timeout") or describe self-policing in honestly soft terms. *(Codex round 2)*
- **`commands/auto-fleet.md:293` "LAST RESULT wins" still has a hole** — If the agent writes `RESULT:` then quotes the protocol later (in explanatory prose), the quoted echo wins. Fix: require `RESULT:` to be the *final line* of the agent's response, not just last-occurring. *(Codex round 2)*
- **`docs/plans/auto-fleet-parallel.md:54` Verification 65-min timeout fixture** — Manual smoke list still includes "task that sleeps 65 min → expect `failed:timeout` at the 60-min boundary" — but v1 explicitly doesn't enforce this. Reframe (e.g. "agent self-emits failed:timeout per its prompt") or drop. *(Codex round 2)*

### Follow-up

- **`commands/auto-fleet.md:394` Failure-modes table** — Missing the orphan-cleanup "Cancel" exit row. Add as an `n/a` no-manifest-update exit. *(Codex round 2)*

## Review findings — 2026-05-04 (PR #22, /auto-fleet v1)

PR #22 (`feat/auto-fleet-parallel`). Round 1 review by Codex CLI + `pr-reviewer` agent in parallel. 6 must-fix items addressed inline; the following should-fix and follow-up items are deferred.

### Should fix

- **`commands/auto-fleet.md` v0.1 backward-compat semantics drift** — v0.1-schema manifests run under v1 as parallel-with-no-deps, which diverges from v0.1's serial halt-on-first semantics. Document the behavioural drift explicitly in the backward-compat note; suggest `--max-parallel=1` + explicit `depends_on` chains for v0.1-equivalent semantics. *(Codex)*
- **`commands/auto-fleet.md:250` `<min-waves>` ignores `--max-parallel`** — DAG depth alone gives wrong estimates when `N > max_parallel` at any level. With 10 independent rows + `--max-parallel=3`, depth=1 but actual waves=4. Compute as `max(DAG-depth, ceil(level-width / max-parallel) summed across levels)`, or document the caveat in the prompt. *(flagged by both)*
- **`commands/auto-fleet.md` outcome classification — parseable RESULT with unknown status** — Currently classifies as `protocol-violation`, conflating "RESULT line exists but `/auto-do` reported a status the matcher doesn't enumerate" with "RESULT line missing/malformed." Introduce `failure_class: unknown-status` as a distinct class so a real new `/auto-do` failure-status surfaces clearly. *(Codex)*
- **`commands/auto-fleet.md` cascade-block `blocked_by` precision** — Always set to the originally-failed root, hiding intermediate ancestors. In a chain A→B→C with A failing, C ends up `blocked_by=A` even though C's `depends_on` is `[B]`. The user-facing report's "C blocked because A failed" doesn't match C's manifest. Fix: track the immediate unsatisfied parent in BFS, or rename to `cascade_root_id` and have the report walk the actual edge. *(pr-reviewer)*
- **`CHANGELOG.md:23` duplicate v0.1+v1 entries** — Both `/auto-fleet` entries land under `[Unreleased]`. v1 supersedes v0.1; the v0.1 bullet duplicates information already in the v1 entry's "replacing v0.1's serial loop" + plan-doc references. Drop the v0.1 entry. *(pr-reviewer)*
- **`docs/solutions/auto-fleet-parallel.md` frontmatter still `decided`** — Per `CLAUDE.md`'s solution convention, a PR that ships the implementation should advance the doc to `in-progress` (or `outcome` if this PR is considered the shipping commit). Currently still `decided`. *(pr-reviewer)*
- **`docs/plans/auto-fleet-parallel.md` Verification — no committed fixture pack** — v1 introduces non-trivial parser surface (cycle detection, forward-ref check, schema-variant detection, id regex, 6-state enum) but ships zero committed fixtures. Stub at minimum the cycle and forward-ref-miss fixtures into the repo (e.g. `docs/research/fixtures/auto-fleet/`). *(flagged by both)*

### Follow-up

- **`commands/auto-fleet.md` `failed:ambiguity` classified as `failure_class: task`** — Defensible simplification, but conflates LLM-decision-ambiguity with code-quality failures. The user's response shape differs (re-author task description vs fix-and-retry). Worth a separate `failure_class: ambiguity` later. *(pr-reviewer)*
- **`commands/auto-fleet.md` worktree teardown** — `git worktree remove --force` already deletes the working dir; the trailing `rm -rf` is redundant. Drop or document defensive intent. *(pr-reviewer)*
- **`commands/auto-fleet.md` scheduler pseudocode** — `<base_sha>` (underscore) inconsistent with `<base-sha>` (hyphen) used elsewhere. Cosmetic. *(pr-reviewer)*
- **`commands/auto-fleet.md:472` `### 7. (No standalone step 7.)` placeholder** — Section header that says "no section." Renumber 8→7 and 9→8 (and update internal cross-references), or drop the placeholder. *(pr-reviewer)*
- **`docs/plans/auto-fleet-parallel.md` Manifest format alignment** — `changelog` row's `depends_on` cell visibly overflows its column header in source; mirror the skill body's column widths. *(pr-reviewer)*
- **`CHANGELOG.md:23` review-count math** — Says "19 findings; 17 folded, 2 → TODOs, 1 disagreed" which sums to 20. Counting error in the v1-entry prose. *(Codex)*

## Eng-review carry-forwards — 2026-05-04 (/auto-fleet v1, PR feat/auto-fleet-parallel)

The Codex outside-voice review on the v1 plan returned 19 findings; 17 were folded into `docs/plans/auto-fleet-parallel.md` and `commands/auto-fleet.md`. The following 4 deferrals + 1 disagreement carry forward:

### Deferred (v1.5+ unless real usage shows otherwise)

- **Concurrent-fleet protection (lock file).** Codex #14 — `.claude/auto-fleet/lock` file would prevent two `/auto-fleet` invocations colliding on worktrees / branches. v1 documents the limitation. Add when real users hit it.
- **Mid-fleet manifest hash recovery.** Codex #16 — when the hash check fires at step 8 after PRs are created, v1 refuses to clobber and exits; user reconciles manually. Real recovery (e.g. amend in-memory state into the user's edits) is v1.5+.
- **Untracked-runtime-state into worktrees.** v1 contract: tasks must be runnable in a fresh checkout. Copy/symlink `.env` / `node_modules` / virtualenvs into worktrees would broaden the kinds of tasks `/auto-fleet` v1 supports. Real but big lift.
- **`/auto-fleet` v1 first-real-run smoke** — like v0.1's analogous TODO, schedule a one-off agent ~2 weeks after ship to run a 4-row DAG fleet against a public template repo and report findings.

### Disagreed (workshop principle)

- **Codex #20 — "Markdown-only is the wrong constraint for this much scheduler logic."** Same foundational disagreement as v0.1. The LLM is the runtime; the markdown is the program. v1 is more complex than v0.1 under the same substrate. Acknowledged in the plan's Constraints section. Not an action item; a known tension.

## Review findings — 2026-05-01 (PR #21, /auto-fleet)

PR #21 (`feat/auto-fleet`). Round 1 review by Codex CLI + `pr-reviewer` agent in parallel. 5 must-fix items addressed inline; the should-fix and follow-up items below are deferred.

### Should fix

- **`docs/plans/auto-fleet.md` Verification section** — no manual smoke fixture exercises the round-2-must-fix → `halted:round-2-failure` path, which is the most consequential failure mode. Add a sixth fixture: a 2-row manifest where the second subtask is deliberately misconfigured to fail at `/review-pr`'s round 2 gate (e.g. has a known-bad assertion that `pr-reviewer` will flag must-fix on round 1, with a fix-up that introduces a regression Codex catches on round 2). Verify the fleet halts cleanly with `Final status: halted:round-2-failure` and the prior subtask's PR is untouched.
- **`docs/brainstorms/auto-fleet.md:22, :36`** — brainstorm still uses `done` in row state taxonomy. Round-1 fold-in claimed the rename was applied "across skill body, plan, manifest constraints, state machine, failure modes, and counts" but missed the brainstorm. Either rename in place, or add a one-line "post-decision: state names landed as `succeeded`/`failed`/`skipped`" note at the top of the brainstorm. Brainstorms are pre-decision artefacts so retroactive renaming distorts the record; the post-decision note is probably the cleaner choice.

### Follow-up

- **Manifest fixture pack** (`tests/fixtures/fleet/*.md`) — a small directory of valid + invalid manifest examples for manual smoke validation when changes touch step 2. Catches table-parse regressions. Already on the eng-review TODO list; reaffirmed by Codex round 1.
- **`docs/plans/auto-fleet.md` engineering-review TODO list** — Codex round 1 noted the plan promises follow-ups will be added to `TODOS.md` "when committed" but the round-1 fix-up commit didn't track them. This commit (round 2 fix-up for PR #21) addresses the point by writing the round-1 review's should-fix and follow-up items here. Remaining eng-review TODOs (rate-limit smoke, push-rejection handling, manifest data-model revisit, first-real-run smoke, gh permission/fork/protected-branch coverage) carry forward — bring them into this file when `/auto-fleet` actually ships.

## Review findings — 2026-05-05 (PR #23, playwright-cli switch)

PR #23 (`feat/browse-playwright-cli`). Round 1 review by Codex CLI + `pr-reviewer` agent in parallel. Must-fix item (step 2/4 navigation ordering) addressed inline; should-fix and follow-up items below.

### Should fix

- **`commands/browse.md:210`** — Degradation table claimed storage-expiry detection existed in step 5 but step 5 had no such logic. Fixed alongside the must-fix ordering item, but verify the detection heuristic is robust.
- **`README.md:39,109`** — Still references "Playwright MCP (or Chrome DevTools MCP)" as the optional integration for `/browse`. Should reference `playwright-cli` / `@playwright/cli`.
- **`docs/changelog.md:20-24`** — Still describes `/browse` as orchestrating "Playwright MCP (primary) or Chrome DevTools MCP (alternative)". Update or add a new entry for the playwright-cli switch.

### Follow-up

- **`TODOS.md`** — Several earlier TODO items (lines 26-28, 33-35) reference MCP-specific concerns (MCP save tool, capability-check tool names, MCP config introspection, README storageState wording) that are now moot after the playwright-cli switch. Sweep and close.
- **`commands/browse.md`** — No smoke test for the CLI auth flow (state-load → goto → expiry detection). A basic manual transcript would catch ordering regressions.
- **`commands/browse.md:87`** (round 2) — `state-load` uses relative `.claude/...` path; running from a subdir could load the wrong file. Consider using `<repo>/.claude/...` absolute path.
- **`commands/browse.md:98`** (round 2) — Expiry detection heuristic treats any `/auth` URL as a login page, which could cause false bails on apps with `/auth/callback` or similar non-login auth paths.

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

