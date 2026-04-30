---
description: Set up the workshop's folder convention in a project, asking before each addition
---

Bootstrap a project to use the workshop's compounding-artefact layout: `docs/research/`, `docs/brainstorms/`, `docs/plans/`, `docs/solutions/`, `docs/changelog.md`, `todos/`, plus a `CLAUDE.md` section pointing future agents at the right places.

User arguments: $ARGUMENTS

## Steps

1. **Confirm git context.** Run `git rev-parse --show-toplevel` to find the repo root. If not in a git repo, respond: "Not in a git repository — /init-workshop bootstraps a project layout, which needs a repo root." Stop here. All subsequent paths are relative to the repo root.

2. **Ask before creating the docs subtree.** Prompt: `Create docs/research/{interviews,context}/, docs/brainstorms/, docs/plans/, docs/solutions/? (y/n)`. On `y`, run `mkdir -p` for each. Skip silently for any that already exist.

3. **Ask before creating todos/.** Prompt: `Create todos/ for triage findings and follow-ups? (y/n)`. On `y`, `mkdir -p todos`.

4. **Ask before creating docs/changelog.md.** Prompt: `Create docs/changelog.md (used by /changelog)? (y/n)`. On `y`, ensure the parent `docs/` directory exists first (`mkdir -p docs`) — this matters when the user declined the docs subtree in step 2 but still wants a changelog. Then write the file with a single line: `# Changelog`. If it already exists, skip silently.

5. **Update CLAUDE.md.**
   - If `CLAUDE.md` does not exist: prompt `No CLAUDE.md found — create one with the workshop conventions section? (y/n)`. On `y`, create the file containing only the section in step 5b.
   - If `CLAUDE.md` exists and already contains a `## Workshop conventions` heading: prompt `CLAUDE.md already has a workshop section — overwrite it, skip, or append a dated note? (o/s/a)`.
   - Otherwise: prompt `Append a 'Workshop conventions' section to CLAUDE.md? (y/n)`.
   - On confirmation, append (or replace) this section verbatim:

   ```markdown
   ## Workshop conventions

   This project uses [the workshop's](https://github.com/adamhulme/the-workshop) folder convention for compounding artefacts:

   - `docs/research/` — source material (interviews, context, prior art). Use `/research` to add.
   - `docs/brainstorms/` — multi-perspective ideation. Use `/brainstorm`.
   - `docs/plans/` — approved plans (post-ExitPlanMode). Use `/plan`.
   - `docs/solutions/` — decision → execution → outcome docs. Use `/solution`.
   - `docs/changelog.md` — synthesised release narrative. Use `/changelog`.
   - `todos/` — triage findings and follow-ups. Use `/triage`.

   Write artefacts to these locations rather than scattering them. Prefer the workshop skills above to populate them.
   ```

6. **Report.** Print a summary of what was created, what was skipped, and the suggested next step: "Try `/plan <task>` to capture your first plan, or `/solution <slug>` to capture an existing decision."

## Degradations

- **Not in a git repo** → step 1 abort.
- **CLAUDE.md unwritable (permission denied, etc)** → skip step 5 with a warning, finish the rest.
- **User answers `n` to everything** → step 6 still runs, reports zero additions.
