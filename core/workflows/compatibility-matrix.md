# Runtime compatibility matrix

| Workflow | Current file | Class | Codex strategy |
|----------|--------------|-------|----------------|
| Init workshop | `commands/init-workshop.md` | adapter-required | Keep artifact rules shared; add Codex installer/instructions adapter. |
| Plan | `commands/plan.md` | adapter-required | Share plan contract; Codex uses native planning/checkpoints. |
| Solution | `commands/solution.md` | portable | Share lifecycle; write Codex skill directly from core spec. |
| Research | `commands/research.md` | adapter-required | Share artifact format; map connectors per runtime. |
| Sanitise | `commands/sanitise.md` | adapter-required | Generalize denylist path, then add runtime wrapper. |
| Design capture | `commands/design-capture.md` | portable | Codex skill can use same static inspection contract. |
| Brainstorm | `commands/brainstorm.md` | portable | Codex skill can use same four-lens contract. |
| Triage | `commands/triage.md` | adapter-required | Share inbox ranking; map Jira/PR connectors per runtime. |
| Changelog | `commands/changelog.md` | portable | Codex skill can use same git/PR synthesis contract. |
| Team init | `commands/team-init.md` | adapter-required | Share persona schema; generalize memory file target. |
| Consult | `commands/consult.md` | adapter-required | Share consultation protocol; map parallel agents per runtime. |
| Plan eng review | `commands/plan-eng-review.md` | adapter-required | Share review criteria; Codex should not use Codex as outside voice by default. |
| Plan design review | `commands/plan-design-review.md` | adapter-required | Share scoring dimensions; map variants/subtasks per runtime. |
| Review PR | `commands/review-pr.md` | native-rewrite | Build Codex-native reviewer orchestration. |
| Browse | `commands/browse.md` | adapter-required | Share safety and artifact rules; map browser tools/storage per runtime. |
| Auto do | `commands/auto-do.md` | native-rewrite | Build Codex-native autonomous runner. |
| Auto fleet | `commands/auto-fleet.md` | native-rewrite | Port after Codex auto-do. |
| Start day | `commands/start-day.md` | personal-template | Parameterize before porting. |
| End day | `commands/end-day.md` | personal-template | Parameterize before porting. |
| Grunt | `commands/grunt.md` | adapter-required | Re-express as runtime-specific response style toggle. |
