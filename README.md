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
| [`/changelog`](commands/changelog.md) | Synthesise an engaging changelog from recent merges to `main`. Writes to `docs/changelog.md`. |

## Agents shipped

| Agent | What it does |
|-------|--------------|
| [`code-archaeologist`](agents/code-archaeologist.md) | Read-only investigator. Traces a feature, function, or symbol across the codebase: where it's defined, where it's called, what depends on it, who introduced it, what caveats exist. Does not propose changes. Useful from any skill that needs to ground itself in current code reality. |
| [`decision-distiller`](agents/decision-distiller.md) | Distils messy multi-thread discussion (PR threads, meeting notes, Jira/Confluence pages, transcripts) into ADR-shaped markdown — the question, options considered, trade-offs, chosen path, dissenting views. Cites every claim. Used by `/solution` and `/brainstorm`. |

## Install

Clone the repo and run the installer:

```bash
git clone https://github.com/adamhulme/the-workshop.git
cd the-workshop
./install.sh                # user-scoped → ~/.claude/{commands,agents}/
./install.sh --project      # project-scoped → ./.claude/{commands,agents}/
```

Requires `bash` and `git`. On Windows, run from Git Bash or WSL. Restart Claude Code after install — commands appear in your `/` autocomplete; agents become dispatchable via the Agent tool.

## Roadmap (loose)

- `/brainstorm` — multi-perspective ideation across four fixed lenses (user, ops, scope, risk), pulling from `docs/research/`
- `/triage` — sweep `todos/`, open PR comments, and (if available) the Jira queue; rank the top moves
- `pr-reviewer` (agent) — independent diff reviewer using the rubric: correctness, scope drift, test coverage, risk-to-revert, follow-up cleanup

These ship when they earn their place — when the workflow has been used enough times to know what the skill should do.

## License

MIT. See [LICENSE](LICENSE).
