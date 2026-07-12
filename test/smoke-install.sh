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

# --- live Claude CLI contract checks (read-only; skip when unavailable) ---
if command -v claude >/dev/null 2>&1; then
  CLAUDE_MARKETPLACE_ADD_HELP="$(claude plugin marketplace add --help)"
  CLAUDE_PLUGIN_UPDATE_HELP="$(claude plugin update --help)"
  grep -q -- '--scope' <<< "$CLAUDE_MARKETPLACE_ADD_HELP" \
    && pass "Claude marketplace add supports --scope" \
    || fail "Claude marketplace add no longer supports --scope"
  grep -q -- '--scope' <<< "$CLAUDE_PLUGIN_UPDATE_HELP" \
    && pass "Claude plugin update supports --scope" \
    || fail "Claude plugin update no longer supports --scope"

  CLAUDE_LIVE_PLUGINS="$(claude plugin list --json 2>/dev/null || printf '[]')"
  if grep -Fq 'codex@openai-codex' <<< "$CLAUDE_LIVE_PLUGINS"; then
    CLAUDE_CODEX_DETAILS="$(claude plugin details codex@openai-codex 2>/dev/null || true)"
    grep -Eq 'Agents \([0-9]+\).*codex-rescue' <<< "$CLAUDE_CODEX_DETAILS" \
      && pass "installed Codex plugin still exposes codex-rescue" \
      || fail "installed Codex plugin no longer exposes codex-rescue"

    CLAUDE_CODEX_ROOT="$(node -e 'const fs=require("fs"); const ps=JSON.parse(fs.readFileSync(0,"utf8")); const p=ps.find(x=>x.id==="codex@openai-codex"); if(p) process.stdout.write(p.installPath)' <<< "$CLAUDE_LIVE_PLUGINS")"
    if command -v cygpath >/dev/null 2>&1 && [[ "$CLAUDE_CODEX_ROOT" =~ ^[A-Za-z]:\\ ]]; then
      CLAUDE_CODEX_ROOT="$(cygpath -u "$CLAUDE_CODEX_ROOT")"
    fi
    if [[ -n "$CLAUDE_CODEX_ROOT" && -f "$CLAUDE_CODEX_ROOT/commands/rescue.md" ]]; then
      for flag in --wait --fresh --effort; do
        grep -q -- "$flag" "$CLAUDE_CODEX_ROOT/commands/rescue.md" \
          && pass "installed Codex rescue command still documents $flag" \
          || fail "installed Codex rescue command no longer documents $flag"
      done
    else
      fail "installed Codex plugin path or rescue command is unavailable"
    fi
  else
    pass "Codex plugin surface check skipped (plugin not installed)"
  fi
else
  pass "live Claude CLI contract checks skipped (claude unavailable)"
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
    CLAUDE_TEST_MARKETPLACES='[{"name": "openai-codex", "source": "github", "repo": "openai/codex-plugin-cc"}]' \
    CLAUDE_TEST_PLUGINS='[{"id": "codex@openai-codex", "version": "1.0.6", "scope": "project", "enabled": true}]' \
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
    CLAUDE_TEST_MARKETPLACES='[{"name": "openai-codex", "source": "github", "repo": "not-openai/impostor"}]' \
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
eval "$(sed -n '/^install_args_for/,/^}/p' "$REPO_ROOT/update.sh")"

SCOPE="project"
WITH_CODEX_PLUGIN=1
UPDATE_INSTALL_ARGS=()
while IFS= read -r arg; do UPDATE_INSTALL_ARGS+=("$arg"); done < <(install_args_for claude)
if [[ "${UPDATE_INSTALL_ARGS[*]}" == "--project --claude --with-codex-plugin" ]]; then
  pass "update.sh forwards --with-codex-plugin to the Claude installer leg"
else
  fail "update.sh Claude installer args were: ${UPDATE_INSTALL_ARGS[*]}"
fi
UPDATE_INSTALL_ARGS=()
while IFS= read -r arg; do UPDATE_INSTALL_ARGS+=("$arg"); done < <(install_args_for codex)
if [[ "${UPDATE_INSTALL_ARGS[*]}" == "--project --codex" ]]; then
  pass "update.sh does not forward the Claude plugin flag to the Codex leg"
else
  fail "update.sh Codex installer args were: ${UPDATE_INSTALL_ARGS[*]}"
fi

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
if [[ ! -L "$SYMLINK_TEST/target/core" ]]; then
  pass "resolves_within: symlink-escape check skipped (native symlinks unavailable)"
elif resolves_within "$SYMLINK_TEST/target/core/evil.md" "$SYMLINK_TEST/target"; then
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
