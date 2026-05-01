---
description: Designer's eye plan review — score 8 design dimensions 0-10, surface gaps and AI-slop risk, with an optional adversarial Codex outside voice
argument-hint: [path-to-plan-file]
---

Review a design plan for missing decisions and AI-slop risk before any code is written. Output is a better plan, not a document about the plan.

User arguments: $ARGUMENTS

## Step 1: Locate the plan

If `$ARGUMENTS` is a path to an existing markdown file, use it. Otherwise:
- Look for `docs/plans/*.md` in the repo root. If exactly one exists, use it.
- If multiple exist, list them and ask the user which to review.
- If none exist, ask the user to paste the plan inline or supply a path.

If no plan file is in play, you will append findings to `TODOS.md` at the repo root (create it if missing). If a plan file exists, edit it in place.

Tell the user which plan you're reviewing and what the output target is.

## Step 2: Scope challenge (interactive)

Before scoring, push back on the plan's scope. Read the plan and ask the user one question per genuine gap, not a batch:

- What's the smallest UI scope that delivers the value? Is the plan trying to design too much at once?
- Does this plan have a UI scope at all? If it's pure backend / API / infra, say so and exit early — design review doesn't apply.
- Is there a `DESIGN.md` or design system to align against? If not, flag the gap once.
- What existing UI patterns or components in the codebase should this plan reuse instead of reinventing?

For each scope concern, present the issue concretely and propose 2–3 options (cut it, defer it, keep it as scoped). Wait for the user's call before moving on. **One issue per question — do not batch.**

## Step 3: Score 8 design dimensions

For each dimension below, output:

```
DIMENSION: <name>
CURRENT: <N>/10 — <one-sentence diagnosis citing what the plan does/doesn't say>
TARGET: 10/10 looks like — <concrete description of the bar>
GAP: <what's missing, in 1–3 bullets>
```

Then ask the user one question per dimension that scores below 8: "Add the missing spec to the plan, defer to a TODO, or leave as-is?" Wait for the answer before editing.

The 8 dimensions:

1. **Color** — Does the plan name actual colors / tokens (hex, CSS variable, design-system reference), or just say "primary" / "accent" / "modern palette"? 10/10 specifies the palette, the contrast ratios for body text (≥4.5:1), and where each color is used. Flag purple-to-blue gradients, generic SaaS palettes.

2. **Typography** — Does the plan name typefaces, weights, sizes, and line-heights? 10/10 specifies the type scale (display / heading / body / caption), the typeface for each, and pairs them intentionally. Flag default stacks (Inter, Roboto, Arial, system-ui as the primary display font — the "I gave up on typography" signal).

3. **Spacing** — Does the plan reference a spacing scale (4px / 8px grid, named tokens), or is layout left to the implementer? 10/10 specifies the rhythm: section padding, component padding, gap between elements, vertical rhythm between text blocks.

4. **Components** — Does the plan name specific components and their states, or just say "card" / "button" / "form"? 10/10 lists each component, where it's reused from (existing system) or net-new, and what states it must support. Flag generic 3-column feature grids, decorative card-mosaics, cards that don't earn their existence.

5. **Accessibility** — Does the plan specify keyboard navigation, ARIA landmarks, focus order, screen-reader behavior, touch targets (44px min), color contrast? 10/10 has an a11y line per screen, not "we'll make it accessible." If absent, this is almost always a deferred TODO.

6. **Interaction** — Does the plan describe loading, empty, error, success, and partial states for every UI feature? 10/10 has a state table:
   ```
   FEATURE | LOADING | EMPTY | ERROR | SUCCESS | PARTIAL
   ```
   Empty states are features — warmth, primary action, context. "No items found." is not a design.

7. **Mobile responsiveness** — Does the plan specify intentional layouts per viewport (mobile / tablet / desktop), or just say "responsive" / "stacks on mobile"? 10/10 names the breakpoints and what changes at each — nav pattern, content priority, hidden vs. shown elements.

8. **Visual hierarchy** — Does the plan specify what the user sees first, second, third on each screen? 10/10 has a one-sentence hierarchy per screen: primary action, secondary action, context. If everything competes, nothing wins. The trunk test: cover everything except the primary action — would the user still know what to do?

After all 8 dimensions are scored and gaps either patched or deferred, show a summary table:

