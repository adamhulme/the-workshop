# Changelog

All notable changes to **the-workshop** are tracked here. Format inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

The version in [`VERSION`](VERSION) is the version `install.sh` and `update.sh` will write into a user's manifest. Bump it in the same commit that adds the corresponding entry below, then tag (`git tag v<version> && git push --tags`) when cutting a release.

Versioning convention:

- **patch** (`0.1.0` → `0.1.1`) — wording fixes, internal hardening of an existing skill, no behaviour change a user would notice.
- **minor** (`0.1.0` → `0.2.0`) — new skill or agent, visible behaviour change to an existing skill, new degradation path.
- **major** (`0.x` → `1.0.0`, `1.x` → `2.0.0`) — install layout change, removed/renamed skills, anything that requires a user to read release notes.

A bump is reserved until the next release; in-progress work lives under `[Unreleased]`.

## [Unreleased]

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
