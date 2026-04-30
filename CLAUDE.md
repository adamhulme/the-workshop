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
