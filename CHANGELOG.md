# Changelog

All notable changes to **the-workshop** are tracked here. Format inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

The version in [`VERSION`](VERSION) is the version `install.sh` and `update.sh` will write into a user's manifest. Bump it in the same commit that adds the corresponding entry below, then tag (`git tag v<version> && git push --tags`) when cutting a release.

Versioning convention:

- **patch** (`0.1.0` → `0.1.1`) — wording fixes, internal hardening of an existing skill, no behaviour change a user would notice.
- **minor** (`0.1.0` → `0.2.0`) — new skill or agent, visible behaviour change to an existing skill, new degradation path.
- **major** (`0.x` → `1.0.0`, `1.x` → `2.0.0`) — install layout change, removed/renamed skills, anything that requires a user to read release notes.

A bump is reserved until the next release; in-progress work lives under `[Unreleased]`.

## [Unreleased]

### Added

- `update.sh` — pulls the latest commands and agents and prunes any that have been removed upstream, using a manifest written by `install.sh` at install time. Same `--user`/`--project` flags as `install.sh`.
- `install.sh` now writes `.workshop-manifest` and `.workshop-version` into the install target so `update.sh` can diff and prune cleanly without touching skills the workshop didn't install.
- `VERSION` and `CHANGELOG.md` at the repo root. The version is echoed at the end of `install.sh` and `update.sh`.

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
- `/changelog` — synthesise a release narrative from recent merges and `outcome` solution docs into `docs/changelog.md`.

### Agents

- `code-archaeologist` — read-only investigator that traces a feature, function, or symbol across the codebase.
- `decision-distiller` — distils messy multi-thread discussion into ADR-shaped markdown with citations and preserved dissent.
- `pr-reviewer` — independent diff reviewer using a fixed five-dimension rubric, grouped by must-fix / should-fix / follow-up.

### Install

- `install.sh` with `--user` (default) and `--project` scopes; supports curl-pipe-bash.
