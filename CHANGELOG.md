# Changelog

All notable changes to **the-workshop** are tracked here. Format inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

The version in [`VERSION`](VERSION) is the version `install.sh` and `update.sh` will write into a user's manifest. Bump it in the same commit that adds the corresponding entry below, then tag (`git tag v<version> && git push --tags`) when cutting a release.

Versioning convention:

- **patch** (`0.1.0` → `0.1.1`) — wording fixes, internal hardening of an existing skill, no behaviour change a user would notice.
- **minor** (`0.1.0` → `0.2.0`) — new skill or agent, visible behaviour change to an existing skill, new degradation path.
- **major** (`0.x` → `1.0.0`, `1.x` → `2.0.0`) — install layout change, removed/renamed skills, anything that requires a user to read release notes.

A bump is reserved until the next release; in-progress work lives under `[Unreleased]`.

## [Unreleased]

### Changed

- `/review-pr` now posts a consolidated findings comment to the PR at each review round (`gh pr comment <n>` with the must-fix / should-fix / follow-up list). Round 2 also posts a "Round 2 clean" comment when no new must-fix items were surfaced. Comment posting is observability-only — failures log and continue, the in-conversation review flow is unaffected. Skips silently when reviewing a feature branch with no PR.

### Added

- `/auto-fleet` — autonomous fleet runner for tasks too large for a single PR. Reads a user-authored manifest at `docs/fleet/<slug>.md` and dispatches `/auto-do` per `queued` row sequentially. v0.1 is a serial dispatcher only — **hard cap of 5 subtasks** per run with no flag override (a v0.1 guard rail; mainstream fleet runners have no cap); halts on first failed subtask (no `--keep-going`, matching Argo / GHA matrix / Make / Bazel default); no auto-stub creation, no `--resume`, no epic-branch mode, no auto-slicing. The fleet's own commits land on a `fleet/<slug>` control-plane branch the user creates off the default branch before invoking; pre-flight refuses to run on the default branch. The fleet branch holds only the manifest and is never merged. Subtask branches (`auto-do/<row-id>`) are created off the default branch by `/auto-do` itself; their PRs target the default branch independently. **State during the dispatch loop is held in memory only**; a single disk write + commit + push happens at step 8 after explicit `git checkout fleet/<slug>` (writing the manifest mid-fleet would dirty the working tree and break `/auto-do`'s pre-flight — round-1 Codex finding on PR #21). SHA-256 hash check on the manifest at fleet start halts cleanly with `Final status: halted:manifest-tampered` if the user edits the manifest externally during a run, rather than silently clobbering. Idempotency check before each dispatch: branch existence (local + remote) plus prior PR state via `gh pr list --head auto-do/<id> --state all` (catches stale branches from closed/merged PRs); surfaces `Skip` *(Recommended)* / `Dispatch anyway` / `Cancel` via `AskUserQuestion`. State names follow Argo / Temporal / GitHub Actions convention: `queued | running | succeeded | failed | skipped`. Outcome classification keys off explicit `/auto-do` `Final status:` strings (`succeeded`, `failed:round-2-must-fix`, `failed:test-gate`, `failed:complexity-smell`); anything unrecognised → `failed` with `halted:unrecognised-auto-do-report`. One commit per fleet run on the control-plane branch. The full v0.1 plan + Codex outside-voice eng-review block + round-1 review fold-ins are at `docs/plans/auto-fleet.md`; the decision rationale is at `docs/solutions/auto-fleet.md`.

- `/auto-do` — autonomous task runner. Chains `/plan` → `/plan-eng-review` (and `/plan-design-review` when UI scope is touched) → implementation → `/solution` (decided + in-progress) → `gh pr create` → `/browse` verification (when applicable) → `/review-pr`, applying a documented auto-decision policy at every gate the underlying skills would have raised. Creates and reviews a PR but **never merges** — the merge gate stays human. Every auto-pick is logged to the PR body's `## Auto-decisions` section for auditing. Hard rules: never push to default branch, never `--force` / `--no-verify`, never merge. Stops loudly on dirty tree, missing `gh`, complexity smell (>8 files or 2+ new services in eng review), test failure before push, or round-2 must-fix findings (PR converted to draft via `gh pr ready --undo`, blocking comment posted, items dumped to `TODOS.md`). UI scope is re-detected from the actual diff after implementation; the `/browse` pass uses pre-captured Playwright storage state if present and skips with a logged "run /browse --setup once" hint if not.

- `/browse` — orchestrates Playwright MCP (primary) or Chrome DevTools MCP (alternative) to drive a *visible* browser so the user can watch Claude verify a UI change or walk a user flow. Captures screenshots under `docs/research/interviews/<slug>-screenshots/` and writes a structured session note (`### Insight:` blocks reused from `/research`) to `docs/research/interviews/<slug>.md`. Read-only by default — destructive actions (form submit, delete, payment) are gated per-step via `AskUserQuestion`. `/browse --setup <login-url>` is the one-shot credential flow: drives a headed login, persists Playwright's `storageState` to `<repo>/.claude/browse/storage-state.json` (skill auto-`.gitignore`s the path), and every subsequent `/browse` reuses it. Bails cleanly on missing MCP, missing required capability (navigate / click / type / screenshot), unreachable localhost, non-git project, or expired storage state. Slug validation and frontmatter quoting lifted from `/research`. **Naming caveat:** collides with gstack's `browse` skill — install workshop with `--project` scope or rename locally if both are present on `~/.claude/commands/`.

## [0.4.0] — 2026-05-01

### Added

