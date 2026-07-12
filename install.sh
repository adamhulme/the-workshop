#!/usr/bin/env bash
# Install the-workshop adapters into Claude Code and/or Codex config.
#
# Local:
#   ./install.sh                    # user-scoped (~/.claude/{commands,agents,hooks}/)
#   ./install.sh --project          # project-scoped (./.claude/{commands,agents,hooks}/)
#
# Remote (curl-pipe-bash):
#   curl -fsSL https://raw.githubusercontent.com/adamhulme/the-workshop/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/adamhulme/the-workshop/main/install.sh | bash -s -- --project

set -euo pipefail

REPO_URL="https://github.com/adamhulme/the-workshop.git"
SCOPE="user"
RUNTIME="claude"
WITH_CODEX_PLUGIN=0
CLAUDE_TARGET_BASE="$HOME/.claude"
CODEX_TARGET_BASE="$HOME/.codex/the-workshop"
TARGET_BASE="$CLAUDE_TARGET_BASE"

usage() {
  cat <<USAGE
Install the-workshop adapters.

Usage:
  install.sh [--user|--project] [--claude|--codex|--both] [--with-codex-plugin]

  --user      Install to user scope (default)
  --project   Install to project scope
  --claude    Install Claude Code adapter only (default)
  --codex     Install Codex adapter only
  --both      Install both adapters
  --with-codex-plugin
              Also install OpenAI's Codex plugin for Claude Code
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) SCOPE="project"; CLAUDE_TARGET_BASE=".claude"; CODEX_TARGET_BASE=".codex/the-workshop"; TARGET_BASE="$CLAUDE_TARGET_BASE"; shift ;;
    --user)    SCOPE="user";    CLAUDE_TARGET_BASE="$HOME/.claude"; CODEX_TARGET_BASE="$HOME/.codex/the-workshop"; TARGET_BASE="$CLAUDE_TARGET_BASE"; shift ;;
    --claude)  RUNTIME="claude"; shift ;;
    --codex)   RUNTIME="codex"; shift ;;
    --both)    RUNTIME="both"; shift ;;
    --with-codex-plugin) WITH_CODEX_PLUGIN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$WITH_CODEX_PLUGIN" -eq 1 && "$RUNTIME" == "codex" ]]; then
  echo "--with-codex-plugin requires the Claude adapter (--claude or --both)." >&2
  exit 1
fi

if [[ "$WITH_CODEX_PLUGIN" -eq 1 ]] && ! command -v claude >/dev/null 2>&1; then
  echo "Claude Code is required for --with-codex-plugin. Install Claude Code and re-run." >&2
  exit 1
fi

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
hook_count=0
codex_skill_count=0
codex_agent_count=0
core_count=0
MANIFEST_LINES=()