```
DIMENSION              | BEFORE | AFTER | NOTES
-----------------------|--------|-------|------
Color                  |   _/10 |  _/10 |
Typography             |   _/10 |  _/10 |
Spacing                |   _/10 |  _/10 |
Components             |   _/10 |  _/10 |
Accessibility          |   _/10 |  _/10 |
Interaction            |   _/10 |  _/10 |
Mobile responsiveness  |   _/10 |  _/10 |
Visual hierarchy       |   _/10 |  _/10 |
```

## Step 4: Variants (optional)

Ask once: "Want 2–3 alternative design directions explored in parallel? (y/n)"

If yes, dispatch parallel subagents — one per variant — using the Task tool with `subagent_type: general-purpose`. Each subagent gets a prompt like:

> You are a senior product designer. Read the plan at `<path>`. Propose ONE coherent design direction for the UI scope, distinct from a "default modern SaaS" baseline. Cover: color palette (named hex / tokens), typography (named typefaces, scale), spacing rhythm, key components, and the visual mood in one sentence. 200–400 words. Be specific — name fonts, name hex codes, name interaction patterns. No generic adjectives ("clean", "modern", "intuitive").

Pick angles that genuinely differ — e.g. editorial-typographic, data-dense calm, playful-expressive. Run them in parallel, present the three side-by-side, ask the user which direction to fold into the plan (or "keep as-is").

## Step 5: Outside voice (optional)

Ask once: "Want an adversarial design review from Codex before we finalise? (y/n) (Requires `codex` on PATH.)"

If yes, dispatch Codex via `Bash`: `codex exec --skip-git-repo-check "<prompt>"` with the prompt below. Codex provides a genuinely independent design read. If `codex` is not on PATH, fall back to an `Agent` call with `subagent_type: general-purpose`.

> Read the plan at `<path>`. You are an independent senior product designer who has not seen any prior review. Find every place this design will look generic, AI-generated, or careless. Specifically check for:
>
> 1. Generic SaaS card grid as first impression
> 2. Strong headline with no clear action
> 3. Sections repeating the same mood
> 4. Cards used decoratively instead of when the card IS the interaction
> 5. Default font stacks (Inter / Roboto / Arial / system-ui) as primary display
> 6. Centered-everything alignment
> 7. Decorative blobs, floating circles, wavy SVG dividers
> 8. Purple-to-blue gradients, icons-in-colored-circles, emoji as design elements
> 9. Cookie-cutter section rhythm (hero → 3 features → testimonials → pricing → CTA)
> 10. Placeholder-as-label form fields, low-contrast body text, missing visited-link distinction
>
> For each finding: what's wrong, what ships if it's not fixed, the specific fix. Be opinionated. No hedging.

Present the findings under a `## Outside Voice (Codex)` header. Surface them as new issues to the user — keep / fix / defer each one.

## Step 6: Write the output

**If a plan file is in scope:**
- Edit it in place. Add or update a `## Design Review` section near the top with the dimension table and the patches you made.
- For each gap patched, edit the relevant section of the plan to include the new spec (e.g. add the state table to the feature spec, add the type scale to a Design section).
- For each deferred gap, list it under `## Design TODOs` in the plan.

**If no plan file (TODOS.md mode):**
- Append a `## Design Review (<date>)` section to `TODOS.md` containing the dimension table, the gaps the user chose to defer, and one-line context per gap so a reader in 3 months understands the motivation.

## Step 7: Report

Print:
- Plan file (or TODOS.md) path that was modified.
- Initial overall score (mean of the 8 dimensions, before fixes) → final score.
- Count of gaps patched in-plan vs. deferred to TODOs.
- Suggested next step: "Consider `/plan` to refine remaining decisions, or hand to engineering review."

## Rules

- **One issue = one question.** Never batch design questions.
- **Specificity over vibes.** "Clean, modern UI" is not a design decision. Push for named fonts, named hex codes, named patterns.
- **Subtraction default.** If a UI element doesn't earn its pixels, recommend cutting it.
- **No code changes.** This is plan-mode review only. Do not modify implementation files.
- **Map recommendations to a principle.** When you push back, name the principle (hierarchy, scannability, AI-slop avoidance, accessibility floor) — keeps taste debuggable.
- **No silent skips.** If a dimension genuinely has no findings, say "No issues, moving on" — but evaluate every dimension.
