---
description: Consult a project's persona team for multi-perspective analysis with surfaced disagreements and rebuttals
argument-hint: <question> [--quick <role>] [--context <file>] [--team <path>] [--all] [--group <name>] [--opus]
---

Run a multi-perspective consultation with the project's persona team. Dispatches personas in parallel, surfaces disagreements, runs targeted rebuttals, and synthesises with tensions preserved.

User arguments: $ARGUMENTS

The experience should feel like a well-run meeting: quiet setup, clear agenda, the right people in the room, structured disagreement, rebuttals on key tensions, a decision at the end.

**Terminal cleanliness:**
- File reading and discovery is silent — do not show raw output to the user.
- Speak only at decision points and when presenting results.
- Use AskUserQuestion for any decision that affects cost or scope.
- Progress updates are one-liners, not paragraphs.

## Step 0: Parse flags

Read $ARGUMENTS first. Detect:

- `--quick <role>` → single-persona fast path (still runs Step 1 to discover team).
- `--context <file-path>` → modifies both --quick and standard mode.
- `--team <path>` → use this directory directly, skip discovery in Step 1. Validate it exists and contains `.md` files. If invalid, tell the user and stop.
- `--opus` → use `model: "opus"` for persona and rebuttal Agent calls instead of `"sonnet"`.
- `--all` → skip classification in Step 2, use full team.
- `--group <name>` → use the named focused group from the manifest if present.
- No flags → standard flow.

This step is mandatory. Do not skip it. Do not start Step 1 before checking flags.

## Step 1: Discover team (silent)

If `--team <path>` was provided, use that path and skip discovery.

Otherwise:

1. Glob `**/teams/*/team.yaml` from the repo root.
2. If no matches, fall back to `**/team.yaml`.
3. If multiple matches, list them and ask the user which to use.
4. If exactly one match, use its parent directory.

If no team is found:

> No team found. Pass `--team /path/to/team/dir` or create a `teams/<name>/team.yaml` manifest.

Then stop. Do not proceed.

## Mode: --quick (after Step 1)

If `--quick <role>` was set:

1. Validate `<role>` against persona files in the team directory. If no match, list available roles and stop: "Role '{role}' not found. Available roles: {comma-separated list}".
2. Skip Step 2 entirely.
3. Read only the named persona file.
4. Dispatch a single Agent call (same prompt structure as Step 4, one persona).
5. If `--context` was also set, read the file and prepend its content as a `## Context` section in the dispatch prompt. If the file does not exist, warn and proceed without context.
6. Return the response directly. No synthesis.

Then stop.

## Mode: --context (modifier for standard flow)

If `--context <file-path>` was set without `--quick`, read the file with the Read tool. If it does not exist, warn ("Context file not found: {path}, proceeding without context") and continue. Otherwise hold the content — it will be prepended to each persona dispatch prompt as a `## Context` section.

## Standard flow

If a team directory was found, silently:

1. Read the manifest (`team.yaml`) if present — parse team name, focused groups, speaking order, decision protocol. Do not show raw YAML.
2. Read just the frontmatter (first 20 lines) of each `.md` file (excluding README.md) to build the roster: role, name, perspective, tensions.

Present the team in one clean block:

> **Team:** {team name from manifest, or "unnamed team"} (`{team_dir_path}`)
> {N} personas: {comma-separated list of "Name (role)" or just role if no name}

## Step 2: Classify and confirm (AskUserQuestion — required)

Look at the user's question and the focused groups from the manifest. Pick the closest match:

- Whether to build something, priorities, business value → `product-decisions`
- How to build something, architecture, tech choices → `technical-feasibility` or `implementation`
- Scope, timeline, what ships this sprint → `scope-delivery`
- UX vs domain complexity → `ux-vs-domain`
- Safe to ship? → `shipping-readiness`
- Ambiguous or cross-cutting → full team

If `--all` was set, skip classification and use the full team.

