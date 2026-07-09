# Codex skill: changelog

Shared contract: `core/workflows/changelog.md`

## Use when

The user asks for a release narrative or changelog from recent merged work.

## Codex behavior

1. Inspect recent merge commits or the requested range.
2. Enrich with PR bodies when `gh` is available.
3. Link related plans or solutions when slugs match.
4. Write a dated entry to `docs/changelog.md`.
5. Keep the narrative user-facing and concrete.
