# the-workshop

> My personal touch on Compound Engineering — shared workshop conventions plus Claude Code and Codex adapters so every task leaves an artifact that compounds.

## What this is

An opinionated, harness-aware playbook for [Compound Engineering](https://every.to/guides/compound-engineering). The durable doctrine now lives in runtime-neutral `core/` specs, with Claude Code adapters in `commands/` and `agents/`, and Codex adapters in `codex/skills/` and `codex/agents/`.

## What this isn't

- A lowest-common-denominator prompt dump. The core doctrine is shared, but each runtime keeps native adapters instead of pretending Claude and Codex have identical mechanics.
- An exhaustive framework. It ships what's lived-in; new skills land as the practice produces them.
- A community project. It's a personal canon. Fork freely.

## Install

Clone the repo and run the installer:

```bash
git clone https://github.com/adamhulme/the-workshop.git
cd the-workshop
./install.sh                         # Claude user scope → ~/.claude/{commands,agents,hooks}/
./install.sh --project               # Claude project scope → ./.claude/{commands,agents,hooks}/
./install.sh --with-codex-plugin     # Claude user scope + OpenAI's Codex companion plugin
./install.sh --project --with-codex-plugin # project-scoped Claude tools + plugin
./install.sh --codex                 # Codex user scope → ~/.codex/the-workshop/
./install.sh --project --codex       # Codex project scope → ./.codex/the-workshop/
./install.sh --both                  # install both runtime adapters
```

Requires `bash` and `git`. On Windows, run from Git Bash or WSL. `--with-codex-plugin` additionally requires the `claude` CLI; the plugin itself requires Node.js 18.18+ and a local Codex login. Restart Claude Code after installing the Claude adapter — commands appear in your `/` autocomplete; agents become dispatchable via the Agent tool. After the plugin install, run `/reload-plugins` and `/codex:setup`. Point Codex sessions at the installed `WORKSHOP.md`, `skills/`, `agents/`, and `core/` directories for the Codex adapter.

`install.sh` writes a manifest (`.workshop-manifest`) and a version file (`.workshop-version`) into each runtime install target so that `update.sh` can later diff cleanly against upstream and prune files that runtime adapter has removed.

`--with-codex-plugin` is an explicit trust decision: it registers the official `openai/codex-plugin-cc` marketplace and tracks its latest published plugin version rather than pinning a commit. The installer verifies the marketplace source before installing or updating. To remove the external state later, use the same scope you installed with:

```bash
claude plugin uninstall codex@openai-codex --scope user      # or: project
claude plugin marketplace remove openai-codex --scope user   # or: project
```

Reverting this repository does not uninstall an already-registered Claude plugin or marketplace.


## Runtime support model

| Layer | Path | Purpose | Runtime coupling |
|-------|------|---------|------------------|
| Shared canon | [`core/`](core/) and [`WORKSHOP.md`](WORKSHOP.md) | Artifact conventions, workflow contracts, and reviewer rubrics | Runtime-neutral |
| Claude adapter | [`commands/`](commands/), [`agents/`](agents/), [`CLAUDE.md`](CLAUDE.md) | Claude Code slash commands, agent frontmatter, hooks, and `.claude` install layout | Claude-native |
| Codex adapter | [`codex/skills/`](codex/skills/), [`codex/agents/`](codex/agents/) | Codex-friendly task playbooks and reviewer roles derived from the shared canon | Codex-native |

The migration strategy is deliberately hybrid: shared ideas live once in `core/`, while orchestration-heavy workflows get native Claude and Codex adapters. Avoid adding new cross-runtime doctrine directly to `commands/` or `codex/`; put it in `core/` first, then adapt it.

## Optional integrations

The workshop runs without any of these. Each one unlocks a specific capability — the affected skills degrade gracefully (with a one-line note) when the integration isn't present.

| Integration | What unlocks | Used by |
|-------------|--------------|---------|
| [**OpenAI Codex plugin for Claude Code**](https://github.com/openai/codex-plugin-cc) | Native `/codex:*` commands, background jobs, session transfer, and a managed Codex rescue agent. Install with `./install.sh --with-codex-plugin`. | Preferred Codex path for `/plan-eng-review`, `/plan-design-review`, `/review-pr`, and `/auto-do` |
| [**Codex CLI**](https://github.com/openai/codex) on `PATH` | Direct cross-model fallback when the Claude plugin is not installed. | `/plan-eng-review`, `/plan-design-review`, `/review-pr`, `/auto-do` |
| [**Atlassian MCP**](https://www.atlassian.com/platform/remote-mcp-server) configured in Claude Code | Pull Jira issues / Confluence pages directly into research, sweep your Jira queue. Skills prompt for paste-in fallback if missing. | `/research` (Jira ID, Confluence URL/ID), `/triage` (Jira queue sweep) |
| **`gh` CLI** authenticated | Read PR titles/bodies and unresolved review threads on the current branch. Skills skip the relevant pass if missing. | `/triage` (PR-comment sweep), `/changelog` (PR enrichment) |
| [**Playwright MCP**](https://github.com/microsoft/playwright-mcp) (or Chrome DevTools MCP) configured in Claude Code | Drive a visible browser to verify changes or walk a user flow. Without it, `/browse` prints a setup snippet and exits. | `/browse` (headed sessions, `--setup` for credential storage state) |

None are hard dependencies. For Claude-side Codex work, the workshop prefers the official plugin's `codex:codex-rescue` agent, then the direct Codex CLI, then a clearly labelled Claude `general-purpose` fallback. Plugin setup/auth failures are surfaced instead of silently changing models. Codex adapter files should map the same workflow intent onto whatever connectors are available in a Codex session. Install the integrations that match your workflow.

## Starter guide — your first run

A short tour of the compounding loop in a project you actually work on. Pick a small real task to anchor it; the artefacts you generate become reusable context for the next time you sit down.

### 1. Bootstrap the folders

In a Claude Code session, in the project root:

```
/init-workshop
```

Asks before each addition. Creates `docs/research/{interviews,context}/`, `docs/brainstorms/`, `docs/plans/`, `docs/solutions/`, `docs/changelog.md`, and `todos/`, then adds a `## Workshop conventions` section to `CLAUDE.md` so future agents know where to write.

### 2. Capture some context

Pull in a real input — a Jira ticket, a Confluence page, a blog post, or paste freeform notes when prompted:

```
/research PROJ-1234
/research https://example.com/article
/research                    # empty → paste text inline
```

Lands at `docs/research/context/<slug>.md` (or `interviews/<participant-slug>.md` with `--type=interview`) as a structured set of `### Insight:` blocks. Future skills read these without you re-pasting context every session.

### 3. Plan a real task

Pick a piece of work you'd actually do this week:

```
/plan Add a queue-depth metric to the worker dashboard
```

Drafts a plan in plan-mode-like behaviour, asks clarifying questions, persists to `docs/plans/<slug>.md` on approval. If any `docs/research/` files share keywords with the task, they're back-linked automatically.

### 4. Capture the decision as work progresses

When you start implementing — even partially:

```
/solution queue-depth-metric
```

Walks the doc through `decided` → `in-progress` → `outcome` over time. One file per piece of work; status tracked in frontmatter. Re-run as the work progresses to advance the stage or update the current stage in place.

### 5. See the loop close

After a few PRs have merged into `main`:

```
/changelog
```

Reads recent merges from `git log`, enriches each with the matching PR body (via `gh`) and any matching `docs/plans/<slug>.md`, then synthesises a release-shaped narrative under a dated heading in `docs/changelog.md`. Now the next person (or the next you) opens the repo and the trail is right there.

A natural pairing: when a `/solution` reaches `outcome`, also run `/changelog` so the narrative trail catches up.

### Where to go next

- **Stuck on what to do next?** `/triage` sweeps `todos/`, unresolved PR review threads on the current branch, and (if the Atlassian MCP is configured) your Jira queue. Categorises and ranks the top three moves.
- **Thorny multi-perspective decision?** `/brainstorm <topic>` runs four fixed lenses (user, ops, scope, risk) over the topic, grounded in any matching `docs/research/` files, and surfaces tensions explicitly.
- **About to flip a private repo public?** `/sanitise` does a denylist + LLM pass for client/internal references, auto-fixes known matches, prompts on novel ones, and audits the run to `docs/solutions/`.
- **Auditing an existing app's design?** `/design-capture` reads the frontend, surfaces inconsistencies against a synthesised system, validates the recommended approach with you, and writes `DESIGN.md`.
- **Want a six-perspective sanity check?** `/team-init` scaffolds a consultation team into the project (product, user, domain, architecture, risk, delivery). `/consult <question>` then dispatches all six personas in parallel and surfaces tensions. Pair with `/plan-eng-review` or `/plan-design-review` for single-perspective plan critique.
- **Reviewing a PR?** `/review-pr <n>` runs Codex and the `pr-reviewer` agent in parallel, consolidates findings, addresses must-fix items as a single fix-up commit, then runs one Codex re-review on the new diff. Hard cap at 2 rounds. Fix-up commits auto-push to the PR's head branch.
- **Want Claude to drive a real browser to verify a UI change?** `/browse <url> <scenario>` orchestrates Playwright MCP (or Chrome DevTools MCP) in headed mode, captures screenshots, and writes the session to `docs/research/interviews/<slug>.md`. First time on an auth-gated app, run `/browse --setup <login-url>` once — Playwright's `storageState` is persisted to `.claude/browse/storage-state.json` (gitignored) and reused on every subsequent run.
- **Have a known-shape task and want it run end-to-end without prompts?** `/auto-do <task>` chains `/plan` → `/plan-eng-review` (and `/plan-design-review` when UI scope is touched) → implementation → `/solution` → PR creation → `/browse` verification (when applicable) → `/review-pr`, applying a documented auto-decision policy at every gate. Creates and reviews a PR but never merges. Every default decision is logged in the PR body for auditing.
- **Have a task too large for one PR?** `/auto-fleet <slug> [--max-parallel=N]` reads a user-authored manifest at `docs/fleet/<slug>.md` and dispatches `/auto-do` per row in **parallel waves** (v1: default 3 concurrent, ceiling 5; cap of 10 queued rows). Each row runs in its own git worktree. Use the `depends_on` column to declare dispatch-ordering deps (cascade-block on failure: dependents become `blocked` when a parent fails; other branches continue). The fleet's own commits land on a `fleet/<slug>` control-plane branch the user creates off the default branch before invoking. Subtask PRs target the default branch independently. ⚠ **Deps are dispatch-ordering only** — children's branches don't contain parent code (parents aren't merged when children dispatch). v1 ships against the contract that `/auto-do` runs in a fresh checkout (no `.env` / `node_modules` carried into worktrees).

The agents (`code-archaeologist`, `decision-distiller`, `pr-reviewer`) are dispatchable from any skill via the Agent tool, or directly when you want a focused second pass. They're not auto-invoked by the shipped skills today — pair them with the skills above as the workflow calls for it (e.g. dispatch `decision-distiller` over a long PR thread before drafting the matching `/solution`, or run `pr-reviewer` against a diff before merging).

## Updating

Pull the latest skills with `update.sh`:

```bash
./update.sh                # auto-detects user vs project from the manifest
./update.sh --user
./update.sh --project
./update.sh --with-codex-plugin # also install/update the Claude Code Codex plugin
```

Or via curl-pipe-bash from anywhere:

```bash
curl -fsSL https://raw.githubusercontent.com/adamhulme/the-workshop/main/update.sh | bash
```

What it does:

- **Always shallow-clones the latest `main` from origin** into a temp dir before installing — even when run from a local clone. A stale checkout never reinstalls itself. (If you want to install from a local checkout, run `install.sh` directly.)
- Overwrites installed skill files (silent overwrite — if you've edited a skill locally, fork it before updating).
- Diffs the previous manifest against the new one and **prunes** any file that was installed by an earlier release but is no longer shipped. Manifest entries are validated against the expected shape for the runtime being updated — `commands/*.md`/`agents/*.md`/`hooks/*.sh` for Claude, `skills/*.md`/`agents/*.md`/`core/**/*.md`/`WORKSHOP.md` for Codex — before any `rm`, rejecting `.`/`..` path segments so a tampered manifest cannot be coerced into deleting files outside the install target. Files the workshop never installed are left alone.
- Reports the version transition (`Update complete: 0.1.0 → 0.2.0 (user scope).`).

See [CHANGELOG.md](CHANGELOG.md) for what changed in each release. The current version is in [VERSION](VERSION).

## The folder convention

Adopt this layout in any project where you want the workshop's discipline:

```
project/
├── CLAUDE.md             # agent instructions, preferences, patterns
├── docs/                 # every artifact lives here, sorted by type
│   ├── research/         # source material that fuels future work
│   │   ├── interviews/   # structured customer interview notes
│   │   └── context/      # product context, market and competitor notes
│   ├── brainstorms/      # ideation
│   ├── plans/            # approved plans (post-ExitPlanMode)
│   ├── solutions/        # solved problems → institutional knowledge
│   └── changelog.md      # /changelog output
└── todos/                # triage findings, follow-ups
```

**The flow.** Research feeds brainstorms. Brainstorms harden into plans. Plans execute into solutions. Solutions get summarised in the changelog. Each layer has its own folder so you (and any skill) know exactly where to look — or where to write.

## Recommended formats

### Customer interviews → `docs/research/interviews/<participant-id>.md`

Long-form interview transcripts get converted (manually, or via [`/research`](commands/research.md)) into a structured AI-friendly format:

````markdown
---
participant: Marketing Manager, B2B SaaS
date: 2026-01-15
focus: Dashboard usage patterns
---

## Key Insights

### Insight: Morning dashboard ritual
**Quote**: "First thing every morning, I check for red flags."
**Implication**: Dashboard needs to surface problems quickly.
**Confidence**: 4/5 participants
````

Why this shape: future skills (synthesis, brainstorming) can scan many interviews and pull structured `### Insight:` blocks without parsing prose. Frontmatter makes filtering by participant or focus area trivial.

## Claude skills shipped

| Command | What it does |
|---------|--------------|
| [`/init-workshop`](commands/init-workshop.md) | Set up the workshop's folder convention in any project, asking before each addition. Updates `CLAUDE.md` so future agents know where to write. |
| [`/plan`](commands/plan.md) | Develop a plan in plan-mode-like behaviour, then persist the approved result to `docs/plans/<slug>.md` with frontmatter and back-links. |
| [`/solution`](commands/solution.md) | Capture or advance a solution doc through `decided` → `in-progress` → `outcome`. One file per piece of work, status tracked in frontmatter. |
| [`/research`](commands/research.md) | Pull source material from Jira, Confluence, a web URL, a file, or pasted text. Synthesise into structured `### Insight:` blocks under `docs/research/`. |
| [`/sanitise`](commands/sanitise.md) | Pre-publish gate. Hybrid denylist + LLM scan for client/internal references; auto-fixes known matches, prompts on novel ones. Audit trail to `docs/solutions/`. |
| [`/design-capture`](commands/design-capture.md) | Read an existing app's frontend, surface design inconsistencies, validate the recommended approach with the user, write `DESIGN.md`. |
| [`/brainstorm`](commands/brainstorm.md) | Multi-perspective ideation across four fixed lenses (user, ops, scope, risk). Pulls relevant `docs/research/` files first; surfaces tensions explicitly. |
| [`/triage`](commands/triage.md) | Sweep `todos/`, open PR comments, and (if available) the Jira queue. Categorise, rank by leverage, surface the top three moves. |
| [`/changelog`](commands/changelog.md) | Synthesise an engaging changelog from recent merges to `main`. Writes to `docs/changelog.md`. |
| [`/team-init`](commands/team-init.md) | Scaffold a six-persona consultation team (product-strategist, user-advocate, domain-specialist, technical-architect, quality-risk, delivery-lead) into the project, filled from a project-context questionnaire. |
| [`/consult`](commands/consult.md) | Multi-perspective consultation with the project's persona team — surfaces disagreements, runs targeted rebuttals, synthesises with tensions preserved. |
| [`/plan-eng-review`](commands/plan-eng-review.md) | Engineering-manager-mode plan critique covering scope, architecture, code quality, tests, and performance — with an optional independent Codex second opinion through the official plugin or CLI fallback. |
| [`/plan-design-review`](commands/plan-design-review.md) | Designer's-eye plan critique scoring eight design dimensions 0–10, surfacing gaps and AI-slop patterns — with an optional adversarial Codex outside voice through the official plugin or CLI fallback. |
| [`/review-pr`](commands/review-pr.md) | Bounded 2-round PR review loop. Codex (official plugin preferred, CLI fallback) and the `pr-reviewer` agent trade reviewer/implementer roles; round 1 in parallel, round 2 swap. Hard cap at 2 rounds. Fix-up commits **auto-push** to the PR branch (never to default branch, never `--force`). |
| [`/browse`](commands/browse.md) | Drive a visible browser via Playwright MCP (or Chrome DevTools MCP) so the user can watch Claude verify a change or walk a flow; capture the session as a structured research note plus screenshots under `docs/research/interviews/<slug>(-screenshots)/`. `--setup` mode persists Playwright `storageState` to `.claude/browse/storage-state.json` (gitignored) for one-shot login on auth-gated apps. Read-only by default; destructive actions gated per-step. **Naming caveat:** collides with gstack's `browse` skill — install with `--project` scope or rename locally if both are present. |
| [`/auto-do`](commands/auto-do.md) | Autonomous task runner. Chains `/plan` → `/plan-eng-review` (+ `/plan-design-review` when UI is touched) → implementation → `/solution` → PR creation → `/browse` verification (when applicable) → `/review-pr`, applying a documented auto-decision policy at every gate. Creates and reviews a PR but never merges — the merge gate stays human. Every auto-pick lands in the PR body's `## Auto-decisions` section for auditing. Stops on dirty tree, missing `gh`, complexity smell, test failure, or round-2 must-fix (PR converted to draft). |
| [`/auto-fleet`](commands/auto-fleet.md) | Autonomous fleet runner. Reads a user-authored manifest at `docs/fleet/<slug>.md` and dispatches `/auto-do` per row in **parallel waves** (v1: `--max-parallel=N`, default 3, ceiling 5). Each row runs in its own git worktree at `.claude/auto-fleet/wt-<slug>-<id>/`. **Declared dependencies** (`depends_on` column) are dispatch-ordering only — children's branches are created off the default branch's pinned SHA, NOT off parent branches; if your task needs parent code in the child, split into multiple sequential fleets or wait for v2's epic-branch mode. **Cascade-block** on failure: when a parent fails, its dependents become `blocked`; other parallel branches continue. Hard cap of 10 queued rows per run. Backward-compatible with v0.1 manifests (no `depends_on` column). The fleet branch (`fleet/<slug>`) is a control plane that holds only the manifest and is never merged; subtask PRs target the default branch independently. SHA-256 hash check halts cleanly if the manifest is edited externally during a run. Failed-row worktrees preserved on disk for debugging. **v1 contract**: `/auto-do` must be runnable in a fresh checkout of the default branch (worktrees inherit only tracked files; no `.env` / `node_modules` / virtualenvs). |

## Claude agents shipped

| Agent | What it does |
|-------|--------------|
| [`code-archaeologist`](agents/code-archaeologist.md) | Read-only investigator. Traces a feature, function, or symbol across the codebase: where it's defined, where it's called, what depends on it, who introduced it, what caveats exist. Does not propose changes. Useful from any skill that needs to ground itself in current code reality. |
| [`decision-distiller`](agents/decision-distiller.md) | Distils messy multi-thread discussion (PR threads, meeting notes, Jira/Confluence pages, transcripts) into ADR-shaped markdown — the question, options considered, trade-offs, chosen path, dissenting views. Cites every claim. Pairs well with `/solution` and `/brainstorm` — dispatchable from any skill, or directly from your own review of a long discussion. |
| [`pr-reviewer`](agents/pr-reviewer.md) | Independent diff reviewer using a fixed rubric: correctness, scope drift, test coverage, risk-to-revert, follow-up cleanup. Groups findings by 'must fix before merge / should fix in this PR / follow-up'. Direct rather than diplomatic. |

## Codex adapter shipped

| Codex path | What it adapts |
|------------|----------------|
| [`codex/skills/plan.md`](codex/skills/plan.md) | Runtime-neutral planning without Claude plan-mode or `AskUserQuestion` mechanics. |
| [`codex/skills/solution.md`](codex/skills/solution.md) | Solution lifecycle capture under `docs/solutions/`. |
| [`codex/skills/research.md`](codex/skills/research.md) | Structured research notes with Codex-available connectors or paste fallback. |
| [`codex/skills/review-pr.md`](codex/skills/review-pr.md) | Codex-native PR review using the shared rubrics. |
| [`codex/skills/auto-do.md`](codex/skills/auto-do.md) | Codex-native autonomous task runner contract. |
| [`codex/skills/auto-fleet.md`](codex/skills/auto-fleet.md) | Codex-native fleet runner contract, to use after Codex `auto-do` is stable. |
| [`codex/skills/browser-verification.md`](codex/skills/browser-verification.md) | Codex-native visible-browser verification and research capture. |
| [`codex/skills/brainstorm.md`](codex/skills/brainstorm.md) | Four-lens ideation, grounded in `docs/research/`. |
| [`codex/skills/changelog.md`](codex/skills/changelog.md) | Changelog synthesis from recent merges. |
| [`codex/skills/consult.md`](codex/skills/consult.md) | Persona-team consultation with surfaced disagreement. |
| [`codex/skills/design-capture.md`](codex/skills/design-capture.md) | Existing-app design system capture into `DESIGN.md`. |
| [`codex/skills/sanitise.md`](codex/skills/sanitise.md) | Pre-publish denylist + LLM scan for client/internal references. |
| [`codex/skills/triage.md`](codex/skills/triage.md) | Inbox sweep (`todos/`, PR comments, issue tracker) ranked by leverage. |
| [`codex/agents/`](codex/agents/) | Codex reviewer and investigator roles backed by `core/rubrics/`. |

## Compatibility matrix

See [`core/workflows/compatibility-matrix.md`](core/workflows/compatibility-matrix.md) for the per-workflow migration class: portable, adapter-required, native-rewrite, or personal-template.

## Credit and departure

The seed comes from Every's [Compound Engineering guide](https://every.to/guides/compound-engineering). What's kept:

- Every meaningful task should leave an artifact.
- The system gets better over time because each artifact is fuel for the next task.
- Engineering is partly building your own tools — not just shipping features.

What's different here:

- **Harness-opinionated, not harness-confused.** Shared doctrine is runtime-neutral, while Claude and Codex keep native adapters for their different execution models.
- **Inputs get equal treatment.** A dedicated `docs/research/` subtree for source material — interviews, product context — with a structured format. The article focuses on outputs.
- **Ships as runnable code.** Every recommendation maps to a file you can install.

## License

MIT. See [LICENSE](LICENSE).
