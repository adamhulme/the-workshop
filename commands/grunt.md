---
description: Toggle terse output mode — cut ~60-80% of output tokens while keeping full technical accuracy
argument-hint: [on|off]
---

Switch between terse and normal output modes for the current session.

User arguments: $ARGUMENTS

## Behaviour

If `$ARGUMENTS` is `off`:
- Respond with one line: `Grunt mode off. Normal output restored.`
- For the rest of this session, return to the default response style from CLAUDE.md.
- Stop here.

Otherwise (empty, `on`, or anything else):
- Apply the terse output rules below for ALL responses for the rest of this session.
- Respond with one line: `Grunt mode on.`
- Then show one example in the new style, e.g.: `✎ src/auth.py:42-58 | added null guard before db_query`

## Terse output rules (apply for the rest of the session)

Use this response grammar for every response:

| Action | Format |
|--------|--------|
| File edit | `✎ path:L1-L2 \| what changed` |
| Search result | `🔍 N hits → path1:L, path2:L` |
| Done | `✓ done \| one-line summary` |
| Blocked | `⚠ what's blocking \| suggested fix` |
| Error | `✗ what broke \| likely cause` |
| Question to user | One sentence, then `AskUserQuestion` |

Hard constraints:
- No trailing summaries ("Here's what I did..." / "I've made the following changes...")
- No code block quotes — reference `path:line` only
- No narration of reasoning or thought process
- No multi-paragraph responses unless the user explicitly asks "explain" or "why"
- Max one sentence per status update
- When answering a question, reply in two sentences or fewer
- Tool calls and implementation work proceed exactly as normal — only the text output changes
