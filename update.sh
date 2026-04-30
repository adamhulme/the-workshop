#!/usr/bin/env bash
# Update the-workshop's installed slash commands and agents.
#
# Behaviour:
#   1. Re-runs install.sh against the current source (script-dir if cloned,
#      else shallow-clones to a temp dir) — this overwrites any local edits
#      to installed skill files.
#   2. Diffs the previous manifest against the new one and removes files that
#      were installed by an earlier version of the workshop but are no longer
#      shipped (i.e. skills the workshop removed or renamed). Files the
#      workshop never installed are left alone.
#
# Local:
#   ./update.sh                    # user-scoped (~/.claude/{commands,agents}/)
#   ./update.sh --project          # project-scoped (./.claude/{commands,agents}/)
#
# Remote (curl-pipe-bash):
#   curl -fsSL https://raw.githubusercontent.com/adamhulme/the-workshop/main/update.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/adamhulme/the-workshop/main/update.sh | bash -s -- --project

set -euo pipefail

REPO_URL="https://github.com/adamhulme/the-workshop.git"
SCOPE=""
TARGET_BASE=""

usage() {
  cat <<USAGE
Update the-workshop's installed slash commands and agents.

Usage:
  update.sh [--user|--project]

  --user      Update the user-scoped install at ~/.claude/{commands,agents}/
  --project   Update the project-scoped install at ./.claude/{commands,agents}/

If neither flag is given, update.sh auto-detects the scope from existing
manifests and prefers --user when both exist.
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

# Auto-detect scope when neither flag was passed.
if [[ -z "$SCOPE" ]]; then
  if [[ -f "$HOME/.claude/.workshop-manifest" ]]; then
    SCOPE="user"
    TARGET_BASE="$HOME/.claude"
  elif [[ -f ".claude/.workshop-manifest" ]]; then
    SCOPE="project"
    TARGET_BASE=".claude"
  else
    echo "No workshop install detected at ~/.claude/ or ./.claude/." >&2
    echo "Run install.sh first, or pass --user / --project to update.sh." >&2
    exit 1
  fi
fi

if [[ ! -f "$TARGET_BASE/.workshop-manifest" ]]; then
  echo "No manifest at $TARGET_BASE/.workshop-manifest — this scope hasn't been" >&2
  echo "installed by a manifest-aware version of install.sh. Run install.sh first" >&2
  echo "(it will write the manifest), then re-run update.sh." >&2
  exit 1
fi

# Snapshot the existing manifest before install.sh overwrites it.
PREV_MANIFEST="$(mktemp)"
trap 'rm -f "$PREV_MANIFEST"' EXIT
grep -v '^#' "$TARGET_BASE/.workshop-manifest" | grep -v '^[[:space:]]*$' | LC_ALL=C sort > "$PREV_MANIFEST"

PREV_VERSION="unknown"
if [[ -f "$TARGET_BASE/.workshop-version" ]]; then
  PREV_VERSION="$(tr -d '[:space:]' < "$TARGET_BASE/.workshop-version")"
fi

# Resolve install.sh: prefer the colocated copy if running from a clone,
# otherwise shallow-clone to a temp dir.
INSTALL_SH=""
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  if [[ -f "$SCRIPT_DIR/install.sh" && -d "$SCRIPT_DIR/commands" ]]; then
    INSTALL_SH="$SCRIPT_DIR/install.sh"
  fi
fi

CLONE_TMP=""
if [[ -z "$INSTALL_SH" ]]; then
  if ! command -v git >/dev/null 2>&1; then
    echo "git is required when running update.sh via curl-pipe-bash. Install git, or clone the repo and run ./update.sh." >&2
    exit 1
  fi
  CLONE_TMP="$(mktemp -d)"
  trap 'rm -f "$PREV_MANIFEST"; rm -rf "$CLONE_TMP"' EXIT
  echo "Fetching the-workshop..."
  git clone --depth=1 "$REPO_URL" "$CLONE_TMP/repo" --quiet
  INSTALL_SH="$CLONE_TMP/repo/install.sh"
fi

echo "Updating from version $PREV_VERSION..."
echo ""

# Run install.sh in the resolved scope. It overwrites files (silent overwrite
# by design) and writes a fresh manifest.
bash "$INSTALL_SH" "--$SCOPE"

# Diff old manifest vs new. Anything in old-but-not-new was removed upstream
# and should be pruned from the install target.
NEW_MANIFEST="$(mktemp)"
trap 'rm -f "$PREV_MANIFEST" "$NEW_MANIFEST"; [[ -n "$CLONE_TMP" ]] && rm -rf "$CLONE_TMP"' EXIT
grep -v '^#' "$TARGET_BASE/.workshop-manifest" | grep -v '^[[:space:]]*$' | LC_ALL=C sort > "$NEW_MANIFEST"

PRUNED=0
while IFS= read -r relpath; do
  [[ -z "$relpath" ]] && continue
  full="$TARGET_BASE/$relpath"
  if [[ -f "$full" ]]; then
    rm -f "$full"
    echo "  pruned: $relpath (no longer in upstream)"
    PRUNED=$((PRUNED + 1))
  fi
done < <(comm -23 "$PREV_MANIFEST" "$NEW_MANIFEST")

NEW_VERSION="$(tr -d '[:space:]' < "$TARGET_BASE/.workshop-version" 2>/dev/null || echo unknown)"

echo ""
if [[ "$PRUNED" -gt 0 ]]; then
  echo "Pruned $PRUNED file(s) that were removed upstream."
fi
echo "Update complete: $PREV_VERSION → $NEW_VERSION ($SCOPE scope)."
