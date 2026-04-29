#!/usr/bin/env bash
# Install the-workshop's slash commands into your Claude Code commands directory.
#
# Local:
#   ./install.sh                    # user-scoped (~/.claude/commands/)
#   ./install.sh --project          # project-scoped (./.claude/commands/)
#
# Remote (curl-pipe-bash):
#   curl -fsSL https://raw.githubusercontent.com/adamhulme/the-workshop/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/adamhulme/the-workshop/main/install.sh | bash -s -- --project

set -euo pipefail

REPO_URL="https://github.com/adamhulme/the-workshop.git"
SCOPE="user"
TARGET="$HOME/.claude/commands"

usage() {
  cat <<USAGE
Install the-workshop's slash commands.

Usage:
  install.sh [--user|--project]

  --user      Install to ~/.claude/commands/ (default)
  --project   Install to ./.claude/commands/
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) SCOPE="project"; TARGET=".claude/commands"; shift ;;
    --user)    SCOPE="user";    TARGET="$HOME/.claude/commands"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; usage; exit 1 ;;
  esac
done

# Locate the source. If the script is running from a clone (commands/ sits next
# to it), use that. Otherwise (curl-pipe-bash), shallow-clone to a temp dir.
SOURCE_DIR=""
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  if [[ -d "$SCRIPT_DIR/commands" ]]; then
    SOURCE_DIR="$SCRIPT_DIR/commands"
  fi
fi

if [[ -z "$SOURCE_DIR" ]]; then
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required when running via curl-pipe-bash. Install git, or clone the repo and run ./install.sh." >&2
    exit 1
  fi
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "Fetching the-workshop..."
  git clone --depth=1 "$REPO_URL" "$TMP/repo" --quiet
  SOURCE_DIR="$TMP/repo/commands"
fi

mkdir -p "$TARGET"

count=0
for f in "$SOURCE_DIR"/*.md; do
  [[ -e "$f" ]] || continue
  cp "$f" "$TARGET/"
  echo "  installed: $(basename "$f")"
  count=$((count + 1))
done

if [[ "$count" -eq 0 ]]; then
  echo "No commands found in $SOURCE_DIR — nothing installed." >&2
  exit 1
fi

echo ""
echo "Installed $count command(s) to $TARGET ($SCOPE scope)."
echo "Restart Claude Code; commands appear in /-autocomplete."