install_dir() {
  local kind="$1"
  local ext="${2:-md}"
  local source_dir="$SOURCE_BASE/$kind"
  local target_dir="$TARGET_BASE/$kind"
  [[ -d "$source_dir" ]] || return 0
  mkdir -p "$target_dir"
  for f in "$source_dir"/*."$ext"; do
    [[ -e "$f" ]] || continue
    cp "$f" "$target_dir/"
    [[ "$ext" == "sh" ]] && chmod +x "$target_dir/$(basename "$f")"
    echo "  installed $kind: $(basename "$f")"
    MANIFEST_LINES+=("$kind/$(basename "$f")")
    case "$kind" in
      commands) cmd_count=$((cmd_count + 1)) ;;
      agents)  agent_count=$((agent_count + 1)) ;;
      hooks)   hook_count=$((hook_count + 1)) ;;
    esac
  done
}

install_tree_files() {
  local source_dir="$1"
  local target_dir="$2"
  local manifest_prefix="$3"
  local label="$4"
  [[ -d "$source_dir" ]] || return 0
  mkdir -p "$target_dir"
  while IFS= read -r f; do
    local rel="${f#$source_dir/}"
    mkdir -p "$target_dir/$(dirname "$rel")"
    cp "$f" "$target_dir/$rel"
    echo "  installed $label: $rel"
    MANIFEST_LINES+=("$manifest_prefix/$rel")
    case "$label" in
      codex/skills) codex_skill_count=$((codex_skill_count + 1)) ;;
      codex/agents) codex_agent_count=$((codex_agent_count + 1)) ;;
      core) core_count=$((core_count + 1)) ;;
    esac
  done < <(find "$source_dir" -type f | LC_ALL=C sort)
}

write_manifest() {
  local target="$1"
  local runtime_label="$2"
  mkdir -p "$target"
  {
    echo "# the-workshop install manifest — managed by install.sh / update.sh"
    echo "# Runtime: $runtime_label"
    echo "# Each line below is a relative path under the install target."
    printf '%s\n' "${MANIFEST_LINES[@]}" | LC_ALL=C sort
  } > "$target/.workshop-manifest"
  echo "$WORKSHOP_VERSION" > "$target/.workshop-version"
  echo "scope=$SCOPE" > "$target/.workshop-scope"
  echo "runtime=$runtime_label" > "$target/.workshop-runtime"
}

# Read source version (from VERSION file at repo root). Default to "unknown"
# if the file is missing — keeps install.sh resilient against detached source
# trees but won't match a tagged release.
WORKSHOP_VERSION="unknown"
if [[ -f "$SOURCE_BASE/VERSION" ]]; then
  WORKSHOP_VERSION="$(tr -d '[:space:]' < "$SOURCE_BASE/VERSION")"
fi

install_claude() {
  TARGET_BASE="$CLAUDE_TARGET_BASE"
  MANIFEST_LINES=()
  cmd_count=0; agent_count=0; hook_count=0
  install_dir commands
  install_dir agents
  install_dir hooks sh
  if [[ "$cmd_count" -eq 0 && "$agent_count" -eq 0 && "$hook_count" -eq 0 ]]; then
    echo "No Claude commands, agents, or hooks found in $SOURCE_BASE — nothing installed." >&2
    exit 1
  fi
  write_manifest "$TARGET_BASE" "claude"
  echo ""
  echo "Installed $cmd_count Claude command(s), $agent_count agent(s), and $hook_count hook(s) ($SCOPE scope, version $WORKSHOP_VERSION)."
  if [[ "$hook_count" -gt 0 ]]; then
    echo ""
    echo "Hooks installed but not yet active. To enable, add hook config to settings.json."
    echo "See comments in each hook file for setup instructions (${TARGET_BASE}/hooks/)."
  fi
  echo "Restart Claude Code; commands appear in /-autocomplete, agents are dispatchable via the Agent tool."
}

install_codex_plugin() {
  # Match the marketplace by its source repo, not just its name — a same-named
  # marketplace registered from elsewhere must fail loudly, never install.
  local marketplaces
  marketplaces="$(claude plugin marketplace list --json 2>/dev/null || printf '[]')"
  if grep -Fq 'openai/codex-plugin-cc' <<< "$marketplaces"; then
    claude plugin marketplace update openai-codex
  elif grep -Eq '"name"[[:space:]]*:[[:space:]]*"openai-codex"' <<< "$marketplaces"; then
    echo "A marketplace named 'openai-codex' is already registered but does not point at openai/codex-plugin-cc." >&2
    echo "Remove it (claude plugin marketplace remove openai-codex) and re-run." >&2
    exit 1
  else
    echo ""
    echo "Adding the OpenAI Codex plugin marketplace..."
    claude plugin marketplace add openai/codex-plugin-cc --scope "$SCOPE"
  fi

  # `plugin install` on an already-installed plugin is not guaranteed idempotent;
  # under set -e a reinstall error would hard-fail every update.sh refresh.
  local plugins
  plugins="$(claude plugin list --json 2>/dev/null || printf '[]')"
  if grep -Eq '"name"[[:space:]]*:[[:space:]]*"codex"' <<< "$plugins"; then
    echo "Updating the Codex plugin for Claude Code..."
    claude plugin update codex@openai-codex --scope "$SCOPE"
  else
    echo "Installing the Codex plugin for Claude Code..."
    claude plugin install codex@openai-codex --scope "$SCOPE"
  fi
  echo "Installed codex@openai-codex ($SCOPE scope). Run /reload-plugins, then /codex:setup in Claude Code."
}

install_codex() {
  TARGET_BASE="$CODEX_TARGET_BASE"
  MANIFEST_LINES=()
  codex_skill_count=0; codex_agent_count=0; core_count=0
  install_tree_files "$SOURCE_BASE/codex/skills" "$TARGET_BASE/skills" "skills" "codex/skills"
  install_tree_files "$SOURCE_BASE/codex/agents" "$TARGET_BASE/agents" "agents" "codex/agents"
  install_tree_files "$SOURCE_BASE/core" "$TARGET_BASE/core" "core" "core"
  if [[ -f "$SOURCE_BASE/WORKSHOP.md" ]]; then
    mkdir -p "$TARGET_BASE"
    cp "$SOURCE_BASE/WORKSHOP.md" "$TARGET_BASE/WORKSHOP.md"
    MANIFEST_LINES+=("WORKSHOP.md")
    core_count=$((core_count + 1))
    echo "  installed codex: WORKSHOP.md"
  fi
  if [[ "$codex_skill_count" -eq 0 && "$codex_agent_count" -eq 0 ]]; then
    echo "No Codex skills or agents found in $SOURCE_BASE — nothing installed." >&2
    exit 1
  fi
  write_manifest "$TARGET_BASE" "codex"
  echo ""
  echo "Installed $codex_skill_count Codex skill(s), $codex_agent_count agent role(s), and $core_count shared file(s) ($SCOPE scope, version $WORKSHOP_VERSION)."
  echo "Codex adapter files installed under ${TARGET_BASE}/. Point Codex sessions at WORKSHOP.md and the skills/agents directories as needed."
}

case "$RUNTIME" in
  claude)
    install_claude
    if [[ "$WITH_CODEX_PLUGIN" -eq 1 ]]; then install_codex_plugin; fi
    ;;
  codex) install_codex ;;
  both)
    install_claude
    if [[ "$WITH_CODEX_PLUGIN" -eq 1 ]]; then install_codex_plugin; fi
    echo ""
    install_codex
    ;;
  *) echo "Unknown runtime: $RUNTIME" >&2; exit 1 ;;
esac
