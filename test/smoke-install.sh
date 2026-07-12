#!/usr/bin/env bash
# Manual smoke test for install.sh/update.sh multi-runtime paths.
# Run from anywhere: bash test/smoke-install.sh
#
# Covers what CI doesn't: install.sh --both against a scratch project dir
# (idempotent re-run, both manifests present, expected trees installed) and
# update.sh's prune allowlist / traversal guard as pure-function checks
# (update.sh itself always clones from origin, so it isn't exercised
# end-to-end here — these checks pin the exact logic that was buggy).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILURES=0

fail() { echo "FAIL: $1" >&2; FAILURES=$((FAILURES + 1)); }
pass() { echo "ok: $1"; }

# --- install.sh --project --both, twice (idempotency) ---
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
(
  cd "$SCRATCH"
  bash "$REPO_ROOT/install.sh" --project --both >/dev/null
  bash "$REPO_ROOT/install.sh" --project --both >/dev/null
)

[[ -f "$SCRATCH/.claude/.workshop-manifest" ]] && pass "claude manifest written" || fail "claude manifest missing"
[[ -f "$SCRATCH/.codex/the-workshop/.workshop-manifest" ]] && pass "codex manifest written" || fail "codex manifest missing"
[[ -f "$SCRATCH/.claude/commands/plan.md" ]] && pass "claude commands installed" || fail "claude commands/plan.md missing"
[[ -f "$SCRATCH/.codex/the-workshop/skills/plan.md" ]] && pass "codex skills installed" || fail "codex skills/plan.md missing"
[[ -f "$SCRATCH/.codex/the-workshop/core/workflows/plan.md" ]] && pass "core tree installed under codex target" || fail "core/workflows/plan.md missing"
[[ -f "$SCRATCH/.codex/the-workshop/WORKSHOP.md" ]] && pass "WORKSHOP.md installed" || fail "WORKSHOP.md missing"

claude_manifest_lines=$(wc -l < "$SCRATCH/.claude/.workshop-manifest")
codex_manifest_lines=$(wc -l < "$SCRATCH/.codex/the-workshop/.workshop-manifest")
( cd "$SCRATCH" && bash "$REPO_ROOT/install.sh" --project --both >/dev/null 2>&1 )
if [[ "$(wc -l < "$SCRATCH/.claude/.workshop-manifest")" -eq "$claude_manifest_lines" ]]; then
  pass "re-running install.sh is idempotent (claude manifest line count stable)"
else
  fail "re-running install.sh changed claude manifest line count"
fi
if [[ "$(wc -l < "$SCRATCH/.codex/the-workshop/.workshop-manifest")" -eq "$codex_manifest_lines" ]]; then
  pass "re-running install.sh is idempotent (codex manifest line count stable)"
else
  fail "re-running install.sh changed codex manifest line count"
fi

# --- optional OpenAI Codex plugin install path ---
MOCK_BIN="$SCRATCH/mock-bin"
CLAUDE_TEST_LOG="$SCRATCH/claude-plugin-calls.log"
mkdir -p "$MOCK_BIN"
cp "$REPO_ROOT/test/fixtures/claude" "$MOCK_BIN/claude"
chmod +x "$MOCK_BIN/claude"

# fresh machine: no marketplace, no plugin
(
  cd "$SCRATCH"
  PATH="$MOCK_BIN:$PATH" CLAUDE_TEST_LOG="$CLAUDE_TEST_LOG" \
    bash "$REPO_ROOT/install.sh" --project --claude --with-codex-plugin >/dev/null
)
grep -qx 'plugin marketplace add openai/codex-plugin-cc --scope project' "$CLAUDE_TEST_LOG" \
  && pass "Codex plugin marketplace added at project scope" \
  || fail "Codex plugin marketplace add was not scoped to the project"
grep -qx 'plugin install codex@openai-codex --scope project' "$CLAUDE_TEST_LOG" \
  && pass "Codex plugin installed at project scope" \
  || fail "Codex plugin install was not scoped to the project"
if grep -qx 'plugin update codex@openai-codex --scope project' "$CLAUDE_TEST_LOG"; then
  fail "fresh install ran plugin update (install alone should suffice)"
else
  pass "fresh install skips plugin update"
fi

