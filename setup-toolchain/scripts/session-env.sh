#!/bin/bash
set -euo pipefail

# Guard: CLAUDE_ENV_FILE may not exist during /clear-triggered SessionStart
CLAUDE_ENV_FILE="${CLAUDE_ENV_FILE:-}"

# ── Frontend project detection ───────────────────────────────────
# These skills are for React/TypeScript frontend projects.
# Warn if installed in the wrong directory (backend, Go, root of monorepo).

# Skip warning in the ui-harness repo itself (hook authoring project, not a frontend app)
_repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || true)
if [ ! -f "package.json" ] && [ "$_repo_name" != "ui-harness" ]; then
  echo '{"hookSpecificOutput":{"additionalContext":"WARNING: No package.json. Skills need React+TS frontend. Monorepo? Install in app dir (apps/web-ui/)."}}' >&2
fi

if [ -f "package.json" ] && ! grep -qE '"react"|"react-dom"' package.json 2>/dev/null; then
  echo '{"hookSpecificOutput":{"additionalContext":"WARNING: No React in package.json. Some hooks may not apply."}}' >&2
fi

# Set environment variables for LLM-friendly defaults
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo "export PKG_MANAGER=bun" >> "$CLAUDE_ENV_FILE"
  echo "export LINTER=biome" >> "$CLAUDE_ENV_FILE"
  echo "export TEST_RUNNER=vitest" >> "$CLAUDE_ENV_FILE"

  # Prevent OOM on large test suites, builds, and type checks
  echo "export NODE_OPTIONS=--max-old-space-size=8192" >> "$CLAUDE_ENV_FILE"
fi

# Clean up stale session directories from previous sessions (safe: /tmp/ only, specific prefix)
# Clean up stale session directories from both harnesses
find /tmp -maxdepth 1 -name "hook-session-*" -type d -mmin +60 -exec rm -r {} + 2>/dev/null || true

# ── Session directory for state tracking ──────────────────────────
_session_dir="/tmp/hook-session-${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-$$}}"
mkdir -p "$_session_dir" 2>/dev/null || true

# ── Capture dirty-files baseline (which files are already uncommitted) ──
# Used by Stop hooks to exclude files dirty before this session started.
git diff --name-only HEAD > "$_session_dir/dirty-files-baseline" 2>/dev/null || touch "$_session_dir/dirty-files-baseline"

# ── Emit hook safety context (for auto mode awareness) ───────────
# Counts active PostToolUse and Stop hooks so Claude (and auto mode
# classifier) knows guardrails are in place. Reduces over-cautious
# permission prompts during compound workflows.
_settings="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/settings.json"
if [ -f "$_settings" ] && command -v jq >/dev/null 2>&1; then
  _post_count=$(jq '[.hooks.PostToolUse[]?.hooks // [] | length] | add // 0' "$_settings" 2>/dev/null || echo 0)
  _stop_count=$(jq '[.hooks.Stop[]?.hooks // [] | length] | add // 0' "$_settings" 2>/dev/null || echo 0)
  _pre_count=$(jq '[.hooks.PreToolUse[]?.hooks // [] | length] | add // 0' "$_settings" 2>/dev/null || echo 0)
  echo "{\"hookSpecificOutput\":{\"additionalContext\":\"[GUARDRAILS] ${_post_count} PostToolUse + ${_pre_count} PreToolUse + ${_stop_count} Stop hooks active. Auto mode safe.\"}}" >&2
fi

# ── Capture typecheck baseline (opt-out, background, no latency) ─
# Used by typecheck-stop.sh to distinguish pre-existing errors from
# errors introduced by this session. Runs in background so SessionStart
# returns immediately. Opt out with CAPTURE_TYPECHECK_BASELINE=0 on
# battery or for question-only sessions.
if [ "${CAPTURE_TYPECHECK_BASELINE:-1}" != "0" ] \
  && [ -f "package.json" ] \
  && jq -e '.scripts["type:check"]' package.json >/dev/null 2>&1; then
  (bun run type:check 2>&1 | grep -E '^.+\.(ts|tsx)\([0-9]+,' | sort > "$_session_dir/typecheck-baseline" 2>/dev/null || touch "$_session_dir/typecheck-baseline") &
fi

# ── Capture test timing baseline (opt-in; expensive) ─────────────
# Used by test-perf-stop.sh to detect test performance changes.
# Full vitest run is heavy (10s–2min depending on suite) — default OFF.
# Opt in with CAPTURE_TEST_BASELINE=1 for sessions that will edit tests.
if [ "${CAPTURE_TEST_BASELINE:-0}" = "1" ]; then
  _vitest_configs=$(find . -maxdepth 1 -name 'vitest.config.*' 2>/dev/null | head -5)
  if [ -n "$_vitest_configs" ] && command -v jq >/dev/null 2>&1; then
    (
      : > "$_session_dir/test-timing-baseline.tsv"
      for cfg in $_vitest_configs; do
        bun vitest --run --reporter=json --config "$cfg" 2>/dev/null \
          | jq -r '.testResults[]?.assertionResults[]? | [.fullName, (.duration // 0 | tostring)] | @tsv' \
          >> "$_session_dir/test-timing-baseline.tsv" 2>/dev/null || true
      done
    ) &
  fi
fi

exit 0
