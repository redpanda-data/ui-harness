#!/bin/bash
set -euo pipefail

# Stop hook for Codex: batch-run all PostToolUse Edit|Write checks on changed files.
# Codex doesn't support Edit|Write matchers, so we run them at Stop instead.

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Source hook-lib for session-scoped file tracking (baseline-only for Codex)
source "$repo_root/.claude/hooks/_hook-lib.sh" 2>/dev/null || \
  source "$(dirname "$0")/../../shared/hook-lib.sh" 2>/dev/null || true

# Paths to exclude from stop-hook checks (vendor, generated, build artifacts)
_exclude_pattern='(opensrc/|dist/|coverage/|playwright-report/|test-results/|node_modules/|\.gen\.(ts|tsx)$|_pb\.(ts|js)$|_connectquery\.ts$|/protogen/)'

# Session-scoped: only check files this session touched
if type hook_session_changed_files &>/dev/null; then
  _all_session=$(hook_session_changed_files | grep -vE "$_exclude_pattern" || true)
  changed_js=$(echo "$_all_session" | grep -E '\.(js|jsx|ts|tsx|mjs|mts|cjs|cts)$' || true)
  changed_css=$(echo "$_all_session" | grep -E '\.(css|scss|sass|less)$' || true)
  changed_pkg=$(echo "$_all_session" | grep -E 'package\.json$' || true)
else
  _all_diff=$(git diff --name-only HEAD 2>/dev/null | grep -vE "$_exclude_pattern" || true)
  changed_js=$(echo "$_all_diff" | grep -E '\.(js|jsx|ts|tsx|mjs|mts|cjs|cts)$' || true)
  changed_css=$(echo "$_all_diff" | grep -E '\.(css|scss|sass|less)$' || true)
  changed_pkg=$(echo "$_all_diff" | grep -E 'package\.json$' || true)
fi

if [ -z "$changed_js" ] && [ -z "$changed_css" ] && [ -z "$changed_pkg" ]; then
  exit 0
fi

# Collect all PostToolUse hook scripts from .claude/hooks/
hooks_dir="$repo_root/.claude/hooks"
if [ ! -d "$hooks_dir" ]; then
  exit 0
fi

errors=""

# Run each *-check.sh hook on each changed JS/TS file
for file in $changed_js; do
  abs_path="$repo_root/$file"
  [ -f "$abs_path" ] || continue

  for hook in "$hooks_dir"/*-check.sh; do
    [ -x "$hook" ] || continue
    hook_name=$(basename "$hook")

    # Skip tailwind-check on JS/TS files that aren't TSX/JSX
    if [ "$hook_name" = "tailwind-check.sh" ]; then
      case "$file" in
        *.tsx|*.jsx) ;; # run it
        *) continue ;;  # skip for plain .ts/.js
      esac
    fi

    input="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$abs_path\"}}"

    hook_stderr=""
    hook_exit=0
    hook_stderr=$(echo "$input" | "$hook" 2>&1 >/dev/null) || hook_exit=$?

    if [ $hook_exit -ne 0 ] && [ -n "$hook_stderr" ]; then
      msg=$(echo "$hook_stderr" | grep -o '"systemMessage":"[^"]*"' | head -1 | sed 's/"systemMessage":"//;s/"$//' || true)
      if [ -n "$msg" ]; then
        errors="$errors\n[$hook_name] $file: $msg"
      fi
    fi
  done
done

# Run tailwind-check.sh on changed CSS/SCSS files
if [ -n "$changed_css" ] && [ -x "$hooks_dir/tailwind-check.sh" ]; then
  for file in $changed_css; do
    abs_path="$repo_root/$file"
    [ -f "$abs_path" ] || continue

    input="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$abs_path\"}}"
    hook_stderr=""
    hook_exit=0
    hook_stderr=$(echo "$input" | "$hooks_dir/tailwind-check.sh" 2>&1 >/dev/null) || hook_exit=$?

    if [ $hook_exit -ne 0 ] && [ -n "$hook_stderr" ]; then
      msg=$(echo "$hook_stderr" | grep -o '"systemMessage":"[^"]*"' | head -1 | sed 's/"systemMessage":"//;s/"$//' || true)
      if [ -n "$msg" ]; then
        errors="$errors\n[tailwind-check] $file: $msg"
      fi
    fi
  done
fi

# Run bundle-guard on changed package.json files
if [ -n "$changed_pkg" ] && [ -x "$hooks_dir/bundle-guard.sh" ]; then
  for pkg in $changed_pkg; do
    abs_path="$repo_root/$pkg"
    [ -f "$abs_path" ] || continue

    input="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$abs_path\"}}"
    hook_stderr=""
    hook_exit=0
    hook_stderr=$(echo "$input" | "$hooks_dir/bundle-guard.sh" 2>&1 >/dev/null) || hook_exit=$?

    if [ $hook_exit -ne 0 ] && [ -n "$hook_stderr" ]; then
      msg=$(echo "$hook_stderr" | grep -o '"systemMessage":"[^"]*"' | head -1 | sed 's/"systemMessage":"//;s/"$//' || true)
      if [ -n "$msg" ]; then
        errors="$errors\n[bundle-guard] $pkg: $msg"
      fi
    fi
  done
fi

# ── Orchestration gates (same as orchestration-stop.sh) ──────────

# Gate: New source files without co-located tests
new_files=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep -vE "$_exclude_pattern" | grep -E '\.(ts|tsx)$' | grep -vE '(\.test\.|\.spec\.|\.unit\.|\.integration\.|\.d\.ts$|\.gen\.|index\.|layout\.|middleware\.|types/|__root|providers?\.|constants?\.|theme\.|context\.|config\.)' || true)
if [ -n "$new_files" ]; then
  for f in $new_files; do
    base="${f%.*}"
    has_test=false
    for suffix in test.tsx test.ts integration.tsx unit.ts spec.ts; do
      [ -f "$repo_root/${base}.${suffix}" ] && has_test=true && break
    done
    if [ "$has_test" = false ]; then
      errors="$errors\n[orchestration] NEW FILE WITHOUT TEST: $(basename "$f")"
    fi
  done
fi

# Gate: Run related tests if vitest available
if [ -n "$changed_js" ] && [ -f "$repo_root/node_modules/.bin/vitest" ]; then
  test_exit=0
  test_output=$(cd "$repo_root" && vitest run --related $changed_js 2>&1) || test_exit=$?
  if [ $test_exit -ne 0 ]; then
    errors="$errors\n[orchestration] TESTS FAILING: $(echo "$test_output" | tail -5)"
  fi
fi

if [ -n "$errors" ]; then
  truncated=$(printf '%b' "$errors" | head -30)
  reason=$(_safe_json_escape "$(printf "Code quality checks found issues. Fix before finishing:\n%s" "$truncated")")
  echo "{\"decision\":\"block\",\"reason\":$reason}" >&2
  exit 2
fi

exit 0
