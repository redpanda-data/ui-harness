#!/bin/bash
set -eo pipefail

# Stop hook: comprehensive quality gate. Reads file categories tracked by
# orchestration-guidance.sh and runs targeted checks. Blocks until truly done.
#
# Set ORCHESTRATION_STRICT=0 to disable blocking (e.g., during prototyping).
# Default: on (blocks on missing tests, security issues, async leaks).

if [ "${ORCHESTRATION_STRICT:-1}" = "0" ]; then
  exit 0
fi

session_files="/tmp/hook-session-${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-$$}}/files"

# Source hook-lib for session-scoped file tracking
source "$(dirname "$0")/source-hook-lib.sh" 2>/dev/null || true

# Session-scoped: only check files this session touched
if type hook_session_changed_files &>/dev/null; then
  changed=$(hook_session_changed_files)
else
  changed=$(git diff --name-only HEAD 2>/dev/null || true)
fi
issues=""

# Pre-flight checks
if [ ! -d ".git" ]; then exit 0; fi
if [ -z "$changed" ] && [ ! -f "$session_files" ]; then
  exit 0
fi

# Check if typecheck-stop already ran related tests (avoid double-running)
stop_outcome_file="/tmp/hook-session-${CLAUDE_SESSION_ID:-${CODEX_SESSION_ID:-$$}}/last-stop"
typecheck_ran_tests=false
if [ -f "$stop_outcome_file" ] && grep -q "tests PASS\|tests FAIL" "$stop_outcome_file" 2>/dev/null; then
  typecheck_ran_tests=true
fi

# ── Gate 1: Test files changed → check for async leaks ──────────

if [ -f "$session_files" ] && grep -q "^test:" "$session_files" 2>/dev/null; then
  test_files=$(grep "^test:" "$session_files" | cut -d: -f2- | sort -u | tr '\n' ' ')

  # Check for async leaks if vitest available
  if [ -f "node_modules/.bin/vitest" ] && [ -n "$test_files" ]; then
    leak_output=""
    leak_exit=0
    leak_output=$(vitest run --detectAsyncLeaks $test_files 2>&1) || leak_exit=$?
    if [ $leak_exit -ne 0 ] && echo "$leak_output" | grep -qiE 'leak|open handle|did not exit'; then
      issues="$issues\n- ASYNC LEAK. vitest run --detectAsyncLeaks"
    fi
  fi
fi

# ── Gate 1b: Run related tests (Bazel-style — only affected tests) ────

if [ "$typecheck_ran_tests" = false ] && [ -n "$changed" ]; then
  changed_source=$(echo "$changed" | grep -E '\.(ts|tsx)$' | grep -vE '(\.test\.|\.spec\.|\.unit\.|\.integration\.|\.d\.ts$|\.gen\.)' || true)
  if [ -n "$changed_source" ] && [ -f "node_modules/.bin/vitest" ]; then
    test_exit=0
    test_output=$(vitest run --related $changed_source 2>&1) || test_exit=$?
    if [ $test_exit -ne 0 ]; then
      truncated=$(echo "$test_output" | tail -10)
      issues="$issues\n- TESTS FAIL. Fix:\n  $truncated"
    fi
  fi
fi

# ── Gate 2: JSX/TSX source changed → verify co-located test ─────

if [ -f "$session_files" ] && grep -q "^jsx:" "$session_files" 2>/dev/null; then
  jsx_files=$(grep "^jsx:" "$session_files" | cut -d: -f2- | sort -u)
  for f in $jsx_files; do
    # Skip files that don't need tests
    if echo "$f" | grep -qE '(index\.|layout\.|middleware\.|types/|\.d\.ts|__root|\.gen\.|providers?\.|constants?\.|theme\.|context\.|config\.)'; then
      continue
    fi
    base="${f%.*}"
    has_test=false
    for suffix in test.tsx test.ts integration.tsx unit.ts spec.ts; do
      if [ -f "${base}.${suffix}" ]; then
        has_test=true
        break
      fi
    done
    if [ "$has_test" = false ]; then
      short_name=$(basename "$f")
      # Warn, not block — prototyping often creates files before tests
      warnings="${warnings:-}\n- NO TEST: $short_name. /tdd"
    fi
  done
fi

# ── Gate 3: New source files → verify they have tests ────────────