- `/review-pr` — bounded 2-round PR review loop. Round 1: Codex CLI and the `pr-reviewer` agent review the diff in parallel; findings are deduped by `(file, line, category)` and grouped must-fix / should-fix / follow-up. Single user gate via `AskUserQuestion`. Main-thread Claude addresses must-fix items as a single fix-up commit; should-fix and follow-up items go verbatim to `TODOS.md`. Round 2: Codex re-reviews the new diff (role swap — Codex is the only voice that hasn't seen the post-fix code). Hard cap at 2 rounds — the cap is the point. Fix-up commits **auto-push** to the PR's head branch (no force, no `--no-verify`); refuses to push to default branch; prompts via `AskUserQuestion` if the branch has no upstream. Falls back to a `general-purpose` Agent in either Codex slot if `codex` is not on PATH.

## [0.3.0] — 2026-04-30

### Added

- `/consult` — multi-perspective team consultation. Discovers a six-persona team via `**/teams/*/team.yaml`, dispatches personas in parallel as Agent subagents, surfaces tensions, runs targeted rebuttals, and synthesises a recommendation that preserves disagreements rather than smoothing them. Flags: `--quick <role>`, `--context <file>`, `--team <path>`, `--group <name>`, `--all`, `--opus`.
- `/team-init` — scaffolds a six-persona consultation team into the project. Interactive questionnaire (product name, primary users, key tech, domain reality, commercial boundary, top risks) fills generic templates for `product-strategist`, `user-advocate`, `domain-specialist`, `technical-architect`, `quality-risk`, and `delivery-lead`. Writes `team.yaml`, six persona files, and an `agent-team-spec.md` rationale doc. Appends a `## Team conventions` section to `CLAUDE.md`.
- `/plan-eng-review` — engineering-manager-mode plan critique. Walks scope challenge, architecture review (boundaries, dependencies, contracts, data flow), code quality (DRY, naming, refactor pressure), test review (coverage, failure modes, ASCII diagram), and performance review. Optional independent second-opinion via Codex CLI (`codex exec`); falls back to a `general-purpose` Agent if `codex` is not on PATH. Findings land in the plan file or `TODOS.md`.
- `/plan-design-review` — designer's-eye plan critique. Scores eight dimensions (color, typography, spacing, components, accessibility, interaction, mobile responsiveness, visual hierarchy) 0–10 with current → target → gap framing. Optional parallel variant generation via Agent subagents, plus an optional adversarial outside voice via Codex CLI (`codex exec`). Embeds AI-slop pattern checklist (default font stacks, three-column grids, centred everything) for adversarial review.

## [0.2.0] — 2026-04-30

### Added

- `update.sh` — always shallow-clones the latest `main` from origin (never trusts a local clone, even when run from one), runs `install.sh` from that fresh source, then diffs the previous manifest against the new one and prunes any skills that have been removed upstream. Same `--user`/`--project` flags as `install.sh`, with auto-detection from the existing manifest when neither flag is given.
- `install.sh` now writes `.workshop-manifest` and `.workshop-version` into the install target so `update.sh` can diff and prune cleanly without touching skills the workshop didn't install.
- `VERSION` and `CHANGELOG.md` at the repo root. The version is echoed at the end of `install.sh` and `update.sh`.
- README **Starter guide** section — five-step walkthrough of the compounding loop (`/init-workshop` → `/research` → `/plan` → `/solution` → `/changelog`) using a real task as the anchor, plus a "where to go next" entry-point map for `/triage`, `/brainstorm`, `/sanitise`, and `/design-capture`.
- README **Updating** section — documents `update.sh` flags, curl-pipe-bash usage, and the silent-overwrite-then-prune model.

### Security

- `update.sh` validates every manifest entry against `^(commands|agents)/[A-Za-z0-9._-]+\.md$` before any `rm` operation. A tampered or hand-edited `.workshop-manifest` containing `..` segments or absolute paths is rejected outright and logged — it cannot be coerced into deleting files outside the install target.

## [0.1.0] — initial public release

The first version intended for public consumption. Nine slash commands and three agents.

### Skills

- `/init-workshop` — bootstrap the folder convention into any project; updates `CLAUDE.md` with a workshop-conventions section.
- `/plan` — plan-mode-like behaviour, persists the approved plan to `docs/plans/<slug>.md` with research back-links.
- `/solution` — capture or advance a solution doc through `decided` → `in-progress` → `outcome`; supports update-in-place semantics per stage.
- `/research` — pull source material from Jira, Confluence, a web URL, a file, or pasted text into structured `### Insight:` blocks under `docs/research/`.
- `/sanitise` — hybrid denylist + LLM pre-publish gate; auto-fixes known matches, prompts on novel ones, audits to `docs/solutions/`.
- `/design-capture` — surface design drift in an existing frontend, validate a synthesised system with the user, write `DESIGN.md`.
- `/brainstorm` — four-lens ideation (user, ops, scope, risk) grounded in `docs/research/`; surfaces tensions explicitly.
- `/triage` — sweep `todos/`, unresolved PR review threads, and (if configured) the Jira queue; rank top moves by cost/value/decay.
- `/changelog` — synthesise a release narrative from recent `main` merges, enriching each with the matching PR body (via `gh`) and `docs/plans/<slug>.md` if present. Writes under a dated heading in `docs/changelog.md`.

### Agents

- `code-archaeologist` — read-only investigator that traces a feature, function, or symbol across the codebase.
- `decision-distiller` — distils messy multi-thread discussion into ADR-shaped markdown with citations and preserved dissent.
- `pr-reviewer` — independent diff reviewer using a fixed five-dimension rubric, grouped by must-fix / should-fix / follow-up.

### Install

- `install.sh` with `--user` (default) and `--project` scopes; supports curl-pipe-bash.
