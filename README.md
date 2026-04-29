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
- **Lifecycle-split folders.** `docs/` for finished, `drafts/` for in-flight. The article doesn't draw this line.
- **Ships as runnable code.** Every recommendation maps to a file you can install.

## The folder convention

Adopt this layout in any project where you want the workshop's discipline:

```
project/
├── CLAUDE.md             # agent instructions, preferences, patterns
├── docs/                 # FINISHED — crystallised artifacts
│   ├── solutions/        # solved problems → institutional knowledge
│   ├── plans/            # approved plans (post-ExitPlanMode)
│   └── changelog.md      # /changelog output
├── drafts/               # IN-FLIGHT — work-in-progress thinking
│   ├── research/         # discovery
│   └── brainstorms/      # ideation
└── todos/                # triage findings, follow-ups
```

**The lifecycle rule.** `drafts/` holds in-flight thinking. Once an artifact crystallises — decision made, problem solved, plan approved — it moves into `docs/`, possibly with a name change. Skills know which bucket to write to; you, as the human, know where to look.

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

- `/research` — open a discovery file in `drafts/research/`
- `/brainstorm` — structured ideation into `drafts/brainstorms/`
- `/plan` — wraps Claude Code plan mode and lands the result in `docs/plans/`
- `/solution` — promote a finished bug fix or feature into `docs/solutions/` for institutional memory
- `/triage` — sweep `todos/` and surface what to do next

These ship when they earn their place — when the workflow has been used enough times to know what the skill should do.

## License

MIT. See [LICENSE](LICENSE).
