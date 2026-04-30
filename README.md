# the-workshop

> My personal touch on Compound Engineering — Claude Code skills and folder conventions so every task leaves an artifact that compounds.

## What this is

An opinionated, harness-aware playbook for [Compound Engineering](https://every.to/guides/compound-engineering). It picks Claude Code as the runtime, commits to a folder convention for compounding artifacts, and ships those conventions as runnable slash commands you can copy in and use today.

## What this isn't

- A tool-agnostic manifesto. It picks Claude Code and goes.
- An exhaustive framework. It ships what's lived-in; new skills land as the practice produces them.
- A community project. It's a personal canon. Fork freely.

## Credit and departure

The seed comes from Every's [Compound Engineering guide](https://every.to/guides/compound-engineering). What's kept:

- Every meaningful task should leave an artifact.
- The system gets better over time because each artifact is fuel for the next task.
- Engineering is partly building your own tools — not just shipping features.

What's different here:

- **Harness-opinionated.** Built around Claude Code's slash commands and skills.
- **Inputs get equal treatment.** A dedicated `docs/research/` subtree for source material — interviews, product context — with a structured format. The article focuses on outputs.
- **Ships as runnable code.** Every recommendation maps to a file you can install.

## Install

Clone the repo and run the installer:

```bash
git clone https://github.com/adamhulme/the-workshop.git
cd the-workshop
./install.sh                # user-scoped → ~/.claude/{commands,agents}/
./install.sh --project      # project-scoped → ./.claude/{commands,agents}/
```

Requires `bash` and `git`. On Windows, run from Git Bash or WSL. Restart Claude Code after install — commands appear in your `/` autocomplete; agents become dispatchable via the Agent tool.

`install.sh` writes a manifest (`.workshop-manifest`) and a version file (`.workshop-version`) into the install target so that `update.sh` can later diff cleanly against upstream and prune skills the workshop has removed.

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

The agents (`code-archaeologist`, `decision-distiller`, `pr-reviewer`) are dispatchable from any skill via the Agent tool, or directly when you want a focused second pass. They're not auto-invoked by the shipped skills today — pair them with the skills above as the workflow calls for it (e.g. dispatch `decision-distiller` over a long PR thread before drafting the matching `/solution`, or run `pr-reviewer` against a diff before merging).

## Updating

Pull the latest skills with `update.sh`:

```bash
./update.sh                # auto-detects user vs project from the manifest
./update.sh --user
./update.sh --project
```

Or via curl-pipe-bash from anywhere:

```bash
curl -fsSL https://raw.githubusercontent.com/adamhulme/the-workshop/main/update.sh | bash
```

What it does:

- **Always shallow-clones the latest `main` from origin** into a temp dir before installing — even when run from a local clone. A stale checkout never reinstalls itself. (If you want to install from a local checkout, run `install.sh` directly.)
- Overwrites installed skill files (silent overwrite — if you've edited a skill locally, fork it before updating).
- Diffs the previous manifest against the new one and **prunes** any skill that was installed by an earlier release but is no longer shipped. Manifest entries are validated against the expected `commands/*.md` or `agents/*.md` shape before any `rm`; anything outside that shape is logged and skipped, so a tampered manifest cannot be coerced into deleting files outside the install target. Files the workshop never installed are left alone.
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

## Skills shipped

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

## Agents shipped

| Agent | What it does |
|-------|--------------|
| [`code-archaeologist`](agents/code-archaeologist.md) | Read-only investigator. Traces a feature, function, or symbol across the codebase: where it's defined, where it's called, what depends on it, who introduced it, what caveats exist. Does not propose changes. Useful from any skill that needs to ground itself in current code reality. |
| [`decision-distiller`](agents/decision-distiller.md) | Distils messy multi-thread discussion (PR threads, meeting notes, Jira/Confluence pages, transcripts) into ADR-shaped markdown — the question, options considered, trade-offs, chosen path, dissenting views. Cites every claim. Pairs well with `/solution` and `/brainstorm` — dispatchable from any skill, or directly from your own review of a long discussion. |
| [`pr-reviewer`](agents/pr-reviewer.md) | Independent diff reviewer using a fixed rubric: correctness, scope drift, test coverage, risk-to-revert, follow-up cleanup. Groups findings by 'must fix before merge / should fix in this PR / follow-up'. Direct rather than diplomatic. |

## Roadmap

The initial roadmap shipped. Future skills land here as the practice produces them — when a workflow has been used enough times to know what its skill should do.

## License

MIT. See [LICENSE](LICENSE).
