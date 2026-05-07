#!/bin/bash
set -eo pipefail

# Stop hook: run type checking and related tests before Claude finishes.
# Only runs if JS/TS files were actually changed BY THIS SESSION.

# Source hook-lib for session-scoped file tracking
source "$(dirname "$0")/source-hook-lib.sh" 2>/dev/null || true

# Session-scoped: only check files this session touched
if type hook_session_changed_files &>/dev/null; then
  changed_files=$(hook_session_changed_files "ts|tsx")
else
  changed_files=$(git diff --name-only HEAD 2>/dev/null | grep -E '\.(ts|tsx)$' || true)
fi

if [ -z "$changed_files" ]; then
  exit 0
fi

# Skip if project doesn't have a type:check script
if [ ! -f "package.json" ] || ! jq -e '.scripts["type:check"]' package.json >/dev/null 2>&1; then
  exit 0
fi

# ── Type check (incremental for speed) ──────────────────────────
# tsgo/tsc cannot target single files — they need the full project graph.
# --incremental reuses .tsbuildinfo to skip unchanged modules.
output=""
exit_code=0
output=$(bun run type:check 2>&1) || exit_code=$?

if [ $exit_code -ne 0 ]; then
  # ── Filter errors to session-owned files ──────────────────────────
  # tsgo runs project-wide, so filter output to only errors in files
  # this session touched. Errors in sibling-session files pass through.
  if [ "$(hook_has_session_tracking 2>/dev/null && echo true || echo false)" = true ] && [ -n "$changed_files" ]; then
    _session_errors=$(hook_filter_errors_to_session "$output" "$changed_files")
    if [ -z "$_session_errors" ]; then
      # All errors are in files OTHER sessions touched — allow through
      echo "{\"decision\":\"allow\",\"reason\":\"Type errors exist but none in session files. Allow.\"}" >&2
      echo "typecheck FAIL (other session)" > "$_hook_session_dir/last-stop" 2>/dev/null || true
      exit 0
    fi
    # Show only this session's errors
    truncated=$(echo "$_session_errors" | head -30)
  else
    truncated=$(echo "$output" | head -30)
  fi

  # ── Baseline comparison (second filter layer) ────────────────────
  _baseline="$_hook_session_dir/typecheck-baseline"
  if [ -f "$_baseline" ]; then
    _current_errors=$(echo "$output" | grep -E '^.+\.(ts|tsx)\([0-9]+,' | sort)
    _new_errors=$(echo "$_current_errors" | comm -23 - "$_baseline" 2>/dev/null || echo "$_current_errors")

    # Apply session-file filter to new errors too
    if [ "$(hook_has_session_tracking 2>/dev/null && echo true || echo false)" = true ] && [ -n "$changed_files" ]; then
      _new_errors=$(hook_filter_errors_to_session "$_new_errors" "$changed_files")
    fi

    if [ -z "$_new_errors" ]; then
      _error_count=$(echo "$_current_errors" | wc -l | tr -d ' ')
      echo "{\"decision\":\"allow\",\"reason\":\"$_error_count pre-existing type error(s). Allow.\"}" >&2
      echo "typecheck FAIL (pre-existing only)" > "$_hook_session_dir/last-stop" 2>/dev/null || true
      exit 0
    fi

    truncated=$(echo "$_new_errors" | head -20)
    _new_count=$(echo "$_new_errors" | wc -l | tr -d ' ')
    hook_stop_finding "$(printf "Type errors (%s new):\n%s" "$_new_count" "$truncated")"
    echo "typecheck FAIL (new errors)" > "$_hook_session_dir/last-stop" 2>/dev/null || true
  fi

  # ── Fallback: no baseline available ──────────────────────────────
  if [ -z "${_new_errors+x}" ]; then
    # Only report if we didn't already handle via baseline comparison
    hook_stop_finding "$(printf "Type errors:\n%s" "$truncated")"
    echo "typecheck FAIL" > "$_hook_session_dir/last-stop" 2>/dev/null || true
  fi
fi

# ── Related tests (only tests affected by session's changed files) ──
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
abs_changed=""
for f in $changed_files; do
  abs_changed="$abs_changed $repo_root/$f"
done

test_output=""
test_exit=0

if [ -f "node_modules/.bin/vitest" ] || [ -f "$repo_root/node_modules/.bin/vitest" ]; then
  test_output=$(vitest run --related $abs_changed 2>&1) || test_exit=$?
elif [ -f "node_modules/.bin/jest" ] || [ -f "$repo_root/node_modules/.bin/jest" ]; then
  test_output=$(npx jest --findRelatedTests $abs_changed --passWithNoTests 2>&1) || test_exit=$?
else
  test_files=""
  for f in $changed_files; do
    base="${f%.*}"
    ext="${f##*.}"
    for suffix in test spec; do
      candidate="$repo_root/${base}.${suffix}.${ext}"
      [ -f "$candidate" ] && test_files="$test_files $candidate"
    done
  done
  if [ -n "$test_files" ]; then
    test_output=$(bun test $test_files 2>&1) || test_exit=$?
  fi
fi

if [ $test_exit -ne 0 ] && [ -n "$test_output" ]; then
  truncated=$(echo "$test_output" | tail -20)
  hook_stop_finding "$(printf "Related tests fail:\n%s" "$truncated")"
  echo "typecheck PASS, tests FAIL" > "$_hook_session_dir/last-stop" 2>/dev/null || true
  hook_stop_save_test_results "FAIL" "$test_output"
else
  echo "typecheck PASS, tests PASS" > "$_hook_session_dir/last-stop" 2>/dev/null || true
  hook_stop_save_test_results "PASS" "$test_output"
fi

exit 0
