#!/usr/bin/env bash
# diet-read — PreToolUse hook for the Read tool.
# Warns Claude when reading large files without offset/limit, nudging toward
# grep-first-then-targeted-read patterns that save thousands of tokens.
#
# Setup (add to settings.json — user or project scope):
#
#   User scope (~/.claude/settings.json):
#     "hooks": {
#       "PreToolUse": [{
#         "matcher": "Read",
#         "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/diet-read.sh" }]
#       }]
#     }
#
#   Project scope (.claude/settings.json):
#     "hooks": {
#       "PreToolUse": [{
#         "matcher": "Read",
#         "hooks": [{ "type": "command", "command": "bash .claude/hooks/diet-read.sh" }]
#       }]
#     }

INPUT=$(cat)

# Parse JSON without jq — the three fields are simple string/number values.
extract() { local v; v=$(echo "$INPUT" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*[^,}]*" | head -1 | sed 's/.*:[[:space:]]*//;s/"//g;s/[[:space:]]*$//'); [[ "$v" == "null" ]] && v=""; echo "$v"; }

FILE_PATH=$(extract file_path)
OFFSET=$(extract offset)
LIMIT=$(extract limit)

# Already targeted — no warning needed
[[ -n "$OFFSET" || -n "$LIMIT" ]] && exit 0
[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

LINE_COUNT=$(wc -l < "$FILE_PATH" 2>/dev/null || echo 0)

if (( LINE_COUNT > 200 )); then
  EST_TOKENS=$(( LINE_COUNT * 4 ))
  echo "diet-read: ${FILE_PATH##*/} is ${LINE_COUNT} lines (~${EST_TOKENS} tokens). Consider: grep for your target, then read with offset+limit."
fi
