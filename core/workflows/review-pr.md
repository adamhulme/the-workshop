# PR review workflow

Portability: `native-rewrite`

## Purpose

Run a bounded, actionable review loop over a pull request or branch diff, fix must-fix findings when appropriate, and preserve review knowledge.

## Inputs

- PR number, branch, or diff range.
- Optional review focus.

## Review dimensions

Use the canonical reviewer rubrics in `core/rubrics/`:

- correctness, scope drift, test coverage, risk-to-revert, follow-up cleanup.
- security when relevant.
- performance when relevant.
- compounding when artifacts or workshop conventions are touched.

## Gates

- Ask before pushing fix-up commits to a branch without an established remote/upstream.
- Ask before addressing findings automatically unless the caller explicitly selected an autonomous mode.
- Stop after two rounds unless the runtime-specific workflow has an explicit human override.

## Output

- Consolidated findings grouped by urgency.
- Fix-up commit for accepted must-fix items when applicable.
- PR comment or local summary with round results.
- Follow-up items in `todos/` or `TODOS.md` when not fixed in the PR.

## Adapter notes

Each runtime should implement this natively. Claude may orchestrate reviewer agents and should prefer the official Codex plugin before using the direct Codex CLI; every fallback must identify which provider actually ran. Codex should not shell out to itself as an outside voice unless that is deliberately useful.
