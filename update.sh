#!/usr/bin/env bash
# Update the-workshop's installed runtime adapters.
#
# Behaviour:
#   1. Always shallow-clones the latest main from origin into a temp dir and
#      runs install.sh from there.
#   2. Overwrites installed workshop adapter files.
#   3. Diffs the previous manifest against the new one and prunes files that
#      were installed by an earlier version but are no longer shipped.
#   4. Supports Claude, Codex, or both runtimes. Manifests are scoped to each
#      runtime target, so one adapter cannot prune the other.

set -euo pipefail

REPO_URL="https://github.com/adamhulme/the-workshop.git"
SCOPE=""
RUNTIME=""
WITH_CODEX_PLUGIN=0
CLAUDE_TARGET_BASE=""
CODEX_TARGET_BASE=""

usage() {
  cat <<USAGE
Update the-workshop adapters.

Usage:
  update.sh [--user|--project] [--claude|--codex|--both] [--with-codex-plugin]

  --user      Update user-scoped install(s)
  --project   Update project-scoped install(s)
  --claude    Update Claude Code adapter
  --codex     Update Codex adapter
  --both      Update both adapters
  --with-codex-plugin
              Also install or refresh OpenAI's Codex plugin for Claude Code

If no scope is given, update.sh auto-detects user vs project manifests and
prefers user when both exist. If no runtime is given, it updates every detected
runtime, or Claude by default for backwards compatibility.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) SCOPE="project"; shift ;;
    --user)    SCOPE="user"; shift ;;
    --claude)  RUNTIME="claude"; shift ;;
    --codex)   RUNTIME="codex"; shift ;;
    --both)    RUNTIME="both"; shift ;;
    --with-codex-plugin) WITH_CODEX_PLUGIN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; usage; exit 1 ;;
  esac
done

set_targets() {
  if [[ "$SCOPE" == "project" ]]; then
    CLAUDE_TARGET_BASE=".claude"
    CODEX_TARGET_BASE=".codex/the-workshop"
  else
    CLAUDE_TARGET_BASE="$HOME/.claude"
    CODEX_TARGET_BASE="$HOME/.codex/the-workshop"
  fi
}

if [[ -z "$SCOPE" ]]; then
  if [[ -f "$HOME/.claude/.workshop-manifest" || -f "$HOME/.codex/the-workshop/.workshop-manifest" ]]; then
    SCOPE="user"
  elif [[ -f ".claude/.workshop-manifest" || -f ".codex/the-workshop/.workshop-manifest" ]]; then
    SCOPE="project"
  else
    SCOPE="user"
  fi
fi
set_targets

if [[ -z "$RUNTIME" ]]; then
  detected=()
  [[ -f "$CLAUDE_TARGET_BASE/.workshop-manifest" ]] && detected+=("claude")
  [[ -f "$CODEX_TARGET_BASE/.workshop-manifest" ]] && detected+=("codex")
  if [[ "${#detected[@]}" -eq 0 ]]; then
    RUNTIME="claude"
  elif [[ "${#detected[@]}" -eq 2 ]]; then
    RUNTIME="both"
  else
    RUNTIME="${detected[0]}"
  fi
fi

if [[ "$WITH_CODEX_PLUGIN" -eq 1 && "$RUNTIME" == "codex" ]]; then
  echo "--with-codex-plugin requires the Claude adapter (--claude or --both)." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required to update the-workshop. Install git and re-run." >&2
  exit 1
fi

CLONE_TMP="$(mktemp -d)"
trap 'rm -rf "$CLONE_TMP"' EXIT
echo "Fetching latest the-workshop..."
git clone --depth=1 "$REPO_URL" "$CLONE_TMP/repo" --quiet
INSTALL_SH="$CLONE_TMP/repo/install.sh"

runtime_target() {
  case "$1" in
    claude) printf '%s\n' "$CLAUDE_TARGET_BASE" ;;
    codex) printf '%s\n' "$CODEX_TARGET_BASE" ;;
    *) echo "Unknown runtime: $1" >&2; exit 1 ;;
  esac
}

