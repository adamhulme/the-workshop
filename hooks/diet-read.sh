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

# Parse JSON without jq. Handles quoted strings (including those with commas)
# and bare values (numbers, null, true/false).
extract() {
  local v
  local dq='"'
  # Try quoted string value first (handles commas, colons in paths)
  v=$(echo "$INPUT" | grep -o "${dq}$1${dq}[[:space:]]*:[[:space:]]*${dq}[^${dq}]*${dq}" | head -1 | sed "s/.*:[[:space:]]*${dq}//;s/${dq}$//")
  if [[ -z "$v" ]]; then
    # Fall back to bare value (numbers, null, booleans)
    v=$(echo "$INPUT" | grep -o "${dq}$1${dq}[[:space:]]*:[[:space:]]*[^,}]*" | head -1 | sed 's/.*:[[:space:]]*//' | tr -d ' ')
  fi
  [[ "$v" == "null" ]] && v=""
  echo "$v"
}

FILE_PATH=$(extract file_path)
OFFSET=$(extract offset)
LIMIT=$(extract limit)
PAGES=$(extract pages)

# Already targeted — no warning needed
[[ -n "$OFFSET" || -n "$LIMIT" || -n "$PAGES" ]] && exit 0
[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

# Skip binary files — line counts are meaningless for images, PDFs, etc.
case "${FILE_PATH##*.}" in
  png|jpg|jpeg|gif|webp|svg|ico|bmp|pdf|zip|tar|gz|bz2|xz|woff|woff2|ttf|eot|mp3|mp4|mov|avi|o|so|dylib|wasm) exit 0 ;;
esac

LINE_COUNT=$(wc -l < "$FILE_PATH" 2>/dev/null || echo 0)

if (( LINE_COUNT > 200 )); then
  EST_TOKENS=$(( LINE_COUNT * 4 ))
  echo "diet-read: ${FILE_PATH##*/} is ${LINE_COUNT} lines (~${EST_TOKENS} tokens). Consider: grep for your target, then read with offset+limit."
fi
