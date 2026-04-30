#!/usr/bin/env bash
# Install the-workshop's slash commands and agents into your Claude Code config.
#
# Local:
#   ./install.sh                    # user-scoped (~/.claude/{commands,agents}/)
#   ./install.sh --project          # project-scoped (./.claude/{commands,agents}/)
#
# Remote (curl-pipe-bash):
#   curl -fsSL https://raw.githubusercontent.com/adamhulme/the-workshop/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/adamhulme/the-workshop/main/install.sh | bash -s -- --project

set -euo pipefail

REPO_URL="https://github.com/adamhulme/the-workshop.git"
SCOPE="user"
TARGET_BASE="$HOME/.claude"

usage() {
  cat <<USAGE
Install the-workshop's slash commands and agents.

Usage:
  install.sh [--user|--project]

  --user      Install to ~/.claude/{commands,agents}/ (default)
  --project   Install to ./.claude/{commands,agents}/
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) SCOPE="project"; TARGET_BASE=".claude"; shift ;;
    --user)    SCOPE="user";    TARGET_BASE="$HOME/.claude"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; usage; exit 1 ;;
  esac
done

# Locate the source. If the script is running from a clone, use it.
# Otherwise (curl-pipe-bash), shallow-clone to a temp dir.
SOURCE_BASE=""
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  if [[ -d "$SCRIPT_DIR/commands" ]]; then
    SOURCE_BASE="$SCRIPT_DIR"
  fi
fi

if [[ -z "$SOURCE_BASE" ]]; then
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required when running via curl-pipe-bash. Install git, or clone the repo and run ./install.sh." >&2
    exit 1
  fi
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  echo "Fetching the-workshop..."
  git clone --depth=1 "$REPO_URL" "$TMP/repo" --quiet
  SOURCE_BASE="$TMP/repo"
fi

cmd_count=0
agent_count=0

install_dir() {
  local kind="$1"
  local source_dir="$SOURCE_BASE/$kind"
  local target_dir="$TARGET_BASE/$kind"
  [[ -d "$source_dir" ]] || return 0
  mkdir -p "$target_dir"
  for f in "$source_dir"/*.md; do
    [[ -e "$f" ]] || continue
    cp "$f" "$target_dir/"
    echo "  installed $kind: $(basename "$f")"
    if [[ "$kind" == "commands" ]]; then
      cmd_count=$((cmd_count + 1))
    else
      agent_count=$((agent_count + 1))
    fi
  done
}

install_dir commands
install_dir agents

if [[ "$cmd_count" -eq 0 && "$agent_count" -eq 0 ]]; then
  echo "No commands or agents found in $SOURCE_BASE — nothing installed." >&2
  exit 1
fi

echo ""
echo "Installed $cmd_count command(s) and $agent_count agent(s) ($SCOPE scope)."
echo "Restart Claude Code; commands appear in /-autocomplete, agents are dispatchable via the Agent tool."