allowed_re_for() {
  case "$1" in
    claude) printf '%s\n' '^(commands|agents)/[A-Za-z0-9._-]+\.md$|^hooks/[A-Za-z0-9._-]+\.sh$' ;;
    codex) printf '%s\n' '^(skills|agents|core)(/[A-Za-z0-9._-]+)+\.md$|^WORKSHOP\.md$' ;;
    *) echo "Unknown runtime: $1" >&2; exit 1 ;;
  esac
}

resolves_within() {
  local full="$1" base="$2"
  local resolved_dir resolved_base
  resolved_dir="$(cd "$(dirname "$full")" 2>/dev/null && pwd -P)" || return 1
  resolved_base="$(cd "$base" 2>/dev/null && pwd -P)" || return 1
  case "$resolved_dir" in
    "$resolved_base"|"$resolved_base"/*) return 0 ;;
    *) return 1 ;;
  esac
}

has_dotdot_segment() {
  local relpath="$1" seg
  IFS='/' read -ra segs <<< "$relpath"
  for seg in "${segs[@]}"; do
    [[ "$seg" == "." || "$seg" == ".." ]] && return 0
  done
  return 1
}

update_one() {
  local runtime="$1"
  local target_base
  target_base="$(runtime_target "$runtime")"
  local prev_manifest new_manifest
  prev_manifest="$(mktemp)"
  new_manifest="$(mktemp)"
  local had_prev=0
  local prev_version="unknown"
  local pruned=0
  local skipped=0

  if [[ -f "$target_base/.workshop-manifest" ]]; then
    had_prev=1
    grep -v '^#' "$target_base/.workshop-manifest" | grep -v '^[[:space:]]*$' | LC_ALL=C sort > "$prev_manifest"
  fi
  if [[ -f "$target_base/.workshop-version" ]]; then
    prev_version="$(tr -d '[:space:]' < "$target_base/.workshop-version")"
  fi

  echo "Updating $runtime adapter from version $prev_version..."
  echo ""
  local install_args=("--$SCOPE" "--$runtime")
  if [[ "$runtime" == "claude" && "$WITH_CODEX_PLUGIN" -eq 1 ]]; then
    install_args+=("--with-codex-plugin")
  fi
  bash "$INSTALL_SH" "${install_args[@]}"

  if [[ "$had_prev" -eq 1 ]]; then
    grep -v '^#' "$target_base/.workshop-manifest" | grep -v '^[[:space:]]*$' | LC_ALL=C sort > "$new_manifest"
    local allowed_re
    allowed_re="$(allowed_re_for "$runtime")"
    while IFS= read -r relpath; do
      [[ -z "$relpath" ]] && continue
      if [[ ! "$relpath" =~ $allowed_re ]] || has_dotdot_segment "$relpath"; then
        echo "  skipped: $relpath (manifest entry outside expected $runtime shape; not pruning)" >&2
        skipped=$((skipped + 1))
        continue
      fi
      local full="$target_base/$relpath"
      if [[ -f "$full" ]]; then
        if resolves_within "$full" "$target_base"; then
          rm -f "$full"
          echo "  pruned: $relpath (no longer in upstream)"
          pruned=$((pruned + 1))
        else
          echo "  skipped: $relpath (resolves outside install target via symlink; not pruning)" >&2
          skipped=$((skipped + 1))
        fi
      fi
    done < <(comm -23 "$prev_manifest" "$new_manifest")
  fi

  local new_version
  new_version="$(tr -d '[:space:]' < "$target_base/.workshop-version" 2>/dev/null || echo unknown)"
  echo ""
  [[ "$pruned" -gt 0 ]] && echo "Pruned $pruned $runtime file(s) that were removed upstream."
  [[ "$skipped" -gt 0 ]] && echo "Skipped $skipped $runtime manifest entr(y/ies) outside the expected shape." >&2
  echo "Update complete: $prev_version → $new_version ($SCOPE scope, $runtime)."
  echo ""
  rm -f "$prev_manifest" "$new_manifest"
}

case "$RUNTIME" in
  claude) update_one claude ;;
  codex) update_one codex ;;
  both) update_one claude; update_one codex ;;
  *) echo "Unknown runtime: $RUNTIME" >&2; exit 1 ;;
esac
