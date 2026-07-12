---
status: in-progress
date: 2026-07-12
started: 2026-07-12
slug: codex-plugin-integration
category: architecture
tags: [codex, multi-runtime, install-sh, cross-model-review]
---

## Problem

Every Claude-side Codex dispatch (`/plan-eng-review`, `/plan-design-review`, `/review-pr`, `/auto-do`) shelled out to `codex exec --skip-git-repo-check` — a bare CLI call with no session management, no background jobs, and a fallback that silently substituted a Claude `general-purpose` agent when `codex` wasn't on PATH, leaving the audit trail implying Codex ran when it hadn't. OpenAI then shipped an official Claude Code plugin ([`codex-plugin-cc`](https://github.com/openai/codex-plugin-cc)) exposing a managed `codex:codex-rescue` agent. The question: how should the workshop adopt it without breaking its optional-integration model?

## Options considered

1. **Replace the CLI path with the plugin entirely.** Simplest doctrine — one Codex path. **Trade-off:** makes a third-party plugin a hard dependency of four commands; users with only the `codex` binary lose the outside voice they had yesterday.
2. **Install the plugin by default in `install.sh`.** Zero-friction adoption. **Trade-off:** violates the workshop's established rule that integrations are explicit opt-ins (`README.md`'s "None are hard dependencies"); silently registers a third-party marketplace and executes its plugin code on every fresh install.
3. **Opt-in flag + three-tier dispatch ladder (chosen).** `--with-codex-plugin` on `install.sh`/`update.sh`; commands prefer `codex:codex-rescue`, fall back to the `codex` CLI, and only then to a `general-purpose` Agent that is explicitly labelled as a Claude fallback. Plugin setup/auth failures stop the slot with `/codex:setup` guidance instead of switching models.
4. **Document manual plugin install only.** No installer changes. **Trade-off:** `update.sh` can't keep the plugin fresh, and the four command docs would reference an agent whose install path the workshop doesn't own.

## Chosen approach

Option 3. Concretely:

- `install.sh` gains `install_codex_plugin()` gated behind `--with-codex-plugin` (rejected when `RUNTIME=codex`; `claude` CLI presence pre-flighted before any files are written). The marketplace is matched by source repo (`openai/codex-plugin-cc`), not name — a same-named marketplace from another source fails loudly rather than installing an impostor's plugin. Install vs update is branched on `claude plugin list` so refresh runs are idempotent under `set -euo pipefail`.
- `update.sh` forwards the flag to the Claude leg only.
- The four command docs encode the ladder: plugin agent (read-only prompt, `--wait --fresh`, never `--write`) → `codex exec` → labelled Claude fallback; plugin-present-but-broken surfaces `/codex:setup` and never silently substitutes.
- `test/smoke-install.sh` drives the installer against a mock `claude` binary (`test/fixtures/claude`) covering fresh install, idempotent re-run, impostor-marketplace rejection, and the codex-only flag rejection.

## Rationale

- Opt-in over default-on: consistent with every other integration in the README's table — each unlocks a capability, none is required, and installing third-party executable code is exactly the kind of step that should be explicit.
- Fail-loud over silent fallback: the pre-existing design had a latent honesty bug — a missing `codex` binary quietly swapped in a same-model Claude review while the output was still headed "Codex". Cross-model review only has value if the audit trail says which model actually ran.
- Source-repo verification over name matching: marketplace names are user-controlled locally (including via project-scoped config in third-party repos), so name alone is spoofable; the source repo is the actual trust anchor.

## Outcome

PR: [#33](https://github.com/adamhulme/the-workshop/pull/33) — `agent/add-codex-plugin-cc` → `main`. In review; this section to be completed at merge.

### Reusable principle

**When dispatching to an external model, degrade along an explicit ladder and label every rung — never let a fallback silently change which model produced the output.** A cross-model second opinion that might secretly be same-model is worse than no second opinion; the audit trail is the feature.

## See also

- [[workshop-runtime-split]] (`docs/solutions/workshop-runtime-split.md`) — the adapter architecture this extends; `install.sh`'s runtime-awareness and manifest model come from there.
