## Workshop conventions

This project uses [the workshop's](https://github.com/adamhulme/the-workshop) folder convention for compounding artefacts:

- `docs/research/` — source material (interviews, context, prior art). Use `/research` to add.
- `docs/brainstorms/` — multi-perspective ideation. Use `/brainstorm`.
- `docs/plans/` — approved plans (post-ExitPlanMode). Use `/plan`.
- `docs/solutions/` — decision → execution → outcome docs. Use `/solution`.
- `docs/changelog.md` — synthesised release narrative. Use `/changelog`.
- `todos/` — triage findings and follow-ups. Use `/triage`.

Write artefacts to these locations rather than scattering them. Prefer the workshop skills above to populate them.

## Team consultation (optional)

Projects can scaffold a six-persona consultation team via `/team-init` and consult it via `/consult <question>`. Personas live at `teams/<slug>/` (or an umbrella path); `team.yaml` controls speaking order and decision protocol. `/plan-eng-review` and `/plan-design-review` provide single-perspective plan critique without needing a team.

## Coding philosophy

The workshop ships opinionated tools, written in opinionated style. When writing or reviewing code in this repo:

- **Simplest fit wins.** Solutions match the scope. If three lines work, don't write thirty. No premature abstractions, no design for hypothetical futures. Three similar lines beat a clever generaliser.
- **Readability over cleverness.** Names should make comments unnecessary. Comments are for **why** — hidden constraints, non-obvious decisions, surprising behaviour. Not for what the code does; well-named identifiers already say that. Don't reference the current task or commit ("added for the X flow") — that belongs in the PR description and rots over time.
- **Edit before adding.** Prefer modifying existing files over creating new ones. New files only when an existing one truly doesn't fit. Skills live as single Markdown files for a reason.
- **Stay in scope.** A bug fix is a bug fix; a new skill is a new skill. Don't bundle drive-by refactors. One idea per change. If you spot something else worth fixing, drop it in `TODOS.md` and move on.
- **Decision points use `AskUserQuestion`.** Trailing prose `(y/n)` prompts get buried under whatever the model just wrote. Surface gates as structured questions; users can type custom answers via the auto-provided "Other" option.
- **Don't add what wasn't asked.** No defensive error handling for cases that can't happen. No backwards-compat shims for code nothing depends on. Trust internal callers and framework guarantees; only validate at real boundaries (user input, external APIs).

## Token efficiency

These directives reduce context window consumption without losing technical accuracy. Use `/grunt` to activate full terse mode.

- **Reference, don't paste.** Never quote code blocks back in responses — reference by `path:line` instead. The user has the file open; redundant quoting wastes context tokens.
- **Grep before you read.** Before reading an entire file, grep for the target symbol or pattern first, then read only the relevant line range with `offset`/`limit`. A 2000-line full read costs ~8K tokens; a 50-line targeted read costs ~200.
- **Trim tool output.** When running shell commands, pipe through `head`, `tail`, or `grep` to keep only what's needed. Prefer `git log --oneline` over `git log`, `find ... | head -20` over unbounded `find`.

## Learned principles

Principles and prevention strategies extracted from shipped work. Each links to its source solution. `/solution` prompts for extraction at the outcome stage — asking what worked, what didn't, and whether the system would catch it next time.

<!-- Add new principles above this line. -->
