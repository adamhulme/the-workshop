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

Long-form interview transcripts get converted (manually via the Atlassian Rovo connector, or via a future synthesis skill) into a structured AI-friendly format:

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
| [`/changelog`](commands/changelog.md) | Synthesise an engaging changelog from recent merges to `main`. Writes to `docs/changelog.md`. |

## Install

Slash commands in this repo are plain markdown. Drop them into your Claude Code commands directory.

**Mac / Linux** — copy into your user-scoped commands folder:

```bash
cp commands/changelog.md ~/.claude/commands/
```

**Windows** — copy into your user-scoped commands folder:

```powershell
Copy-Item commands\changelog.md $env:USERPROFILE\.claude\commands\
```

**Project-scoped** — install only for the current repo:

```bash
mkdir -p .claude/commands && cp commands/changelog.md .claude/commands/
```

Restart Claude Code. The command appears in your `/` autocomplete.

## Roadmap (loose)

- `/research` — synthesise product context (markets, competitors, prior art) into `docs/research/context/`
- `/brainstorm` — structured ideation into `docs/brainstorms/`, pulling from `docs/research/`
- `/plan` — wraps Claude Code plan mode and lands the result in `docs/plans/`
- `/solution` — promote a finished bug fix or feature into `docs/solutions/` for institutional memory
- `/triage` — sweep `todos/` and surface what to do next

These ship when they earn their place — when the workflow has been used enough times to know what the skill should do.

## License

MIT. See [LICENSE](LICENSE).
