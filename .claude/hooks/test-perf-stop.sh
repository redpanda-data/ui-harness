#!/bin/bash
set -eo pipefail

# Stop hook: detect test performance improvements/regressions.
# Compares per-test durations against session-start baseline captured
# by session-env.sh. Non-blocking — outputs audit table as context.

source "$(dirname "$0")/../../shared/hook-lib.sh" 2>/dev/null || true

baseline="$_hook_session_dir/test-timing-baseline.tsv"

# Baseline is captured in background at SessionStart (session-env.sh).
# By the time Stop hooks fire, the session has been running for minutes —
# the baseline is ready. If not, skip gracefully rather than sleeping.


if [ ! -f "$baseline" ] || [ ! -s "$baseline" ]; then
  exit 0
fi

# Session-scoped: only audit files this session touched
if type hook_session_changed_files &>/dev/null; then
  changed_files=$(hook_session_changed_files "ts|tsx")
else
  changed_files=$(git diff --name-only HEAD 2>/dev/null | grep -E '\.(ts|tsx)$' || true)
fi

if [ -z "$changed_files" ]; then
  exit 0
fi

# Need vitest configs to run
vitest_configs=$(find . -maxdepth 1 -name 'vitest.config.*' 2>/dev/null | head -5)
if [ -z "$vitest_configs" ]; then
  exit 0
fi

# Build absolute paths for --related
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
abs_changed=""
for f in $changed_files; do
  abs_changed="$abs_changed $repo_root/$f"
done

# Run related tests with JSON reporter for each vitest config
current_tsv="$_hook_session_dir/test-timing-current.tsv"
: > "$current_tsv"

for cfg in $vitest_configs; do
  bun vitest --run --reporter=json --config "$cfg" --related $abs_changed 2>/dev/null \
    | jq -r '.testResults[]?.assertionResults[]? | [.fullName, (.duration // 0 | tostring)] | @tsv' \
    >> "$current_tsv" 2>/dev/null || true
done

if [ ! -s "$current_tsv" ]; then
  rm -f "$current_tsv"
  exit 0
fi

# Compare: find tests with >30% timing change AND baseline >10ms
# Positive pct = faster, negative = slower
audit=$(awk -F'\t' '
  NR==FNR { baseline[$1] = $2 + 0; next }
  {
    name = $1
    current = $2 + 0
    if (name in baseline) {
      before = baseline[name]
      if (before > 10) {
        diff = before - current
        if (before > 0) pct = (diff / before) * 100
        else pct = 0
        abs_diff = diff < 0 ? -diff : diff
        if ((pct > 30 || pct < -30) && abs_diff > 5) {
          if (before < 1) bs = "<1ms"; else bs = sprintf("%dms", before)
          if (current < 1) cs = "<1ms"; else cs = sprintf("%dms", current)
          printf "%s\t%s\t%s\t%+.0f%%\n", name, bs, cs, pct
        }
      }
    }
  }
' "$baseline" "$current_tsv")

rm -f "$current_tsv"

if [ -z "$audit" ]; then
  exit 0
fi

# Count improvements vs regressions
improvements=$(echo "$audit" | awk -F'\t' '{v=$4+0; if(v>0) c++} END{print c+0}')
regressions=$(echo "$audit" | awk -F'\t' '{v=$4+0; if(v<0) c++} END{print c+0}')

# Build header
header="Test Performance Audit:"
if [ "$improvements" -gt 0 ] && [ "$regressions" -eq 0 ]; then
  header="$header $improvements test(s) faster"
elif [ "$regressions" -gt 0 ] && [ "$improvements" -eq 0 ]; then
  header="$header $regressions test(s) slower"
elif [ "$improvements" -gt 0 ] && [ "$regressions" -gt 0 ]; then
  header="$header $improvements faster, $regressions slower"
fi

# Build markdown table
table="$header\\n\\nTest | Before | After | Change\\n--- | --- | --- | ---"
while IFS=$'\t' read -r name before after pct; do
  table="$table\\n$name | $before | $after | $pct"
done <<< "$audit"

# Add regression warning if needed
if [ "$regressions" -gt 0 ]; then
  table="$table\\n\\nWARNING: Test regressions detected. Consider investigating before finishing."
fi

msg=$(_safe_json_escape "$table")
echo "{\"hookSpecificOutput\":{\"additionalContext\":$msg}}" >&2

# ── Slow test detection ──────────────────────────────────────────
# Flag individual tests exceeding thresholds: unit >500ms, integration >2s.
# Uses current run data (not comparison).

slow_tests=""
while IFS=$'\t' read -r name duration; do
  dur_int=${duration%.*}
  [ -z "$dur_int" ] && continue
  if [ "$dur_int" -gt 2000 ]; then
    slow_tests="${slow_tests}\n  ${name}: ${dur_int}ms (>2s)"
  elif [ "$dur_int" -gt 500 ]; then
    # Only flag as slow for unit tests (no DOM env)
    slow_tests="${slow_tests}\n  ${name}: ${dur_int}ms (>500ms)"
  fi
done < <(awk -F'\t' '{print $1 "\t" $2}' "$baseline" 2>/dev/null || true)

if [ -n "$slow_tests" ]; then
  slow_msg=$(_safe_json_escape "$(printf "Slow tests detected:%b\nConsider: smaller scope, fewer re-renders, mock heavy deps, or .concurrent for independent tests." "$slow_tests")")
  echo "{\"hookSpecificOutput\":{\"additionalContext\":$slow_msg}}" >&2
fi

# ── Async leak detection ─────────────────────────────────────────
# Auto-run --detectAsyncLeaks on session-touched test files.

_vitest_bin="vitest"
[ -x "./node_modules/.bin/vitest" ] && _vitest_bin="./node_modules/.bin/vitest"

if command -v "$_vitest_bin" &>/dev/null || [ -x "$_vitest_bin" ]; then
  leak_output=$($_vitest_bin run --detectAsyncLeaks --related $abs_changed 2>&1 || true)
  leak_warnings=$(echo "$leak_output" | grep -iE 'async.*leak|open handle|did not close' || true)

  if [ -n "$leak_warnings" ]; then
    leak_sample=$(echo "$leak_warnings" | head -5 | tr '\n' ' ')
    leak_msg=$(_safe_json_escape "$(printf "Async leak detected: %s\nFix open handles (timers, connections, listeners) before finishing." "$leak_sample")")
    echo "{\"hookSpecificOutput\":{\"additionalContext\":$leak_msg}}" >&2
  fi
fi

exit 0
