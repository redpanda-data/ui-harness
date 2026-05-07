#!/bin/bash
set -eo pipefail
_lib="$(dirname "$0")/_hook-lib.sh"; if [ -f "$_lib" ]; then source "$_lib"; else _m="${TMPDIR:-/tmp}/frontend-skills-broken.${CLAUDE_SESSION_ID:-fs}"; [ -f "$_m" ] || { echo "[frontend-skills] _hook-lib.sh unavailable - run: /plugin install frontend-skills --force" >&2; touch "$_m" 2>/dev/null; }; exit 0; fi

# PostToolUse Bash: warnings in passing test/lint/type output are violations.
# "Green != done". Scan stdout+stderr of vitest/playwright/tsgo/biome/bun test
# exit-zero runs for curated warning patterns. Emit nudge with file:line.
# Third consecutive same-kind → escalate via consecutive-failure chain.
#
# Escape: set TEST_WARNINGS_ALLOW=1 in env or add `// allow: test-warning` to
# the specific test file for intentional deprecation-coverage tests.

input=$(cat 2>/dev/null || echo '{}')
tool=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
[ "$tool" = "Bash" ] || exit 0

command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null | tr '\n' ' ')
[ -n "$command" ] || exit 0

exit_code=$(echo "$input" | jq -r '.tool_response.exit_code // .tool_result.exit_code // 0' 2>/dev/null)
[ "$exit_code" = "0" ] || exit 0

case "$command" in
  *vitest*|*"bun test"*|*"bun run test"*|*playwright*|*tsgo*|*tsc*|*"type:check"*|*biome*|*"lint"*) ;;
  *) exit 0 ;;
esac

[ "${TEST_WARNINGS_ALLOW:-0}" = "1" ] && exit 0

stdout=$(echo "$input" | jq -r '.tool_response.stdout // .tool_result.stdout // empty' 2>/dev/null)
stderr=$(echo "$input" | jq -r '.tool_response.stderr // .tool_result.stderr // empty' 2>/dev/null)
output="${stdout}
${stderr}"
[ -n "${output// /}" ] || exit 0

# Curated pattern → label map. Each line: "regex||label"
_findings=""
_kind=""

_scan() {
  local re="$1" label="$2"
  local hits
  hits=$(printf '%s' "$output" | grep -nE "$re" 2>/dev/null | head -3 || true)
  if [ -n "$hits" ]; then
    _kind="$label"
    _findings="${_findings}${label}: $(printf '%s' "$hits" | head -1 | cut -c1-160)
"
  fi
}

# Node runtime warnings
_scan '\(node:[0-9]+\) [A-Z][a-zA-Z]*Warning' 'node-runtime-warning'
_scan 'DeprecationWarning:' 'deprecation'
_scan 'ExperimentalWarning:' 'experimental-api'
_scan 'MaxListenersExceededWarning|PossibleEventEmitterMemoryLeak' 'memory-leak'
_scan 'UnhandledPromiseRejection|Unhandled promise rejection|Unhandled Rejection' 'unhandled-rejection'
_scan 'UnhandledError|Unhandled Errors' 'unhandled-error'

# React warnings (dev-mode)
_scan 'Warning: An update to .* inside a test was not wrapped in act' 'react-act'
_scan 'Warning: ReactDOM\.render|Warning: ReactDOMTestUtils' 'react-legacy-api'
_scan 'Warning: Each child in a list should have a unique "key"' 'react-missing-key'
_scan 'Warning: validateDOMNesting' 'react-dom-nesting'
_scan 'Warning: Failed prop type' 'react-prop-type'
_scan 'Warning: Cannot update a component .* while rendering' 'react-bad-setstate'
_scan 'Warning: Received .* for a non-boolean attribute' 'react-bad-attr'

# Vitest / test-runner signals
_scan '^\s*stderr \| ' 'stderr-during-test'
_scan 'Tests skipped\s*[0-9]+' 'skipped-tests'
_scan '\[vitest\].*warn' 'vitest-warn'

# Playwright
_scan 'playwright.*warning|Test ended with interrupted' 'playwright-warn'

# TypeScript suppression (green run that still contained a silenced error)
_scan '@ts-expect-error' 'ts-expect-error'
_scan '@ts-ignore' 'ts-ignore'

if [ -z "$_findings" ]; then
  _hook_log_entry "info" "no-warnings" test-warning-check
  exit 0
fi

# Per-file escape: grep the output for test paths that opt out.
# If ALL finding lines reference files containing `// allow: test-warning`,
# suppress. Conservative: any finding without the escape → emit.
_emit=true
_paths=$(printf '%s' "$_findings" | grep -oE '[^ ]+\.(ts|tsx|js|jsx|spec|test)[^ :]*' | sort -u || true)
if [ -n "$_paths" ]; then
  _all_escaped=true
  while IFS= read -r _p; do
    [ -z "$_p" ] && continue
    [ -f "$_p" ] || { _all_escaped=false; break; }
    if ! grep -qE '//\s*allow:\s*test-warning\b' "$_p" 2>/dev/null; then
      _all_escaped=false
      break
    fi
  done <<< "$_paths"
  [ "$_all_escaped" = true ] && _emit=false
fi

$_emit || { _hook_log_entry "info" "all-escaped" test-warning-check; exit 0; }

# Streak tracking per kind — 3rd consecutive same-kind escalates
_streak_file="$_hook_session_dir/warning-streak"
_last_kind=$(cat "$_streak_file" 2>/dev/null | head -1 || true)
_streak=$(cat "$_streak_file" 2>/dev/null | tail -1 2>/dev/null | tr -d '[:space:]' || true)
[ -z "$_streak" ] && _streak=0
if [ "$_kind" = "$_last_kind" ]; then
  _streak=$((_streak + 1))
else
  _streak=1
fi
printf '%s\n%s\n' "$_kind" "$_streak" > "$_streak_file" 2>/dev/null || true

# Compact message; reporters already markdown-lean
_sample=$(printf '%s' "$_findings" | head -5)
_msg="Green run but warnings present (${_kind}). Fix before calling tests clean:
$_sample
Remediate or add \`// allow: test-warning\` to the test file with reason."

if [ "$_streak" -ge 3 ]; then
  _msg="${_msg}
[${_streak}x same warning — STOP rerunning. Read ALL, fix at source, then one clean run.]"
fi

_hook_log_entry "nudge" "$_kind" test-warning-check
_escaped=$(_safe_json_escape "$_msg")
echo "{\"suppressOutput\":true,\"systemMessage\":${_escaped}}" >&2
exit 0