# marketplace and plugin already present: refresh only, no add / reinstall
CLAUDE_TEST_LOG_RERUN="$SCRATCH/claude-plugin-calls-rerun.log"
(
  cd "$SCRATCH"
  PATH="$MOCK_BIN:$PATH" CLAUDE_TEST_LOG="$CLAUDE_TEST_LOG_RERUN" \
    CLAUDE_TEST_MARKETPLACES='[{"name": "openai-codex", "source": {"source": "github", "repo": "openai/codex-plugin-cc"}}]' \
    CLAUDE_TEST_PLUGINS='[{"name": "codex", "version": "0.1.0"}]' \
    bash "$REPO_ROOT/install.sh" --project --claude --with-codex-plugin >/dev/null
)
grep -qx 'plugin marketplace update openai-codex' "$CLAUDE_TEST_LOG_RERUN" \
  && pass "existing marketplace refreshed on re-run" \
  || fail "existing marketplace was not refreshed on re-run"
grep -qx 'plugin update codex@openai-codex --scope project' "$CLAUDE_TEST_LOG_RERUN" \
  && pass "existing plugin updated on re-run" \
  || fail "existing plugin was not updated on re-run"
if grep -qxE 'plugin (marketplace add|install) .*' "$CLAUDE_TEST_LOG_RERUN"; then
  fail "re-run re-added the marketplace or reinstalled the plugin"
else
  pass "re-run skips marketplace add and plugin install"
fi

# same-named marketplace from a different source: refuse to install
if (
  cd "$SCRATCH"
  PATH="$MOCK_BIN:$PATH" CLAUDE_TEST_LOG="$SCRATCH/claude-plugin-calls-impostor.log" \
    CLAUDE_TEST_MARKETPLACES='[{"name": "openai-codex", "source": {"source": "github", "repo": "not-openai/impostor"}}]' \
    bash "$REPO_ROOT/install.sh" --project --claude --with-codex-plugin >/dev/null 2>&1
); then
  fail "impostor openai-codex marketplace was accepted"
else
  pass "impostor openai-codex marketplace is rejected"
fi

if bash "$REPO_ROOT/install.sh" --project --codex --with-codex-plugin >/dev/null 2>&1; then
  fail "Codex-only adapter accepted --with-codex-plugin"
else
  pass "Codex-only adapter rejects Claude plugin flag"
fi

# --- update.sh prune allowlist + traversal + symlink-escape guards (pure-function checks) ---
eval "$(sed -n '/^resolves_within/,/^}/p' "$REPO_ROOT/update.sh")"
eval "$(sed -n '/^has_dotdot_segment/,/^}/p' "$REPO_ROOT/update.sh")"
eval "$(sed -n '/^allowed_re_for/,/^}/p' "$REPO_ROOT/update.sh")"

check_allowed() {
  local runtime="$1" relpath="$2" want="$3" re got
  re="$(allowed_re_for "$runtime")"
  if [[ "$relpath" =~ $re ]] && ! has_dotdot_segment "$relpath"; then got="allow"; else got="block"; fi
  if [[ "$got" == "$want" ]]; then
    pass "$runtime prune: $relpath -> $got"
  else
    fail "$runtime prune: $relpath -> $got (expected $want)"
  fi
}

check_allowed codex "core/rubrics/pr-reviewer.md" allow
check_allowed codex "skills/design-capture.md" allow
check_allowed codex "WORKSHOP.md" allow
check_allowed codex "core/../../../etc/cron.d/evil.md" block
check_allowed codex "agents/../../../root/.ssh/authorized_keys.md" block
check_allowed claude "commands/plan.md" allow
check_allowed claude "hooks/diet-read.sh" allow
check_allowed claude "commands/../../../etc/passwd" block

# --- resolves_within: symlinked intermediate directory can't escape target_base ---
SYMLINK_TEST="$(mktemp -d)"
trap 'rm -rf "$SCRATCH" "$SYMLINK_TEST"' EXIT
mkdir -p "$SYMLINK_TEST/target/core/workflows" "$SYMLINK_TEST/outside"
touch "$SYMLINK_TEST/target/core/workflows/legit.md" "$SYMLINK_TEST/outside/evil.md"
if resolves_within "$SYMLINK_TEST/target/core/workflows/legit.md" "$SYMLINK_TEST/target"; then
  pass "resolves_within: ordinary nested path stays inside target_base"
else
  fail "resolves_within: ordinary nested path incorrectly rejected"
fi
rm -rf "$SYMLINK_TEST/target/core"
ln -s "$SYMLINK_TEST/outside" "$SYMLINK_TEST/target/core"
if resolves_within "$SYMLINK_TEST/target/core/evil.md" "$SYMLINK_TEST/target"; then
  fail "resolves_within: symlinked directory escaped target_base undetected"
else
  pass "resolves_within: symlinked directory correctly blocked from escaping target_base"
fi

echo ""
if [[ "$FAILURES" -eq 0 ]]; then
  echo "All smoke checks passed."
else
  echo "$FAILURES smoke check(s) failed." >&2
  exit 1
fi
