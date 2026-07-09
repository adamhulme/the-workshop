# Brainstorm workflow

Portability: `portable`

## Purpose

Generate multi-perspective ideation on a topic, grounded in `docs/research/`, before a direction is chosen.

## Inputs

- Topic.
- Existing `docs/research/` material relevant to the topic, if any.

## Contract

1. Search `docs/research/` for material sharing keywords with the topic; surface matches before use — don't ground silently.
2. Produce one section per fixed lens: **User** (what changes for the end user), **Ops** (what changes for the team running/supporting it), **Scope** (what's the smallest thing that solves this), **Risk** (what could break, what's hard to reverse).
3. Add a **Tensions** section naming where the lenses disagree. Do not smooth disagreement away.
4. Validate the output slug before writing: reject path separators, `..` segments, and filesystem-illegal characters; normalise to kebab-case and confirm before persisting.

## Output

Write `docs/brainstorms/<slug>.md` with frontmatter (`date`, `slug`, `topic`, `tags`, `research`) and sections `User` / `Ops` / `Scope` / `Risk` / `Tensions`.

## Adapter notes

Grounding-file discovery (glob/grep vs. native search) and the structured confirm-before-writing gate are harness-specific mechanics.
