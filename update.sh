#!/usr/bin/env bash
# Update the-workshop's installed slash commands and agents.
#
# Behaviour:
#   1. Always shallow-clones the latest main from origin into a temp dir and
#      runs install.sh from there — this is the whole point of "update", so
#      it never trusts a local clone (which may be stale). If you want to
#      install from a local checkout instead, run install.sh directly.
#   2. Overwrites any local edits to installed skill files (silent overwrite).
#   3. Diffs the previous manifest against the new one and removes files that
#      were installed by an earlier version of the workshop but are no longer
#      shipped (i.e. skills the workshop removed or renamed). Manifest entries
#      are validated against the expected commands/*.md / agents/*.md shape
#      before any rm; anything else is logged and skipped. Files the workshop
#      never installed are left alone.
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

# Always shallow-clone the latest main from origin. update.sh is by
# definition "pull latest from upstream" — running it from a stale local
# clone and reinstalling the same stale files would silently no-op.
if ! command -v git >/dev/null 2>&1; then
  echo "git is required to update the-workshop. Install git and re-run." >&2
  exit 1
fi

CLONE_TMP="$(mktemp -d)"
trap 'rm -f "$PREV_MANIFEST"; rm -rf "$CLONE_TMP"' EXIT
echo "Fetching latest the-workshop..."
git clone --depth=1 "$REPO_URL" "$CLONE_TMP/repo" --quiet
INSTALL_SH="$CLONE_TMP/repo/install.sh"

echo "Updating from version $PREV_VERSION..."
echo ""

# Run install.sh in the resolved scope. It overwrites files (silent overwrite
# by design) and writes a fresh manifest.
bash "$INSTALL_SH" "--$SCOPE"

# Diff old manifest vs new. Anything in old-but-not-new was removed upstream
# and should be pruned from the install target.
NEW_MANIFEST="$(mktemp)"
trap 'rm -f "$PREV_MANIFEST" "$NEW_MANIFEST"; rm -rf "$CLONE_TMP"' EXIT
grep -v '^#' "$TARGET_BASE/.workshop-manifest" | grep -v '^[[:space:]]*$' | LC_ALL=C sort > "$NEW_MANIFEST"

PRUNED=0
SKIPPED=0
# Only allow pruning of paths matching the exact commands/<name>.md or
# agents/<name>.md shape. A tampered manifest containing .., absolute paths,
# or anything outside this shape is rejected outright — never trust
# manifest-supplied paths to construct an rm target without re-validating.
ALLOWED_RE='^(commands|agents)/[A-Za-z0-9._-]+\.md$'
while IFS= read -r relpath; do
  [[ -z "$relpath" ]] && continue
  if [[ ! "$relpath" =~ $ALLOWED_RE ]]; then
    echo "  skipped: $relpath (manifest entry outside expected shape; not pruning)" >&2
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
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
if [[ "$SKIPPED" -gt 0 ]]; then
  echo "Skipped $SKIPPED manifest entr(y/ies) that fell outside the expected shape — see warnings above." >&2
fi
echo "Update complete: $PREV_VERSION → $NEW_VERSION ($SCOPE scope)."