If `--group <name>` was set, look up that group in the manifest. If no manifest or no matching group, tell the user "No focused group '{name}' found — falling back to full team." and use the full speaking order.

Otherwise, use AskUserQuestion to confirm:

> **Question type:** {your classification, e.g. "technical feasibility"}
>
> I'd consult **{group name}** for this — {persona list with roles}.
> {One sentence on why this group fits the question.}
>
> Each persona runs as a separate agent (costs ~{N} agent calls).
>
> A) **{group name}** — {persona list} (recommended)
> B) **Full team** — all {N} personas (broader, heavier)
> C) **Custom** — tell me which roles you want in the room
>
> RECOMMENDATION: Choose A — {one-line reason}.

Wait for the response. If they choose C, ask which roles. Do not dispatch without confirmation.

## Step 3: Read selected personas (silent)

Read the full content of each selected persona file. Do not show contents to the user.

After reading, one-liner:

> Reading {N} personas... dispatching now.

## Step 4: Dispatch personas

For each selected persona, dispatch an Agent call. Each agent receives:

```
You are {persona name or role}. Your perspective is: {perspective}.

{Full persona prompt from the markdown file}

---

The team is discussing the following question:

{User's original question}

Provide your perspective. Be specific and opinionated. Structure as:

**Position:** Your stance on this question (2-3 sentences)

**Concerns:** Specific concerns (bulleted list)

**Recommendation:** What you recommend and why (1-2 sentences)

**Disagree with:** If you would disagree with any other team member, name their role and explain why. Reference specific tensions between your roles. If you wouldn't disagree with anyone, say so.
```

Dispatch all persona agents in parallel (multiple Agent calls in a single message). Use `model: "sonnet"` unless `--opus` was set.

## Step 5: Triage and user checkpoint

After all initial responses are collected, triage before synthesising. This surfaces disagreements early and lets the user steer.

### 5a — Extract tensions (silent)

Read all persona responses. Identify:
- **Explicit disagreements** from "Disagree with" fields.
- **Implicit disagreements** where personas take substantively different positions.
- **The sharpest 1-2 tensions**, ranked by how opposed.
- **What the team agrees on**.

Build a condensed summary internally. Each tension as:
`{Role A} vs {Role B} on {topic}: {A's position in 1 sentence} vs {B's position in 1 sentence}`

### 5b — Show a brief positions summary

Concise — do NOT dump full responses:

```
## Initial Positions

**Agrees:** {1-2 sentence summary of alignment}

**Key tension:** {Role A} vs {Role B} on {topic}
> **{Role A}:** {1-sentence position}
> **{Role B}:** {1-sentence position}

{If a second tension exists:}
**Secondary tension:** {Role C} vs {Role D} on {topic}
> **{Role C}:** {1-sentence position}
> **{Role D}:** {1-sentence position}
```

### 5c — User checkpoint (AskUserQuestion — required)

**If tensions were found:**

> The team has weighed in. How would you like to proceed?
>
> A) **Rebuttals** — let {Role A} and {Role B} respond to each other on {tension topic} (~2 agent calls)
> B) **Redirect** — ask a specific persona a follow-up
> C) **Add context** — share information that might shift their positions
> D) **Skip to synthesis** — initial positions are enough

If B, ask which persona and what question before dispatching. If C, ask for the context, then re-dispatch only the personas whose positions would shift (1-2 condensed prompts, not full re-runs).

**If unanimous (no tensions):**

> The team is largely aligned — no sharp disagreements.
>
> A) **Challenge consensus** — push back on the weakest assumption (~1 agent call)
> B) **Ask a follow-up** — direct a question to a specific persona
> C) **Synthesize now** — wrap up with the recommendation

## Step 6: Selective rebuttal

Only runs if the user chose A or B at the checkpoint. Skip entirely for D / C (synthesise now).

### Option A — Automatic rebuttal

Dispatch exactly 2 agents in parallel (the two personas in the sharpest tension). Use **condensed prompts** — do NOT re-send the full persona file:

