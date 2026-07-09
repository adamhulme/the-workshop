# Changelog workflow

Portability: `portable`

## Purpose

Synthesize a narrative changelog entry from recently landed work, so `docs/changelog.md` reads as a release story rather than a commit log.

## Inputs

- Optional lower-bound revision (defaults to the last recorded changelog entry, or a fallback range).
- Optional version label (defaults to bumping the last recorded version).

## Contract

1. List landed work since the lower bound. Support both merge-commit and squash-merge repo conventions.
2. Enrich each item with its PR body/metadata when a code-host CLI or API is available; fall back to the commit diff/body otherwise.
3. Link to a matching `docs/plans/` or `docs/solutions/` entry when one exists, for additional motivation.
4. Write one narrative section per landed item (or tightly related group): why it matters, what changed, any user-observable caveat. Confident, concrete tone — no marketing fluff.
5. Cite the source (PR link and/or short hash) per entry so the next run can find its own lower bound.

## Output

Prepend under a new `## <version> — <date>` heading at the top of `docs/changelog.md`; create the file with a top-level heading if missing.

## Adapter notes

PR enrichment depends on a harness-specific code-host connector (e.g. `gh`); degrade to commit-message-only synthesis and say so when unavailable.