# Session-scoped: only consider new files this session created
_all_new=$(git diff --name-only --diff-filter=A HEAD 2>/dev/null | grep -E '\.(ts|tsx)$' | grep -vE '(\.test\.|\.spec\.|\.unit\.|\.integration\.|\.d\.ts$|\.gen\.|index\.|layout\.|middleware\.|types/|__root)' || true)
if hook_has_session_tracking 2>/dev/null && [ -n "$_all_new" ]; then
  # Intersect new files with session-touched files
  _touched="$_hook_session_dir/session-touched-files"
  if [ -f "$_touched" ]; then
    _repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    # Defense-in-depth: skip secondary-worktree paths before normalizing.
    # _hook-lib.sh filters at write time; guard here for stale entries.
    _touched_norm=$(
      while IFS= read -r _p; do
        [ -z "$_p" ] && continue
        if type _hook_in_secondary_worktree &>/dev/null && _hook_in_secondary_worktree "$_p"; then
          continue
        fi
        echo "${_p#"${_repo_root}"/}"
      done < "$_touched" | sort -u
    )
    new_files=$(comm -12 <(echo "$_all_new" | sort) <(echo "$_touched_norm") 2>/dev/null || echo "$_all_new")
  else
    new_files="$_all_new"
  fi
else
  new_files="$_all_new"
fi
if [ -n "$new_files" ]; then
  for f in $new_files; do
    base="${f%.*}"
    has_test=false
    for suffix in test.tsx test.ts integration.tsx unit.ts spec.ts; do
      if [ -f "${base}.${suffix}" ] || echo "$changed" | grep -q "${base}.${suffix}"; then
        has_test=true
        break
      fi
    done
    if [ "$has_test" = false ]; then
      short_name=$(basename "$f")
      warnings="${warnings:-}\n- NEW: $short_name — no test. /tdd"
    fi
  done
fi

# ── Gate 4: Security-sensitive files → extra scrutiny ────────────

if [ -f "$session_files" ] && grep -q "^security:" "$session_files" 2>/dev/null; then
  security_files=$(grep "^security:" "$session_files" | cut -d: -f2- | sort -u)
  for f in $security_files; do
    if [ -f "$f" ]; then
      if grep -qE '(eval\(|new Function\(|dangerouslySetInnerHTML|\.innerHTML\s*=)' "$f" 2>/dev/null; then
        if ! grep -qE '(allow-dangerouslySetInnerHTML|allow:\s*dangerouslySetInnerHTML|allow-eval|allow:\s*eval)' "$f" 2>/dev/null; then
          short_name=$(basename "$f")
          issues="$issues\n- SECURITY: $short_name — eval/innerHTML. Fix or escape hatch."
        fi
      fi
      if grep -qE "(password|secret|api.?key)\s*[:=]\s*['\"][^'\"]{3,}" "$f" 2>/dev/null; then
        short_name=$(basename "$f")
        issues="$issues\n- SECURITY: $short_name — hardcoded secrets. @/env."
      fi
    fi
  done
fi

# ── Decision ─────────────────────────────────────────────────────

# Hard issues (async leaks, security, failing tests) → write to shared findings
if [ -n "$issues" ]; then
  hook_stop_finding "$(printf "Orchestration:%b" "$issues")"
fi

# Check if source changed but no test files were touched
# Use tr -d to strip newlines — grep -c can embed \n when $changed has trailing blank lines
changed_source_count=$(echo "$changed" | grep -E '\.(ts|tsx)$' | grep -vcE '(\.test\.|\.spec\.)' 2>/dev/null | tr -d '[:space:]')
changed_source_count="${changed_source_count:-0}"
changed_test_count=$(echo "$changed" | grep -cE '\.(test|spec)\.(ts|tsx)$' 2>/dev/null | tr -d '[:space:]')
changed_test_count="${changed_test_count:-0}"
if [ "$changed_source_count" -gt 0 ] 2>/dev/null && [ "$changed_test_count" -eq 0 ] 2>/dev/null; then
  warnings="${warnings:-}\n- No tests modified. /tdd"
fi

# Soft warnings (missing tests) → inform but don't block
if [ -n "${warnings:-}" ]; then
  context=$(_safe_json_escape "$(printf "Suggestions:\n%s" "$(printf '%b' "$warnings" | head -10)")")
  echo "{\"hookSpecificOutput\":{\"additionalContext\":$context}}" >&2
fi

# Clean up session tracking
rm -f "$session_files" 2>/dev/null || true

exit 0