```
You are {persona name}, {role}. {One sentence from frontmatter perspective field.}

In a team discussion about: {user's original question}

You said:
{Your Position + Recommendation from Step 4, verbatim, ~3-5 sentences}

{Opposing role} disagrees. Their position:
{Their Position + Recommendation from Step 4, verbatim, ~3-5 sentences}

Respond to their specific points. Be direct and concise.

Structure as:
**Concede:** What they're right about
**Counter:** Where you push back and why
**Revised recommendation:** Your updated recommendation (or restate original if unchanged)

Keep entire response under 300 words.
```

**Cost controls:**
- No full persona file — just the 1-sentence role identity from frontmatter `perspective`.
- Only the opposing position included, not all responses.
- Explicit 300-word cap in the prompt.
- `model: "sonnet"` (or `"opus"` if `--opus` was set).

### Option B — User-directed question

Dispatch a single agent for the named persona:

```
You are {persona name}, {role}. {One sentence from frontmatter perspective.}

In a team discussion about: {user's original question}

You initially said:
{Your Position + Recommendation from Step 4}

The discussion lead has a follow-up:

"{user's verbatim question}"

Respond directly. Keep under 300 words.
```

### Challenge consensus (unanimous case, Option A)

Dispatch a single agent — pick the persona with the most declared `tensions` entries in their frontmatter (typically a quality/risk or architect role):

```
You are {persona name}, {role}. {One sentence from frontmatter perspective.}

The team unanimously agreed on this approach:
{Consensus summary — 2-3 sentences covering the shared position}

Play devil's advocate. What could go wrong with this approach? What assumption is everyone making that might be false? What would you warn about if forced to argue the other side?

Keep under 300 words.
```

## Step 7: Synthesise

After all responses are in (initial positions + any rebuttals), produce a synthesis.

**Do NOT dump each persona's response verbatim.** Synthesise. The user wants a meeting summary, not a transcript. Preserve substance and disagreement, write it in your own voice.

### Format

```
## Team Consultation: {question summary}

### Perspectives

For each persona, write a **2-4 sentence summary** of their position — what they think, what they're worried about, what they recommend. Use their name and role as a header. Do not copy-paste full responses.

**{Name} ({role}):** {synthesised summary}

### Tension Map

Where the team disagrees:

| Between | About | Summary |
|---------|-------|---------|
| {role A} vs {role B} | {topic} | {one-line summary} |

If the team agrees on everything, say so and skip the table.

### Rebuttal Highlights

{Only include if rebuttals happened in Step 6. Omit if the user skipped or the team was unanimous without challenge.}

**{Role A} conceded:** {what they gave ground on}
**{Role B} conceded:** {what they gave ground on}
**Unresolved:** {what they still disagree about, if anything}

{If the user asked a directed question (Option B), summarise that follow-up here instead.}

{If a consensus challenge happened, summarise the devil's advocate findings here.}

### Decision Protocol

If the manifest has a decision protocol and there are disagreements, apply it:
- "Per the decision protocol: {rule that applies}. {Tiebreaker role} has authority."
- Or: "This requires client input (authority: external)."

If no protocol exists: "No decision protocol defined — recommend escalating disagreements to the project owner."

### Recommendation

State the recommended path forward. Be opinionated. If the team converged, say so. If not, pick a side based on the decision protocol and explain why. If rebuttals happened, reference what changed: "After rebuttals, {Role A} conceded {X}, which strengthens the case for {approach}."

Do NOT consensus-smooth. If two personas genuinely disagree, preserve that.
```

## Step 8: Offer next steps

After presenting the synthesis, use AskUserQuestion to offer concrete follow-ups:

> {One-line summary of the consultation outcome.}
>
> A) **Save this consultation** to a file (I'll ask where — sensible default: `docs/research/consultations/<slug>.md`)
> B) **Dig deeper** — consult additional personas or re-run with full team
> C) **Done** — I have what I need

If A, ask where to save and write the synthesis as a markdown file. If B, return to Step 2 with the expanded roster.
