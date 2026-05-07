#!/bin/bash
set -euo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

# PostToolUse on Bash: detect consecutive same-type failures.
# After 3+ truly consecutive failures of same type (lint, build, test, typecheck),
# inject "read ALL errors, fix ALL at once" guidance.

# Read stdin directly — hook_parse_bash not used because we also need exit_code
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null || true)

if [ "$tool_name" != "Bash" ]; then
  exit 0
fi

exit_code=$(echo "$input" | jq -r '.tool_result.exit_code // "0"' 2>/dev/null || echo "0")

# Short-circuit: most Bash calls succeed — skip classification entirely
if [ "$exit_code" = "0" ]; then
  # On success, clear the last-type tracker
  rm -f "$_hook_session_dir/last-fail-type" "$_hook_session_dir/fail-streak" 2>/dev/null
  exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

# Classify command type with single combined regex
_cmd_type=$(echo "$command" | grep -oE 'lint|biome|ultracite|type:check|typecheck|tsgo|tsc|vitest|jest|bun test|build|rsbuild|webpack|vite build' | head -1 || true)

# Normalize to category
case "$_cmd_type" in
  lint|biome|ultracite) _cmd_type="lint" ;;
  type:check|typecheck|tsgo|tsc) _cmd_type="typecheck" ;;
  vitest|jest|"bun test") _cmd_type="test" ;;
  build|rsbuild|webpack|"vite build") _cmd_type="build" ;;
  *) exit 0 ;;
esac

# Track truly consecutive failures (same type in a row)
_last_type=$(cat "$_hook_session_dir/last-fail-type" 2>/dev/null || true)
_streak=$(cat "$_hook_session_dir/fail-streak" 2>/dev/null || echo "0")
_streak=$(echo "$_streak" | tr -d '[:space:]')

if [ "$_cmd_type" = "$_last_type" ]; then
  _streak=$((_streak + 1))
else
  _streak=1
fi

echo "$_cmd_type" > "$_hook_session_dir/last-fail-type" 2>/dev/null
echo "$_streak" > "$_hook_session_dir/fail-streak" 2>/dev/null

if [ "$_streak" -ge 3 ]; then
  _hook_log_entry "warn" "consecutive-failure"
  echo "{\"suppressOutput\":true,\"systemMessage\":\"${_cmd_type} failed ${_streak}x in a row. STOP. Read ALL errors in the output. Fix ALL of them at once. Then run the check ONE time.\"}" >&2
fi

exit 0
